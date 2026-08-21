import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Importamos a sessão para pegar a cor da escola!
import '../../modulos/autenticacao/apresentacao/estado/auth_provider.dart';

class AdminLayout extends ConsumerWidget {
  final Widget child;

  const AdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Recupera o usuário logado e os dados do Firebase
    final usuario = ref.watch(authProvider).value;
    
    // 2. Extrai a cor exata que você escolheu na paleta no Painel Master!
    final corEscola = usuario?.corPrimaria ?? const Color(0xFF2C3E50); // Cor padrão se algo falhar
    final nomeEscola = usuario?.nomeEscola ?? 'Domex Edu';

    final isWebDesktop = MediaQuery.of(context).size.width > 800;

    // 3. O SEGREDO: Sobrescrevemos o "Theme" do Flutter. 
    // Tudo que estiver dentro do 'child' (Tabelas, Botões, Abas) herda essa cor automaticamente!
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: corEscola,
        colorScheme: ColorScheme.fromSeed(seedColor: corEscola),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: corEscola,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      child: Scaffold(
        body: Row(
          children: [
            // MENU LATERAL DINÂMICO
            if (isWebDesktop)
              Container(
                width: 260,
                color: corEscola, // A mágica visual acontece aqui no fundo do menu!
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    
                    // Ícone temporário da escola (Depois podemos trocar pela logo em imagem real do Firebase)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.school_rounded, size: 40, color: corEscola),
                    ),
                    const SizedBox(height: 16),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        nomeEscola,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    const Text('Painel de Gestão', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 32),
                    const Divider(color: Colors.white24),
                    
                    _MenuItem(
                      icone: Icons.dashboard_rounded,
                      titulo: 'Visão Geral',
                      onTap: () => context.go('/admin'),
                    ),
                    _MenuItem(
                      icone: Icons.folder_shared_rounded,
                      titulo: 'Cadastros Base',
                      onTap: () => context.go('/admin/cadastros'),
                    ),
                    _MenuItem(
                      icone: Icons.receipt_long_rounded,
                      titulo: 'Financeiro & Boletos',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo Financeiro em breve!')));
                      },
                    ),
                    
                    const Spacer(),
                    const Divider(color: Colors.white24),
                    _MenuItem(
                      icone: Icons.exit_to_app_rounded,
                      titulo: 'Sair do Sistema',
                      onTap: () {
                        // Limpa a sessão e volta pro login
                        ref.read(authProvider.notifier).fazerLogout();
                        context.go('/login');
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              
            // ÁREA DE CONTEÚDO DA ESCOLA (O "child")
            Expanded(
              child: Container(
                color: Colors.grey.shade50,
                child: child,
              ),
            ),
          ],
        ),
        
        // BOTTOM NAVIGATION PARA CELULARES
        bottomNavigationBar: isWebDesktop ? null : BottomNavigationBar(
          selectedItemColor: corEscola,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Início'),
            BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Cadastros'),
          ],
          onTap: (index) {
            if (index == 0) context.go('/admin');
            if (index == 1) context.go('/admin/cadastros');
          },
        ),
      ),
    );
  }
}

// Widget utilitário para os botões do menu lateral
class _MenuItem extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final VoidCallback onTap;

  const _MenuItem({required this.icone, required this.titulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // CORREÇÃO: O Material transparente permite o clique sem travar a tela
    return Material(
      color: Colors.transparent, 
      child: ListTile(
        leading: Icon(icone, color: Colors.white70),
        title: Text(titulo, style: const TextStyle(color: Colors.white70)),
        hoverColor: Colors.white10,
        onTap: onTap,
      ),
    );
  }
}