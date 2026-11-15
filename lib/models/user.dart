class User {
  User({
    required this.name,
    required this.email,
    required this.passwordHash,
    this.phone,
    this.role = 'user',
  });

  final String name;
  final String email;
  final String passwordHash;
  final String? phone;
  final String role;

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'phone': phone,
        'role': role,
        'createdAt': DateTime.now().toUtc(),
      };

  /// Remove sensitive fields before sending to the client.
  static Map<String, dynamic> publicView(Map<String, dynamic> doc) =>
      Map<String, dynamic>.from(doc)..remove('passwordHash');
}
