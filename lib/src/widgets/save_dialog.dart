import 'package:flutter/material.dart';
import '../models/azul_editor_strings.dart';

/// Dialog for saving media with overwrite/rename options
class SaveMediaDialog extends StatefulWidget {
  final String originalFilename;
  final String suggestedFilename;
  final bool fileExists;
  final AzulEditorStrings strings;

  const SaveMediaDialog({
    Key? key,
    required this.originalFilename,
    required this.suggestedFilename,
    required this.fileExists,
    this.strings = const AzulEditorStrings(),
  }) : super(key: key);

  @override
  _SaveMediaDialogState createState() => _SaveMediaDialogState();
}

class _SaveMediaDialogState extends State<SaveMediaDialog> {
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
        _errorMessage = widget.strings.saveDialogErrorEmpty;
      });
      return false;
    }

    // Check for invalid characters
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    if (invalidChars.hasMatch(filename)) {
      setState(() {
        _errorMessage = widget.strings.saveDialogErrorInvalidChars;
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
      title: Text(
        widget.strings.saveDialogTitle,
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.strings.saveDialogEnterFilename,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _filenameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              hintText: widget.strings.saveDialogHint,
              hintStyle: TextStyle(color: Colors.grey.shade500),
              errorText: _errorMessage,
            ),
            onChanged: (value) {
              _validateFilename(value);
            },
          ),
          if (widget.fileExists) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.orange.shade400,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.strings.saveDialogFileExists,
                    style: TextStyle(
                      color: Colors.orange.shade400,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: Text(
            widget.strings.saveDialogCancel,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        if (widget.fileExists)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            onPressed: () {
              if (_validateFilename(_filenameController.text)) {
                Navigator.of(context).pop({
                  'filename': _filenameController.text,
                  'overwrite': true,
                });
              }
            },
            child: Text(
              widget.strings.saveDialogOverwrite,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A11CB),
          ),
          onPressed: () {
            if (_validateFilename(_filenameController.text)) {
              Navigator.of(context).pop({
                'filename': _filenameController.text,
                'overwrite': false,
              });
            }
          },
          child: Text(
            widget.strings.saveDialogSave,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
