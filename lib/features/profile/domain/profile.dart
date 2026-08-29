enum UserRole { customer, provider, admin }

UserRole userRoleFromString(String value) {
  return UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.customer,
  );
}

enum AccountStatus { pending, active, suspended }

AccountStatus accountStatusFromString(String value) {
  return AccountStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => AccountStatus.active,
  );
}

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.businessName,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final AccountStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? businessName;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: userRoleFromString(map['role'] as String),
      status: accountStatusFromString(map['status'] as String),
      businessName: map['business_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
