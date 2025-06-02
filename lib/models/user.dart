import 'package:appwrite/models.dart' as AppwriteModels;


class User {
  final String id;
  final String email;
  final String name;
  final DateTime registration;
  final bool emailVerification;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.registration,
    required this.emailVerification,
  });

  factory User.fromAppwrite(AppwriteModels.User user) {
    return User(
      id: user.$id,
      email: user.email,
      name: user.name,
      registration: DateTime.parse(user.registration),
      emailVerification: user.emailVerification,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'registration': registration.toIso8601String(),
      'emailVerification': emailVerification,
    };
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $name)';
  }
}