import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService extends ChangeNotifier {
  final bool isAvailable;
  AuthService({required this.isAvailable});

  User? get user => isAvailable ? FirebaseAuth.instance.currentUser : null;
  Stream<User?> get userStream => isAvailable ? FirebaseAuth.instance.authStateChanges() : const Stream.empty();

  Future<void> signIn(String email, String password) async {
    if (!isAvailable) throw Exception('Firebase Auth não configurado.');
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register(String email, String password) async {
    if (!isAvailable) throw Exception('Firebase Auth não configurado.');
    await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    await FirebaseAuth.instance.signOut();
  }
}
