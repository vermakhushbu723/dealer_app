class Address {
  const Address({
    required this.id,
    required this.label,
    required this.contactName,
    required this.phone,
    required this.line,
    required this.city,
    required this.pincode,
    this.instructions = '',
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String contactName;
  final String phone;
  final String line;
  final String city;
  final String pincode;
  final String instructions;
  final bool isDefault;

  String get singleLine => '$line, $city - $pincode';

  Address copyWith({bool? isDefault}) => Address(
    id: id,
    label: label,
    contactName: contactName,
    phone: phone,
    line: line,
    city: city,
    pincode: pincode,
    instructions: instructions,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'contactName': contactName,
    'phone': phone,
    'line': line,
    'city': city,
    'pincode': pincode,
    'instructions': instructions,
    'isDefault': isDefault,
  };

  factory Address.fromJson(Map<String, dynamic> j) => Address(
    id: j['id'] as String,
    label: j['label'] as String,
    contactName: j['contactName'] as String,
    phone: j['phone'] as String,
    line: j['line'] as String,
    city: j['city'] as String,
    pincode: j['pincode'] as String,
    instructions: j['instructions'] as String,
    isDefault: j['isDefault'] as bool,
  );
}

abstract interface class AddressRepository {
  Future<List<Address>> addresses();

  Future<void> save(Address address);

  Future<void> delete(String id);

  Future<void> setDefault(String id);
}
