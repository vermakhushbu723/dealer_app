/// Business details published on iceclubstore.in.
abstract final class AppConstants {
  static const appName = 'ICECLUB Dealer';
  static const companyName = 'ICECLUB';
  static const serviceArea = 'Mumbai, Thane, Navi Mumbai & Palghar';
  static const supportPhone = '+917009090977';
  static const whatsappNumber = '917009090977';
  static const website = 'https://iceclubstore.in';
  static const webAppDomain = 'dealer.iceclub.online';

  static const logo = 'assets/images/app_logo.png';

  // Placeholders: confirm these with the business before going live.
  static const minOrderValue = 1000.0;
  static const freeDeliveryAbove = 5000.0;
  static const deliveryFee = 250.0;
  static const iceBoxDeposit = 500.0;

  // Fill these in before going live. Invoices and UPI payments depend on them.
  static const companyGstin = '';
  static const companyFssai = '';
  static const companyUpiId = '';
  static const companyStateCode = '27'; // Maharashtra, decides CGST + SGST or IGST

  /// Slot label and the hour it starts.
  static const deliverySlots = [
    ('6 AM - 9 AM', 6),
    ('9 AM - 12 PM', 9),
    ('12 PM - 3 PM', 12),
    ('3 PM - 6 PM', 15),
    ('6 PM - 9 PM', 18),
  ];

  /// A same-day slot can be booked until this many hours before it starts.
  static const slotLeadHours = 2;

  static const stores = [('Andheri', '918282884949'), ('Goregaon West', '919889881970'), ('Worli', '919920090037')];
}
