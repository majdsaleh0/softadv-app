class ProviderProfile {
  const ProviderProfile({required this.id, required this.name, required this.businessName, required this.createdAt});

  final String id;
  final String name;
  final String? businessName;
  final DateTime createdAt;

  factory ProviderProfile.fromMap(Map<String, dynamic> map) {
    return ProviderProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      businessName: map['business_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
