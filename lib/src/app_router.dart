import 'package:dart_shelf_realworld_example_app/src/auth/auth_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_handlers.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_service.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class AppRouter {
  late UsersHandlers _usersHandlers;

  AppRouter(
      {required String secretKey,
      required String issuer,
      required PostgreSQLConnection connection}) {
    final usersService = UsersService(connection: connection);
    final authService = AuthService(
        secretKey: secretKey, issuer: issuer, usersService: usersService);

    _usersHandlers =
        UsersHandlers(authService: authService, usersService: usersService);
  }

  Handler get router {
    final router = Router();

    router.post("/api/users", _usersHandlers.registerUserHandler);

    return router;
  }
}
