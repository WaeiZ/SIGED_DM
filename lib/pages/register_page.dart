import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
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
                                name: _name.text.trim(), // <-- NOME AQUI
                              );

                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
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
