import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'home_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Image.asset(
                  'assets/logo.png',
                  height: 154,
                ),

                const SizedBox(height: 16),

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

                // ➤ BOTÃO "Esqueceu a sua password?"
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Aqui podes adicionar reset de password
                    },
                    child: const Text(
                      'Esqueceu a sua password?',
                      style: TextStyle(color: Color(0xFF1F6036)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // BOTÃO ENTRAR
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            if (!widget.firebaseReady) {
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HomePage(),
                                  ),
                                );
                              }
                              return;
                            }

                            setState(() => _loading = true);

                            try {
                              await auth.signIn(
                                _email.text.trim(),
                                _pass.text.trim(),
                              );

                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HomePage(),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
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

                // LINK PARA REGISTAR
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
