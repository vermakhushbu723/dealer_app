import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Card, field and button shapes and sizes follow growork-user-app.
abstract final class AppRadius {
  static const sm = 8.0; // fields
  static const md = 9.0; // cards and buttons
  static const lg = 12.0; // highlighted panels
  static const sheet = 18.0;
}

abstract final class AppSpacing {
  static const page = EdgeInsets.fromLTRB(13, 12, 13, 20);

  /// Leaves room for a floating action button under the last item.
  static const pageWithFab = EdgeInsets.fromLTRB(13, 12, 13, 88);
  static const bottomBar = EdgeInsets.fromLTRB(13, 8, 13, 8);
  static const card = EdgeInsets.all(12);
}

abstract final class AppTheme {
  /// Dark status icons, and a white navigation bar that matches the app.
  static const overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static const _buttonHeight = 40.0;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: const Color(0xFF3B4A7A).withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 3)),
  ];

  static ThemeData get light {
    OutlineInputBorder field(Color color, [double width = 1.1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: color, width: width),
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md));
    const buttonSize = Size.fromHeight(_buttonHeight);
    const buttonText = TextStyle(
      fontFamily: AppTextStyles.bodyFont,
      fontSize: AppTextStyles.sm,
      fontWeight: FontWeight.w700,
    );
    const fieldText = TextStyle(
      fontFamily: AppTextStyles.bodyFont,
      fontSize: AppTextStyles.sm,
      color: AppColors.neutral500,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.bodyFont,
      visualDensity: VisualDensity.compact,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sky500,
        primary: AppColors.sky700,
        secondary: AppColors.green600,
        error: AppColors.red600,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.sky50,
      textTheme: AppTextStyles.textTheme,
      iconTheme: const IconThemeData(color: AppColors.neutral900, size: 20),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: overlayStyle,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.neutral900,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 52,
        titleSpacing: 13,
        iconTheme: IconThemeData(color: AppColors.neutral900, size: 20),
        actionsIconTheme: IconThemeData(color: AppColors.neutral900, size: 20),
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.headingFont,
          fontFamilyFallback: [AppTextStyles.bodyFont],
          fontSize: AppTextStyles.lg,
          fontWeight: FontWeight.w700,
          color: AppColors.neutral900,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sky700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.sky700.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sky700,
          side: const BorderSide(color: AppColors.sky700, width: 1.2),
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sky700,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: buttonText.copyWith(fontSize: AppTextStyles.label),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintStyle: fieldText,
        labelStyle: fieldText,
        errorStyle: const TextStyle(fontFamily: AppTextStyles.bodyFont, fontSize: AppTextStyles.eyebrow),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        border: field(AppColors.sky200),
        enabledBorder: field(AppColors.sky200),
        focusedBorder: field(AppColors.sky700, 1.6),
        errorBorder: field(AppColors.red600),
        focusedErrorBorder: field(AppColors.red600, 1.6),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.sky700 : AppColors.sky100,
        ),
        labelStyle: TextStyle(
          fontFamily: AppTextStyles.bodyFont,
          fontSize: AppTextStyles.xs,
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.sky700,
          ),
        ),
        showCheckmark: false,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.sky700,
        unselectedLabelColor: AppColors.neutral600,
        indicatorColor: AppColors.sky700,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.sky100,
        labelStyle: TextStyle(
          fontFamily: AppTextStyles.bodyFont,
          fontSize: AppTextStyles.sm,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTextStyles.bodyFont,
          fontSize: AppTextStyles.sm,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        minLeadingWidth: 22,
        horizontalTitleGap: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: 14),
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.bodyFont,
          fontSize: AppTextStyles.sm,
          fontWeight: FontWeight.w600,
          color: AppColors.neutral900,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: AppTextStyles.bodyFont,
          fontSize: AppTextStyles.xs,
          color: AppColors.neutral600,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.sky700 : null),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.sky700 : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.sky700 : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.sky700 : AppColors.neutral600,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.sky700,
        linearTrackColor: AppColors.sky100,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.sky200,
        dragHandleSize: Size(36, 4),
        constraints: BoxConstraints(maxWidth: double.infinity),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: AppTextStyles.textTheme.titleMedium,
        contentTextStyle: AppTextStyles.textTheme.bodyMedium,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.sky100, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: const TextStyle(
          fontFamily: AppTextStyles.bodyFont,
          fontSize: AppTextStyles.label,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.sky700,
        foregroundColor: Colors.white,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
