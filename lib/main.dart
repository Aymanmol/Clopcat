import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true)
          .copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFF5C82))),
      home: const Editor(),
    ));

/// One timeline clip: a trimmed range of a source file plus per-clip settings.
/// (Renamed from `Clip`, which collides with Flutter's own `Clip` enum.)
class EditClip {
  EditClip(this.path, this.srcMs) : endMs = srcMs;
  factory EditClip.fromJson(Map<String, dynamic> j) => EditClip(j['path'] as String, j['srcMs'] as int)
    ..startMs = j['start'] as int
    ..endMs = j['end'] as int
    ..speed = (j['speed'] as num).toDouble()
    ..mute = j['mute'] as bool;
  final String path;
  final int srcMs;
  int startMs = 0, endMs;
  double speed = 1;
  bool mute = false;
  int get outMs => ((endMs - startMs) / speed).round();
  EditClip copy() => EditClip(path, srcMs)
    ..startMs = startMs
    ..endMs = endMs
    ..speed = speed
    ..mute = mute;
  Map<String, Object> toJson() =>
      {'path': path, 'srcMs': srcMs, 'start': startMs, 'end': endMs, 'speed': speed, 'mute': mute};
}

String fmt(int ms) => '${(ms / 1000).toStringAsFixed(1)}s';

/// A text overlay on the project timeline (project time = after clip speed is applied).
/// x, y are the text CENTER as a fraction of the frame; size is a fraction of frame height.
class TextLayer {
  TextLayer(this.text, this.startMs, this.endMs);
  factory TextLayer.fromJson(Map<String, dynamic> j) =>
      TextLayer(j['text'] as String, j['start'] as int, j['end'] as int)
        ..x = (j['x'] as num).toDouble()
        ..y = (j['y'] as num).toDouble()
        ..size = (j['size'] as num).toDouble()
        ..color = j['color'] as int;
  String text;
  int startMs, endMs;
  double x = .5, y = .8, size = .06;
  int color = 0xFFFFFFFF;
  Map<String, Object> toJson([int? end]) =>
      {'text': text, 'start': startMs, 'end': end ?? endMs, 'x': x, 'y': y, 'size': size, 'color': color};
}

class Editor extends StatefulWidget {
  const Editor({super.key});
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  static const ch = MethodChannel('cutline/export'); // native Media3 / AVFoundation export
  final clips = <EditClip>[];
  final _undo = <String>[], _redo = <String>[];
  final texts = <TextLayer>[];
  int sel = 0;
  VideoPlayerController? vc;
  bool busy = false, switching = false;
  File? _store;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void msg(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  // ---- persistence: autosave after every edit, restore on launch ----
  Future<void> _boot() async {
    final dir = await getApplicationDocumentsDirectory();
    _store = File(p.join(dir.path, 'project.json'));
    try {
      if (await _store!.exists()) {
        final j = jsonDecode(await _store!.readAsString()) as Map<String, dynamic>;
        clips.addAll((j['clips'] as List)
            .map((e) => EditClip.fromJson(e as Map<String, dynamic>))
            .where((c) => File(c.path).existsSync()));
        sel = min((j['sel'] as int?) ?? 0, max(0, clips.length - 1));
        texts.addAll(((j['texts'] as List?) ?? []).map((e) => TextLayer.fromJson(e as Map<String, dynamic>)));
        if (clips.isNotEmpty) {
          msg('Restored your last project');
          await select(sel);
        }
      }
    } catch (_) {
      msg('Could not restore the last project');
    }
    if (mounted) setState(() {});
  }

  String _dump() => jsonEncode({
        'sel': sel,
        'clips': clips.map((c) => c.toJson()).toList(),
        'texts': texts.map((t) => t.toJson()).toList(),
      });
  void _save() => _store?.writeAsString(_dump());
  void _snap() {
    _undo.add(_dump());
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  Future<void> _restore(String s) async {
    final j = jsonDecode(s) as Map<String, dynamic>;
    clips
      ..clear()
      ..addAll((j['clips'] as List).map((e) => EditClip.fromJson(e as Map<String, dynamic>)));
    sel = min(j['sel'] as int, max(0, clips.length - 1));
    texts
      ..clear()
      ..addAll(((j['texts'] as List?) ?? []).map((e) => TextLayer.fromJson(e as Map<String, dynamic>)));
    if (clips.isEmpty) {
      await _drop();
      if (mounted) setState(() {});
    } else {
      await select(sel);
    }
    _save();
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    _redo.add(_dump());
    await _restore(_undo.removeLast());
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    _undo.add(_dump());
    await _restore(_redo.removeLast());
  }

  // ---- import: copy into app storage so the file survives cache cleanup ----
  Future<void> add() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (f == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final media = Directory(p.join(dir.path, 'media'))..createSync(recursive: true);
      final dest = p.join(media.path, '${DateTime.now().millisecondsSinceEpoch}_${p.basename(f.path)}');
      await File(f.path).copy(dest);
      final probe = VideoPlayerController.file(File(dest));
      await probe.initialize();
      final ms = probe.value.duration.inMilliseconds;
      await probe.dispose();
      _snap();
      clips.add(EditClip(dest, ms));
      _save();
      await select(clips.length - 1);
    } catch (e) {
      msg('Import failed: $e');
    }
  }

  Future<void> _drop() async {
    final old = vc;
    vc = null;
    old?.removeListener(tick);
    await old?.dispose();
  }

  Future<void> select(int i, {bool play = false}) async {
    if (switching) return;
    switching = true;
    sel = i;
    VideoPlayerController? n;
    try {
      await _drop();
      if (mounted) setState(() {});
      final c = clips[i];
      n = VideoPlayerController.file(File(c.path));
      await n.initialize();
      await n.setVolume(c.mute ? 0 : 1);
      await n.setPlaybackSpeed(c.speed);
      await n.seekTo(Duration(milliseconds: c.startMs));
      n.addListener(tick);
      vc = n;
      if (play) await n.play();
    } catch (e) {
      await n?.dispose();
      msg('Could not open this clip: $e');
    } finally {
      switching = false;
      if (mounted) setState(() {});
    }
  }

  /// Sequential preview: play each clip's trimmed range, then advance.
  void tick() {
    final v = vc;
    if (v == null || switching || sel >= clips.length) return;
    final c = clips[sel];
    if (v.value.isPlaying && v.value.position.inMilliseconds >= c.endMs) {
      if (sel + 1 < clips.length) {
        select(sel + 1, play: true);
        return;
      }
      v.pause();
      v.seekTo(Duration(milliseconds: c.startMs));
    }
    if (mounted) setState(() {});
  }

  void togglePlay() {
    final v = vc;
    if (v == null) return;
    if (v.value.isPlaying) {
      v.pause();
      return;
    }
    final c = clips[sel], pos = v.value.position.inMilliseconds;
    if (pos < c.startMs || pos >= c.endMs - 50) v.seekTo(Duration(milliseconds: c.startMs));
    v.play();
  }

  void split() {
    final v = vc;
    if (v == null) return;
    final pos = v.value.position.inMilliseconds, c = clips[sel];
    if (pos <= c.startMs + 200 || pos >= c.endMs - 200) return msg('Move the playhead inside the clip');
    _snap();
    clips.insert(sel + 1, c.copy()..startMs = pos);
    c.endMs = pos;
    _save();
    setState(() {});
  }

  Future<void> remove() async {
    _snap();
    clips.removeAt(sel);
    _save();
    if (clips.isEmpty) {
      sel = 0;
      await _drop();
      if (mounted) setState(() {});
    } else {
      await select(min(sel, clips.length - 1));
    }
  }

  void move(int d) {
    final j = sel + d;
    if (j < 0 || j >= clips.length) return;
    _snap();
    clips.insert(j, clips.removeAt(sel));
    sel = j;
    _save();
    setState(() {});
  }

  int get total => clips.fold<int>(0, (s, k) => s + k.outMs);

  /// Playhead position on the project timeline (accounts for earlier clips, trims and speed).
  int get nowMs {
    final v = vc;
    if (v == null || clips.isEmpty || sel >= clips.length) return 0;
    final c = clips[sel];
    final rel = ((v.value.position.inMilliseconds - c.startMs) / c.speed).round();
    return clips.take(sel).fold<int>(0, (s, k) => s + k.outMs) + min(max(rel, 0), c.outMs);
  }

  Future<void> addText() async {
    if (clips.isEmpty) {
      msg('Add a video first');
      return;
    }
    _snap();
    final tot = total, s = min(nowMs, max(0, tot - 500));
    texts.add(TextLayer('Text', s, min(s + 2000, tot)));
    _save();
    setState(() {});
    await _editText(texts.length - 1, snap: false);
  }

  Future<void> _editText(int i, {bool snap = true}) async {
    if (i >= texts.length) return;
    final t = texts[i], tc = TextEditingController(text: t.text), tot = max(total, 1);
    if (snap) _snap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void upd(VoidCallback f) {
          f();
          _save();
          setState(() {});
          setS(() {});
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: tc,
                maxLines: 1,
                decoration: const InputDecoration(labelText: 'Text'),
                onChanged: (s) => upd(() => t.text = s)),
            Row(children: [
              for (final col in [0xFFFFFFFF, 0xFFFFEB3B, 0xFFFF5252, 0xFF40C4FF, 0xFF000000])
                IconButton(onPressed: () => upd(() => t.color = col), icon: Icon(Icons.circle, color: Color(col))),
            ]),
            Row(children: [
              const Text('Size'),
              Expanded(
                  child: Slider(
                      min: .03,
                      max: .15,
                      value: t.size.clamp(.03, .15).toDouble(),
                      onChanged: (s) => upd(() => t.size = s))),
            ]),
            RangeSlider(
              min: 0,
              max: tot.toDouble(),
              values: RangeValues(min(t.startMs, tot).toDouble(), min(t.endMs, tot).toDouble()),
              labels: RangeLabels(fmt(t.startMs), fmt(t.endMs)),
              onChanged: (r) {
                if (r.end - r.start < 200) return;
                upd(() {
                  t.startMs = r.start.round();
                  t.endMs = r.end.round();
                });
              },
            ),
            TextButton.icon(
              onPressed: () {
                _snap();
                texts.removeAt(i);
                _save();
                setState(() {});
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete text'),
            ),
          ]),
        );
      }),
    );
    tc.dispose();
  }

  Future<void> export() async {
    if (clips.isEmpty || busy) return;
    setState(() => busy = true);
    await vc?.pause();
    try {
      final dir = await getTemporaryDirectory();
      final out = '${dir.path}/cutline_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final tot = total;
      await ch.invokeMethod('export', {
        'clips': clips.map((c) => c.toJson()).toList(),
        'texts': texts
            .where((t) => t.startMs < tot && t.text.isNotEmpty)
            .map((t) => t.toJson(min(t.endMs, tot)))
            .toList(),
        'out': out,
      });
      await Gal.putVideo(out);
      msg('Saved to your gallery');
    } on PlatformException catch (e) {
      msg('Export failed: ${e.message}');
    } catch (e) {
      msg('Could not save: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = vc, cs = Theme.of(context).colorScheme;
    final c = clips.isEmpty ? null : clips[sel];
    final total = clips.fold<int>(0, (s, k) => s + k.outMs);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cutline', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Undo', onPressed: _undo.isEmpty ? null : undo, icon: const Icon(Icons.undo)),
          IconButton(tooltip: 'Redo', onPressed: _redo.isEmpty ? null : redo, icon: const Icon(Icons.redo)),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: busy ? null : export,
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Export'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: v != null && v.value.isInitialized
                  ? GestureDetector(
                      onTap: togglePlay,
                      child: AspectRatio(
                          aspectRatio: v.value.aspectRatio,
                          child: Stack(fit: StackFit.expand, children: [VideoPlayer(v), _overlay()])))
                  : Text(clips.isEmpty ? 'Add a video to begin' : 'Loading…'),
            ),
          ),
          Text('${clips.length} clips, ${fmt(total)} total'),
          SizedBox(
            height: 72,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
              for (var i = 0; i < clips.length; i++)
                GestureDetector(
                  onTap: () => select(i),
                  child: Container(
                    width: (clips[i].outMs / 100).clamp(64, 400).toDouble(),
                    margin: const EdgeInsets.only(right: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: i == sel ? cs.primary : Colors.blueGrey.shade700,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(fmt(clips[i].outMs)),
                  ),
                ),
              IconButton.filled(onPressed: add, icon: const Icon(Icons.add)),
            ]),
          ),
          if (c != null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(tooltip: 'Move left', onPressed: () => move(-1), icon: const Icon(Icons.arrow_back)),
              IconButton(tooltip: 'Split at playhead', onPressed: split, icon: const Icon(Icons.content_cut)),
              IconButton(
                  tooltip: 'Mute',
                  onPressed: () {
                    _snap();
                    c.mute = !c.mute;
                    vc?.setVolume(c.mute ? 0 : 1);
                    _save();
                    setState(() {});
                  },
                  icon: Icon(c.mute ? Icons.volume_off : Icons.volume_up)),
              IconButton(tooltip: 'Add text', onPressed: addText, icon: const Icon(Icons.title)),
              IconButton(tooltip: 'Delete clip', onPressed: remove, icon: const Icon(Icons.delete_outline)),
              IconButton(tooltip: 'Move right', onPressed: () => move(1), icon: const Icon(Icons.arrow_forward)),
            ]),
            Wrap(spacing: 8, children: [
              for (final s in [0.5, 1.0, 2.0, 4.0])
                ChoiceChip(
                  label: Text('${s}x'),
                  selected: c.speed == s,
                  onSelected: (_) {
                    _snap();
                    c.speed = s;
                    vc?.setPlaybackSpeed(s);
                    _save();
                    setState(() {});
                  },
                ),
            ]),
            RangeSlider(
              min: 0,
              max: c.srcMs.toDouble(),
              values: RangeValues(c.startMs.toDouble(), c.endMs.toDouble()),
              labels: RangeLabels(fmt(c.startMs), fmt(c.endMs)),
              onChangeStart: (_) => _snap(),
              onChangeEnd: (_) => _save(),
              onChanged: (r) {
                if (r.end - r.start < 300) return;
                final startMoved = r.start.round() != c.startMs;
                setState(() {
                  c.startMs = r.start.round();
                  c.endMs = r.end.round();
                });
                vc?.seekTo(Duration(milliseconds: startMoved ? c.startMs : max(c.startMs, c.endMs - 500)));
              },
            ),
          ],
          if (texts.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
                for (var i = 0; i < texts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.title, size: 16),
                      label: Text(texts[i].text.isEmpty ? '(empty)' : texts[i].text),
                      onPressed: () => _editText(i),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  /// Text layers drawn over the preview. Drag to move, tap to edit.
  Widget _overlay() => LayoutBuilder(builder: (ctx, box) {
        final now = nowMs;
        return Stack(children: [
          for (var i = 0; i < texts.length; i++)
            if (now >= texts[i].startMs && now < texts[i].endMs)
              Positioned(
                left: texts[i].x * box.maxWidth,
                top: texts[i].y * box.maxHeight,
                child: FractionalTranslation(
                  translation: const Offset(-.5, -.5),
                  child: GestureDetector(
                    onTap: () => _editText(i),
                    onPanStart: (_) => _snap(),
                    onPanUpdate: (d) => setState(() {
                      texts[i].x = (texts[i].x + d.delta.dx / box.maxWidth).clamp(0.0, 1.0).toDouble();
                      texts[i].y = (texts[i].y + d.delta.dy / box.maxHeight).clamp(0.0, 1.0).toDouble();
                    }),
                    onPanEnd: (_) => _save(),
                    child: Text(
                      texts[i].text,
                      softWrap: false,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: texts[i].size * box.maxHeight,
                        fontWeight: FontWeight.w700,
                        color: Color(texts[i].color),
                        shadows: [
                          Shadow(
                              color: Colors.black,
                              blurRadius: texts[i].size * box.maxHeight * .06,
                              offset: Offset(0, texts[i].size * box.maxHeight * .03)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ]);
      });
}
