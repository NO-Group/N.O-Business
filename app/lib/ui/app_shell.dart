import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widget_bridge.dart';
import '../data/auth_store.dart';
import '../data/store.dart';
import 'screens/cloud_documents_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/delivery_notes_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/generator_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/letterhead_screen.dart';
import 'screens/mils_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/office_documents_screen.dart';
import 'screens/office_sheets_screen.dart';
import 'screens/office_slides_screen.dart';
import 'screens/payment_vouchers_screen.dart';
import 'screens/receipts_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/staff_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/stock_receipts_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/waybills_screen.dart';
import 'watermark_background.dart';

class Destination {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
  const Destination(this.id, this.label, this.icon, this.selectedIcon, this.screen);
}

const _insights = Destination('insights', 'Insights', Icons.insights_outlined, Icons.insights, InsightsScreen());
const _transactions = Destination('transactions', 'Transactions', Icons.swap_horiz_outlined, Icons.swap_horiz, TransactionsScreen());
const _customers = Destination('customers', 'Customers', Icons.people_outline, Icons.people, CustomersScreen());
const _receipts = Destination('receipts', 'Receipts', Icons.receipt_long_outlined, Icons.receipt_long, ReceiptsScreen());
const _vouchers = Destination('vouchers', 'Payment Vouchers', Icons.payments_outlined, Icons.payments, PaymentVouchersScreen());
const _invoices = Destination('invoices', 'Invoices', Icons.request_quote_outlined, Icons.request_quote, InvoicesScreen());
const _waybills = Destination('waybills', 'Waybills', Icons.local_shipping_outlined, Icons.local_shipping, WaybillsScreen());
const _deliveryNotes = Destination('deliverynotes', 'Delivery Notes', Icons.inventory_2_outlined, Icons.inventory_2, DeliveryNotesScreen());
const _mils = Destination('mils', 'MILS', Icons.build_circle_outlined, Icons.build_circle, MilsScreen());
const _sales = Destination('sales', 'Sales', Icons.point_of_sale_outlined, Icons.point_of_sale, SalesScreen());
const _stock = Destination('stock', 'Stock', Icons.inventory_2_outlined, Icons.inventory_2, StockScreen());
const _gallery = Destination('gallery', 'Gallery', Icons.photo_library_outlined, Icons.photo_library, GalleryScreen());
const _stockReceipts = Destination('stockreceipts', 'Stock Receipts', Icons.playlist_add_check_outlined, Icons.playlist_add_check, StockReceiptsScreen());
const _summary = Destination('summary', 'Summary', Icons.summarize_outlined, Icons.summarize, SummaryScreen());
const _docs = Destination('docs', 'Documents', Icons.draw_outlined, Icons.draw, GeneratorScreen());
const _cloudDocs = Destination('clouddocs', 'Cloud Documents', Icons.cloud_outlined, Icons.cloud_done, CloudDocumentsScreen());
const _officeDocs = Destination('officedocs', 'Office Documents', Icons.description_outlined, Icons.description, OfficeDocumentsScreen());
const _officeSheets = Destination('officesheets', 'Office Sheets', Icons.grid_on_outlined, Icons.grid_on, OfficeSheetsScreen());
const _officeSlides = Destination('officeslides', 'Office Slides', Icons.slideshow_outlined, Icons.slideshow, OfficeSlidesScreen());
const _notifications = Destination('notifications', 'Notifications', Icons.notifications_outlined, Icons.notifications, NotificationsScreen());
const _staff = Destination('staff', 'Staff', Icons.badge_outlined, Icons.badge, StaffScreen());
const _letterhead = Destination('letterhead', 'Letterhead', Icons.article_outlined, Icons.article, LetterheadScreen());

const _settings = Destination('settings', 'Settings', Icons.settings_outlined, Icons.settings, SettingsScreen());

/// Admin sees everything; Sales never sees revenue/profit/settings (SPEC §6).
/// Notifications are visible to every role (owner directive 2026-09-01 —
/// "any user" gets notified of every transaction); Staff is CEO/Admin-only
/// (view for both, but only the CEO can actually change a role).
List<Destination> destinationsFor(String? role) {
  // Authority: CEO > Admin > Sales. Settings is visible to EVERY role
  // (owner directive 2026-09-01) — Account/Recovery/Preferences/About are
  // universal, while the management controls inside it (serial reseed,
  // stock seed import) stay CEO-only. Stock editing is CEO/Admin.
  if (role == 'ceo') return _ceoDestinations;
  if (role == 'admin') return _allDestinations;
  return const [
    _sales, _transactions, _stock, _gallery, _customers, _receipts, _invoices, _waybills, _deliveryNotes, _docs, _officeDocs, _officeSheets, _officeSlides, _cloudDocs, _notifications, _settings,
  ];
}

/// CEO receives the private official-letter composer in addition to all
/// operational destinations. Admin cannot navigate to or render it.
const _ceoDestinations = <Destination>[
  _insights, _transactions, _customers, _receipts, _vouchers, _invoices, _waybills, _deliveryNotes,
  _mils, _sales, _stock, _gallery, _stockReceipts, _summary, _docs, _officeDocs, _officeSheets, _officeSlides, _cloudDocs, _letterhead, _notifications, _staff, _settings,
];

/// The complete operational destination set (admin view).
const _allDestinations = <Destination>[
  _insights, _transactions, _customers, _receipts, _vouchers, _invoices, _waybills, _deliveryNotes,
  _mils, _sales, _stock, _gallery, _stockReceipts, _summary, _docs, _officeDocs, _officeSheets, _officeSlides, _cloudDocs, _notifications, _staff, _settings,
];

/// Kept for backwards compatibility (admin view).
const destinations = <Destination>[
  _insights, _transactions, _customers, _receipts, _vouchers, _invoices, _waybills, _deliveryNotes,
  _mils, _sales, _stock, _gallery, _stockReceipts, _summary, _docs, _officeDocs, _officeSheets, _officeSlides, _cloudDocs, _notifications, _staff, _settings,
];

Widget _freshScreen(String id) => switch (id) {
  'insights' => InsightsScreen(), 'transactions' => TransactionsScreen(),
  'customers' => CustomersScreen(), 'receipts' => ReceiptsScreen(),
  'vouchers' => PaymentVouchersScreen(),
  'invoices' => InvoicesScreen(), 'waybills' => WaybillsScreen(),
  'deliverynotes' => DeliveryNotesScreen(), 'mils' => MilsScreen(),
  'sales' => SalesScreen(), 'stock' => StockScreen(), 'gallery' => GalleryScreen(),
  'stockreceipts' => StockReceiptsScreen(), 'summary' => SummaryScreen(),
  'docs' => GeneratorScreen(), 'officedocs' => OfficeDocumentsScreen(),
  'officesheets' => OfficeSheetsScreen(), 'officeslides' => OfficeSlidesScreen(), 'clouddocs' => CloudDocumentsScreen(), 'letterhead' => LetterheadScreen(),
  'notifications' => NotificationsScreen(), 'staff' => StaffScreen(),
  _ => SettingsScreen(),
};

/// Responsive shell — four tiers:
///   ≥1280px : NavigationRail with extended labels (desktop)
///   ≥1000px : compact NavigationRail (small desktop / tablet landscape)
///    ≥640px : drawer + AppBar menu (tablet portrait / large phones)
///    <640px : bottom NavigationBar (5 slots incl. "More") + drawer
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _notifyTimer;
  Timer? _dataTimer;
  Timer? _sessionTimer;

  List<Destination> get _visible => destinationsFor(AuthStore.instance.current?.role);

  @override
  void initState() {
    super.initState();
    // Poll for new notifications every 20s — every signed-in user (CEO,
    // Admin, Sales) sees the same live feed (owner directive 2026-09-01).
    unawaited(AppStore.instance.refreshNotifications());
    _notifyTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(AppStore.instance.refreshNotifications());
    });
    // LIVE DATA SYNC: re-pull the shared dataset every 30s (and whenever the
    // app comes back to the foreground) so stock, customers, sales,
    // receipts, invoices, MILS and documents recorded on ANY device show up
    // on every page of every other device without a restart.
    WidgetsBinding.instance.addObserver(this);
    // Near-instant: a tiny change-stamp poll every 8s; the full dataset is
    // only re-downloaded when the server reports something changed.
    unawaited(AppStore.instance.refreshRemote());
    _dataTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      // Always pull the authoritative shared dataset. Relying on an audit
      // change stamp allowed an account with a stale/rejected local queue to
      // miss changes made by the CEO or another member of staff.
      unawaited(AppStore.instance.refreshRemote());
    });
    // Access JWTs are short-lived. Check every 30 minutes while the app stays
    // open, refreshing only when less than five minutes remain.
    _sessionTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      unawaited(AuthStore.instance.ensureFreshSession());
    });
    // Jump to a screen requested by a home-widget tap / launcher shortcut.
    WidgetBridge.requestedScreen.addListener(_applyRequestedScreen);
    _applyRequestedScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetBridge.requestedScreen.removeListener(_applyRequestedScreen);
    _notifyTimer?.cancel();
    _dataTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_resumeOnlineSession());
  }

  Future<void> _resumeOnlineSession() async {
    // Refresh authentication first; otherwise the simultaneous data and
    // notification calls can both leave the background with an expired JWT.
    await AuthStore.instance.ensureFreshSession();
    await Future.wait([
      AppStore.instance.refreshRemote(),
      AppStore.instance.refreshNotifications(),
    ]);
  }

  void _applyRequestedScreen() {
    final requested = WidgetBridge.requestedScreen.value;
    if (requested == null) return;
    WidgetBridge.requestedScreen.value = null;
    final i = _visible.indexWhere((d) => d.id == requested);
    if (i == -1) return; // screen not visible for this role — ignore
    if (_index != i) setState(() => _index = i);
  }

  void _openNotifications() {
    final i = _visible.indexWhere((d) => d.id == 'notifications');
    if (i != -1) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final extended = w >= 1280;
    final useRail = w >= 1000;
    final useBottomBar = w < 640;
    final visible = _visible;
    if (_index >= visible.length) _index = 0;
    final dest = visible[_index];

    Widget liveBody() {
      final screen = _freshScreen(dest.id);
      if (useRail) {
        return Row(children: [
          _rail(extended: extended),
          Expanded(child: Stack(children: [
            const Positioned.fill(child: WatermarkBackground()), screen,
          ])),
        ]);
      }
      return Stack(children: [
        const Positioned.fill(child: WatermarkBackground()), screen,
      ]);
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: _appBar(dest),
      drawer: _drawer(context),
      // Every page re-renders whenever the store changes (local edit OR a
      // background refresh from the server), not just the notification badge.
      body: AnimatedBuilder(
        animation: AppStore.instance,
        // Return a fresh screen widget so Flutter actually rebuilds its data
        // reads after cloud restore/sync; reusing the canonical const instance
        // caused Insights, Summary and other pages to retain pre-install values.
        builder: (context, _) => liveBody(),
      ),
      bottomNavigationBar: useBottomBar ? _bottomBar() : null,
    );
  }

  PreferredSizeWidget _appBar(Destination dest) {
    final user = AuthStore.instance.current;
    final w = MediaQuery.of(context).size.width;
    return AppBar(
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: Mtek.heroGradient)),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: Mtek.cardShadow,
            ),
            child: Image.asset('assets/branding/logo.png',
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
          const SizedBox(width: 12),
          // Expanded + ellipsis: the title can never push the AppBar's action
          // buttons off-screen (the unexpanded Column overflowed on narrow
          // windows and large font scales).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dest.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white)),
                if (w >= 380) ...[
                  const SizedBox(height: 1),
                  Text('M-TEK FIRE & SAFETY LTD',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.1,
                          color: Colors.white.withValues(alpha: .55))),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        AnimatedBuilder(
          animation: AppStore.instance,
          builder: (context, _) {
            final unread = AppStore.instance.unreadNotificationCount;
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: IconButton(
                tooltip: 'Notifications',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Badge(
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications_outlined, color: Colors.white),
                ),
                onPressed: _openNotifications,
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        _rolePill(user?.role ?? ''),
      ],
      leading: IconButton(
        tooltip: 'Menu',
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
    );
  }

  Widget _rolePill(String role) {
    final (bg, fg) = switch (role) {
      'ceo' => (Mtek.goldTint, Mtek.gold600),
      'admin' => (Mtek.brandTint, Mtek.brand600),
      _ => (Colors.white.withValues(alpha: .12), Colors.white),
    };
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(role.toUpperCase(), style: TextStyle(
        fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8, color: fg)),
    );
  }

  Widget _rail({required bool extended}) {
    return Container(
      decoration: const BoxDecoration(gradient: Mtek.navyGradient),
      child: LayoutBuilder(builder: (context, constraints) => Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          primary: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: NavigationRail(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        extended: extended,
        labelType: extended ? null : NavigationRailLabelType.all,
        groupAlignment: -0.9,
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: Mtek.cardShadow,
            ),
            child: Image.asset('assets/branding/logo.png',
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ),
        destinations: [
          for (final d in _visible)
            NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: Text(d.label),
            ),
        ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _bottomBar() {
    // The top-left burger already opens the complete navigation drawer, so
    // the taskbar contains destinations only—never a duplicate "More" item.
    final preferredIds = AuthStore.instance.isManagement
        ? const ['insights', 'sales', 'transactions', 'stock']
        : const ['sales', 'transactions', 'stock', 'customers'];
    final visibleBottom = preferredIds
        .map((id) => _visible.indexWhere((d) => d.id == id))
        .where((i) => i >= 0)
        .toList();
    // When a drawer-only screen is active, show it in the final taskbar slot
    // so NavigationBar always has a truthful selected destination.
    if (!visibleBottom.contains(_index)) {
      if (visibleBottom.length >= 4) visibleBottom.removeLast();
      visibleBottom.add(_index);
    }
    return NavigationBar(
      height: 68,
      selectedIndex: visibleBottom.indexOf(_index),
      onDestinationSelected: (i) => setState(() => _index = visibleBottom[i]),
      destinations: [
        for (final idx in visibleBottom)
          NavigationDestination(
            icon: Icon(_visible[idx].icon),
            selectedIcon: Icon(_visible[idx].selectedIcon),
            label: _visible[idx].label,
          ),
      ],
    );
  }

  Widget _drawer(BuildContext context) {
    final user = AuthStore.instance.current;
    return NavigationDrawer(
      selectedIndex: _index,
      onDestinationSelected: (i) {
        setState(() => _index = i);
        Navigator.pop(context);
      },
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 16, 20),
          decoration: const BoxDecoration(gradient: Mtek.heroGradient),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset('assets/branding/logo.png',
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('M-Tek Fire & Safety',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(user?.name ?? 'Signed in',
                        style: TextStyle(
                            fontSize: 12, color: Colors.white.withValues(alpha: .7))),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final d in _visible)
          NavigationDrawerDestination(icon: Icon(d.icon), label: Text(d.label)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Divider(),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () {
            Navigator.pop(context);
            AuthStore.instance.signOut();
          },
        ),
      ],
    );
  }
}
