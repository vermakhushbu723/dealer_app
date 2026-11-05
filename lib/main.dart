import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/error/app_exception.dart';
import 'core/storage/local_store.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/common_widgets.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlatformDispatcher.instance.onError = (error, _) {
    if (error is! AppException) return false;
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(error.message), backgroundColor: AppColors.red600));
    return true;
  };
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))], child: const DealerApp()));
}
