//Martim Santos - 22309746
//Sérgio Dias - 22304791

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dashboard_page.dart';
import 'comparison_page.dart';
import 'profile_page.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Obtém o utilizador autenticado
    final currentUser = FirebaseAuth.instance.currentUser;
    final auth = context.watch<AuthService>();

    // Se não houver utilizador autenticado, mostra erro
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Erro: Utilizador não autenticado')),
      );
    }

    // Cria as páginas com os dados corretos do utilizador
    final List<Widget> pages = [
      const DashboardPage(),
      ComparisonPage(userId: currentUser.uid), // ← UID real!
      ProfilePage(
        nome: currentUser.displayName ?? 'User Name',
        email: currentUser.email ?? 'user@example.com',
        firebaseReady: true,
      ),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Comparação',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
