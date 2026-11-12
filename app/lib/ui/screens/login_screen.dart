import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/biometric_service.dart';
import '../../core/phone.dart';
import '../../core/preferences_controller.dart';
import '../../core/theme.dart';
import '../../data/auth_store.dart';
import '../../data/env.dart';
import '../signature_pad.dart';
import '../widgets.dart';

/// Sign-in / create-account. Account creation REQUIRES a Signature
/// Account authentication and optional drawn signature.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _signup = false;
  String? _error;
  String? _passportPhoto;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _recovery = TextEditingController();
  String _role = 'admin';
  String? _signaturePng;
  bool _showPad = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    _recovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Mtek.navyGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: _signup ? _buildSignup() : _buildLogin(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoHeader(String title) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3FA0).withValues(alpha: .18),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Image.asset('assets/branding/logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        const Text('M-TEK FIRE & SAFETY LTD',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 13, color: Mtek.navy800)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildLogin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _logoHeader('Sign in to your workspace'),
        TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
        const SizedBox(height: 12),
        RevealPasswordField(controller: _password, label: 'Password', prefixIcon: Icons.lock_outline),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Mtek.danger, fontSize: 13)),
          ),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Sign in'),
        ),
        if (PreferencesController.instance.biometricsEnabled) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _busy ? null : _biometricSignIn,
            icon: const Icon(Icons.fingerprint), label: const Text('Sign in with biometrics')),
        ],
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() { _signup = true; _error = null; }),
          child: const Text('Create an account →'),
        ),
        if (Env.backendConfigured)
          TextButton(
            onPressed: _showForgotPassword,
            child: const Text('Forgot password?'),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  void _showForgotPassword() {
    final email = TextEditingController(text: _email.text);
    final recovery = TextEditingController();
    final newPassword = TextEditingController();
    String? dialogError;
    bool busy = false;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset your password'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No email or code is sent — enter the recovery phrase you chose at sign-up.',
                  style: TextStyle(fontSize: 12.5, color: Mtek.gray600),
                ),
                const SizedBox(height: 12),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                TextField(controller: recovery, decoration: const InputDecoration(labelText: 'Recovery phrase (min 15 characters)')),
                const SizedBox(height: 10),
                RevealPasswordField(controller: newPassword, label: 'New password (min 6)'),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: const TextStyle(color: Mtek.danger, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() => busy = true);
                      final err = await AuthStore.instance.resetPasswordWithRecovery(
                        email: email.text,
                        recoveryString: recovery.text,
                        newPassword: newPassword.text,
                      );
                      setDialogState(() => busy = false);
                      if (err != null) {
                        setDialogState(() => dialogError = err);
                        return;
                      }
                      if (context.mounted) Navigator.pop(context);
                      if (mounted) {
                        setState(() {
                          _error = null;
                          _email.text = email.text;
                        });
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Password reset — sign in with your new password')),
                        );
                      }
                    },
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Reset password'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _logoHeader('Create your account'),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 10),
        TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
        const SizedBox(height: 10),
        CountryPhoneField(controller: _phone),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickPassportPhoto,
          icon: _passportPhoto == null
              ? const Icon(Icons.add_a_photo_outlined)
              : AppImage(source: _passportPhoto!, title: 'Passport photograph',
                  details: 'Selected staff registration passport photograph', width: 34, height: 34,
                  borderRadius: BorderRadius.circular(20)),
          label: Text(_passportPhoto == null ? 'Add passport photograph *' : 'Passport photograph selected — change'),
        ),
        const SizedBox(height: 10),
        RevealPasswordField(controller: _password, label: 'Account password (min 6)', prefixIcon: Icons.lock_outline),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Mtek.gray100, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.key_outlined, size: 17, color: Mtek.navy800),
                SizedBox(width: 7),
                Text('RECOVERY PHRASE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Mtek.navy800)),
              ]),
              const SizedBox(height: 4),
              const Text('A phrase only you know, at least 15 characters — the ONLY way to reset your password later. No email or SMS code is used.',
                  style: TextStyle(fontSize: 11.5, color: Mtek.gray600)),
              const SizedBox(height: 10),
              TextField(controller: _recovery, decoration: const InputDecoration(labelText: 'Your recovery phrase (min 15 characters)')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (Env.backendConfigured)
          // Real accounts always start as Sales (server-enforced too) — no
          // self-service Admin/CEO, for the same reason a bank teller can't
          // promote themselves to branch manager. An existing Admin/CEO
          // upgrades staff afterwards via the Supabase dashboard.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Mtek.gray100, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New accounts start as Sales staff. An Admin or the CEO can promote you afterwards.',
                    style: TextStyle(fontSize: 12, color: Mtek.gray600),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Text('Role', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(width: 12),
              ChoiceChip(label: const Text('Admin'), selected: _role == 'admin', onSelected: (_) => setState(() => _role = 'admin')),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Sales'), selected: _role == 'sales', onSelected: (_) => setState(() => _role = 'sales')),
            ],
          ),
        const SizedBox(height: 10),
        // Drawn signature is optional and used as a visual document mark.
        if (_showPad)
          SignaturePad(
            onDone: (bytes) {
              setState(() {
                _showPad = false;
                if (bytes != null) _signaturePng = signatureDataUrl(bytes);
              });
            },
          )
        else
          OutlinedButton.icon(
            onPressed: () => setState(() => _showPad = true),
            icon: const Icon(Icons.gesture, size: 18),
            label: Text(_signaturePng == null ? 'Draw your signature (optional)' : 'Signature saved ✓ — redraw'),
          ),
        const SizedBox(height: 14),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Mtek.danger, fontSize: 13)),
          ),
        FilledButton(
          onPressed: _busy ? null : _createAccount,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create account'),
        ),
        TextButton(
          onPressed: () => setState(() { _signup = false; _error = null; }),
          child: const Text('← Back to sign in'),
        ),
      ],
    );
  }

  bool _busy = false;

  Future<void> _biometricSignIn() async {
    setState(() { _busy = true; _error = null; });
    final credentials = await BiometricService.instance.login();
    if (credentials == null) {
      if (mounted) setState(() { _busy = false; _error = 'Biometric sign-in failed or no login has been saved yet.'; });
      return;
    }
    final error = await AuthStore.instance.remoteSignIn(credentials.$1, credentials.$2);
    if (mounted) setState(() { _busy = false; _error = error; });
  }

  Future<void> _signIn() async {
    // REAL backend first (Supabase Auth + profiles role); offline dev
    // (backend not configured) falls back to the local directory.
    if (Env.backendConfigured) {
      setState(() { _busy = true; _error = null; });
      final remoteErr = await AuthStore.instance.remoteSignIn(_email.text, _password.text);
      if (remoteErr == null && PreferencesController.instance.biometricsEnabled) {
        await BiometricService.instance.saveLogin(_email.text.trim(), _password.text);
      }
      if (!mounted) return;
      setState(() { _busy = false; _error = remoteErr; });
      return;
    }
    final err = AuthStore.instance.signIn(_email.text, _password.text);
    setState(() => _error = err);
  }

  Future<void> _pickPassportPhoto() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = picked == null || picked.files.isEmpty ? null : picked.files.first;
    if (file?.bytes == null) return;
    if (file!.bytes!.length > 1500000) {
      setState(() => _error = 'Passport photograph must be smaller than 1.5 MB.');
      return;
    }
    final ext = (file.extension ?? 'jpg').toLowerCase();
    setState(() {
      _passportPhoto = 'data:image/${ext == 'png' ? 'png' : 'jpeg'};base64,${base64Encode(file.bytes!)}';
      _error = null;
    });
  }

  Future<void> _createAccount() async {
    if (_passportPhoto == null) {
      setState(() => _error = 'A passport photograph is compulsory for registration.');
      return;
    }
    if (Env.backendConfigured) {
      final phoneError = internationalPhoneError(_phone.text, required: true);
      if (phoneError != null) {
        setState(() => _error = phoneError);
        return;
      }
      if (_recovery.text.trim().length < 15) {
        setState(() => _error = 'Recovery phrase must be at least 15 characters');
        return;
      }
      if (_recovery.text.trim() == _password.text) {
        setState(() => _error = 'Recovery phrase must differ from your password');
        return;
      }
    }
    // REAL backend: create an actual Supabase account (owner directive
    // 2026-09-01) instead of the local-only fake that had no server
    // permissions and made every write get rejected.
    if (Env.backendConfigured) {
      setState(() { _busy = true; _error = null; });
      final remoteErr = await AuthStore.instance.remoteSignUp(
        name: _name.text,
        email: _email.text,
        phone: normalizeInternationalPhone(_phone.text),
        password: _password.text,
        recoveryString: _recovery.text.trim(),
        passportPhoto: _passportPhoto!,
      );
      if (!mounted) return;
      setState(() { _busy = false; _error = remoteErr; });
      return;
    }
    final err = AuthStore.instance.signUp(
      name: _name.text,
      email: _email.text,
      password: _password.text,
      role: _role,
      signaturePng: _signaturePng,
      passportPhoto: _passportPhoto,
    );
    setState(() => _error = err);
  }
}
