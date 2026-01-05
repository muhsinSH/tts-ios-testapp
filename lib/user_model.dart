class User {
  final int id;
  final String name;
  final String badgeNumber;
  final String department;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.badgeNumber,
    required this.department,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      badgeNumber: json['badge_number'],
      department: json['department'],
      role: json['role'],
    );
  }
}