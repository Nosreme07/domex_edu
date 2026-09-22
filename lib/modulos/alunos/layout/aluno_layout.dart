import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// O caminho volta 3 pastas (layout -> alunos -> modulos) e entra em autenticacao
import '../../autenticacao/apresentacao/estado/auth_provider.dart';

class AlunoLayout extends ConsumerWidget {
  final Widget child;
  const AlunoLayout({super.key, required this.child});

  // Função auxiliar para converter o Hex da escola em Cor do Flutter
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
        
        Color corBase = Colors.blue.shade700; // Cor padrão caso falhe
        String nomeEscola = nomeSessao;
        String? logoEscola;

        if (snapshot.hasData && snapshot.data!.exists) {
          final dados = snapshot.data!.data() as Map<String, dynamic>?;
          if (dados != null) {
            corBase = _converterHexParaColor(dados['corPrimaria'] ?? dados['corHex'], corBase);
            logoEscola = dados['logoUrl'] ?? dados['fotoUrl'] ?? dados['logo'];
            if (dados['nomeEscola'] != null && dados['nomeEscola'].toString().isNotEmpty) {
              nomeEscola = dados['nomeEscola'];
            }
          }
        }

        // Aplica o Tema da Escola em todo o portal do aluno
        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: corBase,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: corBase,
              secondary: corBase,
            ),
          ),
          child: Scaffold(
            appBar: isMobile
                ? AppBar(
                    title: const Text('Portal do Aluno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    backgroundColor: corBase,
                    foregroundColor: Colors.white,
                    elevation: 1,
                  )
                : null,
                
            drawer: isMobile
                ? Drawer(
                    child: _MenuLateralAluno(
                      corBase: corBase, 
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
                        child: _MenuLateralAluno(
                          corBase: corBase, 
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

class _MenuLateralAluno extends StatelessWidget {
  final Color corBase;
  final bool isMobile;
  final String nomeEscola;
  final String? logoEscola;

  const _MenuLateralAluno({
    required this.corBase, 
    required this.isMobile,
    required this.nomeEscola,
    required this.logoEscola,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: corBase,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // ====================================================================
            // LOGO E NOME DA ESCOLA DINÂMICOS
            // ====================================================================
            if (logoEscola != null && logoEscola!.isNotEmpty)
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
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
              'PORTAL DO ALUNO', 
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // ====================================================================
            // OPÇÕES DO MENU DO ALUNO
            // ====================================================================
            _MenuItem(
              icone: Icons.dashboard_rounded,
              titulo: 'Painel Inicial',
              rota: '/aluno',
              rotaAtual: GoRouterState.of(context).matchedLocation,
              isMobile: isMobile,
            ),
            _MenuItem(
              icone: Icons.analytics_rounded,
              titulo: 'Meu Boletim',
              rota: '/aluno/boletim', // Vamos criar depois
              rotaAtual: GoRouterState.of(context).matchedLocation,
              isMobile: isMobile,
            ),
            _MenuItem(
              icone: Icons.fact_check_rounded,
              titulo: 'Frequência Escolar',
              rota: '/aluno/frequencia', // Vamos criar depois
              rotaAtual: GoRouterState.of(context).matchedLocation,
              isMobile: isMobile,
            ),
            _MenuItem(
              icone: Icons.calendar_month_rounded,
              titulo: 'Calendário de Aulas',
              rota: '/aluno/calendario', // Vamos criar depois
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