import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfessorLayout extends StatelessWidget {
  final Widget child;
  const ProfessorLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Cor exclusiva para o painel do Professor (Verde/Teal) para não confundir com o Admin
    final corProfessor = Colors.teal.shade700;
    
    // VARIÁVEL MÁGICA: Verifica se a tela é de um celular (menor que 800 pixels de largura)
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      // Se for celular, mostra a barra superior com o botão do Menu Sanduíche
      appBar: isMobile
          ? AppBar(
              title: const Text('Portal do Professor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              backgroundColor: corProfessor,
              foregroundColor: Colors.white,
              elevation: 1,
            )
          : null,
          
      // Se for celular, o menu vira uma gaveta deslizante (Drawer)
      drawer: isMobile
          ? Drawer(
              child: _MenuLateralConteudo(corProfessor: corProfessor, isMobile: true),
            )
          : null,
          
      body: isMobile
          ? Container(
              color: Colors.grey.shade50,
              child: child, // Tela 100% livre para o conteúdo no celular
            )
          : Row(
              children: [
                // ================= MENU LATERAL FIXO (Para PC/Tablet) =================
                SizedBox(
                  width: 250,
                  child: _MenuLateralConteudo(corProfessor: corProfessor, isMobile: false),
                ),
                
                // ================= ÁREA CENTRAL (A TELA EM SI) =================
                Expanded(
                  child: Container(
                    color: Colors.grey.shade50,
                    child: child, // Aqui o Flutter injeta a Dashboard, Diário, etc.
                  ),
                ),
              ],
            ),
    );
  }
}

// Transformamos o conteúdo do menu em um Widget separado para reaproveitar
// tanto na barra lateral do PC quanto na gaveta do Celular!
class _MenuLateralConteudo extends StatelessWidget {
  final Color corProfessor;
  final bool isMobile;

  const _MenuLateralConteudo({required this.corProfessor, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: corProfessor,
      // SafeArea protege o menu para não ficar escondido atrás do relógio/câmera do celular
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // LOGO / IDENTIFICAÇÃO
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Portal do Professor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Domex Edu', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 32),
            
            // OPÇÕES DO MENU
            _MenuItem(
              icone: Icons.dashboard_rounded,
              titulo: 'Painel Inicial',
              rota: '/professor',
              rotaAtual: GoRouterState.of(context).matchedLocation,
              isMobile: isMobile,
            ),
            _MenuItem(
              icone: Icons.class_rounded,
              titulo: 'Minhas Turmas',
              rota: '/professor/turmas',
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
                // Se for celular, fecha o Drawer antes de sair
                if (isMobile) Navigator.pop(context); 
                // Limpa a navegação e volta pro Login
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

// Widget auxiliar para os botões do menu ficarem bonitos
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
          // No celular, fecha o menu automaticamente após clicar em uma opção
          if (isMobile) {
            Navigator.pop(context);
          }
          if (!isSelecionado) context.go(rota);
        },
      ),
    );
  }
}