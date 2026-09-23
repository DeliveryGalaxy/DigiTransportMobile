import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../services/digi_api.dart';
import '../services/plate_text.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.settings,
    required this.onReady,
    this.store,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onReady;
  final SettingsStore? store;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { afm, name, identity }

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final SettingsStore _store;
  late AppSettings _settings;
  late _Step _step;
  CompanyDetails? _pending;

  final _afmController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _identityController = TextEditingController();
  final _pinController = TextEditingController();

  bool _busy = false;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SettingsStore();
    _settings = widget.settings;
    _afmController.text = _settings.afm;
    _firstNameController.text = _settings.firstName;
    _lastNameController.text = _settings.lastName;
    if (!_settings.companyConfirmed) {
      _step = _Step.afm;
    } else if (_settings.firstName.trim().isEmpty || _settings.lastName.trim().isEmpty) {
      _step = _Step.name;
    } else {
      _step = _Step.identity;
    }
  }

  @override
  void dispose() {
    _afmController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _identityController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final afm = _afmController.text.trim();
    if (afm.isEmpty) {
      _showMessage('Συμπλήρωσε ΑΦΜ.');
      return;
    }
    setState(() => _busy = true);
    try {
      final api = DigiApi(baseUrl: digiApiBaseUrl);
      final company = await api.lookupCompany(afm);
      if (!mounted) {
        return;
      }
      setState(() {
        _pending = company;
        _busy = false;
      });
    } on DigiApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage(error.message);
    }
  }

  Future<void> _confirmCompany() async {
    final company = _pending;
    if (company == null) {
      return;
    }
    final next = _settings.copyWith(
      companyId: company.id,
      companyConfirmed: true,
      companyName: company.name,
      companyAfm: company.afm,
      afm: company.afm,
      username: company.username,
      subscriptionKey: company.subscriptionKey,
      isMetaforiki: company.isMetaforiki,
      isContainer: company.isContainer,
      isOther: company.isOther,
      isMetaforeas: company.shouldDisplayPlated,
      token: '',
      identityUserId: '',
      pin: '',
    );
    await _store.save(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = next;
      _pending = null;
      _step = _Step.name;
    });
  }

  Future<void> _saveNames() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      _showMessage('Συμπλήρωσε όνομα και επώνυμο.');
      return;
    }
    final next = _settings.copyWith(firstName: firstName, lastName: lastName);
    await _store.save(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = next;
      _step = _Step.identity;
    });
  }

  Future<void> _verify() async {
    final identity = _identityController.text.trim();
    final pin = _pinController.text.trim();
    if (identity.isEmpty || pin.isEmpty) {
      _showMessage(
        _settings.shouldDisplayPlated
            ? 'Συμπλήρωσε πινακίδα και PIN.'
            : 'Συμπλήρωσε username και PIN.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final api = DigiApi(baseUrl: digiApiBaseUrl);
      final result = await api.verifyIdentity(
        companyId: _settings.companyId,
        userId: identity,
        pin: pin,
      );
      final next = _settings.copyWith(
        token: result.token,
        identityUserId: result.userId,
        pin: pin,
        isMetaforiki: result.company.isMetaforiki,
        isContainer: result.company.isContainer,
        isOther: result.company.isOther,
        isMetaforeas: result.company.shouldDisplayPlated,
      );
      await _store.save(next);
      if (!mounted) {
        return;
      }
      widget.onReady(next);
    } on DigiApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    showDialog<void>(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          children: [
            const Text(
              'DigiTransport',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            if (_step == _Step.afm) _afmBody(),
            if (_step == _Step.name) _nameBody(),
            if (_step == _Step.identity) _identityBody(),
          ],
        ),
      ),
    );
  }

  Widget _afmBody() {
    final pending = _pending;
    if (pending != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Εταιρεία',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            pending.name,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pending.afm,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _busy ? null : _confirmCompany,
            child: const Text('OK'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => setState(() => _pending = null),
            child: const Text('Πίσω'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ΑΦΜ εταιρείας',
          style: TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _afmController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _lookup(),
          decoration: const InputDecoration(labelText: 'ΑΦΜ'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _lookup,
          child: Text(_busy ? 'Αναζήτηση...' : 'Συνέχεια'),
        ),
      ],
    );
  }

  Widget _nameBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _settings.companyName,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          'Τα στοιχεία σου',
          style: TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _firstNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Όνομα'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _lastNameController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveNames(),
          decoration: const InputDecoration(labelText: 'Επώνυμο'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saveNames,
          child: const Text('Συνέχεια'),
        ),
      ],
    );
  }

  Widget _identityBody() {
    final plated = _settings.shouldDisplayPlated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _settings.companyName,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          plated ? 'Πινακίδα και PIN' : 'Username και PIN',
          style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _identityController,
          inputFormatters: plated ? const [PlateTextInputFormatter()] : null,
          decoration: InputDecoration(labelText: plated ? 'Πινακίδα' : 'Username'),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(_busy ? 'Έλεγχος...' : 'Είσοδος'),
        ),
      ],
    );
  }
}
