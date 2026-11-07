import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/error/app_exception.dart';
import 'core/storage/local_store.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/common_widgets.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On the web: real paths such as /dealer/orders instead of /#/orders, and the address bar
  // follows every page that is opened, so a link to it can be shared or reloaded.
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  PlatformDispatcher.instance.onError = (error, _) {
    if (error is! AppException) return false;
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(error.message), backgroundColor: AppColors.red600));
    return true;
  };
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))], child: const DealerApp()));
}
