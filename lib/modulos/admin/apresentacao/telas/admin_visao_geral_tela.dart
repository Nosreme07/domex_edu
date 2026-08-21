import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importamos o provedor para pegar os dados da escola logada
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class AdminVisaoGeralTela extends ConsumerWidget {
  const AdminVisaoGeralTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).value;
    final corEscola = usuario?.corPrimaria ?? Theme.of(context).primaryColor;
    final nomeEscola = usuario?.nomeEscola ?? 'Escola';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bem-vindo(a) à gestão do $nomeEscola',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: corEscola),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aqui está o resumo atualizado do seu ambiente.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 32),

          // KPIs (Indicadores) ZERADOS para uma nova escola
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                crossAxisCount: constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1),
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                children: [
                  _DashboardCard(
                    titulo: 'Alunos Matriculados',
                    valor: '0', // Zerado!
                    icone: Icons.school_rounded,
                    cor: Colors.blue.shade700,
                  ),
                  _DashboardCard(
                    titulo: 'Turmas Ativas',
                    valor: '0', // Zerado!
                    icone: Icons.meeting_room_rounded,
                    cor: Colors.orange.shade700,
                  ),
                  _DashboardCard(
                    titulo: 'Professores',
                    valor: '0', // Zerado!
                    icone: Icons.assignment_ind_rounded,
                    cor: Colors.green.shade700,
                  ),
                  _DashboardCard(
                    titulo: 'Inadimplência',
                    valor: '0%', // Zerado!
                    icone: Icons.warning_rounded,
                    cor: Colors.red.shade700,
                  ),
                ],
              );
            }
          ),
          
          const SizedBox(height: 48),
          
          // Área de Acesso Rápido ou Avisos (Pronta para uso real)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'Seu ambiente está pronto!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Comece cadastrando suas Turmas e em seguida matricule os Alunos.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget isolado para os cartões de resumo
class _DashboardCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;

  const _DashboardCard({
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: cor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    valor,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}