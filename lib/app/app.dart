import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/common_widgets.dart';
import 'app_shell.dart';
import 'router.dart';
import 'routes.dart';
import 'web_frame.dart';

class DealerApp extends ConsumerWidget {
  const DealerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      scaffoldMessengerKey: rootMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Keeps everything above the phone's navigation bar, on every screen. In a wide browser
      // window the app gets a sidebar; on a phone, in the app or the browser, it looks the same.
      builder: (context, child) => WebFrame(
        router: router,
        tabs: appTabs,
        tabRoutes: appTabRoutes,
        signedOutRoutes: const {Routes.splash, Routes.login, Routes.otp, Routes.kyc, Routes.kycPending},
        child: ColoredBox(
          color: Colors.white,
          child: SafeArea(top: false, child: child!),
        ),
      ),
    );
  }
}
