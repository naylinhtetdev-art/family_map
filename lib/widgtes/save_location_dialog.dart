// Controller ရဲ့ Lifecycle ကို သီးသန့် ထိန်းချုပ်ပေးမည့် Dialog Widget
import 'package:flutter/material.dart';

class SaveLocationDialog extends StatefulWidget {
  final String initialText;

  const SaveLocationDialog({required this.initialText});

  @override
  State<SaveLocationDialog> createState() => _SaveLocationDialogState();
}

class _SaveLocationDialogState extends State<SaveLocationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller
        .dispose(); // Dialog လုံးဝ ပိတ်သွားမှသာ စိတ်ချလက်ချ dispose လုပ်မည်
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Location'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Location Name',
          hintText: 'Enter place name',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _controller.text.trim();
            Navigator.pop(context, text.isNotEmpty ? text : 'Saved Location');
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
