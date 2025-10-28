import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool darkMode = false;
  bool notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Modo Escuro'),
            value: darkMode,
            onChanged: (v) => setState(() => darkMode = v),
          ),
          SwitchListTile(
            title: const Text('Notificações'),
            value: notifications,
            onChanged: (v) => setState(() => notifications = v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre o SIGED'),
            subtitle: const Text('Versão 2.0.0\nSistema Inteligente de Gestão de Energia Doméstica'),
          ),
        ],
      ),
    );
  }
}
