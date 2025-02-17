import 'package:dart_shelf_realworld_example_app/src/users/jwt_service.dart';

import '../test_fixtures.dart';

Map<String, String> makeHeadersWithAuthorization(String token) {
  return {'Authorization': 'Token $token'};
}

String makeTokenWithEmail(String email) {
  final jwtService = JwtService(issuer: issuer, secretKey: secretKey);
  return jwtService.getToken(email);
}
