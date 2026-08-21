import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Importa o arquivo que você acabou de gerar
import 'nucleo/rotas/app_rotas.dart';

void main() async {
  // Garante que o Flutter esteja pronto antes de chamar o Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o Firebase com as configurações geradas
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: MeuApp(),
    ),
  );
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Domex Edu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2C3E50),
        useMaterial3: true,
      ),
      routerConfig: AppRotas.router,
    );
  }
}