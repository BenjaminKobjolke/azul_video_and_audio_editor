import 'package:flutter/material.dart';

/// Dialog for asking user for filename when saving media
class SaveFilenameDialog extends StatefulWidget {
  final String suggestedFilename;
  final String? fileExtension; // Optional extension to show (locked)

  const SaveFilenameDialog({
    Key? key,
    required this.suggestedFilename,
    this.fileExtension,
  }) : super(key: key);

  @override
  _SaveFilenameDialogState createState() => _SaveFilenameDialogState();
}

class _SaveFilenameDialogState extends State<SaveFilenameDialog> {
  late TextEditingController _filenameController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _filenameController = TextEditingController(text: widget.suggestedFilename);
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  bool _validateFilename(String filename) {
    if (filename.isEmpty) {
      setState(() {
        _errorMessage = 'Filename cannot be empty';
      });
      return false;
    }

    // Check for invalid characters
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    if (invalidChars.hasMatch(filename)) {
      setState(() {
        _errorMessage = 'Filename contains invalid characters';
      });
      return false;
    }

    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C3E50),
      title: const Text(
        'Save Media File',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter filename:',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filenameController,
                  style: const TextStyle(color: Colors.white),
                  autofocus: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Enter filename',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    errorText: _errorMessage,
                  ),
                  onChanged: (value) {
                    _validateFilename(value);
                  },
                  onSubmitted: (value) {
                    if (_validateFilename(value)) {
                      Navigator.of(context).pop(value);
                    }
                  },
                ),
              ),
              if (widget.fileExtension != null) ...[
                const SizedBox(width: 4),
                Text(
                  widget.fileExtension!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A11CB),
          ),
          onPressed: () {
            if (_validateFilename(_filenameController.text)) {
              Navigator.of(context).pop(_filenameController.text);
            }
          },
          child: const Text(
            'Save',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
