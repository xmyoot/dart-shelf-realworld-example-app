import 'package:dart_shelf_realworld_example_app/src/common/exceptions/already_exists_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/argument_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/not_found_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/users/model/user.dart';
import 'package:email_validator/email_validator.dart';
import 'package:postgres_pool/postgres_pool.dart';

class UsersService {
  static String usersTable = 'users';

  final PgPool connectionPool;

  UsersService({required this.connectionPool});

  Future<User> createUser(
      {required String username,
      required String email,
      required String password}) async {
    await _validateUsernameOrThrow(username);

    await _validateEmailOrThrow(email);

    _validatePasswordOrThrow(password);

    final sql =
        "INSERT INTO $usersTable(username, email, password_hash) VALUES (@username, @email, crypt(@password, gen_salt('bf'))) RETURNING id, created_at, updated_at;";

    final result = await connectionPool.query(sql, substitutionValues: {
      'username': username,
      'email': email,
      'password': password
    });

    final userRow = result[0];
    final userId = userRow[0];
    final createdAt = userRow[1];
    final updatedAt = userRow[2];

    return User(
        id: userId,
        username: username,
        email: email,
        createdAt: createdAt,
        updatedAt: updatedAt);
  }

  Future<User?> getUserById(String userId) async {
    final sql =
        'SELECT email, username, bio, image, created_at, updated_at FROM $usersTable WHERE id = @id;';

    final result =
        await connectionPool.query(sql, substitutionValues: {'id': userId});

    if (result.isEmpty) {
      return null;
    }

    final userRow = result[0];

    final email = userRow[0];
    final username = userRow[1];
    final bio = userRow[2];
    final image = userRow[3];
    final createdAt = userRow[4];
    final updatedAt = userRow[5];

    return User(
        id: userId,
        username: username,
        email: email,
        bio: bio,
        image: image,
        createdAt: createdAt,
        updatedAt: updatedAt);
  }

  Future<User?> getUserByEmail(String email) async {
    final sql = 'SELECT id FROM $usersTable WHERE email = @email;';

    final result =
        await connectionPool.query(sql, substitutionValues: {'email': email});

    if (result.isEmpty) {
      return null;
    }

    final userId = result[0][0];

    return await getUserById(userId);
  }

  Future<User?> getUserByEmailAndPassword(String email, String password) async {
    final sql =
        'SELECT id FROM $usersTable WHERE email = @email AND password_hash = crypt(@password, password_hash);';

    final result = await connectionPool
        .query(sql, substitutionValues: {'email': email, 'password': password});

    if (result.isEmpty) {
      return null;
    }

    final userId = result[0][0];

    return await getUserById(userId);
  }

  Future<User?> getUserByUsername(String username) async {
    final sql = 'SELECT id FROM $usersTable WHERE username = @username;';

    final result = await connectionPool
        .query(sql, substitutionValues: {'username': username});

    if (result.isEmpty) {
      return null;
    }

    final userId = result[0][0];

    return await getUserById(userId);
  }

  Future<User> updateUserByEmail(String email,
      {String? username,
      String? emailForUpdate,
      String? password,
      String? bio,
      String? image}) async {
    final user = await getUserByEmail(email);

    if (user == null) {
      throw NotFoundException(message: 'User not found');
    }

    final initialSql = 'UPDATE $usersTable';

    var sql = initialSql;

    if (username != null && username != user.username) {
      await _validateUsernameOrThrow(username);

      if (sql == initialSql) {
        sql = sql + ' SET username = @username';
      } else {
        sql = sql + ', username = @username';
      }
    }

    if (emailForUpdate != null && emailForUpdate != user.email) {
      await _validateEmailOrThrow(emailForUpdate);

      if (sql == initialSql) {
        sql = sql + ' SET email = @emailForUpdate';
      } else {
        sql = sql + ', email = @emailForUpdate';
      }
    }

    if (password != null) {
      _validatePasswordOrThrow(password);

      if (sql == initialSql) {
        sql = sql + " SET password_hash = crypt(@password, gen_salt('bf'))";
      } else {
        sql = sql + ", password_hash = crypt(@password, gen_salt('bf'))";
      }
    }

    if (bio != null && bio != user.bio) {
      if (sql == initialSql) {
        sql = sql + ' SET bio = @bio';
      } else {
        sql = sql + ', bio = @bio';
      }
    }

    if (image != null && image != user.image) {
      _validateImageOrThrow(image);

      if (sql == initialSql) {
        sql = sql + ' SET image = @image';
      } else {
        sql = sql + ', image = @image';
      }
    }

    var updatedEmail = email;

    if (sql != initialSql) {
      sql = sql + ', updated_at = current_timestamp';
      sql = sql + ' WHERE email = @email RETURNING email;';

      final result = await connectionPool.query(sql, substitutionValues: {
        'email': email,
        'username': username,
        'emailForUpdate': emailForUpdate,
        'password': password,
        'bio': bio,
        'image': image
      });

      updatedEmail = result[0][0];
    }

    final updatedUser = await getUserByEmail(updatedEmail);

    if (updatedUser == null) {
      throw AssertionError(
          "User cannot be null at this point. Email: $email. Updated Email: $updatedEmail");
    }

    return updatedUser;
  }

  Future _validateUsernameOrThrow(String username) async {
    if (username.trim().isEmpty) {
      throw ArgumentException(
          message: 'username cannot be blank', parameterName: 'username');
    }

    if ((await getUserByUsername(username)) != null) {
      throw AlreadyExistsException(message: 'Username is taken');
    }
  }

  Future _validateEmailOrThrow(String email) async {
    if (!EmailValidator.validate(email)) {
      throw ArgumentException(
          message: 'Invalid email: $email', parameterName: 'email');
    }

    if ((await getUserByEmail(email)) != null) {
      throw AlreadyExistsException(message: 'Email is taken');
    }
  }

  void _validatePasswordOrThrow(String password) {
    // See https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html#implement-proper-password-strength-controls
    final passwordMinLength = 8;
    final passwordMaxLength = 64;

    if (password.length < passwordMinLength) {
      throw ArgumentException(
          message:
              'Password length must be greater than or equal to $passwordMinLength',
          parameterName: 'password');
    }

    if (password.length > passwordMaxLength) {
      throw ArgumentException(
          message:
              'Password length must be less than or equal to $passwordMaxLength',
          parameterName: 'password');
    }
  }

  void _validateImageOrThrow(String image) {
    final imageUri = Uri.tryParse(image);

    if (imageUri == null ||
        !(imageUri.isScheme('HTTP') || imageUri.isScheme('HTTPS'))) {
      throw ArgumentException(
          message: 'image must be a HTTP/HTTPS URL', parameterName: 'image');
    }
  }
}
