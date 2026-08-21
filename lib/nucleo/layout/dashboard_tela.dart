import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Importamos o nosso provedor de autenticação atualizado
import '../../modulos/autenticacao/apresentacao/estado/auth_provider.dart';

class DashboardTela extends ConsumerWidget {
  const DashboardTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Recupera os dados do usuário logado (Professor)
    final usuario = ref.watch(authProvider).value;
    
    // 2. Define a cor do app baseada na escola do usuário logado
    final corPrimaria = usuario?.corPrimaria ?? Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: corPrimaria, 
        foregroundColor: Colors.white,
        title: Text(usuario?.nomeEscola ?? 'Domex Edu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              // Limpa o estado de autenticação (Resolvemos o TODO!)
              ref.read(authProvider.notifier).fazerLogout();
              context.go('/login');
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // Usa o nome real do professor que logou!
                'Olá, ${usuario?.nome ?? 'Professor(a)'}!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: corPrimaria,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O que você deseja gerenciar hoje?',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),

              // Grid Responsivo para os Módulos do Sistema
              LayoutBuilder(
                builder: (context, constraints) {
                  // Ajusta a quantidade de colunas baseado no tamanho da tela
                  int colunas = constraints.maxWidth > 600 ? 3 : 2;

                  return GridView.count(
                    crossAxisCount: colunas,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true, // Necessário dentro de um ScrollView
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _ModuloCard(
                        titulo: 'Diário de\nClasse',
                        icone: Icons.fact_check_rounded,
                        cor: corPrimaria,
                        onTap: () {
                          // Navega para o diário passando o ID de uma turma fictícia para teste
                          context.push('/diario/turma_101');
                        },
                      ),
                      _ModuloCard(
                        titulo: 'Mural de\nAvisos',
                        icone: Icons.campaign_rounded,
                        cor: Colors.orange.shade700,
                        onTap: () {
                          context.push('/mural');
                        },
                      ),
                      _ModuloCard(
                        titulo: 'Boletim &\nNotas',
                        icone: Icons.school_rounded,
                        cor: Colors.blue.shade700,
                        onTap: () {},
                      ),
                      _ModuloCard(
                        titulo: 'Meu\nPerfil',
                        icone: Icons.person_rounded,
                        cor: Colors.grey.shade700,
                        onTap: () {},
                      ),
                    ],
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Componente Visual Isolado para os botões do Menu
class _ModuloCard extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final Color cor;
  final VoidCallback onTap;

  const _ModuloCard({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 40, color: cor),
              const SizedBox(height: 12),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}