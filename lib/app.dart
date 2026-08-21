import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Import da nossa configuração central de rotas
import 'nucleo/rotas/app_rotas.dart';

/// Ponto central da Plataforma Domex Edu.
/// É aqui que injetamos o Design System e configuramos a navegação global.
class DomexEduApp extends StatelessWidget {
  const DomexEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------------------------------
    // [1] CONFIGURAÇÃO MULTI-TENANT (Tema Dinâmico)
    // ------------------------------------------------------------------------
    // No estado final da arquitetura, estas cores NÃO devem ser fixas.
    // O Riverpod deverá escutar o "TenantState" injetado pelo subdomínio (Web)
    // ou pelo código da escola digitado pelo usuário (Mobile) no login.
    //
    // Por enquanto, utilizamos a paleta base definida: Modern Emerald & Cream.
    const Color corPrimaria = Color(0xFF064E3B); // Dark Emerald
    const Color corFundo = Color(0xFFF8E7C9);    // Cream

    return MaterialApp.router(
      title: 'Domex Edu Workspace',
      debugShowCheckedModeBanner: false,
      
      // ------------------------------------------------------------------------
      // [2] DESIGN SYSTEM (Material 3)
      // ------------------------------------------------------------------------
      // As definições visuais aqui se propagam por todo o sistema.
      // Modificações feitas neste bloco afetam todos os botões, cards e headers.
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: corPrimaria,
        scaffoldBackgroundColor: corFundo,
        
        // Estilização global da AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: corPrimaria,
          foregroundColor: corFundo, // Cor do título e ícones na barra
          elevation: 0,
          centerTitle: true,
        ),
        
        // Estilização global dos Call-to-Actions (Botões)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: corPrimaria,
            foregroundColor: corFundo, // Cor do texto
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        
        // Estilização global de Cards (Utilizados em murais de avisos, dashboards, etc)
        // Nota técnica: Utilizando CardThemeData conforme exigência do SDK recente
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      
      // ------------------------------------------------------------------------
      // [3] GESTÃO DE ROTAS (GoRouter)
      // ------------------------------------------------------------------------
      // Delegamos o controle de navegação para a classe AppRotas.
      // Isso habilita navegação por URL profunda (Deep Linking) e Web Subdomains.
      routerConfig: AppRotas.router, 
    );
  }
}

// ----------------------------------------------------------------------------
// [WIDGET TEMPORÁRIO] TELA INICIAL (SPLASH)
// ----------------------------------------------------------------------------
// Este widget simula o ponto de partida do aplicativo. 
// Em produção, ele geralmente é substituído por uma validação silenciosa (Splash Screen)
// que verifica se há um token JWT salvo no dispositivo e decide se vai para Login ou Home.
class TelaInicialDomex extends StatelessWidget {
  const TelaInicialDomex({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Domex Edu Workspace'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Identidade Visual Básica
            const Icon(
              Icons.school_rounded,
              size: 80,
              color: Color(0xFF064E3B), // Primary hardcoded temporariamente no ícone
            ),
            const SizedBox(height: 24),
            
            // Texto adaptável que obedece à cor primária do Tema ativo
            Text(
              'Bem-vindo ao Domex Edu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            
            const Text(
              'Plataforma de Gestão Escolar B2B',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),
            
            // Botão de acesso acionando o GoRouter para a tela de Login
            ElevatedButton(
              onPressed: () {
                // Utilizando a engine do GoRouter para navegar de forma limpa.
                // Isso modificará a URL na WEB para '/login'.
                context.go('/login');
              },
              child: const Text('Acessar Sistema'),
            ),
          ],
        ),
      ),
    );
  }
}