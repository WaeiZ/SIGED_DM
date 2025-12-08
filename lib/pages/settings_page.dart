import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool modoEscuro = false;
  bool notificacoes = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Volta para a página de perfil
          },
        ),
        title: const Text(
          'Definições',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1F6036),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // Modo Escuro
          Container(
            color: Colors.white,
            child: _buildSwitchTile(
              title: 'Modo Escuro',
              value: modoEscuro,
              onChanged: (value) {
                setState(() {
                  modoEscuro = value;
                });
              },
            ),
          ),
          const Divider(height: 1),
          // Notificações
          Container(
            color: Colors.white,
            child: _buildSwitchTile(
              title: 'Notificações',
              value: notificacoes,
              onChanged: (value) {
                setState(() {
                  notificacoes = value;
                });
              },
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Sobre o SIGED
          Container(
            color: Colors.white,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Icon(Icons.info_outline, size: 20),
              ),
              title: const Text(
                'Sobre o SIGED',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text('Versão 2.0.0', style: TextStyle(fontSize: 14)),
                  Text(
                    'Sistema Inteligente de Gestão de Energia Doméstica',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              onTap: () {
                _mostrarSobreDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF1F6036),
      ),
    );
  }

  void _mostrarSobreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sobre o SIGED'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versão 2.0.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Sistema Inteligente de Gestão de Energia Doméstica'),
              SizedBox(height: 16),
              Text(
                'Desenvolvido para monitorizar e otimizar o consumo de energia na tua casa.',
                style: TextStyle(fontSize: 14),
              ),
            ],
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
  }
}
