import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../autenticacao/apresentacao/estado/auth_provider.dart';

class ProfessorLayout extends ConsumerWidget {
  final Widget child;
  const ProfessorLayout({super.key, required this.child});

  // Função auxiliar para converter o Hex Decimal do Firebase em Cor do Flutter
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
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioLogado = ref.watch(authProvider).value;
    final tenantId = usuarioLogado?.id;
    final nomeSessao = usuarioLogado?.nomeEscola ?? 'ESCOLA NÃO CONFIGURADA';
    
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (tenantId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ========================================================================
    // BUSCA OS DADOS GLOBAIS DA ESCOLA (COR, LOGO E NOME) EM TEMPO REAL
    // ========================================================================
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).snapshots(),
      builder: (context, snapshot) {
        
        // Valores Padrão (Fallback caso não carregue a tempo)
        Color corProfessor = Colors.teal.shade700;
        String nomeEscola = nomeSessao;
        String? logoEscola;

        if (snapshot.hasData && snapshot.data!.exists) {
          final dados = snapshot.data!.data() as Map<String, dynamic>?;
          if (dados != null) {
            // 1. Pega a cor primária exata que a administração escolheu
            corProfessor = _converterHexParaColor(dados['corPrimaria'] ?? dados['corHex'], corProfessor);
            
            // 2. Pega a Logo enviada
            logoEscola = dados['logoUrl'] ?? dados['fotoUrl'] ?? dados['logo'];
            
            // 3. Pega o Nome atualizado
            if (dados['nomeEscola'] != null && dados['nomeEscola'].toString().isNotEmpty) {
              nomeEscola = dados['nomeEscola'];
            }
          }
        }

        // A GRANDE MÁGICA: Sobrescreve o tema do Flutter!
        // Ao invés de azul, todas as telas filhas (Dashboard, Calendario, Perfil)
        // vão usar automaticamente a cor primária que veio do Firebase (Laranja).
        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: corProfessor,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: corProfessor,
              secondary: corProfessor,
            ),
          ),
          child: Scaffold(
            appBar: isMobile
                ? AppBar(
                    title: const Text('Portal do Professor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    backgroundColor: corProfessor,
                    foregroundColor: Colors.white,
                    elevation: 1,
                  )
                : null,
                
            drawer: isMobile
                ? Drawer(
                    child: _MenuLateralConteudo(
                      corProfessor: corProfessor, 
                      isMobile: true,
                      nomeEscola: nomeEscola,
                      logoEscola: logoEscola,
                    ),
                  )
                : null,
                
            body: isMobile
                ? Container(
                    color: Colors.grey.shade50,
                    child: child, 
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 250,
                        child: _MenuLateralConteudo(
                          corProfessor: corProfessor, 
                          isMobile: false,
                          nomeEscola: nomeEscola,
                          logoEscola: logoEscola,
                        ),
                      ),
                      
                      Expanded(
                        child: Container(
                          color: Colors.grey.shade50,
                          child: child, 
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _MenuLateralConteudo extends StatelessWidget {
  final Color corProfessor;
  final bool isMobile;
  final String nomeEscola;
  final String? logoEscola;

  const _MenuLateralConteudo({
    required this.corProfessor, 
    required this.isMobile,
    required this.nomeEscola,
    required this.logoEscola,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: corProfessor,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // ====================================================================
            // LOGO E NOME DA ESCOLA (100% DINÂMICO)
            // ====================================================================
            if (logoEscola != null && logoEscola!.isNotEmpty)
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white, // Fundo branco para destacar imagens transparentes
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2), // Borda elegante
                  image: DecorationImage(
                    image: NetworkImage(logoEscola!),
                    fit: BoxFit.contain, 
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 48),
              ),
              
            const SizedBox(height: 16),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                nomeEscola.toUpperCase(), 
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'PORTAL DO PROFESSOR', 
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // ====================================================================
            // OPÇÕES DO MENU
            // ====================================================================
            _MenuItem(
              icone: Icons.dashboard_rounded,
              titulo: 'Painel Inicial',
              rota: '/professor',
              rotaAtual: GoRouterState.of(context).matchedLocation,
              isMobile: isMobile,
            ),
            _MenuItem(
              icone: Icons.calendar_month_rounded,
              titulo: 'Calendário Escolar',
              rota: '/professor/calendario',
              rotaAtual: GoRouterState.of(context).matchedLocation,
              isMobile: isMobile,
            ),
            _MenuItem(
              icone: Icons.person_rounded,
              titulo: 'Meu Perfil',
              rota: '/professor/perfil',
              rotaAtual: GoRouterState.of(context).matchedLocation,
              isMobile: isMobile,
            ),
            
            const Spacer(),
            const Divider(color: Colors.white24, height: 1),
            
            // BOTÃO DE SAIR
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.white70),
              title: const Text('Sair do Sistema', style: TextStyle(color: Colors.white70)),
              onTap: () {
                if (isMobile) Navigator.pop(context); 
                context.go('/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String rota;
  final String rotaAtual;
  final bool isMobile;

  const _MenuItem({
    required this.icone, 
    required this.titulo, 
    required this.rota, 
    required this.rotaAtual,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final isSelecionado = rotaAtual == rota;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelecionado ? Colors.white.withAlpha(50) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icone, color: isSelecionado ? Colors.white : Colors.white70),
        title: Text(
          titulo,
          style: TextStyle(
            color: isSelecionado ? Colors.white : Colors.white70,
            fontWeight: isSelecionado ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          if (isMobile) {
            Navigator.pop(context);
          }
          if (!isSelecionado) context.go(rota);
        },
      ),
    );
  }
}