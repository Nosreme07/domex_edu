import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ============================================================================
// LAYOUT BASE DO SUPER ADMIN (DONO DO SAAS)
// Este layout envolve as telas do Master, garantindo que o menu escuro 
// apareça fixo na lateral, isolando visualmente da área das escolas.
// ============================================================================
class SuperAdminLayout extends StatelessWidget {
  final Widget child;

  const SuperAdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Cor oficial do Domex Edu Master (Branding da Empresa Mãe)
    const corMaster = Color(0xFF080E1C); 
    
    // Controle de responsividade
    final isWebDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          // ==================================================================
          // MENU LATERAL (SIDEBAR) - Visível apenas em Telas Grandes
          // ==================================================================
          if (isWebDesktop)
            Container(
              width: 260,
              color: corMaster,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  
                  // Logo da Domex Edu (Dona do SaaS)
                  Image.asset(
                    'assets/2.png',
                    height: 56, 
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
                  
                  // Botões de Navegação
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
                    onTap: () {}, // Rota futura para listar apenas as escolas
                  ),
                  _MenuItem(
                    icone: Icons.account_balance_wallet_rounded,
                    titulo: 'Faturamento Domex',
                    onTap: () {}, // Rota futura do financeiro do SaaS
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
            
          // ==================================================================
          // ÁREA DE CONTEÚDO PRINCIPAL (Telas injetadas via Router)
          // ==================================================================
          Expanded(
            child: Container(
              color: Colors.grey.shade100, 
              child: child, // Aqui entra o dashboard, usuarios, etc.
            ),
          ),
        ],
      ),
      
      // ==================================================================
      // MENU INFERIOR (BOTTOM BAR) - Visível apenas em Celulares
      // ==================================================================
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

// ============================================================================
// WIDGET UTILITÁRIO: BOTÃO DO MENU LATERAL
// ============================================================================
class _MenuItem extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final VoidCallback onTap;

  const _MenuItem({required this.icone, required this.titulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // O Material transparente com o InkWell (via ListTile) cria o efeito 
    // de clique correto no Flutter Web sem bugar a renderização
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