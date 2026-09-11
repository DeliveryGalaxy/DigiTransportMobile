import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../services/aade_client.dart';
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
  bool _testing = false;
  AadeEnvironment _environment = AadeEnvironment.development;

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
    setState(() {
      _environment = settings.environment;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _store.save(_currentSettings());
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Αποθηκεύτηκε')));
  }

  AppSettings _currentSettings() {
    return AppSettings(
      username: _usernameController.text.trim(),
      afm: _afmController.text.trim(),
      subscriptionKey: _subscriptionController.text.trim(),
      environment: _environment,
    );
  }

  Future<void> _testAade() async {
    setState(() => _testing = true);
    final result = await AadeClient(
      settings: _currentSettings(),
    ).testConnection();
    if (!mounted) {
      return;
    }
    setState(() => _testing = false);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(result.ok ? 'Σύνδεση ΑΑΔΕ OK' : 'Αποτυχία σύνδεσης'),
          content: SingleChildScrollView(
            child: SelectableText(
              [
                result.message,
                if (result.endpoint != null) '\n${result.endpoint}',
                if (result.body != null && result.body!.isNotEmpty)
                  '\n${result.body}',
              ].join('\n'),
            ),
          ),
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
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD5DEE2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Dev',
                            style: TextStyle(
                              color: _environment.isProduction
                                  ? AppColors.muted
                                  : AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _environment.isProduction,
                            onChanged: (useProd) {
                              setState(() {
                                _environment = useProd
                                    ? AadeEnvironment.production
                                    : AadeEnvironment.development;
                              });
                            },
                          ),
                          const Spacer(),
                          Text(
                            'Prod',
                            style: TextStyle(
                              color: _environment.isProduction
                                  ? AppColors.navy
                                  : AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _environment.baseUrl,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving || _testing ? null : _save,
                  child: Text(_saving ? 'Αποθήκευση...' : 'Αποθήκευση'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _saving || _testing ? null : _testAade,
                  child: _testing
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Έλεγχος σύνδεσης ΑΑΔΕ'),
                ),
              ],
            ),
    );
  }
}
