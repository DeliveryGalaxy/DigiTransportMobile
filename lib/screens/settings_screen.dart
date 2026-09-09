import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.store});

  final SettingsStore? store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsStore _store;
  final _usernameController = TextEditingController();
  final _afmController = TextEditingController();
  final _subscriptionController = TextEditingController();
  bool _loading = true;
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SettingsStore();
    _load();
  }

  Future<void> _load() async {
    final settings = await _store.load();
    if (!mounted) {
      return;
    }
    _usernameController.text = settings.username;
    _afmController.text = settings.afm;
    _subscriptionController.text = settings.subscriptionKey;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _store.save(
      AppSettings(
        username: _usernameController.text.trim(),
        afm: _afmController.text.trim(),
        subscriptionKey: _subscriptionController.text.trim(),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Αποθηκεύτηκε')));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _afmController.dispose();
    _subscriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
              children: [
                const Text(
                  'Ρυθμίσεις',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Τα στοιχεία αποθηκεύονται στη συσκευή.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _afmController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  decoration: const InputDecoration(labelText: 'ΑΦΜ'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _subscriptionController,
                  obscureText: _obscureKey,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: 'Subscription Key',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscureKey = !_obscureKey);
                      },
                      icon: Icon(
                        _obscureKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Αποθήκευση...' : 'Αποθήκευση'),
                ),
              ],
            ),
    );
  }
}
