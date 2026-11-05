enum KycStatus { notSubmitted, pending, approved, rejected }

class Dealer {
  const Dealer({
    required this.id,
    required this.phone,
    this.ownerName = '',
    this.businessName = '',
    this.businessType = '',
    this.email = '',
    this.gstin = '',
    this.pan = '',
    this.fssai = '',
    this.addressLine = '',
    this.city = '',
    this.pincode = '',
    this.documents = const {},
    this.kycStatus = KycStatus.notSubmitted,
    this.rejectionReason = '',
    this.tier = 'Standard',
    this.creditLimit = 0,
    this.creditDays = 0,
    this.joinedOn,
  });

  final String id;
  final String phone;
  final String ownerName;
  final String businessName;
  final String businessType;
  final String email;
  final String gstin;
  final String pan;
  final String fssai;
  final String addressLine;
  final String city;
  final String pincode;

  /// Document name to local file path, for example `GST certificate`.
  final Map<String, String> documents;
  final KycStatus kycStatus;
  final String rejectionReason;
  final String tier;
  final double creditLimit;
  final int creditDays;
  final DateTime? joinedOn;

  bool get isApproved => kycStatus == KycStatus.approved;

  Dealer copyWith({
    String? ownerName,
    String? businessName,
    String? businessType,
    String? email,
    String? gstin,
    String? pan,
    String? fssai,
    String? addressLine,
    String? city,
    String? pincode,
    Map<String, String>? documents,
    KycStatus? kycStatus,
    String? rejectionReason,
    String? tier,
    double? creditLimit,
    int? creditDays,
    DateTime? joinedOn,
  }) => Dealer(
    id: id,
    phone: phone,
    ownerName: ownerName ?? this.ownerName,
    businessName: businessName ?? this.businessName,
    businessType: businessType ?? this.businessType,
    email: email ?? this.email,
    gstin: gstin ?? this.gstin,
    pan: pan ?? this.pan,
    fssai: fssai ?? this.fssai,
    addressLine: addressLine ?? this.addressLine,
    city: city ?? this.city,
    pincode: pincode ?? this.pincode,
    documents: documents ?? this.documents,
    kycStatus: kycStatus ?? this.kycStatus,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    tier: tier ?? this.tier,
    creditLimit: creditLimit ?? this.creditLimit,
    creditDays: creditDays ?? this.creditDays,
    joinedOn: joinedOn ?? this.joinedOn,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'ownerName': ownerName,
    'businessName': businessName,
    'businessType': businessType,
    'email': email,
    'gstin': gstin,
    'pan': pan,
    'fssai': fssai,
    'addressLine': addressLine,
    'city': city,
    'pincode': pincode,
    'documents': documents,
    'kycStatus': kycStatus.name,
    'rejectionReason': rejectionReason,
    'tier': tier,
    'creditLimit': creditLimit,
    'creditDays': creditDays,
    'joinedOn': joinedOn?.toIso8601String(),
  };

  factory Dealer.fromJson(Map<String, dynamic> j) => Dealer(
    id: j['id'] as String,
    phone: j['phone'] as String,
    ownerName: j['ownerName'] as String,
    businessName: j['businessName'] as String,
    businessType: j['businessType'] as String,
    email: j['email'] as String,
    gstin: j['gstin'] as String,
    pan: j['pan'] as String,
    fssai: j['fssai'] as String,
    addressLine: j['addressLine'] as String,
    city: j['city'] as String,
    pincode: j['pincode'] as String,
    documents: (j['documents'] as Map).cast<String, String>(),
    kycStatus: KycStatus.values.byName(j['kycStatus'] as String),
    rejectionReason: j['rejectionReason'] as String,
    tier: j['tier'] as String,
    creditLimit: (j['creditLimit'] as num).toDouble(),
    creditDays: j['creditDays'] as int,
    joinedOn: j['joinedOn'] == null ? null : DateTime.parse(j['joinedOn'] as String),
  );
}
