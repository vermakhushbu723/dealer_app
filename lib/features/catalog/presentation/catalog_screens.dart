import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../domain/product.dart';
import 'catalog_providers.dart';

enum ProductSort { recommended, priceLow, priceHigh, name }

const _sortLabels = {
  ProductSort.recommended: 'Recommended',
  ProductSort.priceLow: 'Price: low to high',
  ProductSort.priceHigh: 'Price: high to low',
  ProductSort.name: 'Name',
};

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String _query = '';
  String? _categoryId;
  bool _favouritesOnly = false;
  bool _inStockOnly = false;
  ProductSort _sort = ProductSort.recommended;

  List<Product> _filter(List<Product> products, Set<String> favourites) {
    final query = _query.trim().toLowerCase();
    final result = products.where((p) {
      if (_categoryId != null && p.categoryId != _categoryId) return false;
      if (_favouritesOnly && !favourites.contains(p.id)) return false;
      if (_inStockOnly && !p.inStock) return false;
      if (query.isEmpty) return true;
      return '${p.name} ${p.packSize} ${p.uses.join(' ')}'.toLowerCase().contains(query);
    }).toList();
    switch (_sort) {
      case ProductSort.priceLow:
        result.sort((a, b) => a.basePrice.compareTo(b.basePrice));
      case ProductSort.priceHigh:
        result.sort((a, b) => b.basePrice.compareTo(a.basePrice));
      case ProductSort.name:
        result.sort((a, b) => a.name.compareTo(b.name));
      case ProductSort.recommended:
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final favourites = ref.watch(favouritesProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Price list',
            icon: const Icon(Icons.price_change_outlined),
            onPressed: () => context.push(Routes.priceList),
          ),
          const CartIconButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search ice, pack size or use',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                PopupMenuButton<ProductSort>(
                  tooltip: 'Sort products',
                  icon: const Icon(Icons.sort),
                  initialValue: _sort,
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => [
                    for (final e in _sortLabels.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              children: [
                _chip('All', _categoryId == null, () => setState(() => _categoryId = null)),
                for (final c in categories)
                  _chip(c.name, _categoryId == c.id, () => setState(() => _categoryId = c.id)),
                _chip('Favourites', _favouritesOnly, () => setState(() => _favouritesOnly = !_favouritesOnly)),
                _chip('In stock', _inStockOnly, () => setState(() => _inStockOnly = !_inStockOnly)),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody(
              value: products,
              onRetry: () => ref.invalidate(productsProvider),
              builder: (data) {
                final items = _filter(data, favourites);
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No products found',
                    message: 'Try a different search or filter.',
                  );
                }
                return ListView.separated(
                  padding: AppSpacing.page,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => ProductTile(product: items[i]),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CartSummaryBar(),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(label: Text(label), selected: selected, showCheckmark: false, onSelected: (_) => onTap()),
  );
}

class ProductImage extends StatelessWidget {
  const ProductImage(this.path, {super.key, this.size = 64});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      ),
    );
  }
}

class ProductTile extends ConsumerWidget {
  const ProductTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push(Routes.product(product.id)),
      child: Row(
        children: [
          ProductImage(product.image),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: text.titleSmall),
                Text(product.packSize, style: text.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '${money(product.basePrice)} / ${product.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.neutral900),
                ),
                if (product.standardPrice != null)
                  Text(
                    'List price ${money(product.standardPrice!)}',
                    style: text.labelSmall?.copyWith(decoration: TextDecoration.lineThrough),
                  ),
                Text('Min. order ${product.minOrderQty} ${product.unit}', style: text.labelSmall),
              ],
            ),
          ),
          product.inStock
              ? AddToCartControl(product: product)
              : const StatusChip('Out of stock', color: AppColors.red600),
        ],
      ),
    );
  }
}

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  Future<void> _toggleFavourite(WidgetRef ref, bool favourite) async {
    await ref.read(catalogRepositoryProvider).setFavourite(productId, favourite);
    ref.invalidate(favouritesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavourite = ref.watch(favouritesProvider).value?.contains(productId) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product details'),
        actions: [
          IconButton(
            tooltip: isFavourite ? 'Remove from favourites' : 'Add to favourites',
            icon: Icon(
              isFavourite ? Icons.favorite : Icons.favorite_border,
              color: isFavourite ? AppColors.red600 : null,
            ),
            onPressed: () => _toggleFavourite(ref, !isFavourite),
          ),
          const CartIconButton(),
        ],
      ),
      body: AsyncBody(
        value: ref.watch(productProvider(productId)),
        builder: (product) => product == null
            ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'Product not found')
            : _ProductDetailBody(product: product),
      ),
      bottomNavigationBar: const CartSummaryBar(),
    );
  }
}

class _ProductDetailBody extends ConsumerWidget {
  const _ProductDetailBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final hasAlert = ref.watch(stockAlertsProvider).value?.contains(product.id) ?? false;
    final qty = ref.watch(cartProvider)[product.id] ?? 0;

    return ListView(
      padding: AppSpacing.page,
      children: [
        Center(child: ProductImage(product.image, size: 180)),
        const SizedBox(height: 12),
        Text(product.name, style: text.headlineMedium),
        Text(product.packSize),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${money(qty > 0 ? product.priceFor(qty) : product.basePrice)} / ${product.unit}',
                style: text.titleLarge?.copyWith(color: AppColors.sky600),
              ),
            ),
            if (product.inStock) AddToCartControl(product: product),
          ],
        ),
        Text(
          'Your dealer price + ${product.gstPercent.toStringAsFixed(0)}% GST'
          '${product.standardPrice == null ? '' : ' · List price ${money(product.standardPrice!)}'}',
          style: text.bodySmall,
        ),
        if (product.usageWarning != null) ...[
          const SizedBox(height: 12),
          NoticeBanner(product.usageWarning!, icon: Icons.warning_amber_rounded),
        ],
        if (!product.inStock) ...[
          const SizedBox(height: 12),
          const NoticeBanner('Currently out of stock.', color: AppColors.red600),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(hasAlert ? Icons.notifications_active : Icons.notifications_none),
            label: Text(hasAlert ? 'We will notify you' : 'Notify me when available'),
            onPressed: () async {
              await ref.read(catalogRepositoryProvider).setStockAlert(product.id, !hasAlert);
              ref.invalidate(stockAlertsProvider);
            },
          ),
        ],
        const SectionTitle('Volume pricing'),
        AppCard(
          child: Column(
            children: [
              for (final (i, slab) in product.slabs.indexed)
                InfoRow(
                  i + 1 < product.slabs.length
                      ? '${slab.minQty} - ${product.slabs[i + 1].minQty - 1} ${product.unit}'
                      : '${slab.minQty}+ ${product.unit}',
                  money(slab.price),
                  valueColor: qty > 0 && product.priceFor(qty) == slab.price ? AppColors.green600 : null,
                ),
            ],
          ),
        ),
        const SectionTitle('About'),
        Text(product.description),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final use in product.uses) StatusChip(use)]),
        const SectionTitle('Ordering'),
        AppCard(
          child: Column(
            children: [
              InfoRow('Minimum order', '${product.minOrderQty} ${product.unit}'),
              InfoRow('Order in multiples of', '${product.stepQty} ${product.unit}'),
              InfoRow(
                'Availability',
                product.inStock ? '${product.availableQty} ${product.unit} in stock' : 'Out of stock',
              ),
              if (product.isReturnable) const InfoRow('Returnable', 'Yes, tracked in Ice Boxes'),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Every product with this dealer's own prices. The rates are set by the admin.
class PriceListScreen extends ConsumerWidget {
  const PriceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const <IceCategory>[];
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Products and price list')),
      body: AsyncBody(
        value: ref.watch(productsProvider),
        onRetry: () => ref.invalidate(productsProvider),
        builder: (products) => ListView(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 16),
          children: [
            const SizedBox(height: 12),
            const NoticeBanner(
              'These are your dealer prices, before GST. Only you can see them.',
              color: AppColors.sky600,
              icon: Icons.verified_outlined,
            ),
            for (final category in categories)
              if (products.any((p) => p.categoryId == category.id)) ...[
                SectionTitle(category.name),
                for (final p in products.where((p) => p.categoryId == category.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.push(Routes.product(p.id)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.packSize, style: text.titleSmall),
                          const SizedBox(height: 4),
                          for (final (i, slab) in p.slabs.indexed)
                            InfoRow(
                              i + 1 < p.slabs.length
                                  ? '${slab.minQty} - ${p.slabs[i + 1].minQty - 1} ${p.unit}'
                                  : '${slab.minQty}+ ${p.unit}',
                              money(slab.price),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

/// One Products sub-menu: the packs of a single type of ice.
class CategoryProductsScreen extends ConsumerWidget {
  const CategoryProductsScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const <IceCategory>[];
    final title = categories.where((c) => c.id == categoryId).firstOrNull?.name ?? 'Products';
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [CartIconButton()]),
      bottomNavigationBar: const CartSummaryBar(),
      body: AsyncBody(
        value: ref.watch(productsProvider),
        onRetry: () => ref.invalidate(productsProvider),
        builder: (products) {
          final items = products.where((p) => p.categoryId == categoryId).toList();
          if (items.isEmpty) return EmptyState(icon: Icons.ac_unit, title: 'No $title right now');
          return ListView.separated(
            padding: AppSpacing.page,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => ProductTile(product: items[i]),
          );
        },
      ),
    );
  }
}
