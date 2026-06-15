/// A single emergency contact. SOS texts every contact and calls the first one.
class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
      );
}
