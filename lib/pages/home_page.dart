//Martim Santos - 22309746
//Sérgio Dias - 22304791

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import 'comparison_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Erro: Utilizador não autenticado')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get(),
      builder: (context, snapshot) {
        // Enquanto carrega
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1F6036)),
            ),
          );
        }

        // Extrai os dados do Firestore
        String nomeUtilizador = 'User';
        String emailUtilizador = currentUser.email ?? 'user@example.com';

        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          nomeUtilizador =
              data?['name'] ?? currentUser.email?.split('@').first ?? 'User';
        } else {
          nomeUtilizador = currentUser.email?.split('@').first ?? 'User';
        }

        // Cria as páginas com os dados corretos
        final List<Widget> pages = [
          DashboardPage(userId: currentUser.uid),
          ComparisonPage(userId: currentUser.uid),
          ProfilePage(
            nome: nomeUtilizador,
            email: emailUtilizador,
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
                label: 'Histórico',
              ),
              NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        );
      },
    ); // ← Fecha o FutureBuilder
  }
}
