import 'package:flutter/material.dart';

void showSuccessDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 30),
          SizedBox(width: 10),
          Text("Success"),
        ],
      ),
      content: const Text("Your password has been changed successfully."),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close Dialog
          },
          child: const Text("OK"),
        ),
      ],
    ),
  );
}
