import 'package:supabase_flutter/supabase_flutter.dart';

/// A service to encapsulate all Supabase authentication activities.
class AuthService {
  AuthService._();

  /// The singleton instance of the AuthService.
  static final AuthService instance = AuthService._();

  /// Signs up a new user using email and password.
  Future<AuthResponse> signUpWithEmail(String email, String password) {
    return Supabase.instance.client.auth.signUp(email: email, password: password);
  }

  /// Signs in an existing user using email and password.
  Future<AuthResponse> signInWithEmail(String email, String password) {
    return Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
  }

  /// Signs in a user with a Google OAuth ID token and Access token.
  Future<AuthResponse> signInWithIdToken({required String idToken, required String accessToken}) {
    return Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Signs out the current user session.
  Future<void> signOut() {
    return Supabase.instance.client.auth.signOut();
  }

  /// Triggers account deletion for the currently authenticated user via Database RPC.
  Future<void> deleteUserAccount() async {
    await Supabase.instance.client.rpc('delete_current_user');
  }
}
