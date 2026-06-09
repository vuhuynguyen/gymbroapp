import '../../core/utils/json.dart';

/// `GET /api/auth/me` → MeDto.
class Me {
  const Me({required this.userId, required this.name, this.email, required this.isPlatformAdmin});

  final String userId;
  final String name;
  final String? email;
  final bool isPlatformAdmin;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        userId: j['userId'].toString(),
        name: asString(j['name']) ?? '',
        email: asString(j['email']),
        isPlatformAdmin: asBool(j['isPlatformAdmin']),
      );
}

/// login / register / refresh response body: `{ token }`.
class AuthTokenResponse {
  const AuthTokenResponse({required this.token});
  final String token;

  factory AuthTokenResponse.fromJson(Map<String, dynamic> j) =>
      AuthTokenResponse(token: j['token'].toString());
}
