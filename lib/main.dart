import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/auth_service.dart';
import 'services/iot_service.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseReady = true;
  try {
    await Firebase.initializeApp();
  } catch (_) {
    firebaseReady = false;
  }
  runApp(SIGEDApp(firebaseReady: firebaseReady));
}

class SIGEDApp extends StatelessWidget {
  final bool firebaseReady;
  const SIGEDApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(isAvailable: firebaseReady)),
        Provider<IoTService>(create: (_) => IoTService.demo()..start()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SIGED',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F80ED), brightness: Brightness.light),
          useMaterial3: true,
        ),
        home: AuthGate(firebaseReady: firebaseReady),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final bool firebaseReady;
  const AuthGate({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!firebaseReady && kIsWeb) {
      return const _DemoModeScreen();
    }
    return StreamBuilder(
      stream: auth.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) return const HomePage();
        return LoginPage(firebaseReady: firebaseReady);
      },
    );
  }
}

class _DemoModeScreen extends StatelessWidget {
  const _DemoModeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SIGED (Demo Mode)')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Firebase não configurado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Corre "flutterfire configure" para ligar ao Firebase.'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomePage())),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Continuar em modo Demo'),
            )
          ],
        ),
      ),
    );
  }
}
