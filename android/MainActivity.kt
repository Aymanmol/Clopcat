// android/app/src/main/kotlin/com/example/cutline/MainActivity.kt
package com.example.cutline

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.SonicAudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.SpeedChangeEffect
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.*
import com.google.common.collect.ImmutableList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Full-frame transparent bitmap with the text drawn at its final pixel position, so the result does not
 * depend on how Media3 sizes overlays. Outside [startUs, endUs) a 1x1 transparent bitmap is returned.
 */
@UnstableApi
private class TimedText(
    text: String, sizePx: Float, argb: Int, x: Float, y: Float,
    private val startUs: Long, private val endUs: Long, w: Int, h: Int
) : BitmapOverlay() {
    private val shown: Bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also { bmp ->
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.color = argb
        p.textSize = sizePx
        p.typeface = Typeface.DEFAULT_BOLD
        p.textAlign = Paint.Align.CENTER
        p.setShadowLayer(sizePx * 0.06f, 0f, sizePx * 0.03f, Color.BLACK)
        val fm = p.fontMetrics
        Canvas(bmp).drawText(text, x * w, y * h - (fm.ascent + fm.descent) / 2f, p)
    }
    private val blank: Bitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
    override fun getBitmap(presentationTimeUs: Long): Bitmap =
        if (presentationTimeUs in startUs until endUs) shown else blank
}

@UnstableApi
class MainActivity : FlutterActivity() {

    /** Output canvas: 720x1280 if the first clip is portrait, else 1280x720 (same rule as iOS). */
    private fun canvasFor(path: String): Pair<Int, Int> {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            var w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)!!.toInt()
            var h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)!!.toInt()
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
            if (rot == 90 || rot == 270) { val t = w; w = h; h = t }
            return if (h > w) 720 to 1280 else 1280 to 720
        } finally {
            r.release()
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "cutline/export").setMethodCallHandler { call, result ->
            if (call.method != "export") return@setMethodCallHandler result.notImplemented()
            try {
                val out = call.argument<String>("out")!!
                val clipArgs = call.argument<List<Map<String, Any>>>("clips")!!
                val textArgs = call.argument<List<Map<String, Any>>>("texts") ?: emptyList()
                val (cw, chh) = canvasFor(clipArgs.first()["path"] as String)

                val items = clipArgs.map { m ->
                    val speed = (m["speed"] as Number).toFloat()
                    val range = MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs((m["start"] as Number).toLong())
                        .setEndPositionMs((m["end"] as Number).toLong()).build()
                    val media = MediaItem.Builder().setUri(Uri.fromFile(File(m["path"] as String)))
                        .setClippingConfiguration(range).build()
                    val b = EditedMediaItem.Builder(media).setRemoveAudio(m["mute"] as Boolean)
                    if (speed != 1f) {
                        val sonic = SonicAudioProcessor().apply { setSpeed(speed) }
                        b.setEffects(Effects(listOf(sonic), listOf(SpeedChangeEffect(speed))))
                    }
                    b.build()
                }

                val overlays: List<TextureOverlay> = textArgs.map { t ->
                    TimedText(
                        t["text"] as String,
                        (t["size"] as Number).toFloat() * chh,
                        (t["color"] as Number).toLong().toInt(),
                        (t["x"] as Number).toFloat(), (t["y"] as Number).toFloat(),
                        (t["start"] as Number).toLong() * 1000, (t["end"] as Number).toLong() * 1000,
                        cw, chh
                    )
                }
                val videoEffects = mutableListOf<Effect>(
                    Presentation.createForWidthAndHeight(cw, chh, Presentation.LAYOUT_SCALE_TO_FIT)
                )
                if (overlays.isNotEmpty()) videoEffects.add(OverlayEffect(ImmutableList.copyOf(overlays)))

                val composition = Composition.Builder(listOf(EditedMediaItemSequence(items)))
                    .setEffects(Effects(emptyList(), videoEffects)).build()
                File(out).delete()
                Transformer.Builder(this)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(c: Composition, r: ExportResult) = result.success(out)
                        override fun onError(c: Composition, r: ExportResult, e: ExportException) =
                            result.error("EXPORT", e.message, null)
                    }).build().start(composition, out)
            } catch (e: Exception) {
                result.error("EXPORT", e.message, null)
            }
        }
    }
}
