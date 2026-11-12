import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// The single Material theme for N.O Business, assembled from the tokens.
///
/// The product ships one (dark) theme by design: the brand is a luminous
/// palette on near-black. A light variant would be added here as a second
/// builder over the same tokens, not as per-widget overrides.
ThemeData buildNobTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: NobColors.cobalt,
    onPrimary: NobColors.onAccent,
    primaryContainer: Color(0xFF0A2A7A),
    onPrimaryContainer: NobColors.textPrimary,
    secondary: NobColors.cyan,
    onSecondary: NobColors.onCyan,
    secondaryContainer: Color(0xFF063A4A),
    onSecondaryContainer: NobColors.textPrimary,
    tertiary: NobColors.violet,
    onTertiary: NobColors.onAccent,
    error: NobColors.danger,
    onError: Color(0xFF2A0008),
    surface: NobColors.surface,
    onSurface: NobColors.textPrimary,
    onSurfaceVariant: NobColors.textSecondary,
    outline: NobColors.borderStrong,
    outlineVariant: NobColors.border,
    surfaceContainerLowest: NobColors.background,
    surfaceContainerLow: NobColors.backgroundRaised,
    surfaceContainer: NobColors.surface,
    surfaceContainerHigh: NobColors.surfaceHigh,
    surfaceContainerHighest: NobColors.surfaceHigh,
    inverseSurface: NobColors.textPrimary,
    onInverseSurface: NobColors.background,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final textTheme = const TextTheme(
    displaySmall: NobText.display,
    headlineMedium: NobText.headline,
    headlineSmall: NobText.headline,
    titleLarge: NobText.title,
    titleMedium: NobText.subtitle,
    titleSmall: NobText.subtitle,
    bodyLarge: NobText.body,
    bodyMedium: NobText.body,
    bodySmall: NobText.bodySmall,
    labelLarge: NobText.subtitle,
    labelMedium: NobText.label,
    labelSmall: NobText.label,
  ).apply(bodyColor: NobColors.textPrimary, displayColor: NobColors.textPrimary);

  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: NobRadius.medium,
        borderSide: BorderSide(color: color, width: width),
      );

  const buttonShape = RoundedRectangleBorder(borderRadius: NobRadius.medium);
  const buttonPadding = EdgeInsets.symmetric(horizontal: NobSpace.xl, vertical: NobSpace.lg);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: NobText.family,
    textTheme: textTheme,
    scaffoldBackgroundColor: NobColors.background,
    canvasColor: NobColors.background,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    dividerTheme: const DividerThemeData(color: NobColors.border, thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: NobColors.textSecondary, size: 20),
    appBarTheme: const AppBarTheme(
      backgroundColor: NobColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: NobColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: NobText.title,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: const CardThemeData(
      color: NobColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: NobRadius.large,
        side: BorderSide(color: NobColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NobColors.backgroundRaised,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: NobSpace.lg, vertical: 14),
      hintStyle: NobText.body.copyWith(color: NobColors.textMuted),
      labelStyle: NobText.body.copyWith(color: NobColors.textSecondary),
      floatingLabelStyle: NobText.label.copyWith(color: NobColors.cyan),
      helperStyle: NobText.label.copyWith(color: NobColors.textMuted),
      errorStyle: NobText.label.copyWith(color: NobColors.danger),
      prefixIconColor: NobColors.textSecondary,
      suffixIconColor: NobColors.textSecondary,
      border: inputBorder(NobColors.border),
      enabledBorder: inputBorder(NobColors.border),
      disabledBorder: inputBorder(NobColors.border.withValues(alpha: 0.5)),
      focusedBorder: inputBorder(NobColors.cyan, 1.5),
      errorBorder: inputBorder(NobColors.danger),
      focusedErrorBorder: inputBorder(NobColors.danger, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NobColors.cobalt,
        foregroundColor: NobColors.onAccent,
        disabledBackgroundColor: NobColors.surfaceHigh,
        disabledForegroundColor: NobColors.textMuted,
        textStyle: NobText.subtitle,
        padding: buttonPadding,
        minimumSize: const Size(0, 44),
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NobColors.textPrimary,
        side: const BorderSide(color: NobColors.borderStrong),
        textStyle: NobText.subtitle,
        padding: buttonPadding,
        minimumSize: const Size(0, 44),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NobColors.cyan,
        textStyle: NobText.subtitle,
        padding: const EdgeInsets.symmetric(horizontal: NobSpace.md, vertical: NobSpace.sm),
        minimumSize: const Size(0, 40),
        shape: buttonShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: NobColors.textSecondary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NobColors.cobalt,
      foregroundColor: NobColors.onAccent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: NobRadius.large),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NobColors.backgroundRaised,
      selectedColor: NobColors.cobalt.withValues(alpha: 0.28),
      disabledColor: NobColors.backgroundRaised,
      side: const BorderSide(color: NobColors.border),
      labelStyle: NobText.label.copyWith(color: NobColors.textPrimary),
      secondaryLabelStyle: NobText.label.copyWith(color: NobColors.textPrimary),
      checkmarkColor: NobColors.cyan,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: NobSpace.sm, vertical: NobSpace.xs),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: NobColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: NobText.title,
      shape: RoundedRectangleBorder(
        borderRadius: NobRadius.extraLarge,
        side: BorderSide(color: NobColors.borderStrong),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NobColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: NobColors.surface,
      showDragHandle: true,
      dragHandleColor: NobColors.borderStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NobRadius.xl)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: NobColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      textStyle: NobText.body,
      shape: RoundedRectangleBorder(
        borderRadius: NobRadius.medium,
        side: BorderSide(color: NobColors.borderStrong),
      ),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(NobColors.surfaceHigh),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NobColors.surfaceHigh,
      contentTextStyle: NobText.body.copyWith(color: NobColors.textPrimary),
      actionTextColor: NobColors.cyan,
      shape: const RoundedRectangleBorder(
        borderRadius: NobRadius.medium,
        side: BorderSide(color: NobColors.borderStrong),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: NobColors.surfaceHigh,
        borderRadius: NobRadius.small,
        border: Border.all(color: NobColors.borderStrong),
      ),
      textStyle: NobText.label.copyWith(color: NobColors.textPrimary),
      waitDuration: const Duration(milliseconds: 400),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: NobColors.textSecondary,
      textColor: NobColors.textPrimary,
      titleTextStyle: NobText.subtitle,
      subtitleTextStyle: NobText.bodySmall,
      contentPadding: EdgeInsets.symmetric(horizontal: NobSpace.lg),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NobColors.backgroundRaised,
      surfaceTintColor: Colors.transparent,
      indicatorColor: NobColors.cobalt.withValues(alpha: 0.28),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => NobText.label.copyWith(
          color: states.contains(WidgetState.selected) ? NobColors.textPrimary : NobColors.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected) ? NobColors.cyan : NobColors.textSecondary,
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? NobColors.cobalt : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(NobColors.onAccent),
      side: const BorderSide(color: NobColors.borderStrong, width: 1.5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? NobColors.onAccent : NobColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? NobColors.cobalt : NobColors.surfaceHigh,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(NobColors.borderStrong),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: const WidgetStatePropertyAll(NobText.label),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? NobColors.textPrimary : NobColors.textSecondary,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NobColors.cobalt.withValues(alpha: 0.28)
              : Colors.transparent,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: NobColors.border)),
        shape: const WidgetStatePropertyAll(buttonShape),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: NobColors.cyan,
      linearTrackColor: NobColors.border,
      circularTrackColor: Colors.transparent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(NobColors.borderStrong.withValues(alpha: 0.9)),
      radius: const Radius.circular(NobRadius.pill),
      thickness: const WidgetStatePropertyAll(6),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: NobColors.cyan,
      selectionColor: NobColors.cobalt.withValues(alpha: 0.45),
      selectionHandleColor: NobColors.cyan,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: NobColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
