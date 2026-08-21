import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SuperAdminLayout extends StatelessWidget {
  final Widget child;

  const SuperAdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Nova cor oficial Domex Edu Master (#080e1c)
    const corMaster = Color(0xFF080E1C); 
    final isWebDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          // Menu Lateral (Sidebar)
          if (isWebDesktop)
            Container(
              width: 260,
              color: corMaster,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  
                  // Nova Logo Domex Edu (Substituindo o foguete)
                  Image.asset(
                    'assets/2.png',
                    height: 56, // Altura ajustada para manter a proporção
                    fit: BoxFit.contain,
                  ),
                  
                  const SizedBox(height: 16),
                  const Text(
                    'Domex Edu',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const Text('SaaS Control Panel', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24),
                  
                  _MenuItem(
                    icone: Icons.insights_rounded,
                    titulo: 'Visão Geral (SaaS)',
                    onTap: () => context.go('/super-admin'),
                  ),
                  _MenuItem(
                    icone: Icons.admin_panel_settings_rounded,
                    titulo: 'Usuários Master',
                    onTap: () => context.go('/super-admin/usuarios'),
                  ),
                  _MenuItem(
                    icone: Icons.domain_add_rounded,
                    titulo: 'Escolas Clientes',
                    onTap: () {}, // Futura expansão
                  ),
                  _MenuItem(
                    icone: Icons.account_balance_wallet_rounded,
                    titulo: 'Faturamento Domex',
                    onTap: () {}, 
                  ),
                  
                  const Spacer(),
                  const Divider(color: Colors.white24),
                  _MenuItem(
                    icone: Icons.exit_to_app_rounded,
                    titulo: 'Sair do Master',
                    onTap: () => context.go('/login'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            
          // Área de Conteúdo Principal
          Expanded(
            child: Container(
              color: Colors.grey.shade100, 
              child: child,
            ),
          ),
        ],
      ),
      
      // Menu Inferior (BottomBar) para telas pequenas / Mobile
      bottomNavigationBar: isWebDesktop ? null : BottomNavigationBar(
        selectedItemColor: corMaster,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'SaaS'),
          BottomNavigationBarItem(icon: Icon(Icons.domain), label: 'Escolas'),
        ],
        onTap: (index) {
          if (index == 0) context.go('/super-admin');
        },
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