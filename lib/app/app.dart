import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/common_widgets.dart';
import 'router.dart';

class DealerApp extends ConsumerWidget {
  const DealerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      scaffoldMessengerKey: rootMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      // Keeps everything above the phone's navigation bar, on every screen.
      builder: (context, child) => ColoredBox(
        color: Colors.white,
        child: SafeArea(top: false, child: child!),
      ),
    );
  }
}
