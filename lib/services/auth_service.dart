import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final bool isAvailable;
  AuthService({required this.isAvailable});

  User? get user => isAvailable ? FirebaseAuth.instance.currentUser : null;
  Stream<User?> get userStream => isAvailable
      ? FirebaseAuth.instance.authStateChanges()
      : const Stream.empty();

  Future<void> signIn(String email, String password) async {
    if (!isAvailable) throw Exception('Firebase Auth não configurado.');
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // --- REGISTO COM NOME (NOVO) ---
  Future<void> register(String email, String password,
      {required String name}) async {
    if (!isAvailable) throw Exception('Firebase Auth não configurado.');

    // Criar o utilizador
    UserCredential credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Guardar nome na base de dados (Firestore)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(credential.user!.uid)
        .set({
      'uid': credential.user!.uid,
      'email': email,
      'name': name,
      'createdAt': DateTime.now(),
    });
  }
  // ---------------------------------

  Future<void> signOut() async {
    if (!isAvailable) return;
    await FirebaseAuth.instance.signOut();
  }
}
