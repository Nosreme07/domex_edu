import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../autenticacao/apresentacao/estado/auth_provider.dart';

class ResponsavelLayout extends ConsumerStatefulWidget {
  final Widget child;

  const ResponsavelLayout({super.key, required this.child});

  @override
  ConsumerState<ResponsavelLayout> createState() => _ResponsavelLayoutState();
}

class _ResponsavelLayoutState extends ConsumerState<ResponsavelLayout> {
  Color _converterHexParaColor(String? hex, Color corPadrao) {
    if (hex == null || hex.isEmpty) return corPadrao;
    try {
      String cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return corPadrao;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).value;
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    
    final tenantId = usuario?.tenantId;
    final nomeSessao = usuario?.nomeEscola ?? 'ESCOLA NÃO CONFIGURADA';

    if (tenantId == null || tenantId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).snapshots(),
      builder: (context, snapshot) {
        
        Color corResponsavel = Colors.blue.shade700; // Cor padrão caso falhe
        String nomeEscola = nomeSessao;
        String? logoEscola;

        if (snapshot.hasData && snapshot.data!.exists) {
          final dados = snapshot.data!.data() as Map<String, dynamic>?;
          if (dados != null) {
            corResponsavel = _converterHexParaColor(dados['corPrimaria'] ?? dados['corHex'], corResponsavel);
            logoEscola = dados['logoUrl'] ?? dados['fotoUrl'] ?? dados['logo'];
            if (dados['nomeEscola'] != null && dados['nomeEscola'].toString().isNotEmpty) {
              nomeEscola = dados['nomeEscola'];
            }
          }
        }

        final logoWidget = logoEscola != null && logoEscola.isNotEmpty
            ? Container(
                width: 64, height: 64, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white,
                  border: Border.all(color: Colors.white.withAlpha(100), width: 2),
                  image: DecorationImage(image: NetworkImage(logoEscola), fit: BoxFit.contain),
                ),
              )
            : Container(
                width: 60, height: 60, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white.withAlpha(50), shape: BoxShape.circle),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 36),
              );

        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: corResponsavel,
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: corResponsavel, secondary: corResponsavel),
          ),
          child: Scaffold(
            appBar: isMobile
                ? AppBar(
                    title: const Text('Portal da Família', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    backgroundColor: corResponsavel, foregroundColor: Colors.white, elevation: 1,
                  )
                : null,
            drawer: isMobile
                ? Drawer(backgroundColor: corResponsavel, child: _buildDrawerContent(context, corResponsavel, nomeEscola, logoWidget))
                : null,
            body: Row(
              children: [
                if (!isMobile)
                  Container(width: 250, color: corResponsavel, child: _buildDrawerContent(context, corResponsavel, nomeEscola, logoWidget)),
                Expanded(child: Container(color: Colors.grey.shade50, child: widget.child)),
              ],
            ),
          ),
        );
      },
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
                logoWidget,
                Text(
                  nomeEscola.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text('PORTAL DA FAMÍLIA', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ),
        ),
        _buildMenuItem(context, Icons.dashboard_rounded, 'Painel Inicial', '/responsavel'),
        _buildMenuItem(context, Icons.payments_rounded, 'Financeiro', '/responsavel/financeiro'),
        
        const Spacer(),
        const Divider(color: Colors.white24, height: 1),
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