import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- NOVO IMPORT

// Importamos a sessão para saber qual usuário/escola está acessando
import '../../modulos/autenticacao/apresentacao/estado/auth_provider.dart';

class AdminLayout extends ConsumerWidget {
  final Widget child;

  const AdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Recupera o usuário logado
    final usuario = ref.watch(authProvider).value;
    
    // Se o sistema ainda estiver checando o login, mostra um carregamento
    if (usuario == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isWebDesktop = MediaQuery.of(context).size.width > 800;

    // ========================================================================
    // A MÁGICA DO TEMPO REAL: Ouvimos a pasta dessa escola específica no Firebase!
    // Sempre que ela salvar uma cor ou logo nas Configurações, isso aqui reage na hora.
    // ========================================================================
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('tenants').doc(usuario.id).snapshots(),
      builder: (context, snapshot) {
        
        // Valores Padrão (Caso seja o primeiro acesso)
        Color corEscola = const Color(0xFF2C3E50); 
        String nomeEscola = 'Domex Edu';
        String? logoUrl;

        // Se os dados chegaram do Firebase, nós extraímos e aplicamos!
        if (snapshot.hasData && snapshot.data!.data() != null) {
          final dados = snapshot.data!.data() as Map<String, dynamic>;
          
          nomeEscola = dados['nomeEscola'] ?? dados['nome'] ?? 'Domex Edu';
          logoUrl = dados['logoUrl'] ?? dados['fotoUrl'] ?? dados['logo'];

          // Lógica forte para garantir que a cor HEX não quebre o Flutter
          final corStr = dados['corPrimaria'] ?? dados['corHex'] ?? '';
          if (corStr.isNotEmpty) {
            try {
              String cleanHex = corStr.replaceAll('#', '');
              if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
              corEscola = Color(int.parse(cleanHex, radix: 16));
            } catch (_) {}
          }
        }

        // ====================================================================
        // O SEGREDO DO TEMA: Sobrescrevemos as cores do aplicativo aqui
        // ====================================================================
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
                    color: corEscola, // A cor do fundo muda em tempo real!
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        
                        // LOGO DA ESCOLA (Substitui o ícone antigo!)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10)],
                            image: logoUrl != null 
                              ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover) 
                              : null,
                          ),
                          // Se não tiver logo, mostra o chapeuzinho padrão
                          child: logoUrl == null 
                            ? Icon(Icons.school_rounded, size: 40, color: corEscola) 
                            : null,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            nomeEscola, // Nome muda em tempo real!
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
                        
                        // === BOTÃO DE CONFIGURAÇÕES ===
                        _MenuItem(
                          icone: Icons.settings_rounded,
                          titulo: 'Configurações',
                          onTap: () => context.go('/admin/configuracoes'),
                        ),
                        
                        const Spacer(),
                        const Divider(color: Colors.white24),
                        _MenuItem(
                          icone: Icons.exit_to_app_rounded,
                          titulo: 'Sair do Sistema',
                          onTap: () {
                            ref.read(authProvider.notifier).fazerLogout();
                            context.go('/login');
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  
                // ÁREA DE CONTEÚDO DA ESCOLA (Telas)
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
              selectedItemColor: corEscola, // Fica na cor da escola também!
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Início'),
                BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Cadastros'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Configurações'),
              ],
              onTap: (index) {
                if (index == 0) context.go('/admin');
                if (index == 1) context.go('/admin/cadastros');
                if (index == 2) context.go('/admin/configuracoes');
              },
            ),
          ),
        );
      }
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