import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'core/notification_service.dart';
import 'core/permission_gate.dart';
import 'core/preferences_controller.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'core/widget_bridge.dart';
import 'data/auth_store.dart';
import 'data/store.dart';
import 'ui/app_shell.dart';
import 'ui/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Replace Flutter's default red "Error" box with a calm, jargon-free
  // panel. The real error detail is logged to the console only — a
  // production user never sees exception text or stack traces on screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Flutter build error: ${details.exception}');
    return const _FriendlyError();
  };
  await ThemeController.instance.load();
  await PreferencesController.instance.load();
  await NotificationService.instance.initialize();
  // Subscribe to home-widget / launcher-shortcut taps (Android only).
  unawaited(WidgetBridge.init());
  runApp(const MtekApp());
}

/// Friendly fallback for any widget that throws while building — shown in
/// place of Flutter's default red error box. No technical detail on screen.
class _FriendlyError extends StatelessWidget {
  const _FriendlyError();

  @override
  Widget build(BuildContext context) {
    // Full-screen branded surface — a caught build error must never read as
    // a "black screen" (the bare Center previously rendered on a black
    // fallback background when no Material ancestor was above it).
    return Scaffold(
      backgroundColor: Mtek.gray50,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.error_outline, size: 40, color: Mtek.gold500),
                SizedBox(height: 12),
                Text('Something went wrong here.',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 6),
                Text('Please go back and try again.',
                    style: TextStyle(color: Mtek.gray500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App-wide scroll behaviour (owner directive 2026-09-01: "every screen in
/// the Windows build should have a visible scroller"). On desktop platforms
/// this (a) always draws a visible, always-on scrollbar — not just the
/// hover/drag flash Flutter shows by default — and (b) lets a mouse drag
/// scroll content, same as the login screen already did. Applied once here
/// on the root MaterialApp so every screen in the app gets it for free,
/// without needing a Scrollbar wrapper hand-added to each one.
class MtekScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        // Force it always-visible; the default only flashes on hover/scroll.
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: true,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return super.buildScrollbar(context, child, details);
    }
  }
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class MtekApp extends StatelessWidget {
  const MtekApp({super.key});

  ThemeData _withPreferences(ThemeData theme) {
    final preferences = PreferencesController.instance;
    return theme.copyWith(
      visualDensity: preferences.compactLists
          ? const VisualDensity(horizontal: -2, vertical: -2)
          : VisualDensity.standard,
      pageTransitionsTheme: preferences.reduceMotion
          ? const PageTransitionsTheme(builders: {
              TargetPlatform.android: _NoTransitionsBuilder(),
              TargetPlatform.windows: _NoTransitionsBuilder(),
              TargetPlatform.linux: _NoTransitionsBuilder(),
              TargetPlatform.macOS: _NoTransitionsBuilder(),
              TargetPlatform.iOS: _NoTransitionsBuilder(),
            })
          : theme.pageTransitionsTheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        PreferencesController.instance,
      ]),
      builder: (context, _) => MaterialApp(
      title: 'MFSL Office',
      debugShowCheckedModeBanner: false,
      scrollBehavior: MtekScrollBehavior(),
      theme: _withPreferences(MtekTheme.light()),
      darkTheme: _withPreferences(MtekTheme.dark()),
      themeMode: ThemeController.instance.mode,
      // Clamp the device text-scale (owner's phone uses a very large system
      // font). At scale ≥1.5 every fixed-width row in the app overflowed,
      // painting the yellow/black "overflow" stripes over each screen and
      // blowing dialogs wider than the display. 1.4 keeps text accessible
      // while layouts stay intact; layouts themselves are responsive.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.4),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AnimatedBuilder(
        animation: Listenable.merge([AuthStore.instance, AppStore.instance]),
        builder: (context, _) {
          if (!AppStore.instance.isLoaded) {
            return const _BootScreen();
          }
          return AuthStore.instance.isSignedIn ? const AppShell() : const LoginScreen();
        },
      ),
    ),
    );
  }
}

/// Loads the local database / seed data on first frame (Phase B).
class _BootScreen extends StatefulWidget {
  const _BootScreen();

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen> {
  @override
  void initState() {
    super.initState();
    // AppStore.init() first (creates the RestClient/ApiClient the session
    // restore needs), THEN silently try to resume a saved session from the
    // last app run before deciding whether to show the login screen — this
    // is what keeps the user signed in across app exits (owner directive
    // 2026-09-01; previously every restart forced a fresh sign-in).
    AppStore.instance.init().then((_) async {
      await AuthStore.instance.restoreSession();
      if (mounted) await PermissionGate.enforce(context);
      AuthStore.instance.ping();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Mtek.navyGradient),
        child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: Mtek.brand600, borderRadius: BorderRadius.circular(16)),
              child: Image.asset('assets/branding/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            const Text('M-TEK FIRE & SAFETY LTD.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 10),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(color: Mtek.gold500, strokeWidth: 2.5),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
