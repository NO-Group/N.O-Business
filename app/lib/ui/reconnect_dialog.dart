import 'package:flutter/material.dart';

import '../data/auth_store.dart';
import '../data/env.dart';

/// In-place re-authentication for a session whose refresh token can no longer
/// be exchanged (password changed elsewhere, token rotated out from under
/// this device, Android Keystore wiped, ...).
///
/// It NEVER signs the user out: a failed attempt leaves the cached identity,
/// role and local data exactly as they were, and a successful attempt simply
/// installs a fresh session over the top. The workspace stays open throughout.
Future<void> showReconnectDialog(BuildContext context) async {
  final email = TextEditingController(text: AuthStore.instance.current?.email ?? '');
  final password = TextEditingController();
  String? error;
  bool busy = false;
  try {
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setDialogState) => AlertDialog(
          title: const Text('Reconnect to M-TEK cloud'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your workspace and saved work stay open. Sign in once more to resume live sync.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      final mail = email.text.trim();
                      final secret = password.text;
                      final String? failure = Env.backendConfigured
                          ? await AuthStore.instance.remoteSignIn(mail, secret)
                          : AuthStore.instance.signIn(mail, secret);
                      if (!sheetContext.mounted) return;
                      if (failure != null) {
                        setDialogState(() {
                          busy = false;
                          error = failure;
                        });
                        return;
                      }
                      Navigator.pop(sheetContext);
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reconnect'),
            ),
          ],
        ),
      ),
    );
  } finally {
    email.dispose();
    password.dispose();
  }
}
