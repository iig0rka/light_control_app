import 'package:flutter/material.dart';

class EditDeviceResult {
  final String title;
  final String password;

  const EditDeviceResult({required this.title, required this.password});
}

Future<EditDeviceResult?> showEditDeviceDialog({
  required BuildContext context,
  required String initialTitle,
  required String initialPassword,
}) async {
  final titleController = TextEditingController(text: initialTitle);
  final passController = TextEditingController(text: initialPassword);

  final formKey = GlobalKey<FormState>();
  bool obscure = true;

  return showDialog<EditDeviceResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Edit device'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Device name',
                      hintText: 'esp32 car',
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Enter device name';
                      if (t.length < 2) return 'Too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: '111111',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final p = (v ?? '').trim();
                      if (p.isEmpty) return 'Enter password';
                      if (p.length < 4) return 'Min 4 chars';
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'After saving you can send this password to ESP32 from your connect logic.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;

                  final title = titleController.text.trim();
                  final password = passController.text.trim();

                  Navigator.of(
                    ctx,
                  ).pop(EditDeviceResult(title: title, password: password));
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
