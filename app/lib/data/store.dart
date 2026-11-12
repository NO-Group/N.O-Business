import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/format.dart' as fmt;
import '../core/notification_service.dart';
import '../core/widget_bridge.dart';
import 'api_client.dart';
import 'auth_store.dart';
import 'env.dart';
import 'local_store.dart';
import 'models.dart';
import 'rest_client.dart';
import '../documents/serial_service.dart';

// re-export for callers that imported it from here
export 'models.dart';

/// AppStore — the Phase B data layer. Same observable API the screens were
/// built against, now:
///   1. loads from the LOCAL CACHE (local_store, JSON per collection),
///   2. falls back to the bundled TXT seed (the owner's REAL catalogue),
///   3. every mutation PERSISTS locally (offline key per record),
///   4. a sync flush uploads every record the server does not hold yet
///      to POST /api/sync/import (idempotent) whenever the API is reachable
///      (env.dart) — the app stays fully usable offline (SPEC §5, §12 Phase B).
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  final List<Product> products = [];
  final List<Customer> customers = [];
  final List<Sale> sales = [];
  final List<Transaction> transactions = [];
  final List<Receipt> receipts = [];
  final List<Invoice> invoices = [];
  final List<MaintenanceLog> milsLogs = [];
  final List<StockAdjustment> adjustments = [];

  /// Generated-document history (Phase A/B): every PDF the app issued.
  final List<IssuedDocument> docHistory = [];

  StoreSettings settings = StoreSettings();
  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// In-app notifications (every transaction/document/stock/customer/product
  /// change, plus CEO/Admin announcements) — newest first. Populated by
  /// [refreshNotifications], polled periodically by the app shell.
  List<AppNotification> notifications = [];
  bool _remoteNotificationsPrimed = false;
  int get unreadNotificationCount {
    final uid = AuthStore.instance.remoteSignInUid;
    if (uid == null || uid.isEmpty) return notifications.length;
    return notifications.where((n) => !n.isReadBy(uid)).length;
  }

  /// Staff directory (CEO/Admin only) — populated by [refreshStaff].
  final List<StaffMember> staff = [];

  RestClient? _remote;
  ApiClient? _api;

  /// The live Supabase auth client (null until configured).
  RestClient? get remote => _remote;

  /// The M-TEK data API client (Supabase Postgres sections) — null until configured.
  ApiClient? get api => _api;

  // ---------------------------------------------------------------- init
  Future<void> init() async {
    if (_loaded) return;
    if (Env.supabaseUrl.isNotEmpty) {
      _remote = RestClient(
        baseUrl: Env.supabaseUrl,
        apiKey: Env.supabaseAnonKey,
      );
    }
    if (Env.authApiConfigured) {
      _api = ApiClient(baseUrl: Env.apiBase); // auth routes always; data routes only when apiConfigured
    }
    var loadedAny = false;
    if (Env.apiConfigured && AuthStore.instance.accessToken != null) {
      // OFFLINE → SERVER: anything recorded on this device while the data
      // API was disconnected is uploaded FIRST. Only when nothing is pending
      // (or the upload succeeded) do we switch to the server dataset —
      // otherwise the local files would be overwritten and the offline
      // records silently lost.
      final clean = await _uploadOfflineData();
      if (clean) {
        final localHasData = await _localFilesHaveData();
        loadedAny = await _loadRemote();
        if (loadedAny && localHasData && !_hasAnyData) {
          // A brand-new / empty Supabase store must NEVER discard records
          // this device still holds locally. Fall through to _loadLocal()
          // instead, and leave the cache files untouched.
          _clearAll();
          loadedAny = false;
          lastSyncError = _emptyCloudMessage;
        } else if (loadedAny) {
          await _markAllKnown();
        } else {
          _clearAll(); // partial server data must not mix with the local files
        }
      }
    }
    if (!loadedAny) loadedAny = await _loadLocal();
    _loaded = true;
    notifyListeners();
    unawaited(flushSyncQueue());
    pushHomeWidgetStats();
  }

  /// Resolves the boot gate even when the local load hit an unexpected error.
  /// An empty workspace is always preferable to a splash screen that never
  /// finishes (and looks exactly like a broken sign-in).
  void markLoaded() {
    if (_loaded) return;
    _loaded = true;
    notifyListeners();
  }

  Future<void>? _bootstrapFuture;

  /// One-time boot pipeline, safe to call from a rebuilt splash screen.
  /// Theme/preference changes rebuild the widget tree, but the boot work
  /// (local load, then session restore) must run EXACTLY ONCE: a second
  /// restore would exchange the same rotating refresh token twice.
  Future<void> bootstrap() => _bootstrapFuture ??= _doBootstrap();

  Future<void> _doBootstrap() async {
    try {
      await init();
      await AuthStore.instance.restoreSession();
    } catch (error) {
      debugPrint('boot pipeline (non-fatal): $error');
    } finally {
      // Even an unexpected failure must resolve the splash screen; a stuck
      // boot is just as disruptive as a surprise login screen.
      markLoaded();
      AuthStore.instance.markBootReady();
    }
  }

  Future<List<dynamic>> _readList(String key) async {
    final raw = await localRead(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  /// LIVE load — one bootstrap call to the data API (Supabase Postgres sections).
  /// Returns true when real data arrived; otherwise offline fallbacks kick in.
  Future<bool> _loadRemote() async {
    final api = _api;
    if (api == null) return false;
    try {
      final res = await api.get('/api/bootstrap');
      if (res == null) {
        lastSyncError = 'Cloud server did not respond';
        return false;
      }
      if (!res.ok || res.json is! Map) {
        lastSyncError = res.json is Map
            ? '${(res.json as Map)['error'] ?? 'Cloud rejected the data request'}'
            : 'Invalid cloud response (${res.status})';
        return false;
      }
      final data = (res.json as Map).cast<String, dynamic>();
      final u = data['user'];
      if (u is Map) {
        remoteRole = '${u['role'] ?? ''}';
        // Reconcile the authoritative server role into the signed-in
        // identity so a promoted/demoted account reflects immediately on
        // the next data reload — no re-login required. EXCEPT the CEO, whose
        // role is LOCKED to their email: a stale deployed function that
        // answers role 'sales' must never downgrade the boss to Sales UI.
        final cur = AuthStore.instance.current;
        final lockedCeo = cur != null && cur.email == AuthStore.ceoEmail;
        if (remoteRole.isNotEmpty && cur != null && cur.role != remoteRole && !lockedCeo) {
          cur.role = remoteRole;
          AuthStore.instance.ping();
        }
        if (lockedCeo && cur!.role != 'ceo') {
          cur.role = 'ceo';
          AuthStore.instance.ping();
        }
      }

      products.addAll(parseProducts([
        for (final e in (data['products'] as List? ?? const []))
          if (e is Map) {...(e).cast<String, dynamic>(), 'id': e['_id']},
      ]));
      for (final e in (data['customers'] as List? ?? const [])) {
        if (e is Map) {
          customers.add(parseCustomer(
            {...(e).cast<String, dynamic>(), 'id': e['_id'] ?? ''}));
        }
      }
      final s = data['settings'];
      if (s is Map) {
        settings = StoreSettings.fromJson((s).cast<String, dynamic>());
      }
      SerialService.instance
          .loadFrom((data['serials'] as Map? ?? {}).cast<String, dynamic>());
      for (final e in (data['transactions'] as List? ?? const [])) {
        if (e is Map) {
          final m = (e).cast<String, dynamic>();
          transactions.add(Transaction(
            id: '${m['_id'] ?? ''}',
            date: DateTime.tryParse('${m['txn_date']}') ?? DateTime.now(),
            type: TxnType.values.firstWhere((t) => t.name == m['txn_type'],
                orElse: () => TxnType.salePayment),
            amount: _asInt(m['amount']),
            method: PaymentMethod.values.firstWhere((t) => t.name == m['method'],
                orElse: () => PaymentMethod.cash),
            reference: '${m['reference'] ?? ''}',
          ));
        }
      }
      for (final e in (data['receipts'] as List? ?? const [])) {
        if (e is Map) {
          final m = (e).cast<String, dynamic>();
          receipts.add(Receipt(
            number: '${m['no'] ?? ''}',
            date: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
            customer: _lookupCustomer(
              customers,
              m['customer_id'] as String?,
              '${m['customer_name'] ?? '—'}',
            ),
            amount: _asInt(m['amount']),
            method: PaymentMethod.values.firstWhere((t) => t.name == m['method'],
                orElse: () => PaymentMethod.cash),
            forDoc: '${m['source'] ?? ''}',
            signedBy: '${m['issued_name'] ?? 'Admin'}',
            issuedBy: '${m['issued_name'] ?? 'Admin'}',
            customerSignature: '${m['customer_signature'] ?? ''}',
          ));
        }
      }
      for (final e in (data['invoices'] as List? ?? const [])) {
        if (e is Map) invoices.add(_invoiceFromServer((e).cast<String, dynamic>(), products, customers));
      }
      for (final e in (data['docs'] as List? ?? const [])) {
        if (e is Map) {
          docHistory.add(IssuedDocument.fromJson((e).cast<String, dynamic>()));
        }
      }
      for (final e in (data['sales'] as List? ?? const [])) {
        if (e is Map) sales.add(_saleFromServer((e).cast<String, dynamic>(), products, customers));
      }
      for (final e in (data['adjustments'] as List? ?? const [])) {
        if (e is Map) {
          final adj = _adjustmentFromServer((e).cast<String, dynamic>(), products);
          if (adj != null) adjustments.add(adj);
        }
      }
      for (final e in (data['mils'] as List? ?? const [])) {
        if (e is Map) {
          final log = _milsLogFromServer((e).cast<String, dynamic>(), customers);
          if (log != null) milsLogs.add(log);
        }
      }
      // A successful bootstrap IS the live dataset, even when empty.
      lastSyncError = null;
      return true;
    } catch (error) {
      lastSyncError = 'Cloud data could not be read: $error';
      debugPrint('cloud bootstrap failed: $error');
      return false;
    }
  }

  /// Clears local collections and pulls the live dataset again (called right
  /// after a successful sign-in, so the app lands on real server data).
  Future<void> reloadRemote() async {
    if (!Env.apiConfigured || _api == null) return;
    _api!.accessToken = AuthStore.instance.accessToken;
    // On account change, never upload the previous user's device cache under
    // the newly authenticated identity. Start with the shared cloud dataset;
    // ordinary in-session refreshes handle that user's own pending queue.
    _clearAll();
    final okRemote = await _loadRemote();
    if (okRemote) {
      lastServerSync = DateTime.now();
      await _persistAll();
      await _markAllKnown();
    } else {
      _clearAll();
      await _loadLocal();
    }
    notifyListeners();
    pushHomeWidgetStats();
  }

  /// LIVE REFRESH (every page, every device): re-pulls the server dataset
  /// and swaps it in atomically. Called by the app shell on a timer, on app
  /// resume and after pull-to-refresh, so a sale made on one device shows
  /// on every other device within seconds. Pending offline records are
  /// uploaded first; if the server is unreachable the current data is kept.
  bool _refreshing = false;
  bool _manualSyncing = false;
  DateTime? lastServerSync;
  String? lastSyncError;
  String _changeStamp = '';

  /// Cheap poll: asks the server for its latest change stamp and only pulls
  /// the full dataset when it differs from the last one seen. Lets the app
  /// poll every few seconds without re-downloading anything.
  Future<void> pollChanges() async {
    if (!Env.apiConfigured || _api == null || AuthStore.instance.accessToken == null) return;
    if (_refreshing || _uploading) return;
    _api!.accessToken = AuthStore.instance.accessToken;
    final res = await _api!.get('/api/changes');
    if (res == null || !res.ok || res.json is! Map) return;
    final stamp = '${(res.json as Map)['stamp'] ?? ''}';
    if (stamp == _changeStamp && lastServerSync != null) return;
    if (await refreshRemote()) _changeStamp = stamp;
  }

  /// Loads history older than what the bootstrap carries (latest 300).
  /// Returns how many rows were appended; false-y when nothing older exists.
  bool _loadingMore = false;
  final Set<String> exhaustedHistory = {};
  Future<int> loadOlder(String kind) async {
    if (!Env.apiConfigured || _api == null || AuthStore.instance.accessToken == null) return 0;
    if (_loadingMore || exhaustedHistory.contains(kind)) return 0;
    _loadingMore = true;
    try {
      _api!.accessToken = AuthStore.instance.accessToken;
      String? before;
      switch (kind) {
        case 'sales': if (sales.isNotEmpty) before = sales.map((s) => s.date).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(); break;
        case 'receipts': if (receipts.isNotEmpty) before = receipts.map((s) => s.date).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(); break;
        case 'invoices': if (invoices.isNotEmpty) before = invoices.map((s) => s.issued).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(); break;
        case 'transactions': if (transactions.isNotEmpty) before = transactions.map((s) => s.date).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(); break;
        case 'mils': if (milsLogs.isNotEmpty) before = milsLogs.map((s) => s.serviceDate).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(); break;
        case 'docs': if (docHistory.isNotEmpty) before = docHistory.map((s) => s.issuedAt).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(); break;
      }
      final q = before == null ? '' : '&before=${Uri.encodeQueryComponent(before)}';
      final res = await _api!.get('/api/history?kind=$kind$q');
      if (res == null || !res.ok || res.json is! Map) return 0;
      final body = res.json as Map;
      final rows = [for (final e in (body['rows'] as List? ?? const [])) if (e is Map) e.cast<String, dynamic>()];
      if (body['more'] != true) exhaustedHistory.add(kind);
      var added = 0;
      for (final m in rows) {
        switch (kind) {
          case 'sales':
            final id = '${m['_id'] ?? ''}';
            if (sales.any((x) => x.id == id)) continue;
            sales.add(_saleFromServer(m, products, customers)); added++;
          case 'receipts':
            final no = '${m['no'] ?? ''}';
            if (receipts.any((x) => x.number == no)) continue;
            receipts.add(Receipt(
              number: no, date: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
              customer: _lookupCustomer(customers, m['customer_id'] as String?, '${m['customer_name'] ?? '—'}'),
              amount: _asInt(m['amount']),
              method: PaymentMethod.values.firstWhere((t) => t.name == m['method'], orElse: () => PaymentMethod.cash),
              forDoc: '${m['source'] ?? ''}', signedBy: '${m['issued_name'] ?? 'Admin'}',
              issuedBy: '${m['issued_name'] ?? 'Admin'}', customerSignature: '${m['customer_signature'] ?? ''}',
            )); added++;
          case 'invoices':
            final no = '${m['no'] ?? ''}';
            if (invoices.any((x) => x.number == no)) continue;
            invoices.add(_invoiceFromServer(m, products, customers)); added++;
          case 'transactions':
            final id = '${m['_id'] ?? ''}';
            if (transactions.any((x) => x.id == id)) continue;
            transactions.add(Transaction(
              id: id, date: DateTime.tryParse('${m['txn_date']}') ?? DateTime.now(),
              type: TxnType.values.firstWhere((t) => t.name == m['txn_type'], orElse: () => TxnType.salePayment),
              amount: _asInt(m['amount']),
              method: PaymentMethod.values.firstWhere((t) => t.name == m['method'], orElse: () => PaymentMethod.cash),
              reference: '${m['reference'] ?? ''}',
            )); added++;
          case 'mils':
            final log = _milsLogFromServer(m, customers);
            if (log == null || milsLogs.any((x) => x.id == log.id)) continue;
            milsLogs.add(log); added++;
          case 'docs':
            final d = IssuedDocument.fromJson(m);
            if (docHistory.any((x) => x.type == d.type && x.serial == d.serial)) continue;
            docHistory.add(d); added++;
        }
      }
      if (added > 0) notifyListeners();
      return added;
    } catch (_) {
      return 0;
    } finally {
      _loadingMore = false;
    }
  }

  /// User-requested sync waits for any background cycle instead of falsely
  /// reporting failure merely because the eight-second timer is active.
  Future<bool> syncNow() async {
    if (_manualSyncing) return false;
    _manualSyncing = true;
    try {
      for (var i = 0; i < 100 && (_refreshing || _uploading); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (_refreshing || _uploading) return false;
      var ok = await refreshRemote(manual: true);
      if (!ok && (lastSyncError?.contains('520') ?? false)) {
        // HTTP 520 can be produced before the function executes when an old
        // session JWT still contains legacy oversized Auth metadata. Refresh
        // through the public body-based endpoint, adopt its repaired token,
        // then retry the authoritative read once. Use the refresh path (NOT
        // restoreSession): a full boot restore here would re-read storage,
        // re-run the identity bootstrap and rotate the token a second time
        // while the 8s poll is active.
        await AuthStore.instance.forceRefreshSession();
        ok = await refreshRemote(manual: true);
      }
      return ok;
    } finally {
      _manualSyncing = false;
    }
  }

  Future<bool> refreshRemote({bool manual = false}) async {
    if (!Env.apiConfigured || _api == null || AuthStore.instance.accessToken == null) return false;
    if ((_manualSyncing && !manual) || _refreshing || _uploading) return false;
    _refreshing = true;
    try {
      _api!.accessToken = AuthStore.instance.accessToken;
      // Reads and writes are independent: a rejected legacy queue row must
      // not prevent fresh CEO/Admin/Sales changes from being downloaded.
      await _uploadOfflineData();
      exhaustedHistory.clear();
      // load into the live lists but keep a snapshot to roll back on failure
      final hadLocalData = _hasAnyData;
      final snap = (
        List.of(products), List.of(customers), List.of(sales), List.of(transactions),
        List.of(receipts), List.of(invoices), List.of(milsLogs), List.of(adjustments), List.of(docHistory),
      );
      _clearAll();
      final ok = await _loadRemote();
      // An EMPTY successful snapshot is just as dangerous as a failed one:
      // persisting it would overwrite this device's cached business records.
      // Roll back and skip _persistAll() so the local cache files survive.
      if (!ok || (hadLocalData && !_hasAnyData)) {
        _clearAll();
        products.addAll(snap.$1); customers.addAll(snap.$2); sales.addAll(snap.$3);
        transactions.addAll(snap.$4); receipts.addAll(snap.$5); invoices.addAll(snap.$6);
        milsLogs.addAll(snap.$7); adjustments.addAll(snap.$8); docHistory.addAll(snap.$9);
        if (ok) lastSyncError = _emptyCloudMessage;
        notifyListeners();
        return false;
      }
      lastServerSync = DateTime.now();
      await _persistAll();
      await _markAllKnown();
      notifyListeners();
      pushHomeWidgetStats();
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  void _clearAll() {
    products.clear();
    customers.clear();
    sales.clear();
    transactions.clear();
    receipts.clear();
    invoices.clear();
    milsLogs.clear();
    adjustments.clear();
    docHistory.clear();
  }

  // ---- empty-cloud safety net ---------------------------------------------
  // Owner directive 2026-11-04: Supabase alone is the backend. The new
  // Postgres store starts EMPTY (MongoDB was cut off, nothing was imported).
  // refreshRemote() replaces the live lists with the server snapshot and then
  // writes them to disk, so without this guard the first successful sync after
  // the migration could wipe records still cached on a device.
  static const _emptyCloudMessage =
      'Cloud store is empty — local records kept. Enter or import data in the app first.';

  bool get _hasAnyData => products.isNotEmpty ||
      customers.isNotEmpty || sales.isNotEmpty || transactions.isNotEmpty ||
      receipts.isNotEmpty || invoices.isNotEmpty || milsLogs.isNotEmpty ||
      adjustments.isNotEmpty || docHistory.isNotEmpty;

  static const _localDataFiles = [
    'products', 'customers', 'sales', 'transactions', 'receipts',
    'invoices', 'mils_logs', 'adjustments', 'doc_history',
  ];

  /// At boot the live lists are still empty, so check the cache files
  /// directly before deciding whether an empty cloud snapshot is acceptable.
  Future<bool> _localFilesHaveData() async {
    for (final f in _localDataFiles) {
      if ((await _readList(f)).isNotEmpty) return true;
    }
    return false;
  }

  /// Pushes the three headline figures onto the Android home-screen widget.
  /// No-op everywhere else (the method channel only exists on Android).
  void pushHomeWidgetStats() {
    final now = DateTime.now();
    var todaySales = 0;
    for (final t in transactions) {
      if (t.date.year == now.year &&
          t.date.month == now.month &&
          t.date.day == now.day) {
        todaySales += t.amount;
      }
    }
    final dueInvoices = invoices.where((i) => i.balance > 0).length;
    unawaited(WidgetBridge.updateStats(
      todaySales: fmt.nairaCompact(todaySales),
      receipts: '${receipts.length}',
      invoices: '$dueInvoices',
    ));
  }

  // ------------------------------------------------------------ notifications
  /// Pulls the latest notifications (transactions, documents, stock,
  /// customers, products, MILS, staff changes, announcements) for every
  /// signed-in user — CEO, Admin and Sales all see the same feed (owner
  /// directive 2026-09-01). Safe to call repeatedly (e.g. from a poll timer).
  Future<void> refreshNotifications() async {
    unawaited(flushSyncQueue()); // piggy-back: retry pending offline uploads
    final api = _api;
    if (!Env.apiConfigured || api == null || AuthStore.instance.accessToken == null) {
      await _loadLocalNotifications();
      return;
    }
    api.accessToken = AuthStore.instance.accessToken;
    try {
      final res = await api.get('/api/notifications');
      if (res == null || !res.ok || res.json is! Map) return;
      final list = (res.json as Map)['notifications'];
      if (list is! List) return;
      final previousIds = notifications.map((item) => item.id).toSet();
      final incoming = [
        for (final e in list)
          if (e is Map) AppNotification.fromJson(e.cast<String, dynamic>()),
      ];
      notifications
        ..clear()
        ..addAll(incoming);
      if (_remoteNotificationsPrimed) {
        for (final item in incoming.reversed) {
          if (previousIds.contains(item.id)) continue;
          unawaited(NotificationService.instance.show(
            key: 'remote:${item.id}',
            title: item.title,
            body: item.message,
            payload: item.ref,
            kind: item.kind,
            critical: item.kind == 'stock' || item.kind == 'approval' ||
                item.kind == 'stockApproval' || item.kind == 'voucherApproval' || item.kind == 'staff',
          ));
        }
      }
      _remoteNotificationsPrimed = true;
      notifyListeners();
    } catch (_) {
      // offline — keep whatever was last loaded
    }
  }

  /// Marks a notification as read by the current user (idempotent — the
  /// server only appends once per uid) and updates the local copy so the
  /// unread badge count reflects it immediately.
  Future<void> markNotificationRead(String id) async {
    final uid = AuthStore.instance.remoteSignInUid;
    final name = AuthStore.instance.current?.name ?? '';
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && uid != null && !notifications[idx].isReadBy(uid)) {
      notifications[idx] = AppNotification(
        id: notifications[idx].id,
        kind: notifications[idx].kind,
        title: notifications[idx].title,
        message: notifications[idx].message,
        ref: notifications[idx].ref,
        createdBy: notifications[idx].createdBy,
        createdByName: notifications[idx].createdByName,
        createdAt: notifications[idx].createdAt,
        readBy: [
          ...notifications[idx].readBy,
          NotificationRead(uid: uid, name: name, at: DateTime.now()),
        ],
      );
      notifyListeners();
    }
    await _saveLocalNotifications();
    try {
      await _apiPost('/api/notifications/read', {'id': id});
    } catch (_) {
      // best-effort — the read receipt will resync next refresh
    }
  }

  /// Marks EVERY notification as read by the current user (Settings →
  /// Preferences). Updates the local copies immediately so the unread badge
  /// clears, then asks the server to do the same (idempotent — each uid is
  /// only appended to a notification's `read_by` once).
  Future<void> markAllNotificationsRead() async {
    final uid = AuthStore.instance.remoteSignInUid;
    final name = AuthStore.instance.current?.name ?? '';
    if (uid != null && uid.isNotEmpty) {
      notifications = [
        for (final n in notifications)
          if (!n.isReadBy(uid))
            AppNotification(
              id: n.id,
              kind: n.kind,
              title: n.title,
              message: n.message,
              ref: n.ref,
              createdBy: n.createdBy,
              createdByName: n.createdByName,
              createdAt: n.createdAt,
              readBy: [
                ...n.readBy,
                NotificationRead(uid: uid, name: name, at: DateTime.now()),
              ],
            )
          else
            n,
      ];
      notifyListeners();
    }
    await _saveLocalNotifications();
    try {
      await _apiPost('/api/notifications/read-all', {});
    } catch (_) {
      // best-effort — the read receipts will resync on the next refresh
    }
  }

  /// CEO/Admin-only: broadcasts an announcement, which lands in every
  /// user's notification feed exactly like a transaction notification, but
  /// with kind 'announcement' so the UI can show it distinctly and the
  /// sender can see who has read it via `readBy`.
  Future<String?> sendAnnouncement(String title, String message) async {
    if (!Env.apiConfigured) {
      if (title.trim().isEmpty) return 'Announcement title is required';
      if (message.trim().isEmpty) return 'Announcement message is required';
      await addLocalNotification('announcement', title.trim(), message.trim(), '');
      return null;
    }
    try {
      final applied = await _apiPost('/api/announcements', {'title': title, 'message': message});
      if (!applied) return 'Network unreachable — check your connection';
      await refreshNotifications();
      return null;
    } catch (e) {
      debugPrint('sendAnnouncement failed: $e');
      final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '';
      return msg.isEmpty ? 'Something went wrong — please try again.' : msg;
    }
  }

  // ---- device-local notification feed (offline-first) ----
  bool _localNotifsLoaded = false;
  Future<void> _loadLocalNotifications() async {
    if (_localNotifsLoaded) return;
    _localNotifsLoaded = true;
    final raw = await _readList('notifications');
    notifications = [
      for (final e in raw)
        if (e is Map) AppNotification.fromJson(e.cast<String, dynamic>()),
    ];
    notifyListeners();
  }

  Future<void> _saveLocalNotifications() =>
      writeStore('notifications', notifications.take(500).map((n) => n.toJson()).toList());

  /// Records an in-app notification on this device (mirrors what the server
  /// used to write for transactions, documents, stock, MILS, announcements).
  Future<void> addLocalNotification(String kind, String title, String message, String ref) async {
    await _loadLocalNotifications();
    final me = AuthStore.instance.current;
    notifications.insert(0, AppNotification(
      id: 'L${DateTime.now().microsecondsSinceEpoch}',
      kind: kind, title: title, message: message, ref: ref,
      createdBy: AuthStore.instance.remoteSignInUid ?? me?.email ?? '',
      createdByName: me?.name ?? '',
      createdAt: DateTime.now(),
      readBy: const [],
    ));
    final created = notifications.first;
    notifyListeners();
    await _saveLocalNotifications();
    unawaited(NotificationService.instance.show(
      key: 'local:${created.id}',
      title: created.title,
      body: created.message,
      payload: created.ref,
      kind: kind,
      critical: kind == 'stock' || kind == 'approval' || kind == 'staff',
    ));
  }

  // ------------------------------------------------------------------ staff
  /// CEO/Admin staff directory (name/email/phone/role). Only the CEO can
  /// actually change a role via [setStaffRole] — the server enforces this
  /// too, so an Admin calling it will get a 403 back.
  Future<void> refreshStaff() async {
    final api = _api;
    if (!Env.apiConfigured || api == null || AuthStore.instance.accessToken == null) {
      // OFFLINE-FIRST: the directory is every account known to this device.
      staff
        ..clear()
        ..addAll([
          for (final u in AuthStore.instance.users)
            StaffMember(uid: u.email, name: u.name, email: u.email, phone: '', role: u.role),
        ]);
      notifyListeners();
      return;
    }
    api.accessToken = AuthStore.instance.accessToken;
    try {
      final res = await api.get('/api/staff');
      if (res == null || !res.ok || res.json is! Map) return;
      final list = (res.json as Map)['staff'];
      if (list is! List) return;
      // A historical bootstrap bug could leave duplicate profile documents.
      // Canonicalise by uid first and normalised email second so the locked
      // CEO (and every other staff identity) can render only once.
      final unique = <String, StaffMember>{};
      for (final e in list) {
        if (e is! Map) continue;
        final member = StaffMember.fromJson(e.cast<String, dynamic>());
        final emailKey = member.email.trim().toLowerCase();
        final key = emailKey.isNotEmpty ? 'email:$emailKey' : 'uid:${member.uid}';
        unique[key] = member;
      }
      staff
        ..clear()
        ..addAll(unique.values);
      notifyListeners();
    } catch (_) {
      // offline — keep whatever was last loaded
    }
  }

  /// CEO-only: promotes a Sales staffer to Admin, or demotes an Admin back
  /// to Sales. Throws (as a message string) on any refusal — including a
  /// non-CEO caller, since the server is the source of truth on authority.
  Future<String?> setStaffRole(String uid, String role) async {
    if (!Env.apiConfigured) {
      if (!AuthStore.instance.isCeo) return 'Only the CEO can promote or demote staff';
      final u = AuthStore.instance.users.where((x) => x.email == uid).firstOrNull;
      if (u == null) return 'Staff member not found';
      if (u.role == 'ceo' || u.email == AuthStore.ceoEmail) return 'The CEO role cannot be changed here';
      u.role = role;
      await AuthStore.instance.persistUsers();
      await refreshStaff();
      return null;
    }
    try {
      final applied = await _apiPost('/api/staff/role', {'uid': uid, 'role': role});
      if (!applied) return 'Network unreachable — check your connection';
      await refreshStaff();
      return null;
    } catch (e) {
      debugPrint('setStaffRole failed: $e');
      final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '';
      return msg.isEmpty ? 'Something went wrong — please try again.' : msg;
    }
  }

  Future<String?> deleteStaff(String uid) async {
    if (!AuthStore.instance.isCeo) return 'Only the CEO can delete staff accounts';
    if (_api == null || AuthStore.instance.accessToken == null) {
      return 'Cloud connection is required. Staff was not deleted.';
    }
    try {
      final res = await _api!.post('/api/staff/delete', {'uid': uid});
      if (res == null || !res.ok) {
        return (res?.json is Map ? '${(res!.json as Map)['error'] ?? ''}' : '').trim().isNotEmpty
            ? '${(res!.json as Map)['error']}' : 'Staff deletion failed';
      }
      staff.removeWhere((member) => member.uid == uid);
      notifyListeners();
      return null;
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Role reported by the API for the signed-in user (ceo/admin/sales).
  String remoteRole = '';

  /// Site photos attached to MILS jobs: logId → data URLs. Real captures
  /// from the device camera/gallery (no placeholders).
  final Map<String, List<String>> milsPhotos = {};

  /// CEO/Admin: create a product from the app's own fields and push it to
  /// the same server used by every build.
  /// both builds use. Local cache mirrors it; offline it queues for sync.
  Future<void> addProduct(Product p) async {
    final normalized = p.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (products.any((x) => x.id != p.id &&
        x.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') == normalized)) {
      throw Exception('This stock item already exists. Select or edit the existing item instead.');
    }
    final serverApplied = await _apiPost('/api/products/upsert', {
      'products': [productToJson(p)],
    });
    final idx = products.indexWhere((x) => x.id == p.id);
    if (idx == -1) {
      products.add(p);
    } else {
      products[idx] = p;
    }
    await _persistAll();
    if (serverApplied) {
      await _markKnown('products', [productToJson(p)]);
    } else {
      enqueueSync('products', [productToJson(p)]);
      unawaited(flushSyncQueue());
    }
    notifyListeners();
  }

  Future<void> updateProductDetails(Product original, Product updated) async {
    if (_api == null || AuthStore.instance.accessToken == null) {
      throw Exception('Cloud connection is required. Product was not changed.');
    }
    final res = await _api!.post('/api/products/upsert', {
      'products': [productToJson(updated)],
    });
    if (res == null || !res.ok) throw Exception(
      (res?.json is Map ? (res!.json as Map)['error'] : null) ?? 'Product update failed');
    final index = products.indexWhere((p) => p.id == original.id);
    if (index >= 0) products[index] = updated;
    await writeStore('products', products.map(productToJson).toList());
    await _markKnown('products', [productToJson(updated)]);
    notifyListeners();
  }

  Future<void> updateProductImages(Product original, List<String> imageUrls) async {
    final updated = Product(
      id: original.id, name: original.name, brand: original.brand, category: original.category,
      costPrice: original.costPrice, sellingPrice: original.sellingPrice,
      qtyOnHand: original.qtyOnHand, reorderLevel: original.reorderLevel,
      unit: original.unit, length: original.length, lengthUnit: original.lengthUnit,
      width: original.width, widthUnit: original.widthUnit,
      size: original.size, sizeUnit: original.sizeUnit,
      weight: original.weight, weightUnit: original.weightUnit,
      imageUrls: List.unmodifiable(imageUrls), isService: original.isService,
    );
    if (_api == null || AuthStore.instance.accessToken == null) {
      throw Exception('Cloud connection is required. Product images were not changed.');
    }
    final res = await _api!.post('/api/products/upsert', {
      'products': [productToJson(updated)],
    });
    if (res == null || !res.ok) throw Exception(
      (res?.json is Map ? (res!.json as Map)['error'] : null) ?? 'Image update failed');
    final index = products.indexWhere((p) => p.id == original.id);
    if (index >= 0) products[index] = updated;
    await writeStore('products', products.map(productToJson).toList());
    await _markKnown('products', [productToJson(updated)]);
    notifyListeners();
  }

  Future<void> deleteProduct(Product product) async {
    if (_api == null || AuthStore.instance.accessToken == null) {
      throw Exception('Cloud connection is required. Product was not deleted.');
    }
    final res = await _api!.post('/api/products/delete', {'id': product.id});
    if (res == null || !res.ok) throw Exception(
      (res?.json is Map ? (res!.json as Map)['error'] : null) ?? 'Product deletion failed');
    products.removeWhere((p) => p.id == product.id);
    await writeStore('products', products.map(productToJson).toList());
    notifyListeners();
  }

  Future<void> deleteCustomer(Customer customer) async {
    if (_api == null || AuthStore.instance.accessToken == null) {
      throw Exception('Cloud connection is required. Customer was not deleted.');
    }
    final res = await _api!.post('/api/customers/delete', {'id': customer.id});
    if (res == null || !res.ok) throw Exception(
      (res?.json is Map ? (res!.json as Map)['error'] : null) ?? 'Customer deletion failed');
    customers.removeWhere((c) => c.id == customer.id);
    await writeStore('customers', customers.map(customerToJson).toList());
    notifyListeners();
  }

  Future<List<String>> uploadProductImages(String productId, List<String> dataUrls) async {
    if (dataUrls.isEmpty) return const [];
    if (_api == null || AuthStore.instance.accessToken == null) {
      throw Exception('Cloud connection is required to upload stock images.');
    }
    final res = await _api!.post('/api/products/images', {
      'product_id': productId, 'images': dataUrls,
    });
    if (res == null || !res.ok || res.json is! Map) {
      throw Exception((res?.json is Map ? (res!.json as Map)['error'] : null) ??
          'Could not upload stock images.');
    }
    return ((res.json as Map)['urls'] as List? ?? const []).map((x) => '$x').toList();
  }

  /// Attach real site photos (data URLs) to a MILS job.
  Future<void> attachMilsPhotos(String logId, List<String> dataUrls) async {
    if (dataUrls.isEmpty) return;
    milsPhotos.putIfAbsent(logId, () => <String>[]).addAll(dataUrls);
    final all = <Map<String, dynamic>>[];
    milsPhotos.forEach((log, urls) {
      for (final u in urls) {
        all.add({'log': log, 'url': u});
      }
    });
    await writeStore('mils_photos', all);
    notifyListeners();
  }

  /// Next document serial — SERVER-assigned when the backend is configured
  /// (atomic RPC and paper-book continuity);
  /// local counter otherwise (offline dev).
  Future<int> nextDocSerial({
    required String type,
    required String customer,
    required double total,
    String? verifyHash,
    String contact = '', // customer phone OR email — server rejects documents without one
    String? issueKey,
  }) async {
    if (Env.apiConfigured && _api != null && AuthStore.instance.accessToken != null) {
      final res = await _api!.post('/api/docs/issue', {
        'type': type, 'customer': customer, 'total': total,
        'hash': verifyHash ?? '',
        'contact': contact, 'issue_key': issueKey,
      });
      if (res != null && res.ok && res.json is Map) {
        final serial = _asInt((res.json as Map)['serial']);
        if (serial > 0) {
          SerialService.instance.reseed(type, serial); // keep peek() in step
          return serial;
        }
      }
      throw Exception(res == null
          ? 'Data API unreachable — document NOT issued offline'
          : 'Document NOT issued — ${(res.json is Map ? (res.json as Map)['error'] : null) ?? 'server refused the request'}');
    }
    return SerialService.instance.next(type);
  }

  Future<bool> _loadLocal() async {
    final rawProducts = await _readList('products');
    final rawCustomers = await _readList('customers');

    products.addAll(parseProducts(rawProducts));
    for (final e in rawCustomers) {
      if (e is Map) customers.add(parseCustomer((e).cast<String, dynamic>()));
    }
    final rawPhotos = await _readList('mils_photos');
    for (final e in rawPhotos) {
      if (e is Map) {
        final m = (e).cast<String, dynamic>();
        milsPhotos.putIfAbsent('${m['log']}', () => <String>[]).add('${m['url']}');
      }
    }
    final rawTxns = await _readList('transactions');
    for (final e in rawTxns) {
      if (e is Map) {
        final m = (e).cast<String, dynamic>();
        transactions.add(Transaction(
          id: '${m['id'] ?? ''}',
          date: DateTime.tryParse('${m['date']}') ?? DateTime.now(),
          type: TxnType.values.firstWhere((t) => t.name == m['type'], orElse: () => TxnType.salePayment),
          amount: _asInt(m['amount']),
          method: PaymentMethod.values.firstWhere((t) => t.name == m['method'], orElse: () => PaymentMethod.cash),
          reference: '${m['reference'] ?? ''}',
        ));
      }
    }
    final rawSettings = await readStore('settings');
    if (rawSettings.isNotEmpty) {
      settings = StoreSettings.fromJson(rawSettings);
    }
    final rawSerials = await readStore('serials');
    if (rawSerials.isNotEmpty) {
      SerialService.instance.loadFrom(rawSerials);
    }
    final rawReceipts = await _readList('receipts');
    for (final e in rawReceipts) {
      if (e is Map) {
        final m = (e).cast<String, dynamic>();
        receipts.add(Receipt(
          number: '${m['number'] ?? ''}',
          date: DateTime.tryParse('${m['date']}') ?? DateTime.now(),
          customer: _lookupCustomer(
            customers,
            m['customer_id'] as String?,
            '${m['customer'] ?? ''}',
          ),
          amount: _asInt(m['amount']),
          method: PaymentMethod.values.firstWhere((t) => t.name == m['method'], orElse: () => PaymentMethod.cash),
          forDoc: '${m['for_doc'] ?? ''}',
          signedBy: '${m['signed_by'] ?? 'Admin'}',
          issuedBy: '${m['issued_by'] ?? 'Admin'}',
        ));
      }
    }
    final rawInvoices = await _readList('invoices');
    for (final e in rawInvoices) {
      if (e is Map) {
        final inv = _invoiceFromLocal((e).cast<String, dynamic>(), products, customers);
        if (inv != null) invoices.add(inv);
      }
    }
    final rawDocs = await _readList('doc_history');
    for (final e in rawDocs) {
      if (e is Map) docHistory.add(IssuedDocument.fromJson((e).cast<String, dynamic>()));
    }
    final rawSales = await _readList('sales');
    for (final e in rawSales) {
      if (e is Map) {
        final s = _saleFromLocal((e).cast<String, dynamic>(), products, customers);
        if (s != null) sales.add(s);
      }
    }
    final rawAdjustments = await _readList('adjustments');
    for (final e in rawAdjustments) {
      if (e is Map) {
        final a = _adjustmentFromLocal((e).cast<String, dynamic>(), products);
        if (a != null) adjustments.add(a);
      }
    }
    final rawMils = await _readList('mils_logs');
    for (final e in rawMils) {
      if (e is Map) {
        final log = _milsLogFromLocal((e).cast<String, dynamic>(), customers);
        if (log != null) milsLogs.add(log);
      }
    }
    return true;
  }

  // ---------------------------------------------------------------- sync
  // OFFLINE ↔ SERVER RECONCILIATION. Every record has a stable offline key
  // (<device>:<table>:<id>:<date>). `_known` holds the keys the server
  // already has (loaded from it, applied by it, or uploaded). A flush posts
  // every local record NOT in that set to POST /api/sync/import, which is
  // idempotent server-side ($setOnInsert by offline_key), so a retry after a
  // half-failed upload can never duplicate anything.
  final Set<String> _known = {};
  bool _knownLoaded = false;
  String _deviceId = '';
  bool _uploading = false;

  Future<void> _loadSyncState() async {
    if (_knownLoaded) return;
    final st = await readStore('sync_state');
    _deviceId = '${st['device'] ?? ''}';
    if (_deviceId.isEmpty) {
      _deviceId = 'd${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      await writeStore('sync_state', {'device': _deviceId, 'known': const []});
    }
    for (final k in (st['known'] as List? ?? const [])) {
      _known.add('$k');
    }
    _knownLoaded = true;
  }

  Future<void> _saveSyncState() =>
      writeStore('sync_state', {'device': _deviceId, 'known': _known.toList()});

  static final _objectId = RegExp(r'^[0-9a-f]{24}$');
  // 24-hex server ids, or customers already uploaded under their offline key
  // (their server _id IS the key, so they come back as '<device>:c:<id>').
  static bool _isServerId(String id) => _objectId.hasMatch(id) || id.contains(':c:');

  /// Offline key for a LOCAL JSON row (the same shape the files hold).
  String? _keyFor(String table, Map<String, dynamic> r) {
    String id;
    switch (table) {
      case 'customers':
        id = '${r['id'] ?? ''}';
        if (id.isEmpty || _isServerId(id)) return null; // server customers need no upload
        return '$_deviceId:c:$id';
      case 'products':
        id = '${r['id'] ?? ''}';
        return id.isEmpty ? null : '$_deviceId:p:$id';
      case 'sales':
        id = '${r['id'] ?? ''}';
        if (id.isEmpty || _isServerId(id)) return null;
        return '$_deviceId:s:$id:${r['date']}';
      case 'transactions':
        id = '${r['id'] ?? ''}';
        if (id.isEmpty || _isServerId(id)) return null;
        return '$_deviceId:t:$id:${r['date']}';
      case 'receipts':
        id = '${r['number'] ?? ''}';
        return id.isEmpty ? null : '$_deviceId:r:$id:${r['date']}';
      case 'invoices':
        id = '${r['number'] ?? ''}';
        return id.isEmpty ? null : '$_deviceId:i:$id:${r['issued']}';
      case 'documents':
        return '$_deviceId:d:${r['type']}:${r['serial']}';
      case 'mils_logs':
        id = '${r['mils_no'] ?? ''}';
        return id.isEmpty ? null : '$_deviceId:m:$id:${r['service_date']}';
      case 'stock_adjustments':
        id = '${r['id'] ?? ''}';
        if (id.isEmpty || _isServerId(id)) return null;
        return '$_deviceId:a:$id:${r['date']}';
    }
    return null;
  }

  /// Marks rows the SERVER already holds (applied online or loaded from it).
  Future<void> _markKnown(String table, Iterable<Map<String, dynamic>> rows) async {
    await _loadSyncState();
    var changed = false;
    for (final r in rows) {
      final k = _keyFor(table, r);
      if (k != null && _known.add(k)) changed = true;
    }
    if (changed) await _saveSyncState();
  }

  Future<void> _markAllKnown() async {
    await _loadSyncState();
    var changed = false;
    void add(String table, Iterable<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final key = _keyFor(table, row);
        if (key != null && _known.add(key)) changed = true;
      }
    }
    add('customers', customers.map(customerToJson));
    add('products', products.map(productToJson));
    add('sales', sales.map(saleToJson));
    add('transactions', transactions.map(txnToJson));
    add('receipts', receipts.map(receiptToJson));
    add('invoices', invoices.map(invoiceToJson));
    add('documents', docHistory.map((d) => d.toJson()));
    add('mils_logs', milsLogs.map(milsLogToJson));
    add('stock_adjustments', adjustments.map(adjToJson));
    if (changed) await _saveSyncState();
  }

  /// Flags rows as changed so the next flush re-sends them (products carry
  /// their stock level, so an edit must reach the server again).
  void enqueueSync(String table, List<Map<String, dynamic>> rows) {
    if (table != 'products') return; // other tables are append-only by key
    unawaited(() async {
      await _loadSyncState();
      for (final r in rows) {
        final k = _keyFor(table, r);
        if (k != null) _known.remove(k);
      }
      await _saveSyncState();
    }());
  }

  /// Pushes pending offline records to the data API. No-op when the backend
  /// isn't configured or nothing is pending; safe to call often.
  Future<void> flushSyncQueue() async {
    await _uploadOfflineData();
  }

  Future<List<Map<String, dynamic>>> _rows(String file, Iterable<Map<String, dynamic>> Function() live) async {
    if (_loaded) return live().toList();
    return [for (final e in await _readList(file)) if (e is Map) e.cast<String, dynamic>()];
  }

  /// True when nothing is pending or the upload succeeded; false when
  /// offline records still wait (server unreachable / rejected).
  Future<bool> _uploadOfflineData() async {
    if (!Env.apiConfigured || _api == null || AuthStore.instance.accessToken == null) return false;
    if (_uploading) return false;
    _uploading = true;
    try {
      await _loadSyncState();
      _api!.accessToken = AuthStore.instance.accessToken;
      final custRows = await _rows('customers', () => customers.map(customerToJson));
      final prodRows = await _rows('products', () => products.map(productToJson));
      final saleRows = await _rows('sales', () => sales.map(saleToJson));
      final txnRows = await _rows('transactions', () => transactions.map(txnToJson));
      final recRows = await _rows('receipts', () => receipts.map(receiptToJson));
      final invRows = await _rows('invoices', () => invoices.map(invoiceToJson));
      final docRows = await _rows('doc_history', () => docHistory.map((d) => d.toJson()));
      final milsRows = await _rows('mils_logs', () => milsLogs.map(milsLogToJson));
      final adjRows = await _rows('adjustments', () => adjustments.map(adjToJson));
      final serialsRaw = _loaded ? SerialService.instance.toJson() : await readStore('serials');

      final custName = {for (final c in custRows) '${c['id']}': '${c['name'] ?? ''}'};
      String? custRef(dynamic id) {
        final s = '$id';
        if (s.isEmpty || s == 'null') return null;
        if (_isServerId(s)) return s;
        return custName.containsKey(s) ? '$_deviceId:c:$s' : null;
      }
      final prodName = {for (final p in prodRows) '${p['id']}': '${p['name'] ?? ''}'};

      final sent = <String>[];
      List<Map<String, dynamic>> pick(String table, List<Map<String, dynamic>> rows,
          Map<String, dynamic> Function(Map<String, dynamic>) shape) {
        final out = <Map<String, dynamic>>[];
        for (final r in rows) {
          final k = _keyFor(table, r);
          if (k == null || _known.contains(k)) continue;
          out.add({...shape(r), 'offline_key': k});
          sent.add(k);
        }
        return out;
      }

      final payload = <String, dynamic>{
        'device': _deviceId,
        'customers': pick('customers', custRows, (r) => {
          'name': r['name'], 'is_corporate': r['is_corporate'] == true, 'phone': r['phone'],
          'email': r['email'], 'address': r['address'], 'credit_balance': r['credit_balance'],
        }),
        'products': pick('products', prodRows, (r) => r),
        'sales': pick('sales', saleRows, (r) {
          final items = [
            for (final it in (r['items'] as List? ?? const []))
              if (it is Map) {
                'product_id': '${it['product']}', 'name': prodName['${it['product']}'] ?? 'Item',
                'qty': it['qty'], 'unit_price': it['unit_price'],
              }
          ];
          var subtotal = 0;
          for (final it in items) subtotal += _asInt(it['qty']) * _asInt(it['unit_price']);
          return {
            'id': r['id'], 'created_at': r['date'], 'customer_id': custRef(r['customer']),
            'customer_name': custName['${r['customer']}'] ?? 'Walk-in customer',
            'method': r['method'], 'discount': r['discount'], 'items': items,
            'total': subtotal - _asInt(r['discount']) < 0 ? 0 : subtotal - _asInt(r['discount']),
          };
        }),
        'transactions': pick('transactions', txnRows, (r) => {
          'txn_type': r['type'], 'method': r['method'], 'amount': r['amount'],
          'reference': r['reference'], 'txn_date': r['date'],
        }),
        'receipts': pick('receipts', recRows, (r) => {
          'no': r['number'], 'created_at': r['date'], 'amount': r['amount'], 'method': r['method'],
          'source': '${r['for_doc']}'.startsWith('MTK-INV') ? 'invoice' : 'sale',
          'reference': r['for_doc'], 'customer_id': custRef(r['customer_id']),
          'customer_name': r['customer'],
          'customer_contact': '${r['customer_phone']}'.isNotEmpty
              ? r['customer_phone'] : r['customer_email'],
          'issued_name': r['issued_by'], 'customer_signature': r['customer_signature'],
        }),
        'invoices': pick('invoices', invRows, (r) => {
          'no': r['number'], 'created_at': r['issued'], 'due': r['due'],
          'customer_id': custRef(r['customer_id']), 'customer_name': r['customer'],
          'amount_paid': r['amount_paid'], 'total': r['total'],
          'items': [
            for (final it in (r['items'] as List? ?? const []))
              if (it is Map) {'product_id': '${it['product']}', 'name': it['name'], 'qty': it['qty'], 'unit_price': it['unit_price']}
          ],
        }),
        'documents': pick('documents', docRows, (r) => {
          'doc_type': r['type'], 'serial': r['serial'], 'customer': r['customer'],
          'customer_contact': r['customer_contact'], 'total': r['total'],
          'signed_name': r['signed_by'], 'verify_hash': r['verify_hash'], 'issued_at': r['issued_at'],
        }),
        'mils': pick('mils_logs', milsRows, (r) => {...r, 'customer_id': custRef(r['customer_id'])}),
        'adjustments': pick('stock_adjustments', adjRows, (r) => {
          'product_id': r['product'], 'delta': r['delta'], 'reason': r['reason'],
          'note': r['note'], 'created_at': r['date'],
        }),
        'serials': {
          ...serialsRaw,
          'receiptIssue': recRows.fold<int>(0, (m, r) {
            final n = int.tryParse('${r['number']}'.replaceFirst('MTK-REC-', '')) ?? 0;
            return n > m ? n : m;
          }),
          'invoice': invRows.fold<int>(_asInt(serialsRaw['invoice']), (m, r) {
            final n = int.tryParse('${r['number']}'.replaceFirst('MTK-INV-', '')) ?? 0;
            return n > m ? n : m;
          }),
        },
      };
      if (sent.isEmpty) return true;
      final res = await _api!.post('/api/sync/import', payload);
      if (res == null || !res.ok) {
        debugPrint('offline sync: server unavailable/rejected (${sent.length} pending)');
        return false;
      }
      final body = res.json is Map ? (res.json as Map) : const {};
      final skipped = {for (final k in (body['skipped'] as List? ?? const [])) '$k'};
      _known.addAll(sent.where((k) => !skipped.contains(k)));
      // rows the server refused for this role (e.g. Sales uploading stock
      // edits) are dropped from the retry set too — they would fail forever
      _known.addAll(skipped);
      await _saveSyncState();
      debugPrint('offline sync: uploaded ${sent.length - skipped.length} records');
      return true;
    } catch (e) {
      debugPrint('offline sync failed: $e');
      return false;
    } finally {
      _uploading = false;
    }
  }

  // ---------------------------------------------------------------- docs
  /// Persists a generated document (Phase A flow) into history + serials.
  Future<IssuedDocument> issueDocument({
    required String type,
    required int serial,
    required String customer,
    String customerContact = '',
    required double total,
    required String signedBy,
    required String verifyHash,
    bool serverIssued = false,
  }) async {
    final doc = IssuedDocument(
      type: type,
      serial: serial,
      customer: customer,
      customerContact: customerContact,
      total: total,
      signedBy: signedBy,
      verifyHash: verifyHash,
      issuedAt: DateTime.now(),
    );
    docHistory.insert(0, doc);
    await writeStore('doc_history', docHistory.map((d) => d.toJson()).toList());
    unawaited(addLocalNotification('document', 'Document issued',
        '$signedBy issued $type No ${serial.toString().padLeft(9, '0')} for $customer',
        '$type $serial'));
    if (serverIssued) {
      await _markKnown('documents', [doc.toJson()]); // server archive already has it
    } else {
      unawaited(flushSyncQueue());
    }
    notifyListeners();
    return doc;
  }

  /// A manually created payment receipt is also a money-ledger transaction.
  /// Keep both records together so it immediately appears on Transactions and
  /// can be reopened as its original receipt.
  Future<void> recordGeneratedReceipt({
    required int serial,
    required DateTime date,
    required Customer customer,
    required int amount,
    required PaymentMethod method,
    required String purpose,
    required String signedBy,
    String customerSignature = '',
  }) async {
    final number = 'MTK-REC-${serial.toString().padLeft(9, '0')}';
    if (receipts.any((receipt) => receipt.number == number)) return;

    // Receipt entry is customer entry: reuse a matching customer, otherwise
    // create and sync one automatically. Phone is the strongest practical
    // identity; name is the fallback when no phone was supplied.
    final normalizedName = customer.name.trim().toLowerCase();
    final normalizedPhone = customer.phone.replaceAll(RegExp(r'\D'), '');
    final matches = customers.where((candidate) {
      final phone = candidate.phone.replaceAll(RegExp(r'\D'), '');
      if (normalizedPhone.isNotEmpty && phone.isNotEmpty) {
        return phone == normalizedPhone;
      }
      return candidate.name.trim().toLowerCase() == normalizedName;
    }).toList();
    final receiptCustomer = matches.isNotEmpty
        ? matches.first
        : Customer(
            id: 'C-REC-${serial.toString().padLeft(9, '0')}',
            name: customer.name.trim(),
            isCorporate: customer.isCorporate,
            phone: customer.phone.trim(),
            email: customer.email.trim(),
            address: customer.address.trim(),
          );
    if (matches.isEmpty) {
      try {
        await addCustomer(receiptCustomer);
      } catch (_) {
        // An ad-hoc receipt customer may lack an international phone; the
        // cloud rejection must NOT abort the receipt. Keep it locally so the
        // normal offline sync can retry it later.
        customers.add(receiptCustomer);
        await writeStore('customers', customers.map(customerToJson).toList());
        notifyListeners();
      }
    }

    transactions.add(Transaction(
      id: 'TXN-REC-${serial.toString().padLeft(9, '0')}',
      date: date,
      type: TxnType.salePayment,
      amount: amount,
      method: method,
      reference: number,
    ));
    receipts.add(Receipt(
      number: number,
      date: date,
      customer: receiptCustomer,
      amount: amount,
      method: method,
      forDoc: purpose,
      signedBy: signedBy,
      issuedBy: signedBy,
      customerSignature: customerSignature,
    ));
    await writeStore('transactions', transactions.map(txnToJson).toList());
    await writeStore('receipts', receipts.map(receiptToJson).toList());
    // Wait for the cloud attempt before reporting completion. If offline, the
    // local records remain pending and the normal reconnect sync retries them.
    await flushSyncQueue();
    notifyListeners();
  }

  // ------------------------------------------------------------ settings
  Future<void> updateSettings({
    bool? vatEnabled,
    double? vatRate,
    Map<String, int>? serialReseed,
  }) async {
    // CEO-only — enforced again server-side (owner directive 2026-08-30)
    if (Env.apiConfigured && _api != null && AuthStore.instance.accessToken != null) {
      if (vatEnabled != null || vatRate != null) {
        final response = await _api!.post('/api/settings', {
          'vatEnabled': vatEnabled, 'vatRate': vatRate,
          'watermark': null,
        });
        if (response == null || !response.ok) {
          final message = response?.json is Map
              ? '${(response!.json as Map)['error'] ?? 'Server rejected the setting'}'
              : 'Server rejected the setting';
          throw Exception(response == null
              ? 'Server unavailable — setting was not changed'
              : message);
        }
      }
      if (serialReseed != null) {
        for (final e in serialReseed.entries) {
          final response = await _api!.post('/api/settings',
              {'reseed': {'type': e.key, 'value': e.value}});
          if (response == null || !response.ok) {
            final message = response?.json is Map
                ? '${(response!.json as Map)['error'] ?? 'Server rejected the serial'}'
                : 'Server rejected the serial';
            throw Exception(response == null
                ? 'Server unavailable — serial was not changed'
                : message);
          }
        }
      }
    }
    if (vatEnabled != null) settings = settings.copyWith(vatEnabled: vatEnabled);
    if (vatRate != null) settings = settings.copyWith(vatRate: vatRate);
    if (serialReseed != null) {
      for (final e in serialReseed.entries) {
        SerialService.instance.reseed(e.key, e.value);
      }
    }
    await writeStore('settings', settings.toJson());
    notifyListeners();
  }

  // ------------------------------------------------------- persistence IO
  Future<void> writeStore(String key, Object data) =>
      localWrite(key, jsonEncode(data));

  Future<Map<String, dynamic>> readStore(String key) async {
    final raw = await localRead(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _persistAll() async {
    // Independent cache files are written concurrently. This removes the long
    // serial disk-write tail from refresh without changing cloud authority.
    await Future.wait([
      writeStore('products', products.map(productToJson).toList()),
      writeStore('customers', customers.map(customerToJson).toList()),
      writeStore('settings', settings.toJson()),
      writeStore('serials', SerialService.instance.toJson()),
      writeStore('sales', sales.map(saleToJson).toList()),
      writeStore('adjustments', adjustments.map(adjToJson).toList()),
      writeStore('mils_logs', milsLogs.map(milsLogToJson).toList()),
      writeStore('transactions', transactions.map(txnToJson).toList()),
      writeStore('receipts', receipts.map(receiptToJson).toList()),
      writeStore('invoices', invoices.map(invoiceToJson).toList()),
      writeStore('doc_history', docHistory.map((d) => d.toJson()).toList()),
    ]);
  }

  // ------------------------------------------------------------ analytics

  /// Net revenue: all payments in, minus refunds.
  int revenue({DateTime? from, DateTime? to}) {
    int sum = 0;
    for (final t in transactions) {
      if (from != null && t.date.isBefore(from)) continue;
      if (to != null && t.date.isAfter(to)) continue;
      if (t.isReceivable) continue; // recorded in ledger, recognised on payment
      sum += (t.isRefund || t.type == TxnType.expense) ? -t.amount : t.amount;
    }
    return sum;
  }

  int get revenueToday {
    final now = DateTime.now();
    return revenue(
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  int get revenueThisWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return revenue(
      from: DateTime(monday.year, monday.month, monday.day),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  int get revenueThisMonth {
    final now = DateTime.now();
    return revenue(
      from: DateTime(now.year, now.month),
      to: DateTime(now.year, now.month + 1),
    );
  }

  /// Avg. transaction value = net revenue / paying transactions.
  int avgTransactionValue() {
    final paying = transactions.where((t) => t.isPayment).length;
    return paying == 0 ? 0 : revenue() ~/ paying;
  }

  /// Revenue grouped by product category (for the breakdown chart).
  Map<ProductCategory, int> revenueByCategory() {
    final byCat = <ProductCategory, int>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        if (sale.method == PaymentMethod.credit && !_invoiceFullyPaid(sale)) {
          continue; // credit counts when the invoice is paid
        }
        byCat[item.product.category] =
            (byCat[item.product.category] ?? 0) + item.total;
      }
    }
    return byCat;
  }

  Map<PaymentMethod, int> revenueByMethod() {
    final byMethod = <PaymentMethod, int>{};
    for (final t in transactions) {
      if (!t.isPayment) continue;
      byMethod[t.method] = (byMethod[t.method] ?? 0) + t.amount;
    }
    return byMethod;
  }

  bool _invoiceFullyPaid(Sale sale) => invoices
      .where((i) =>
          i.items.length == sale.items.length && i.total == sale.total)
      .any((i) => i.amountPaid >= i.total);

  int stockValueAtCost() =>
      products.fold(0, (s, p) => s + (p.isService ? 0 : p.costPrice * p.qtyOnHand));

  int outstandingInvoicesTotal() => invoices.fold(0, (s, i) => s + i.balance);

  int estimatedProfit({DateTime? from, DateTime? to}) {
    int profit = 0;
    for (final sale in sales) {
      if (sale.method == PaymentMethod.credit) continue; // recognised on payment
      if (from != null && sale.date.isBefore(from)) continue;
      if (to != null && sale.date.isAfter(to)) continue;
      final cost =
          sale.items.fold(0, (s, i) => s + i.product.costPrice * i.qty);
      profit += sale.total - cost;
    }
    return profit;
  }

  LinkedHashMap<String, int> topProducts({int limit = 5}) {
    final byProduct = <String, int>{};
    final qty = <String, int>{};
    for (final sale in sales) {
      for (final i in sale.items) {
        byProduct[i.product.name] = (byProduct[i.product.name] ?? 0) + i.total;
        qty[i.product.name] = (qty[i.product.name] ?? 0) + i.qty;
      }
    }
    final entries = byProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final out = LinkedHashMap<String, int>();
    for (final e in entries.take(limit)) {
      out['${e.key} ×${qty[e.key]}'] = e.value;
    }
    return out;
  }

  // ------------------------------------------------------------ mutations
  Future<void> completeSale({
    required Customer customer,
    required List<SaleItem> items,
    required PaymentMethod method,
    int discount = 0,
    required String signedBy,
    String? customerSignature,
    required String issueKey,
  }) async {
    final now = DateTime.now();
    // SERVER-AUTHENTICATED SALE: stock check, pricing (server prices),
    // decrement, transaction + receipt happen in one authoritative cloud
    // request for CEO, Admin and Sales alike. No role receives a misleading
    // local-success fallback.
    String? serverReceiptNo;
    String? serverInvoiceNo;
    String? serverSaleId;
    var serverApplied = false;
    if (!Env.apiConfigured || _api == null || AuthStore.instance.accessToken == null) {
      throw Exception('Cloud connection and sign-in are required. Sale was not recorded.');
    }
    {
      final res = await _api!.post('/api/sales', {
        'customerId': customer.id.length > 20 ? customer.id : null,
        'customer': customer.id.length > 20 ? null : {
          'name': customer.name, 'phone': customer.phone,
          'email': customer.email, 'address': customer.address,
        },
        'customer_contact': customer.phone.isNotEmpty ? customer.phone : customer.email,
        'method': method.name,
        'items': [for (final i in items) {'product_id': i.product.id, 'qty': i.qty}],
        'discount': discount,
        'customer_signature': customerSignature,
        'issue_key': issueKey,
      });
      if (res == null) {
        throw Exception('Cloud server is unreachable. Sale was not recorded; please retry.');
      }
      if (!res.ok || res.json is! Map || (res.json as Map)['server_applied'] != true) {
        throw Exception((res.json is Map ? (res.json as Map)['error'] : null) ?? 'Sale rejected by server');
      }
      serverApplied = true;
      final body = res.json as Map;
      serverSaleId = '${body['sale_id'] ?? ''}';
      final rawReceipt = body['receipt_no'];
      final rawInvoice = body['invoice_no'];
      serverReceiptNo = rawReceipt == null ? null : '$rawReceipt';
      serverInvoiceNo = rawInvoice == null ? null : '$rawInvoice';
    }
    final sale = Sale(
      id: serverSaleId!.isEmpty ? 'S${sales.length + 1}' : serverSaleId,
      date: now,
      customer: customer,
      items: List.of(items),
      method: method,
      discount: discount,
    );
    sales.add(sale);
    for (final i in items) {
      final idx = products.indexWhere((p) => p.id == i.product.id);
      if (idx != -1 && !products[idx].isService) {
        products[idx] = products[idx].copyWith(qtyOnHand: products[idx].qtyOnHand - i.qty);
      }
    }
    if (method == PaymentMethod.credit) {
      final number = serverInvoiceNo ??
          'MTK-INV-${(invoices.length + 1).toString().padLeft(9, '0')}';
      transactions.add(Transaction(
        id: 'TXN-${(transactions.length + 1).toString().padLeft(4, '0')}',
        date: now,
        type: TxnType.creditSale,
        amount: sale.total,
        method: PaymentMethod.credit,
        reference: number,
      ));
      invoices.add(Invoice(
        number: number,
        issued: now,
        due: now.add(const Duration(days: 14)),
        customer: customer,
        items: List.of(items),
      ));
    } else {
      _postPayment(date: now, amount: sale.total, method: method, forDoc: sale.id,
          customer: customer, signedBy: signedBy,
          receiptNo: serverReceiptNo, customerSignature: customerSignature);
    }
    await _persistSaleSide(sale, enqueue: !serverApplied);
    unawaited(addLocalNotification('transaction', 'Sale recorded',
        '$signedBy recorded a ${fmt.naira(sale.total)} sale for ${customer.name}', sale.id));
    for (final item in items) {
      final matches = products.where((p) => p.id == item.product.id).toList();
      final product = matches.isEmpty ? null : matches.first;
      if (product != null && !product.isService && product.qtyOnHand <= product.reorderLevel) {
        unawaited(addLocalNotification(
          'stock',
          'Low stock warning',
          '${product.name} has ${product.qtyOnHand} ${product.unit} remaining '
              '(reorder level ${product.reorderLevel}).',
          product.id,
        ));
      }
    }
    notifyListeners();
    pushHomeWidgetStats();
  }

  Future<void> _persistSaleSide(Sale sale, {bool enqueue = true}) async {
    await writeStore('products', products.map(productToJson).toList());
    await writeStore('sales', sales.map(saleToJson).toList());
    await writeStore('transactions', transactions.map(txnToJson).toList());
    await writeStore('receipts', receipts.map(receiptToJson).toList());
    await writeStore('invoices', invoices.map(invoiceToJson).toList());
    if (enqueue) {
      unawaited(flushSyncQueue()); // server did not apply it — upload when reachable
    } else {
      // the server already holds this sale + its receipt/transaction/invoice
      await _markKnown('sales', [saleToJson(sale)]);
      if (transactions.isNotEmpty) await _markKnown('transactions', [txnToJson(transactions.last)]);
      if (sale.method != PaymentMethod.credit && receipts.isNotEmpty) {
        await _markKnown('receipts', [receiptToJson(receipts.last)]);
      }
      if (sale.method == PaymentMethod.credit && invoices.isNotEmpty) {
        await _markKnown('invoices', [invoiceToJson(invoices.last)]);
      }
    }
  }

  Future<void> payInvoice(Invoice invoice, int amount, {required String signedBy}) async {
    final idx = invoices.indexOf(invoice);
    if (idx < 0) throw Exception('Invoice no longer exists — payment was not recorded.');
    if (!Env.apiConfigured || _api == null || AuthStore.instance.accessToken == null) {
      throw Exception('Cloud connection and sign-in are required. Payment was not recorded.');
    }
    // SERVER-AUTHORITATIVE, exactly like recordSale(). Previously a failed or
    // unreachable /api/invoices/pay still marked the invoice paid locally,
    // issued a locally numbered receipt and persisted both — so the device
    // said "paid" while Supabase said "unpaid". Never mutate local state
    // unless the server confirms it applied the payment.
    // A deterministic issue_key makes a retry (e.g. the 401/refresh replay in
    // ApiClient) idempotent instead of charging the invoice twice.
    final issueKey = 'PAY-${invoice.number}-${invoice.amountPaid}-$amount';
    final res = await _api!.post('/api/invoices/pay', {
      'no': invoice.number, 'amount': amount, 'method': 'transfer',
      'issue_key': issueKey,
    });
    if (res == null) {
      throw Exception('Cloud server is unreachable. Payment was not recorded; please retry.');
    }
    if (!res.ok || res.json is! Map) {
      throw Exception((res.json is Map ? (res.json as Map)['error'] : null)
          ?? 'Payment rejected by server — nothing was changed.');
    }
    final body = res.json as Map;
    final rawReceipt = body['receipt_no'];
    final serverReceiptNo = rawReceipt == null ? '' : '$rawReceipt';
    if (serverReceiptNo.isEmpty) {
      throw Exception('Server did not return a receipt number — refresh before retrying.');
    }
    final now = DateTime.now();
    invoices[idx] = Invoice(
      number: invoice.number,
      issued: invoice.issued,
      due: invoice.due,
      customer: invoice.customer,
      items: invoice.items,
      amountPaid: invoice.amountPaid + amount,
    );
    _postPayment(date: now, amount: amount, method: PaymentMethod.transfer, forDoc: invoice.number,
        customer: invoice.customer, signedBy: signedBy, receiptNo: serverReceiptNo);
    await writeStore('invoices', invoices.map(invoiceToJson).toList());
    await writeStore('transactions', transactions.map(txnToJson).toList());
    await writeStore('receipts', receipts.map(receiptToJson).toList());
    if (transactions.isNotEmpty) await _markKnown('transactions', [txnToJson(transactions.last)]);
    if (receipts.isNotEmpty) await _markKnown('receipts', [receiptToJson(receipts.last)]);
    notifyListeners();
    pushHomeWidgetStats();
  }

  /// Records a completed maintenance/service job (CEO/Admin — MILS screen +
  /// the MILS document generator both feed this). Server-first via
  /// POST /api/mils; the local mirror keeps the MILS screen usable offline.
  Future<MaintenanceLog> logMaintenance({
    required String equipment,
    String? serial,
    required Customer client,
    required String location,
    required MaintenanceAction action,
    required String findings,
    required String technician,
    DateTime? serviceDate,
    DateTime? nextDue,
    String? milsNo,
  }) async {
    final service = serviceDate ?? DateTime.now();
    final due = nextDue ?? service.add(const Duration(days: 180));
    var log = MaintenanceLog(
      id: milsNo ?? 'MILS-${(milsLogs.length + 1).toString().padLeft(9, '0')}',
      serviceDate: service,
      equipment: equipment,
      serial: serial,
      client: client,
      location: location,
      action: action,
      findings: findings,
      technician: technician,
      nextDue: due,
    );
    var serverApplied = false;
    if (Env.apiConfigured && _api != null && AuthStore.instance.accessToken != null) {
      try {
        final res = await _api!.post('/api/mils', {
          'equipment': equipment, 'serial': serial,
          'customer_id': client.id.length > 20 ? client.id : null,
          'customer_name': client.name, 'location': location,
          'action': action.name, 'findings': findings, 'technician': technician,
          'service_date': service.toIso8601String(), 'next_due': due.toIso8601String(),
        });
        if (res != null && res.ok && res.json is Map) {
          final serverNo = '${(res.json as Map)['mils_no'] ?? ''}';
          if (serverNo.isNotEmpty) {
            log = MaintenanceLog(
              id: serverNo, serviceDate: service, equipment: equipment, serial: serial,
              client: client, location: location, action: action, findings: findings,
              technician: technician, nextDue: due,
            );
          }
          serverApplied = true;
        }
      } catch (_) {
        serverApplied = false;
      }
    }
    milsLogs.insert(0, log);
    await writeStore('mils_logs', milsLogs.map(milsLogToJson).toList());
    if (serverApplied) {
      await _markKnown('mils_logs', [milsLogToJson(log)]);
    } else {
      unawaited(flushSyncQueue());
    }
    notifyListeners();
    return log;
  }

  Future<void> adjustStock(Product product, int delta, AdjustmentReason reason, String note) async {
    // CEO/Admin only — enforced AGAIN server-side by the RPC (RLS + check)
    final serverApplied = await _apiPost(
        '/api/stock/adjust', {
      'id': product.id, 'delta': delta, 'reason': reason.name, 'note': note,
    });
    final idx = products.indexOf(product);
    products[idx] = product.copyWith(qtyOnHand: products[idx].qtyOnHand + delta);
    final adj = StockAdjustment(
      id: 'ADJ-${adjustments.length + 1}',
      date: DateTime.now(),
      product: products[idx],
      delta: delta,
      reason: reason,
      note: note,
    );
    adjustments.insert(0, adj);
    await writeStore('products', products.map(productToJson).toList());
    await writeStore('adjustments', adjustments.map(adjToJson).toList());
    if (serverApplied) {
      await _markKnown('stock_adjustments', [adjToJson(adj)]);
      await _markKnown('products', [productToJson(products[idx])]);
    } else {
      enqueueSync('products', [productToJson(products[idx])]);
      unawaited(flushSyncQueue());
    }
    notifyListeners();
  }

  /// POSTs to the data API; true when the server applied it (false when
  /// unreachable — callers fall back to the offline queue). Throws when the
  /// server actively refuses (e.g. permission denied).
  Future<bool> _apiPost(String path, Map<String, dynamic> body) async {
    if (!Env.apiConfigured || _api == null) return false;
    if (AuthStore.instance.accessToken != null) _api!.accessToken = AuthStore.instance.accessToken;
    final res = await _api!.post(path, body);
    if (res == null) return false; // unreachable → offline fallback
    if (!res.ok) {
      throw Exception((res.json is Map ? (res.json as Map)['error'] : null) ?? 'request rejected');
    }
    return true;
  }

  /// SERVER-FIRST, exactly like addProduct()/payInvoice(): the cloud record
  /// must be created (or the API must be genuinely unreachable) before the
  /// customer appears in the local list. A server refusal throws WITHOUT
  /// mutating local state, so the caller can show the real error. Returns the
  /// customer actually stored (its id is the server _id when available).
  Future<Customer> addCustomer(Customer c) async {
    var saved = c;
    if (Env.apiConfigured && _api != null && AuthStore.instance.accessToken != null) {
      _api!.accessToken = AuthStore.instance.accessToken;
      final res = await _api!.post('/api/customers', {
        'name': c.name, 'kind': c.isCorporate ? 'corporate' : 'individual',
        'phone': c.phone, 'email': c.email, 'address': c.address,
      });
      if (res != null && !res.ok) {
        throw Exception((res.json is Map ? (res.json as Map)['error'] : null)
            ?? 'Customer was not saved. Check the name and phone number.');
      }
      final srv = res != null && res.json is Map ? (res.json as Map)['customer'] : null;
      final sid = srv is Map ? '${srv['_id'] ?? ''}' : '';
      if (sid.isNotEmpty) {
        saved = Customer(id: sid, name: c.name, isCorporate: c.isCorporate,
            phone: c.phone, email: c.email, address: c.address,
            creditBalance: c.creditBalance);
      }
    }
    customers.add(saved);
    await writeStore('customers', customers.map(customerToJson).toList());
    unawaited(flushSyncQueue());
    notifyListeners();
    return saved;
  }

  void _postPayment({
    required DateTime date,
    required int amount,
    required PaymentMethod method,
    required String forDoc,
    required Customer customer,
    required String signedBy,
    String? receiptNo,
    String? customerSignature,
  }) {
    final txnSeq = transactions.length + 1;
    transactions.add(Transaction(
      id: 'TXN-${txnSeq.toString().padLeft(4, '0')}',
      date: date,
      type: forDoc.startsWith('MTK-INV') ? TxnType.invoicePayment : TxnType.salePayment,
      amount: amount,
      method: method,
      reference: forDoc,
    ));
    receipts.add(Receipt(
      number: (receiptNo == null || receiptNo.isEmpty)
          ? 'MTK-REC-${(receipts.length + 1).toString().padLeft(9, '0')}'
          : receiptNo, // server-assigned (authoritative when online)
      date: date,
      customer: customer,
      amount: amount,
      method: method,
      forDoc: forDoc,
      signedBy: signedBy,
      issuedBy: signedBy,
      customerSignature: customerSignature ?? '',
    ));
  }
}

// ---------------------------------------------------------------- model IO
// Lightweight JSON shims kept beside the store so models stay dependency-free.

Map<String, dynamic> productToJson(Product p) => {
      'id': p.id, 'name': p.name, 'brand': p.brand, 'category': p.category.name,
      'cost_price': p.costPrice, 'selling_price': p.sellingPrice,
      'qty_on_hand': p.qtyOnHand, 'reorder_level': p.reorderLevel,
      'unit': p.unit,
      'length': p.length, 'length_unit': p.lengthUnit,
      'width': p.width, 'width_unit': p.widthUnit,
      'size': p.size, 'size_unit': p.sizeUnit,
      'weight': p.weight, 'weight_unit': p.weightUnit,
      'image_urls': p.imageUrls,
      'is_service': p.isService,
    };

List<Product> parseProducts(dynamic raw) {
  final list = raw is List ? raw : (raw is Map ? raw['rows'] ?? raw['items'] ?? const [] : const []);
  return list.map<Product>((e) {
    final m = (e as Map).cast<String, dynamic>();
    return Product(
      id: '${m['id'] ?? m['ID'] ?? ''}',
      name: '${m['name'] ?? m['NAME'] ?? ''}', brand: '${m['brand'] ?? m['BRAND'] ?? ''}',
      category: ProductCategory.values.firstWhere(
        (c) => c.name == (m['category'] ?? ''), orElse: () => ProductCategory.fire),
      costPrice: _asInt(m['cost_price'] ?? m['COST PRICE (NGN)']),
      sellingPrice: _asInt(m['selling_price'] ?? m['SELLING PRICE (NGN)']),
      qtyOnHand: _asInt(m['qty_on_hand'] ?? m['QTY / OPENING BALANCE']),
      reorderLevel: _asInt(m['reorder_level'] ?? m['REORDER LEVEL']),
      unit: '${m['unit'] ?? 'pcs'}',
      length: (m['length'] as num?)?.toDouble(), lengthUnit: '${m['length_unit'] ?? ''}',
      width: (m['width'] as num?)?.toDouble(), widthUnit: '${m['width_unit'] ?? ''}',
      size: (m['size'] as num?)?.toDouble(), sizeUnit: '${m['size_unit'] ?? ''}',
      weight: (m['weight'] as num?)?.toDouble(), weightUnit: '${m['weight_unit'] ?? ''}',
      imageUrls: (m['image_urls'] as List? ?? const []).map((x) => '$x').toList(),
      isService: m['is_service'] == true,
    );
  }).toList();
}

Customer parseCustomer(Map<String, dynamic> m) => Customer(
      id: '${m['id'] ?? ''}', name: '${m['name'] ?? ''}',
      isCorporate: m['is_corporate'] == true,
      phone: '${m['phone'] ?? ''}', email: '${m['email'] ?? ''}',
      address: '${m['address'] ?? ''}',
      creditBalance: _asInt(m['credit_balance']),
    );

Map<String, dynamic> customerToJson(Customer c) => {
      'id': c.id, 'name': c.name, 'is_corporate': c.isCorporate,
      'phone': c.phone, 'email': c.email, 'address': c.address,
      'credit_balance': c.creditBalance,
    };

Map<String, dynamic> saleToJson(Sale s) => {
      'id': s.id, 'date': s.date.toIso8601String(), 'customer': s.customer.id,
      'items': s.items.map((i) => {'product': i.product.id, 'qty': i.qty, 'unit_price': i.unitPrice}).toList(),
      'discount': s.discount, 'method': s.method.name,
    };

Map<String, dynamic> txnToJson(Transaction t) => {
      'id': t.id, 'date': t.date.toIso8601String(), 'type': t.type.name,
      'amount': t.amount, 'method': t.method.name, 'reference': t.reference,
    };

Map<String, dynamic> receiptToJson(Receipt r) => {
      'number': r.number, 'date': r.date.toIso8601String(),
      'customer_signature': r.customerSignature,
      'customer': r.customer.name, 'customer_id': r.customer.id,
      'customer_phone': r.customer.phone, 'customer_email': r.customer.email,
      'customer_address': r.customer.address, 'amount': r.amount,
      'method': r.method.name, 'for_doc': r.forDoc,
      'signed_by': r.signedBy, 'issued_by': r.issuedBy,
    };

Map<String, dynamic> invoiceToJson(Invoice i) => {
      'number': i.number, 'issued': i.issued.toIso8601String(),
      'due': i.due.toIso8601String(), 'customer': i.customer.name,
      'customer_id': i.customer.id,
      'amount_paid': i.amountPaid, 'total': i.total,
      'items': i.items.map((x) => {'product': x.product.id, 'name': x.product.name, 'qty': x.qty, 'unit_price': x.unitPrice}).toList(),
    };

/// Offline-first: rebuild an invoice from disk. Line items that no longer
/// match a product fall back to a detached product so totals stay right.
Invoice? _invoiceFromLocal(Map<String, dynamic> m, List<Product> products, List<Customer> customers) {
  final number = '${m['number'] ?? ''}';
  if (number.isEmpty) return null;
  final items = <SaleItem>[];
  for (final it in (m['items'] as List? ?? const [])) {
    if (it is! Map) continue;
    final pid = '${it['product'] ?? ''}';
    final found = products.where((p) => p.id == pid).toList();
    final product = found.isNotEmpty
        ? found.first
        : Product(id: pid, name: '${it['name'] ?? 'Item'}', category: ProductCategory.safety, unit: 'unit',
            costPrice: 0, sellingPrice: _asInt(it['unit_price']), qtyOnHand: 0, reorderLevel: 0, isService: true);
    items.add(SaleItem(product: product, qty: _asInt(it['qty']), unitPrice: _asInt(it['unit_price'])));
  }
  if (items.isEmpty) {
    // legacy record without lines — keep the total as one summary line
    final total = _asInt(m['total']);
    if (total <= 0) return null;
    items.add(SaleItem(
        product: Product(id: 'legacy', name: 'Invoice total', category: ProductCategory.safety, unit: 'unit',
            costPrice: 0, sellingPrice: total, qtyOnHand: 0, reorderLevel: 0, isService: true),
        qty: 1, unitPrice: total));
  }
  return Invoice(
    number: number,
    issued: DateTime.tryParse('${m['issued']}') ?? DateTime.now(),
    due: DateTime.tryParse('${m['due']}') ?? DateTime.now(),
    customer: _lookupCustomer(customers, m['customer_id'] as String?, '${m['customer'] ?? '—'}'),
    items: items,
    amountPaid: _asInt(m['amount_paid']),
  );
}

Map<String, dynamic> adjToJson(StockAdjustment a) => {
      'id': a.id, 'date': a.date.toIso8601String(), 'product': a.product.id,
      'delta': a.delta, 'reason': a.reason.name, 'note': a.note,
    };

int _asInt(dynamic v) => v is int ? v : v is num ? v.round() : int.tryParse('$v') ?? 0;

// ---------------------------------------------------- server ↔ UI mapping
// The data API's /api/bootstrap already returns `sales`, `adjustments` and
// `mils` — these turn that server shape into the models the Insights,
// Customers, Stock and MILS screens already read (store.sales,
// store.adjustments, store.milsLogs).

Customer _lookupCustomer(List<Customer> customers, String? id, String fallbackName) {
  if (id != null && id.isNotEmpty) {
    final found = customers.where((c) => c.id == id).toList();
    if (found.isNotEmpty) return found.first;
  }
  return Customer(id: id ?? 'walk-in', name: fallbackName, isCorporate: false, phone: '', email: '', address: '');
}

/// Server invoice → model WITH its line items (the server stores
/// {product_id,name,qty,unit_price} per line; a detached product is built
/// for lines whose product no longer exists so totals stay exact).
Invoice _invoiceFromServer(Map<String, dynamic> m, List<Product> products, List<Customer> customers) {
  final items = <SaleItem>[];
  for (final it in (m['items'] as List? ?? const [])) {
    if (it is! Map) continue;
    final pid = '${it['product_id'] ?? it['product'] ?? ''}';
    final found = products.where((p) => p.id == pid).toList();
    final product = found.isNotEmpty
        ? found.first
        : Product(id: pid, name: '${it['name'] ?? 'Item'}', category: ProductCategory.safety, unit: 'unit',
            costPrice: 0, sellingPrice: _asInt(it['unit_price']), qtyOnHand: 0, reorderLevel: 0, isService: true);
    items.add(SaleItem(product: product, qty: _asInt(it['qty']), unitPrice: _asInt(it['unit_price'])));
  }
  if (items.isEmpty) {
    final total = _asInt(m['total']);
    if (total > 0) {
      items.add(SaleItem(
          product: Product(id: 'legacy', name: 'Invoice total', category: ProductCategory.safety, unit: 'unit',
              costPrice: 0, sellingPrice: total, qtyOnHand: 0, reorderLevel: 0, isService: true),
          qty: 1, unitPrice: total));
    }
  }
  final issued = DateTime.tryParse('${m['created_at']}') ?? DateTime.now();
  return Invoice(
    number: '${m['no'] ?? ''}',
    issued: issued,
    due: DateTime.tryParse('${m['due'] ?? ''}') ?? issued.add(const Duration(days: 14)),
    customer: _lookupCustomer(customers, m['customer_id'] as String?, '${m['customer_name'] ?? '—'}'),
    items: items,
    amountPaid: _asInt(m['amount_paid']),
  );
}

Sale _saleFromServer(Map<String, dynamic> m, List<Product> products, List<Customer> customers) {
  final rawItems = m['items'] as List? ?? const [];
  final items = <SaleItem>[];
  for (final it in rawItems) {
    if (it is! Map) continue;
    final pid = '${it['product_id'] ?? ''}';
    final product = products.where((p) => p.id == pid).toList();
    items.add(SaleItem(
      product: product.isNotEmpty
          ? product.first
          : Product(id: pid, name: '${it['name'] ?? 'Item'}', category: ProductCategory.fire,
              costPrice: 0, sellingPrice: _asInt(it['unit_price']), qtyOnHand: 0, reorderLevel: 0),
      qty: _asInt(it['qty']),
      unitPrice: _asInt(it['unit_price']),
    ));
  }
  return Sale(
    id: '${m['_id'] ?? ''}',
    date: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
    customer: _lookupCustomer(customers, m['customer_id'] as String?, '${m['customer_name'] ?? 'Walk-in customer'}'),
    items: items,
    discount: _asInt(m['discount']),
    method: PaymentMethod.values.firstWhere((t) => t.name == m['method'], orElse: () => PaymentMethod.cash),
  );
}

Sale? _saleFromLocal(Map<String, dynamic> m, List<Product> products, List<Customer> customers) {
  final rawItems = m['items'] as List? ?? const [];
  final items = <SaleItem>[];
  for (final it in rawItems) {
    if (it is! Map) continue;
    final pid = '${it['product'] ?? ''}';
    final product = products.where((p) => p.id == pid).toList();
    if (product.isEmpty) continue;
    items.add(SaleItem(product: product.first, qty: _asInt(it['qty']), unitPrice: _asInt(it['unit_price'])));
  }
  if (items.isEmpty) return null;
  return Sale(
    id: '${m['id'] ?? ''}',
    date: DateTime.tryParse('${m['date']}') ?? DateTime.now(),
    customer: _lookupCustomer(customers, m['customer'] as String?, 'Walk-in customer'),
    items: items,
    discount: _asInt(m['discount']),
    method: PaymentMethod.values.firstWhere((t) => t.name == m['method'], orElse: () => PaymentMethod.cash),
  );
}

StockAdjustment? _adjustmentFromServer(Map<String, dynamic> m, List<Product> products) {
  final pid = '${m['product_id'] ?? ''}';
  final product = products.where((p) => p.id == pid).toList();
  if (product.isEmpty) return null;
  return StockAdjustment(
    id: '${m['_id'] ?? ''}',
    date: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
    product: product.first,
    delta: _asInt(m['delta']),
    reason: AdjustmentReason.values.firstWhere((r) => r.name == m['reason'], orElse: () => AdjustmentReason.correction),
    note: '${m['note'] ?? ''}',
  );
}

StockAdjustment? _adjustmentFromLocal(Map<String, dynamic> m, List<Product> products) {
  final pid = '${m['product'] ?? ''}';
  final product = products.where((p) => p.id == pid).toList();
  if (product.isEmpty) return null;
  return StockAdjustment(
    id: '${m['id'] ?? ''}',
    date: DateTime.tryParse('${m['date']}') ?? DateTime.now(),
    product: product.first,
    delta: _asInt(m['delta']),
    reason: AdjustmentReason.values.firstWhere((r) => r.name == m['reason'], orElse: () => AdjustmentReason.correction),
    note: '${m['note'] ?? ''}',
  );
}

MaintenanceLog? _milsLogFromServer(Map<String, dynamic> m, List<Customer> customers) {
  final equipment = '${m['equipment'] ?? ''}';
  if (equipment.isEmpty) return null;
  return MaintenanceLog(
    id: '${m['mils_no'] ?? m['_id'] ?? ''}',
    serviceDate: DateTime.tryParse('${m['service_date']}') ?? DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
    equipment: equipment,
    serial: m['serial'] as String?,
    client: _lookupCustomer(customers, m['customer_id'] as String?, '${m['customer_name'] ?? '—'}'),
    location: '${m['location'] ?? ''}',
    action: MaintenanceAction.values.firstWhere((a) => a.name == m['action'], orElse: () => MaintenanceAction.refill),
    findings: '${m['findings'] ?? ''}',
    technician: '${m['technician'] ?? m['recorded_name'] ?? ''}',
    nextDue: DateTime.tryParse('${m['next_due']}') ?? DateTime.now().add(const Duration(days: 180)),
  );
}

MaintenanceLog? _milsLogFromLocal(Map<String, dynamic> m, List<Customer> customers) =>
    _milsLogFromServer(m, customers);

Map<String, dynamic> milsLogToJson(MaintenanceLog l) => {
      'mils_no': l.id,
      'service_date': l.serviceDate.toIso8601String(),
      'equipment': l.equipment,
      'serial': l.serial,
      'customer_id': l.client.id,
      'customer_name': l.client.name,
      'location': l.location,
      'action': l.action.name,
      'findings': l.findings,
      'technician': l.technician,
      'next_due': l.nextDue.toIso8601String(),
    };

// ------------------------------------------------------------- settings
class StoreSettings {
  final bool vatEnabled;
  final double vatRate;
  StoreSettings({
    this.vatEnabled = false,
    this.vatRate = 0.075,
  });

  StoreSettings copyWith({
    bool? vatEnabled,
    double? vatRate,
  }) => StoreSettings(
        vatEnabled: vatEnabled ?? this.vatEnabled,
        vatRate: vatRate ?? this.vatRate,
      );

  Map<String, dynamic> toJson() => {
        'vat_enabled': vatEnabled,
        'vat_rate': vatRate,
      };
  static StoreSettings fromJson(Map<String, dynamic> j) => StoreSettings(
        vatEnabled: j['vat_enabled'] == true,
        vatRate: (j['vat_rate'] as num?)?.toDouble() ?? 0.075,
      );
}

/// One row of the generated-document history (Phase A/B).
class IssuedDocument {
  final String type; // receipt | invoice | mils | waybill | deliverynote
  final int serial;
  final String customer;
  final String customerContact; // phone or email captured on the document
  final double total;
  final String signedBy;
  final String verifyHash;
  final DateTime issuedAt;
  IssuedDocument({
    required this.type,
    required this.serial,
    required this.customer,
    this.customerContact = '',
    required this.total,
    required this.signedBy,
    required this.verifyHash,
    required this.issuedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type, 'serial': serial, 'customer': customer,
        'customer_contact': customerContact,
        'total': total, 'signed_by': signedBy,
        'verify_hash': verifyHash, 'issued_at': issuedAt.toIso8601String(),
      };
  /// Accepts BOTH shapes: local JSON (type/signed_by/…) and the real
  /// Archive rows served by /api/bootstrap (doc_type/signed_name/…).
  static IssuedDocument fromJson(Map<String, dynamic> j) => IssuedDocument(
        type: '${j['type'] ?? j['doc_type'] ?? 'doc'}',
        serial: _asInt(j['serial']),
        customer: '${j['customer'] ?? j['customer_name'] ?? '—'}',
        customerContact: '${j['customer_contact'] ?? j['contact'] ?? ''}',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        signedBy: '${j['signed_name'] ?? j['signed_by'] ?? '—'}',
        verifyHash: '${j['verify_hash'] ?? j['hash'] ?? ''}',
        issuedAt: DateTime.tryParse('${j['issued_at'] ?? j['created_at'] ?? ''}') ??
            DateTime.now(),
      );
}

