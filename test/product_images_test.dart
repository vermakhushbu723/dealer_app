import 'dart:ui' as ui;

import 'package:dealer_app/features/catalog/data/fake_catalog_repository.dart';
import 'package:dealer_app/core/storage/local_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A cut-off download once left product photos blank, so decode each one for real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every product image and the logo decode at the size the list shows', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final products = await FakeCatalogRepository(store, tier: 'Gold').products();
    final paths = {for (final p in products) p.image, 'assets/images/app_logo.png'};

    expect(paths.length, greaterThan(1));
    for (final path in paths) {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 192);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 192, reason: path);
      expect(frame.image.height, greaterThan(0), reason: path);
    }
  });
}
