import 'package:bcrypt/bcrypt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationService {
  final SupabaseClient client = Supabase.instance.client;

  Future<void> logLoginActivity(String userId) async {
    await client.from('login_activity').insert({
      'user_id': userId,
      'login_time': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateLastLogin(String userId, String tableName) async {
    await client
        .from(tableName)
        .update({'last_login': DateTime.now().toIso8601String()})
        .eq('id', userId);

    await logLoginActivity(userId);
  }

  Future<Map<String, dynamic>?> signInWithUsernameOrEmailAndPassword(String input, String password) async {
    try {
      var response = await client
          .from('user_admin')
          .select()
          .or('email.eq.$input,username.eq.$input')
          .limit(1)
          .single();

      if (response == null) {
        throw AuthException('User not found with this email or username');
      }

      final user = response;

      if (BCrypt.checkpw(password, user['password'])) {
        await saveUserData(user['id'], user['fname'] ?? user['username'], user['email']);
        await updateLastLogin(user['id'], 'user_admin');
        return user;
      } else {
        throw AuthException('Invalid password');
      }
    } catch (error) {
      throw AuthException('Unexpected error: $error');
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
    await removeUserData();
  }

  Future<void> updatePassword(String userId, String newPassword, String tableName) async {
    final hashedPassword = BCrypt.hashpw(newPassword, BCrypt.gensalt());

    final response = await client
        .from(tableName)
        .update({'password': hashedPassword})
        .eq('id', userId);

    if (response.error != null) {
      throw AuthException('Failed to update password: ${response.error!.message}');
    }
  }

  String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  Future<void> deleteUser(String tableName) async {
    final userId = getCurrentUserId();
    if (userId != null) {
      final response = await client
          .from(tableName)
          .delete()
          .eq('id', userId);

      if (response.error != null) {
        throw AuthException('Failed to delete user: ${response.error!.message}');
      } else {
        await signOut();
      }
    } else {
      throw AuthException('No user is currently signed in.');
    }
  }

  Future<void> deleteTrackingData(String userId) async {
    final response = await client
        .from('emotion_tracking')
        .delete()
        .eq('user_id', userId);

    if (response != null) {
      throw AuthException('Failed to delete tracking data: ${response.error!.message}');
    }
  }

  Future<void> saveUserData(String userId, String? name, String email) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('userId', userId);
    prefs.setString('userName', name ?? 'User');
    prefs.setString('userEmail', email);
  }

  Future<Map<String, String>?> getUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    String? userName = prefs.getString('userName');
    String? userEmail = prefs.getString('userEmail');
    if (userId != null && userName != null && userEmail != null) {
      return {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
      };
    }
    return null;
  }

  Future<void> removeUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('userId');
    prefs.remove('userName');
    prefs.remove('userEmail');
  }

  bool isAuthenticated() {
    return client.auth.currentUser != null;
  }

  Future<Map<String, String>?> loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('rememberMe') ?? false) {
      return {
        'username': prefs.getString('username') ?? '',
        'password': prefs.getString('password') ?? '',
      };
    }
    return null;
  }

  Future<void> saveCredentials(String username, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('rememberMe', true);
    prefs.setString('username', username);
    prefs.setString('password', password);
  }

  Future<void> removeCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('rememberMe');
    prefs.remove('username');
    prefs.remove('password');
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
