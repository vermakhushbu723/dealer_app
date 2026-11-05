import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../catalog/domain/product.dart';

class CartLine {
  const CartLine(this.product, this.quantity);

  final Product product;
  final int quantity;

  double get unitPrice => product.priceFor(quantity);
  double get amount => unitPrice * quantity;
}

class CartBill {
  const CartBill({
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.gst,
    required this.deliveryFee,
    required this.total,
    this.couponCode,
  });

  final List<CartLine> lines;
  final double subtotal;
  final double discount;
  final double gst;
  final double deliveryFee;
  final double total;
  final String? couponCode;

  bool get meetsMinimumOrder => subtotal >= AppConstants.minOrderValue;

  /// Works out the bill. GST is charged after the discount, spread across the
  /// lines in proportion to their value.
  factory CartBill.calculate(List<CartLine> lines, {double discount = 0, String? couponCode}) {
    final subtotal = lines.fold<double>(0, (sum, l) => sum + l.amount);
    final cappedDiscount = discount > subtotal ? subtotal : discount;
    final ratio = subtotal == 0 ? 0.0 : (subtotal - cappedDiscount) / subtotal;
    final gst = lines.fold<double>(0, (sum, l) => sum + l.amount * ratio * l.product.gstPercent / 100);
    final fee = lines.isEmpty || subtotal >= AppConstants.freeDeliveryAbove ? 0.0 : AppConstants.deliveryFee;
    return CartBill(
      lines: lines,
      subtotal: roundMoney(subtotal),
      discount: roundMoney(cappedDiscount),
      gst: roundMoney(gst),
      deliveryFee: fee,
      total: roundMoney(subtotal - cappedDiscount + gst + fee),
      couponCode: couponCode,
    );
  }
}
