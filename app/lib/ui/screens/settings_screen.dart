import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/biometric_service.dart';
import '../../core/notification_service.dart';
import '../../core/preferences_controller.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';
import '../../data/auth_store.dart';
import '../../data/store.dart';
import '../../documents/forms_spec.dart';
import '../../documents/serial_service.dart';
import '../widgets.dart';

/// SETTINGS — visible to EVERY role (owner directive 2026-09-01).
///
/// Every signed-in user sees:
///   • Account      — profile, change password,
///                    recovery (reset password + reset recovery
///                    string), and sign out.
///   • Preferences  — mark all notifications read, refresh from the server.
///   • About        — app version + live server status.
///
/// Management controls such as document serial reseed and stock import stay
/// CEO-only. VAT is deliberately selected per priced document during creation.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tsv = TextEditingController();
  String _importMsg = '';
  bool _syncing = false;

  @override
  void dispose() {
    _tsv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final auth = AuthStore.instance;
    final user = auth.current;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeader(
          title: 'Settings',
          subtitle: 'Your account, preferences and app information',
          icon: Icons.settings,
        ),
        const SizedBox(height: 16),

        // ---------------- Account (every role) ----------------
        _sectionLabel('ACCOUNT'),
        Card(
          child: Column(children: [
            ListTile(
              leading: InitialsAvatar(_initials(user?.name), background: Mtek.brand600),
              title: Text(user?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(user?.email ?? ''),
              trailing: StatusChip.neutral((user?.role ?? '').toUpperCase()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right, color: Mtek.gray400),
              onTap: () => _changePassword(context),
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Recovery'),
              subtitle: const Text('Reset your password or recovery string'),
              trailing: const Icon(Icons.chevron_right, color: Mtek.gray400),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RecoveryScreen())),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Mtek.danger),
              title: const Text('Sign out', style: TextStyle(color: Mtek.danger, fontWeight: FontWeight.w600)),
              onTap: () => AuthStore.instance.signOut(),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // ---------------- Preferences (every role) ----------------
        _sectionLabel('PREFERENCES'),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Appearance'),
              subtitle: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {ThemeController.instance.mode},
                showSelectedIcon: false,
                onSelectionChanged: (modes) async {
                  await ThemeController.instance.setMode(modes.first);
                  if (mounted) setState(() {});
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('Mark all notifications as read'),
              onTap: () async {
                await AppStore.instance.markAllNotificationsRead();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All notifications marked as read.')));
                }
              },
            ),
          ]),
        ),
        const SizedBox(height: 14),

        _sectionLabel('NOTIFICATIONS & ALERTS'),
        Card(
          child: Column(children: [
            _preferenceSwitch(
              icon: Icons.notifications_active_outlined,
              title: 'Native device notifications',
              subtitle: 'Master control for Android and Windows alerts',
              value: PreferencesController.instance.nativeNotifications,
              onChanged: (v) => _updatePreference(nativeNotifications: v),
            ),
            const Divider(height: 1),
            _preferenceSwitch(
              icon: Icons.payments_outlined,
              title: 'Sales and payment alerts',
              subtitle: 'Sales, invoice settlements and refunds',
              value: PreferencesController.instance.transactionAlerts,
              enabled: PreferencesController.instance.nativeNotifications,
              onChanged: (v) => _updatePreference(transactionAlerts: v),
            ),
            _preferenceSwitch(
              icon: Icons.description_outlined,
              title: 'Document alerts',
              subtitle: 'Receipts, invoices, MILS, waybills and delivery notes',
              value: PreferencesController.instance.documentAlerts,
              enabled: PreferencesController.instance.nativeNotifications,
              onChanged: (v) => _updatePreference(documentAlerts: v),
            ),
            _preferenceSwitch(
              icon: Icons.inventory_2_outlined,
              title: 'Stock and approval alerts',
              subtitle: 'Low inventory and actions needing attention',
              value: PreferencesController.instance.stockAlerts,
              enabled: PreferencesController.instance.nativeNotifications,
              onChanged: (v) => _updatePreference(stockAlerts: v),
            ),
            _preferenceSwitch(
              icon: Icons.groups_outlined,
              title: 'Staff and announcement alerts',
              subtitle: 'Role changes and management broadcasts',
              value: PreferencesController.instance.staffAlerts,
              enabled: PreferencesController.instance.nativeNotifications,
              onChanged: (v) => _updatePreference(staffAlerts: v),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notification_add_outlined),
              title: const Text('Send test notification'),
              subtitle: const Text('Verify native notifications on this device'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _testNotification,
            ),
          ]),
        ),
        const SizedBox(height: 14),

        _sectionLabel('ACCESSIBILITY & DISPLAY'),
        Card(
          child: Column(children: [
            _preferenceSwitch(
              icon: Icons.fingerprint,
              title: 'Biometric authentication',
              subtitle: 'Use fingerprint, face authentication or Windows Hello for login and signatures',
              value: PreferencesController.instance.biometricsEnabled,
              onChanged: (enabled) async {
                if (enabled && (!await BiometricService.instance.available() ||
                    !await BiometricService.instance.authenticate('Enable biometric authentication'))) {
                  _snack('Biometrics are unavailable or were not confirmed.');
                  return;
                }
                await PreferencesController.instance.update(biometricsEnabled: enabled);
                if (!enabled) await BiometricService.instance.clear();
                if (mounted) setState(() {});
              },
            ),
            const Divider(height: 1),
            _preferenceSwitch(
              icon: Icons.motion_photos_off_outlined,
              title: 'Reduce motion',
              subtitle: 'Minimise decorative transitions and movement',
              value: PreferencesController.instance.reduceMotion,
              onChanged: (v) => _updatePreference(reduceMotion: v),
            ),
            _preferenceSwitch(
              icon: Icons.view_agenda_outlined,
              title: 'Compact lists',
              subtitle: 'Use denser rows to show more business records',
              value: PreferencesController.instance.compactLists,
              onChanged: (v) => _updatePreference(compactLists: v),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        _sectionLabel('DATA & SYNCHRONISATION'),
        Card(
          child: Column(children: [
            ListTile(
              leading: Icon(
                store.lastServerSync == null ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                color: store.lastServerSync == null ? Mtek.warn : Mtek.success,
              ),
              title: Text(store.lastServerSync == null
                  ? 'No live sync completed this session'
                  : 'Last synced ${_relativeTime(store.lastServerSync!)}'),
              subtitle: Text(store.lastSyncError ??
                  '${store.products.length} products · ${store.customers.length} customers · '
                  '${store.sales.length} sales · ${store.transactions.length} transactions'),
              trailing: IconButton(
                tooltip: 'Synchronise now',
                onPressed: _syncing ? null : _syncNow,
                icon: const Icon(Icons.sync),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Business records on this device'),
              subtitle: Text('${store.invoices.length} invoices · ${store.receipts.length} receipts · '
                  '${store.milsLogs.length} MILS jobs · ${store.docHistory.length} issued documents'),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        _sectionLabel('DEVICE & PERMISSIONS'),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera and notification permissions'),
              subtitle: const Text('Manage site-photo and alert access in system settings'),
              trailing: const Icon(Icons.open_in_new),
              onTap: openAppSettings,
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Printing and sharing'),
              subtitle: const Text('Uses the native Android or Windows print and share services'),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // ---------------- About (every role) ----------------
        _sectionLabel('ABOUT & SUPPORT'),
        Card(
          child: Column(children: [
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/branding/app_icon.png', width: 40, height: 40,
                    errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department, size: 32, color: Mtek.brand600)),
              ),
              title: const Text(AppInfo.appName, style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('v${AppInfo.version} · ${AppInfo.publisher}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Contact M-TEK support'),
              subtitle: const Text('mtekfiresafetyltd@gmail.com'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openUri('mailto:mtekfiresafetyltd@gmail.com?subject=MFSL%20Inventory%20Support'),
            ),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('Company website'),
              subtitle: const Text('www.mtekLtd.com.ng'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openUri('https://www.mtekLtd.com.ng'),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // ---------------- CEO-only management ----------------
        if (auth.isCeo) ...[
          _sectionLabel('MANAGEMENT (CEO)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DOCUMENT SERIALS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('Set each counter to the number of the last used page in the physical book — digital documents continue the sequence.',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  for (final entry in [
                    ('receipt', 'Payment Receipt', MtekForms.seedSerials['receipt']!),
                    ('invoice', 'Sales Invoice', MtekForms.seedSerials['invoice']!),
                    ('mils', 'MILS Sheet', MtekForms.seedSerials['mils']!),
                    ('waybill', 'Waybill (starts 000000001)', MtekForms.seedSerials['waybill']!),
                    ('deliverynote', 'Delivery Note (starts 000000001)', MtekForms.seedSerials['deliverynote']!),
                  ])
                    _serialRow(context, entry.$1, entry.$2, entry.$3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('M-TEK FIRE & SAFETY LTD.'),
              subtitle: Text('RC: 1082534 · YY12 Kazaure Road, by Lagos Street Round About, Kaduna\nmtekfiresafetyltd@gmail.com · +2348033498452'),
              isThreeLine: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _preferenceSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) => SwitchListTile.adaptive(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: enabled ? onChanged : null,
      );

  Future<void> _updatePreference({
    bool? nativeNotifications,
    bool? transactionAlerts,
    bool? documentAlerts,
    bool? stockAlerts,
    bool? staffAlerts,
    bool? reduceMotion,
    bool? compactLists,
  }) async {
    await PreferencesController.instance.update(
      nativeNotifications: nativeNotifications,
      transactionAlerts: transactionAlerts,
      documentAlerts: documentAlerts,
      stockAlerts: stockAlerts,
      staffAlerts: staffAlerts,
      reduceMotion: reduceMotion,
      compactLists: compactLists,
    );
    if (mounted) setState(() {});
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    var refreshed = false;
    try {
      refreshed = await AppStore.instance.syncNow();
      await AppStore.instance.refreshNotifications();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
    _snack(refreshed
        ? 'Synchronisation complete — this device has the latest server records.'
        : 'Synchronisation failed — no cloud success was recorded. Check your connection or sign in again.');
  }

  Future<void> _testNotification() async {
    final delivered = await NotificationService.instance.show(
      key: 'settings-test-${DateTime.now().millisecondsSinceEpoch}',
      title: 'MFSL Office alerts are working',
      body: 'This device will receive the business alerts selected in Settings.',
      kind: 'general',
    );
    _snack(delivered
        ? 'Test notification sent.'
        : PreferencesController.instance.nativeNotifications
            ? 'The operating system did not accept the notification. Check this app\'s notification permission.'
            : 'Native notifications are disabled. Enable them above first.');
  }

  Future<void> _openUri(String value) async {
    final opened = await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
    if (!opened) _snack('No compatible application is available on this device.');
  }

  String _relativeTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 30) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: SectionTitle(text),
      );

  // ---- server status ----
  // ---- change password dialog ----
  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    // Dialog result: null = cancelled · '' = proceed · non-empty = error to show.
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RevealPasswordField(controller: current, label: 'Current password'),
            RevealPasswordField(controller: next, label: 'New password'),
            RevealPasswordField(controller: confirm, label: 'Confirm new password'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (next.text.length < 6) {
                Navigator.pop(context, 'New password must be at least 6 characters');
                return;
              }
              if (next.text != confirm.text) {
                Navigator.pop(context, 'New passwords do not match');
                return;
              }
              Navigator.pop(context, '');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return; // cancelled
    if (result.isNotEmpty) {
      _snack(result);
      return;
    }
    final outcome = await AuthStore.instance.changePassword(
      currentPassword: current.text,
      newPassword: next.text,
    );
    _snack(outcome ?? 'Password changed.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _serialRow(BuildContext context, String type, String label, int bookSeed) {
    final controller = TextEditingController(text: '${SerialService.instance.current(type)}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'book started at $bookSeed', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () async {
            final v = int.tryParse(controller.text);
            if (v == null || v < 1) return;
            try {
              await AppStore.instance.updateSettings(serialReseed: {type: v});
              if (mounted) {
                _snack('Next $label will be numbered ${v + 1} — continues the book.');
                setState(() {});
              }
            } catch (error) {
              _snack(error.toString().replaceFirst('Exception: ', ''));
            }
          },
          child: const Text('Set'),
        ),
      ]),
    );
  }
}

/// ACCOUNT → RECOVERY — two self-service flows (owner directive 2026-09-01):
///   1. Reset the account password using the recovery string.
///   2. Rotate the recovery string using the account password.
/// There is deliberately NO email/OTP flow.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final email = AuthStore.instance.current?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Account recovery',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(
            'Use the recovery string you chose at sign-up to reset a forgotten '
            'password — or reset the recovery string itself using your current '
            'password.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          _resetPasswordCard(email),
          const SizedBox(height: 14),
          _resetRecoveryCard(email),
        ],
      ),
    );
  }

  Widget _resetPasswordCard(String email) {
    final emailC = TextEditingController(text: email);
    final recoveryC = TextEditingController();
    final passC = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RESET PASSWORD',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Account email')),
            TextField(controller: recoveryC, decoration: const InputDecoration(labelText: 'Recovery string')),
            RevealPasswordField(controller: passC, label: 'New password (min 6 characters)'),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_reset, size: 18),
              label: const Text('Reset password'),
              onPressed: _busy ? null : () => _doResetPassword(emailC, recoveryC, passC),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resetRecoveryCard(String email) {
    final emailC = TextEditingController(text: email);
    final passC = TextEditingController();
    final newRecoveryC = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RESET RECOVERY STRING',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Account email')),
            RevealPasswordField(controller: passC, label: 'Current password'),
            TextField(controller: newRecoveryC, decoration: const InputDecoration(labelText: 'New recovery string (min 15 characters)')),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.key_outlined, size: 18),
              label: const Text('Reset recovery string'),
              onPressed: _busy ? null : () => _doResetRecovery(emailC, passC, newRecoveryC),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doResetPassword(TextEditingController emailC, TextEditingController recoveryC,
      TextEditingController passC) async {
    if (recoveryC.text.trim().isEmpty) return _fail('Enter your recovery string.');
    if (passC.text.length < 6) return _fail('New password must be at least 6 characters.');
    setState(() => _busy = true);
    final result = await AuthStore.instance.resetPasswordWithRecovery(
      email: emailC.text,
      recoveryString: recoveryC.text,
      newPassword: passC.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    result == null ? _ok('Password reset — sign in with the new password.') : _fail(result);
  }

  Future<void> _doResetRecovery(TextEditingController emailC, TextEditingController passC,
      TextEditingController newRecoveryC) async {
    if (passC.text.isEmpty) return _fail('Enter your current password.');
    if (newRecoveryC.text.length < 15) return _fail('New recovery string must be at least 15 characters.');
    setState(() => _busy = true);
    final result = await AuthStore.instance.resetRecovery(
      email: emailC.text,
      password: passC.text,
      newRecoveryString: newRecoveryC.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    result == null ? _ok('Recovery string updated — keep it safe.') : _fail(result);
  }

  void _ok(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(backgroundColor: Mtek.success, content: Text(msg)));
  }

  void _fail(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
