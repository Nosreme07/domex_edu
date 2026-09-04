import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

// O caminho correto para achar o arquivo de autenticação!
import '../../../autenticacao/apresentacao/estado/auth_provider.dart'; 

// ============================================================================
// PROVIDER: BUSCA AS TURMAS DA ESCOLA DO PROFESSOR LOGADO
// ============================================================================
final turmasDoProfessorProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authState = ref.watch(authProvider).value;
  if (authState == null) return [];

  final db = FirebaseFirestore.instance;

  // 1. Descobre o tenantId (escolaId) do professor atual
  final userSnap = await db.collection('usuarios').where('email', isEqualTo: authState.email).get();
  if (userSnap.docs.isEmpty) return [];

  final dadosUser = userSnap.docs.first.data();
  final tenantId = dadosUser['tenantId'] ?? dadosUser['escolaId'];
  if (tenantId == null) return [];

  // 2. Busca todas as turmas cadastradas e ativas dessa escola
  final turmasSnap = await db.collection('tenants')
      .doc(tenantId)
      .collection('turmas')
      .where('status', isNotEqualTo: 'Inativa')
      .get();

  return turmasSnap.docs.map((doc) => doc.data()).toList();
});


class ProfessorDashboardTela extends ConsumerWidget {
  const ProfessorDashboardTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Puxa os dados de sessão e as turmas
    final usuario = ref.watch(authProvider).value;
    final estadoTurmas = ref.watch(turmasDoProfessorProvider);
    
    // Cor padrão do portal do professor
    final corProfessor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Painel de Aulas', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================== CABEÇALHO DE BOAS-VINDAS ==================
            Text(
              'Olá, Prof. ${usuario?.nome.split(' ').first ?? ''}!', 
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: corProfessor)
            ),
            const SizedBox(height: 8),
            Text(
              'Bem-vindo(a) ao seu diário de classe digital. Selecione uma turma abaixo para iniciar.', 
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700)
            ),
            const SizedBox(height: 32),
            
            // ================== LISTAGEM DE TURMAS ==================
            const Text('Minhas Turmas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const Divider(),
            const SizedBox(height: 16),

            Expanded(
              child: estadoTurmas.when(
                loading: () => Center(child: CircularProgressIndicator(color: corProfessor)),
                error: (e, stack) => Center(child: Text('Erro ao carregar turmas: $e')),
                data: (turmas) {
                  if (turmas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded, size: 80, color: Colors.teal.shade200),
                          const SizedBox(height: 16),
                          Text('Nenhuma turma alocada para você no momento.', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Text('Procure a secretaria para realizar a vinculação.', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Responsividade corrigida
                      int colunas = 1;
                      if (constraints.maxWidth > 1100) {
                        colunas = 3;
                      } else if (constraints.maxWidth > 700) {
                        colunas = 2;
                      }

                      return GridView.builder(
                        itemCount: turmas.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: colunas,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: 2.2, // Proporção dos cards
                        ),
                        itemBuilder: (context, index) {
                          final turma = turmas[index];
                          return _TurmaCard(turma: turma, corTema: corProfessor);
                        },
                      );
                    }
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENTE: CARD DA TURMA
// ============================================================================
class _TurmaCard extends StatelessWidget {
  final Map<String, dynamic> turma;
  final Color corTema;

  const _TurmaCard({required this.turma, required this.corTema});

  @override
  Widget build(BuildContext context) {
    final nomeTurma = turma['nome'] ?? 'Turma';
    final anoLetivo = turma['anoLetivo'] ?? DateTime.now().year.toString();
    final turno = turma['turno'] ?? 'N/A';
    final sala = turma['sala'] ?? 'Sem Sala';
    final idTurma = turma['id'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navega para a tela do Diário passando o ID da turma pela URL
            context.push('/diario/$idTurma');
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: corTema.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.class_rounded, color: corTema, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nomeTurma, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('Ano Letivo: $anoLetivo', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(turno, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                    
                    const SizedBox(width: 16),
                    
                    Icon(Icons.meeting_room_outlined, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('Sala $sala', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                    
                    const Spacer(),
                    
                    // Botão visual para indicar a ação
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: corTema, borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        children: [
                          Text('Abrir Diário', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}