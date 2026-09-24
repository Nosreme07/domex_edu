import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../autenticacao/apresentacao/estado/auth_provider.dart';

class AlunoLayout extends ConsumerStatefulWidget {
  final Widget child;

  const AlunoLayout({super.key, required this.child});

  @override
  ConsumerState<AlunoLayout> createState() => _AlunoLayoutState();
}

class _AlunoLayoutState extends ConsumerState<AlunoLayout> {
  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).value;
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    
    // Cor dinâmica da escola!
    final corPrimaria = usuario?.corPrimaria ?? Theme.of(context).primaryColor;
    final nomeEscola = usuario?.nomeEscola ?? 'ESCOLA DOMEX';
    final tenantId = usuario?.tenantId;

    // =========================================================================
    // WIDGET INTELIGENTE DA LOGO (Busca a imagem da escola no Banco de Dados)
    // =========================================================================
    final logoWidget = tenantId == null 
      ? _buildLogoPadrao() 
      : FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('tenants').doc(tenantId).get(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              // Busca os nomes comuns de campos de logo que usamos no sistema
              final String? logoUrl = data['logoUrl'] ?? data['fotoUrl'] ?? data['logo'];
              
              if (logoUrl != null && logoUrl.isNotEmpty) {
                return Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white.withAlpha(100), width: 2),
                    image: DecorationImage(
                      image: NetworkImage(logoUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }
            }
            // Se a escola ainda não fez upload de logo, mostra o chapéu padrão
            return _buildLogoPadrao();
          },
        );

    return Scaffold(
      drawer: isMobile
          ? Drawer(
              backgroundColor: corPrimaria,
              child: _buildDrawerContent(context, corPrimaria, nomeEscola, logoWidget),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            Container(
              width: 250,
              color: corPrimaria,
              child: _buildDrawerContent(context, corPrimaria, nomeEscola, logoWidget),
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  // Chapéu de formatura caso não haja imagem
  Widget _buildLogoPadrao() {
    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(50),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.school_rounded, color: Colors.white, size: 36),
    );
  }

  Widget _buildDrawerContent(BuildContext context, Color corPrimaria, String nomeEscola, Widget logoWidget) {
    return Column(
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: corPrimaria),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                logoWidget, // A logo carregada entra aqui!
                Text(
                  nomeEscola.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        _buildMenuItem(context, Icons.dashboard_rounded, 'Painel Inicial', '/aluno'),
        _buildMenuItem(context, Icons.analytics_rounded, 'Meu Boletim', '/aluno/boletim'),
        _buildMenuItem(context, Icons.fact_check_rounded, 'Frequência Escolar', '/aluno/frequencia'),
        _buildMenuItem(context, Icons.calendar_month_rounded, 'Calendário de Aulas', '/aluno/calendario'),
        const Spacer(),
        ListTile(
          leading: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
          title: const Text('Sair do Sistema', style: TextStyle(color: Colors.white)),
          onTap: () async {
            await ref.read(authProvider.notifier).fazerLogout();
            if (context.mounted) context.go('/');
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String route) {
    final String currentRoute = GoRouterState.of(context).uri.toString();
    final bool isSelected = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selectedTileColor: Colors.white.withAlpha(30),
        selected: isSelected,
        leading: Icon(icon, color: Colors.white, size: 22),
        title: Text(title, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
        onTap: () {
          if (MediaQuery.of(context).size.width < 800) Navigator.pop(context);
          context.go(route);
        },
      ),
    );
  }
}