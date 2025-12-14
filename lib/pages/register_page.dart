//Martim Santos - 22309746
//Sérgio Dias - 22304791

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
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

  String _registerMessageFromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'O email não é válido.';
      case 'email-already-in-use':
        return 'Esse email já está registado.';
      case 'weak-password':
        return 'A password é demasiado fraca.';
      case 'network-request-failed':
        return 'Sem ligação à internet. Tenta novamente.';
      case 'too-many-requests':
        return 'Demasiadas tentativas. Tenta mais tarde.';
      default:
        return 'Não foi possível criar a conta.';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Criar Conta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Image.asset('assets/logo.png', height: 154),

                const SizedBox(height: 24),

                // NOME
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),

                const SizedBox(height: 12),

                // EMAIL
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),

                const SizedBox(height: 12),

                // PASSWORD
                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),

                const SizedBox(height: 20),

                // BOTÃO REGISTAR
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            setState(() => _loading = true);

                            try {
                              await auth.register(
                                _email.text.trim(),
                                _pass.text.trim(),
                                name: _name.text.trim(),
                              );

                              if (!mounted) return;
                              Navigator.pop(context);
                            } on FirebaseAuthException catch (e) {
                              _showSnack(_registerMessageFromCode(e.code));
                              debugPrint(
                                'Register error: ${e.code} | ${e.message}',
                              );
                            } catch (e) {
                              _showSnack('Ocorreu um erro. Tenta novamente.');
                              debugPrint('Register error: $e');
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          },
                    child: const Text('Registar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
