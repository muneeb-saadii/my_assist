class AppUser {
  final String id;
  final String phone;
  final String passkey;
  final bool isAdmin;
  final String name;
  final String entity;

  AppUser({
    required this.id,
    required this.phone,
    required this.passkey,
    required this.isAdmin,
    required this.name,
    required this.entity,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'phone': phone,
        'isAdmin': isAdmin,
        'name': name,
        'entity': entity,
      };
}

/// Static users — replace phone numbers and passkeys with real values before release.
class StaticUsers {
  static final List<AppUser> users = [
    AppUser(
      id: 'user_1',
      phone: '03001234567',  // ← replace with real phone
      passkey: '12345678',   // ← replace with secure 8-digit key
      isAdmin: true,
      name: 'Admin User',
      entity: 'Entity1',
    ),
    AppUser(
      id: 'user_2',
      phone: '03009876543',  // ← replace with real phone
      passkey: '87654321',   // ← replace with secure 8-digit key
      isAdmin: false,
      name: 'Regular User',
      entity: 'Entity2',
    ),
  ];

  static AppUser? authenticate(String phone, String passkey) {
    try {
      return users.firstWhere(
        (u) => u.phone == phone.trim() && u.passkey == passkey.trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
