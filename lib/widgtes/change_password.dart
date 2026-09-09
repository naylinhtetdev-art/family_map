import 'package:family_map/widgtes/show_error_dialog.dart';
import 'package:family_map/widgtes/show_success_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

void showChangePasswordDialog(BuildContext context) {
  final formKey = GlobalKey<FormState>();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool obscureCurrent1 = true;
  bool obscureCurrent2 = true;
  bool obscureCurrent3 = true;
  // void showMessage(String message) {
  //   ScaffoldMessenger.of(context)
  //     ..hideCurrentSnackBar()
  //     ..showSnackBar(SnackBar(content: Text(message)));
  // }

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text("Change Password"),

        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                obscureText: obscureCurrent1,
                controller: currentPasswordController,
                //obscureText: true,
                decoration: InputDecoration(
                  labelText: "Current Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrent1 ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      obscureCurrent1 = !obscureCurrent1;
                      (dialogContext as Element).markNeedsBuild();
                    },
                  ),
                  //border: const UnderlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Current Password is required";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: newPasswordController,
                obscureText: obscureCurrent2,
                decoration: InputDecoration(
                  labelText: "New Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrent2 ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      obscureCurrent2 = !obscureCurrent2;
                      (dialogContext as Element).markNeedsBuild();
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "New Password is required";
                  }

                  if (value.length < 6) {
                    return "Password must be at least 6 characters";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: confirmPasswordController,
                obscureText: obscureCurrent3,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrent3 ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      obscureCurrent3 = !obscureCurrent3;
                      (dialogContext as Element).markNeedsBuild();
                    },
                  ),
                  // border: const UnderlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Confirm Password is required";
                  }
                  if (value != newPasswordController.text) {
                    return "Passwords do not match";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                // Firebase Change Password
                // await changePassword();
                // User? user = FirebaseAuth.instance.currentUser;

                // AuthCredential credential = EmailAuthProvider.credential(
                //   email: user!.email!,
                //   password: currentPasswordController.text,
                // );

                // await user.reauthenticateWithCredential(credential);

                // await user.updatePassword(newPasswordController.text);
                try {
                  User? user = FirebaseAuth.instance.currentUser;

                  AuthCredential credential = EmailAuthProvider.credential(
                    email: user!.email!,
                    password: currentPasswordController.text.trim(),
                  );

                  await user.reauthenticateWithCredential(credential);

                  await user.updatePassword(newPasswordController.text.trim());

                  Navigator.pop(context); // Close Change Password Dialog

                  // ignore: use_build_context_synchronously
                  showSuccessDialog(context); // Show Success Dialog
                } on FirebaseAuthException catch (e) {
                  if (e.code == "invalid-credential") {
                    showErrorDialog(context, "Current password is incorrect.");
                  } else if (e.code == "requires-recent-login") {
                    showErrorDialog(context, "Please login again and try.");
                  } else {
                    showErrorDialog(
                      context,
                      e.message ?? "Password change failed.",
                    );
                  }
                }
              }
            },
            child: const Text("Change"),
          ),
        ],
      );
    },
  );
}
