import 'package:flutter/material.dart';

class ExportProgressDialog extends StatefulWidget {
  final VoidCallback onCancel;

  const ExportProgressDialog({Key? key, required this.onCancel}) : super(key: key);

  @override
  _ExportProgressDialogState createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<ExportProgressDialog> {
  double _progress = 0.0;
  bool _isExporting = true;

  @override
  void initState() {
    super.initState();
    _simulateExportProgress();
  }

  void _simulateExportProgress() async {
    for (int i = 0; i <= 100; i += 5) {
      if (!_isExporting) return;
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _progress = i / 100;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'جاري تصدير الفيديو وتطبيق الطبقات...',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white12,
                color: Colors.blueAccent,
                minHeight: 8,
              ),
              const SizedBox(height: 10),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _isExporting = false);
                      widget.onCancel();
                      Navigator.of(context).pop();
                    },
                    child: const Text('إلغاء التصدير', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
