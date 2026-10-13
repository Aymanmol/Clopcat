import 'package:flutter/material.dart';

class TimelineToolbar extends StatelessWidget {
  final VoidCallback onSplitPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onUndoPressed;

  const TimelineToolbar({
    Key? key,
    required this.onSplitPressed,
    required this.onDeletePressed,
    required this.onUndoPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.call_split, color: Colors.white),
            tooltip: 'تقسيم المقطع (Split)',
            onPressed: onSplitPressed,
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'حذف الطبقة',
            onPressed: onDeletePressed,
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white70),
            tooltip: 'تراجع',
            onPressed: onUndoPressed,
          ),
        ],
      ),
    );
  }
}
