import 'package:flutter/material.dart';

/// M-Tek brand design system — tokens mirrored 1:1 from the physical forms
/// and website, extended with gradients, shadows and a refined component
/// theme so every screen shares one cohesive look.
abstract final class Mtek {
  // Brand (red) palette — original M-Tek tokens, unchanged.
  static const brand700 = Color(0xFFA50F1E);
  static const brand600 = Color(0xFFC8102E);
  static const brand500 = Color(0xFFE11D2E);
  static const brand400 = Color(0xFFEF2D3C);
  static const brand300 = Color(0xFFFF5B66);
  static const brandTint = Color(0xFFFDECEE);

  // Deep navy surfaces
  static const navy950 = Color(0xFF060B16);
  static const navy900 = Color(0xFF0A1220);
  static const navy850 = Color(0xFF0D1728);
  static const navy800 = Color(0xFF111D36);
  static const navy700 = Color(0xFF1A2A4A);
  static const navy600 = Color(0xFF24365C);

  // Gold accent
  static const gold600 = Color(0xFFB87B14);
  static const gold500 = Color(0xFFF0A92E);
  static const gold400 = Color(0xFFF7C04A);
  static const goldTint = Color(0xFFFDF3DD);

  // Neutrals (slate)
  static const gray50 = Color(0xFFF8FAFC);
  static const gray100 = Color(0xFFF1F5F9);
  static const gray200 = Color(0xFFE2E8F0);
  static const gray300 = Color(0xFFCBD5E1);
  static const gray400 = Color(0xFF94A3B8);
  static const gray500 = Color(0xFF64748B);
  static const gray600 = Color(0xFF475569);
  static const gray700 = Color(0xFF334155);
  static const gray800 = Color(0xFF1E293B);
  static const gray900 = Color(0xFF0F172A);

  static const ink = Color(0xFF0B1220);

  // Status accents
  static const success = Color(0xFF15803D);
  static const successTint = Color(0xFFDCFCE7);
  static const warn = Color(0xFFB45309);
  static const warnTint = Color(0xFFFEF3C7);
  static const danger = Color(0xFFB91C1C);
  static const dangerTint = Color(0xFFFEE2E2);
  static const info = Color(0xFF2563EB);
  static const infoTint = Color(0xFFEFF6FF);

  // Radii
  static const radius = 16.0;
  static const radiusSm = 12.0;
  static const radiusLg = 22.0;
  static const fontFamily = 'Sora';

  // Gradients
  static const brandGradient = LinearGradient(
    colors: [Color(0xFFC8102E), Color(0xFFA50F1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const navyGradient = LinearGradient(
    colors: [Color(0xFF0D1728), Color(0xFF060B16)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF1A2A4A), Color(0xFF0A1220)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const goldGradient = LinearGradient(
    colors: [Color(0xFFF7C04A), Color(0xFFF0A92E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Soft elevation shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x100B1220), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x1A0B1220), blurRadius: 28, offset: Offset(0, 14)),
  ];
}

/// Convenience accessor used by main.dart.
abstract final class MtekTheme {
  static ThemeData light() => mtekLightTheme();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Mtek.brand400,
      brightness: Brightness.dark,
      primary: Mtek.brand300,
      secondary: Mtek.gold400,
      surface: Mtek.navy850,
      error: const Color(0xFFFF6B6B),
    );
    return mtekLightTheme().copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Mtek.navy950,
      textTheme: mtekLightTheme().textTheme.apply(
        bodyColor: const Color(0xFFF8FAFC),
        displayColor: Colors.white,
      ),
      primaryTextTheme: mtekLightTheme().primaryTextTheme.apply(
        bodyColor: Colors.white, displayColor: Colors.white),
      iconTheme: const IconThemeData(color: Mtek.gray200),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFFF8FAFC), iconColor: Mtek.gray200,
        subtitleTextStyle: TextStyle(color: Mtek.gray300)),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Mtek.navy850,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Mtek.radius),
          side: const BorderSide(color: Mtek.navy600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Mtek.navy850,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Mtek.radiusLg)),
      ),
      inputDecorationTheme: mtekLightTheme().inputDecorationTheme.copyWith(
        fillColor: Mtek.navy800,
        labelStyle: const TextStyle(color: Mtek.gray200),
        hintStyle: const TextStyle(color: Mtek.gray400),
        helperStyle: const TextStyle(color: Mtek.gray300),
        prefixIconColor: Mtek.gray300,
        suffixIconColor: Mtek.gray300,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Mtek.radiusSm),
          borderSide: const BorderSide(color: Mtek.navy600),
        ),
      ),
      chipTheme: mtekLightTheme().chipTheme.copyWith(
        backgroundColor: Mtek.navy800,
        selectedColor: Mtek.navy600,
        side: const BorderSide(color: Mtek.navy600),
        labelStyle: const TextStyle(color: Mtek.gray100),
        secondaryLabelStyle: const TextStyle(color: Colors.white)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white, side: const BorderSide(color: Mtek.gray400))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: Mtek.brand300)),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: Colors.white),
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(Mtek.navy800))),
      dividerTheme: const DividerThemeData(color: Mtek.navy600, thickness: 1, space: 1),
      navigationBarTheme: mtekLightTheme().navigationBarTheme.copyWith(
        backgroundColor: Mtek.navy900,
        indicatorColor: Mtek.brand700,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? Colors.white : Mtek.gray300,
          fontSize: 11, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? Colors.white : Mtek.gray300)),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Mtek.navy800,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: Colors.white),
      ),
      menuTheme: const MenuThemeData(style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Mtek.navy800),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      )),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Mtek.gray100,
        contentTextStyle: const TextStyle(color: Mtek.gray900, fontSize: 13.5),
        actionTextColor: Mtek.brand700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Mtek.radiusSm)),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Mtek.brand300,
        selectionColor: Mtek.navy600,
        selectionHandleColor: Mtek.brand300,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? Mtek.brand400 : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Mtek.gray300),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected) ? Mtek.brand300 : Mtek.gray300)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? Colors.white : Mtek.gray300),
        trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? Mtek.brand600 : Mtek.navy600),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Mtek.brand300, linearTrackColor: Mtek.navy600),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white, unselectedLabelColor: Mtek.gray300,
        indicatorColor: Mtek.brand300,
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        dataTextStyle: TextStyle(color: Mtek.gray100),
        headingRowColor: WidgetStatePropertyAll(Mtek.navy800),
        dividerThickness: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: Mtek.gray100, borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: Mtek.gray900, fontSize: 12),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Mtek.navy850,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Mtek.radiusLg)),
        ),
      ),
    );
  }
}

/// Material 3 light theme branded for M-Tek.
ThemeData mtekLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Mtek.brand600,
    primary: Mtek.brand600,
    secondary: Mtek.navy800,
    tertiary: Mtek.gold500,
    surface: Colors.white,
    error: Mtek.danger,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Mtek.radiusSm));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Mtek.gray50,
    fontFamily: Mtek.fontFamily,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Mtek.navy900,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Mtek.navy900,
      indicatorColor: Mtek.brand600,
      selectedIconTheme: const IconThemeData(color: Colors.white),
      unselectedIconTheme: const IconThemeData(color: Mtek.gray400),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(color: Mtek.gray400, fontSize: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Mtek.brandTint,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? Mtek.brand600 : Mtek.gray500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? Mtek.brand600 : Mtek.gray400,
        ),
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Mtek.navy900),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x100B1220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Mtek.radius),
        side: const BorderSide(color: Mtek.gray200),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: const BorderSide(color: Mtek.gray200),
      backgroundColor: Colors.white,
      selectedColor: Mtek.brandTint,
      labelStyle: const TextStyle(color: Mtek.gray600, fontSize: 12.5),
      secondaryLabelStyle: const TextStyle(color: Mtek.brand600, fontSize: 12.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Mtek.brand600,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Mtek.radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Mtek.navy800,
        side: const BorderSide(color: Mtek.gray300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Mtek.radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Mtek.brand600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Mtek.radiusSm)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Mtek.brand600,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Mtek.radiusSm),
        borderSide: const BorderSide(color: Mtek.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Mtek.radiusSm),
        borderSide: const BorderSide(color: Mtek.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Mtek.radiusSm),
        borderSide: const BorderSide(color: Mtek.brand600, width: 1.6),
      ),
      labelStyle: const TextStyle(color: Mtek.gray500),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Mtek.navy700),
    dividerTheme: const DividerThemeData(color: Mtek.gray100, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Mtek.navy900,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Mtek.radiusSm)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Mtek.radiusLg)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Mtek.radiusLg)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Mtek.brand600),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Mtek.navy900,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

/// Standard page padding shared across screens.
const EdgeInsets kPagePadding = EdgeInsets.all(20);
