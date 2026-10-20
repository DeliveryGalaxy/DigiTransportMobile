import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/digi_api.dart';
import '../services/scan_history_store.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.store,
    this.api,
    this.history,
    this.onChangeCompany,
  });

  final SettingsStore? store;
  final DigiApi? api;
  final ScanHistoryStore? history;
  final ValueChanged<AppSettings>? onChangeCompany;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsStore _store;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _changingCompany = false;

  bool get _busy => _saving || _testing || _changingCompany;
  String _token = '';
  String _companyName = '';

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
    _firstNameController.text = settings.firstName;
    _lastNameController.text = settings.lastName;
    setState(() {
      _token = settings.token;
      _companyName = settings.companyName;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      _showMessage('Στοιχεία', 'Συμπλήρωσε όνομα και επώνυμο.');
      return;
    }
    final previous = await _store.load();
    setState(() => _saving = true);
    await _store.save(
      previous.copyWith(
        firstName: firstName,
        lastName: lastName,
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

  Future<void> _testAade() async {
    if (_token.isEmpty) {
      _showMessage('Αποτυχία σύνδεσης', 'Ολοκλήρωσε πρώτα την είσοδο.');
      return;
    }
    setState(() => _testing = true);
    try {
      final api = widget.api ??
          DigiApi(baseUrl: digiApiBaseUrl, token: _token);
      final message = await api.testAade();
      if (!mounted) {
        return;
      }
      setState(() => _testing = false);
      _showMessage('Σύνδεση ΑΑΔΕ OK', message);
    } on DigiApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _testing = false);
      _showMessage('Αποτυχία σύνδεσης', error.message);
    }
  }

  Future<void> _changeCompany() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Αλλαγή εταιρείας'),
          content: const Text(
            'Η εταιρεία και το όχημα θα διαγραφούν. Το όνομα και το επώνυμο μένουν και η είσοδος ξεκινά από την αρχή.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Άκυρο'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Αλλαγή'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _changingCompany = true);
    final previous = await _store.load();
    final typedFirst = _firstNameController.text.trim();
    final typedLast = _lastNameController.text.trim();
    final next = await _store.clearCompanyAndVehicle(
      firstName: typedFirst.isEmpty ? previous.firstName : typedFirst,
      lastName: typedLast.isEmpty ? previous.lastName : typedLast,
    );
    await (widget.history ?? ScanHistoryStore()).clear();
    if (!mounted) {
      return;
    }
    final onChangeCompany = widget.onChangeCompany;
    if (onChangeCompany == null) {
      setState(() => _changingCompany = false);
      return;
    }
    onChangeCompany(next);
  }

  Future<void> _showMessage(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
                Text(
                  _companyName.isEmpty ? 'Εταιρεία' : 'Εταιρεία: $_companyName',
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _firstNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Όνομα'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _lastNameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Επώνυμο'),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_saving ? 'Αποθήκευση...' : 'Αποθήκευση'),
                ),
                if (_token.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _testAade,
                    child: const Text('Έλεγχος σύνδεσης ΑΑΔΕ'),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _changeCompany,
                  child: const Text('Αλλαγή εταιρείας'),
                ),
              ],
            ),
    );
  }
}
