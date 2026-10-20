import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/digi_api.dart';
import '../services/plate_text.dart';
import '../services/settings_store.dart';

class VehicleChange {
  const VehicleChange({required this.identity, required this.pin});

  final String identity;
  final String pin;
}

class ChangeVehicleDialog extends StatefulWidget {
  const ChangeVehicleDialog();

  @override
  State<ChangeVehicleDialog> createState() => _ChangeVehicleDialogState();
}

class _ChangeVehicleDialogState extends State<ChangeVehicleDialog> {
  final _identityController = TextEditingController();
  final _pinController = TextEditingController();
  var _obscurePin = true;

  @override
  void dispose() {
    _identityController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Αλλαγή οχήματος'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _identityController,
              inputFormatters: const [PlateTextInputFormatter()],
              decoration: const InputDecoration(labelText: 'Πινακίδα'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'PIN',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  icon: Icon(
                    _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Άκυρο'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              VehicleChange(
                identity: normalizePlate(_identityController.text.trim()),
                pin: _pinController.text.trim(),
              ),
            );
          },
          child: const Text('Έλεγχος'),
        ),
      ],
    );
  }
}

/// Plate and PIN check used by the home card and by the scan mismatch dialog.
/// Returns the saved profile when the new plate is accepted.
Future<AppSettings?> changeDeclaredVehicle(
  BuildContext context, {
  DigiApi? api,
}) async {
  final change = await showDialog<VehicleChange>(
    context: context,
    builder: (context) => const ChangeVehicleDialog(),
  );
  if (change == null || !context.mounted) {
    return null;
  }
  if (change.identity.isEmpty || change.pin.isEmpty) {
    await _showMessage(context, 'Συμπλήρωσε πινακίδα και PIN.');
    return null;
  }
  final settings = await SettingsStore().load();
  try {
    final client = api ?? await DigiApi.fromStore();
    final result = await client.verifyIdentity(
      companyId: settings.companyId,
      userId: change.identity,
      pin: change.pin,
    );
    final next = settings.copyWith(
      token: result.token,
      identityUserId: result.userId,
      pin: change.pin,
    );
    await SettingsStore().save(next);
    return next;
  } on DigiApiException catch (error) {
    if (context.mounted) {
      await _showMessage(context, error.message);
    }
    return null;
  }
}

Future<void> _showMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
