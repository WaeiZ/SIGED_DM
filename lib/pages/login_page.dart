//Martim Santos - 22309746
//Sérgio Dias - 22304791

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  final bool firebaseReady;
  const LoginPage({super.key, required this.firebaseReady});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1F6036),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  String _loginMessageFromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'O email não é válido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou password inválidos.';
      case 'network-request-failed':
        return 'Sem ligação à internet. Tenta novamente.';
      case 'too-many-requests':
        return 'Demasiadas tentativas. Tenta mais tarde.';
      default:
        return 'Não foi possível iniciar sessão.';
    }
  }

  String _resetMessageFromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'O email não é válido.';
      case 'user-not-found':
        return 'Não existe nenhuma conta com esse email.';
      case 'network-request-failed':
        return 'Sem ligação à internet. Tenta novamente.';
      default:
        return 'Não foi possível enviar o email de redefinição.';
    }
  }

  Future<void> _esqueceuSenha() async {
    final email = _email.text.trim();

    if (email.isEmpty) {
      _showSnack('Por favor, insira um email válido.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Email Enviado'),
            content: const Text(
              'Um link para redefinir a sua password foi enviado para o seu email.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(_resetMessageFromCode(e.code));
      debugPrint('Reset password error: ${e.code} | ${e.message}');
    } catch (e) {
      _showSnack('Ocorreu um erro. Tenta novamente.');
      debugPrint('Reset password error: $e');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', height: 154),

                const SizedBox(height: 16),

                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _esqueceuSenha,
                    child: const Text(
                      'Esqueceu a sua password?',
                      style: TextStyle(color: Color(0xFF1F6036)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            if (!widget.firebaseReady) {
                              if (!mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HomePage(),
                                ),
                              );
                              return;
                            }

                            setState(() => _loading = true);

                            try {
                              await auth.signIn(
                                _email.text.trim(),
                                _pass.text.trim(),
                              );

                              if (!mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HomePage(),
                                ),
                              );
                            } on FirebaseAuthException catch (e) {
                              _showSnack(_loginMessageFromCode(e.code));
                              debugPrint(
                                'Login error: ${e.code} | ${e.message}',
                              );
                            } catch (e) {
                              _showSnack('Ocorreu um erro. Tenta novamente.');
                              debugPrint('Login error: $e');
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          },
                    child: Text(
                      widget.firebaseReady ? 'Entrar' : 'Entrar (Demo)',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Sem conta?'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      child: const Text('Criar conta'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
