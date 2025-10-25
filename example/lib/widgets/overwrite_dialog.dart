import 'package:flutter/material.dart';

enum OverwriteAction { overwrite, rename, cancel }

/// Dialog shown when a file with the chosen name already exists
class OverwriteDialog extends StatelessWidget {
  final String filename;

  const OverwriteDialog({
    Key? key,
    required this.filename,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C3E50),
      title: Row(
        children: [
          Icon(
            Icons.warning,
            color: Colors.orange.shade400,
            size: 28,
          ),
          const SizedBox(width: 10),
          const Text(
            'File Exists',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A file named "$filename" already exists.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          const Text(
            'What would you like to do?',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(OverwriteAction.cancel);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
          ),
          onPressed: () {
            Navigator.of(context).pop(OverwriteAction.rename);
          },
          child: const Text(
            'Rename',
            style: TextStyle(color: Colors.white),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
          ),
          onPressed: () {
            Navigator.of(context).pop(OverwriteAction.overwrite);
          },
          child: const Text(
            'Overwrite',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
