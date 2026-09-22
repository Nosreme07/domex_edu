import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Importamos o provedor de Autenticação para saber qual aluno está logado
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class AlunoDashboardTela extends ConsumerStatefulWidget {
  const AlunoDashboardTela({super.key});

  @override
  ConsumerState<AlunoDashboardTela> createState() => _AlunoDashboardTelaState();
}

class _AlunoDashboardTelaState extends ConsumerState<AlunoDashboardTela> {
  
  // Função para buscar os dados do aluno logado
  Future<Map<String, dynamic>?> _buscarDadosAluno(String tenantId, String email) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('alunos')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final dados = snap.docs.first.data();
        dados['docId'] = snap.docs.first.id;
        return dados;
      }
    } catch (e) {
      debugPrint('Erro ao buscar aluno: $e');
    }
    return null;
  }

  // Widget para os Botões de Atalho Rápidos
  Widget _buildAtalho(String titulo, IconData icone, Color corBase, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: corBase.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4))
            ],
            border: Border.all(color: corBase.withAlpha(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: corBase.withAlpha(30), shape: BoxShape.circle),
                child: Icon(icone, color: corBase, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final usuarioLogado = ref.watch(authProvider).value;
    
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    if (usuarioLogado == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: corPrimaria)));
    }

    final tenantId = usuarioLogado.id;
    final emailUsuario = usuarioLogado.email.trim().toLowerCase();
    final nomeEscola = usuarioLogado.nomeEscola ?? 'Escola Domex Edu';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _buscarDadosAluno(tenantId, emailUsuario),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: corPrimaria));
          }

          final aluno = snapshot.data;

          if (aluno == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Perfil de aluno não encontrado.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('O e-mail $emailUsuario não está vinculado a nenhuma matrícula.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final nomeAluno = aluno['nome'] ?? 'Estudante';
          final turmaNome = aluno['turma'] ?? 'Turma não informada';
          final turmaId = aluno['turmaId'];
          final fotoUrl = aluno['fotoUrl'];
          final alunoDocId = aluno['docId'];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================================
                // CABEÇALHO HERO (Estilo App Moderno)
                // ============================================================
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(isMobile ? 24 : 40, isMobile ? 48 : 60, isMobile ? 24 : 40, 40),
                  decoration: BoxDecoration(
                    color: corPrimaria,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(color: corPrimaria.withAlpha(80), blurRadius: 15, offset: const Offset(0, 8))
                    ]
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomeEscola.toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Olá, $nomeAluno 👋',
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(turmaNome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: isMobile ? 35 : 45,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: isMobile ? 32 : 42,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                          child: fotoUrl == null || fotoUrl.isEmpty ? Icon(Icons.person, size: 40, color: corPrimaria) : null,
                        ),
                      )
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(isMobile ? 24.0 : 40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ============================================================
                      // ATALHOS RÁPIDOS
                      // ============================================================
                      Row(
                        children: [
                          _buildAtalho('Boletim', Icons.analytics_rounded, Colors.blue, () {
                            // Ação: Abrir Boletim
                          }),
                          const SizedBox(width: 16),
                          _buildAtalho('Calendário', Icons.calendar_month_rounded, Colors.purple, () {
                            // Ação: Abrir Calendário
                          }),
                          const SizedBox(width: 16),
                          _buildAtalho('Frequência', Icons.fact_check_rounded, Colors.green, () {
                            // Ação: Abrir Frequência
                          }),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // ============================================================
                      // PRÓXIMAS AVALIAÇÕES (Lista Horizontal)
                      // ============================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Próximas Avaliações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400)
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (turmaId != null)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId.toString()).collection('avaliacoes')
                              .orderBy('dataCriacao', descending: true).limit(5).snapshots(),
                          builder: (context, snapAvaliacoes) {
                            if (snapAvaliacoes.connectionState == ConnectionState.waiting && !snapAvaliacoes.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            var avaliacoes = snapAvaliacoes.data?.docs ?? [];
                            if (avaliacoes.isEmpty) {
                              return Container(
                                width: double.infinity, padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                                child: Column(
                                  children: [
                                    Icon(Icons.event_available_rounded, size: 40, color: Colors.grey.shade300),
                                    const SizedBox(height: 8),
                                    Text('Nenhuma avaliação agendada.', style: TextStyle(color: Colors.grey.shade500)),
                                  ],
                                ),
                              );
                            }

                            return SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: avaliacoes.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final aval = avaliacoes[index].data() as Map<String, dynamic>;
                                  final notas = Map<String, dynamic>.from(aval['notas'] ?? {});
                                  final notaDoAluno = notas[alunoDocId];
                                  final max = aval['pontuacaoMaxima'] ?? 10.0;

                                  return Container(
                                    width: 260,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade200),
                                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                                              child: Text(aval['bimestre'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: corPrimaria)),
                                            ),
                                            Text(aval['dataAvaliacao'] != null ? _formatarDataDisplay(aval['dataAvaliacao']) : '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(aval['nome'] ?? 'Avaliação', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 8),
                                        if (notaDoAluno != null)
                                          Text('Sua Nota: $notaDoAluno / $max', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 13))
                                        else
                                          Text('Valendo $max pontos', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          }
                        ),

                      const SizedBox(height: 40),

                      // ============================================================
                      // MURAL DE AVISOS (Turma e Direção)
                      // ============================================================
                      Row(
                        children: [
                          const Icon(Icons.campaign_rounded, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Mural de Avisos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (turmaId != null)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId.toString()).collection('avisos')
                              .orderBy('dataEnvio', descending: true).limit(10).snapshots(),
                          builder: (context, snapAvisos) {
                            if (snapAvisos.connectionState == ConnectionState.waiting && !snapAvisos.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final docs = snapAvisos.data?.docs ?? [];
                            
                            // Filtrar avisos relevantes para o aluno
                            final avisosAluno = docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final tipoDest = data['tipoDestinatario'];
                              final alvoId = data['alunoId'];

                              // Mostra avisos gerais da turma
                              if (tipoDest == 'TURMA' || tipoDest == 'TODOS') return true;
                              // Mostra avisos específicos para ESTE aluno ou responsável
                              if ((tipoDest == 'ALUNO' || tipoDest == 'RESPONSAVEL') && alvoId == alunoDocId) return true;
                              
                              return false;
                            }).toList();

                            if (avisosAluno.isEmpty) {
                              return Container(
                                width: double.infinity, padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                                child: Column(
                                  children: [
                                    Icon(Icons.notifications_off_rounded, size: 40, color: Colors.grey.shade300),
                                    const SizedBox(height: 8),
                                    Text('Nenhum aviso no mural.', style: TextStyle(color: Colors.grey.shade500)),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: avisosAluno.length,
                              separatorBuilder: (c, i) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final aviso = avisosAluno[index].data() as Map<String, dynamic>;
                                final dataEnvio = aviso['dataEnvio'];
                                final textoData = dataEnvio != null ? DateFormat('dd/MM HH:mm').format((dataEnvio as dynamic).toDate()) : '';
                                final isDireto = aviso['tipoDestinatario'] == 'ALUNO' || aviso['tipoDestinatario'] == 'RESPONSAVEL';

                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isDireto ? Colors.orange.shade50 : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDireto ? Colors.orange.shade200 : Colors.grey.shade200),
                                    boxShadow: isDireto ? null : const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(isDireto ? Icons.message_rounded : Icons.campaign_rounded, size: 16, color: isDireto ? Colors.orange.shade800 : corPrimaria),
                                              const SizedBox(width: 8),
                                              Text(
                                                aviso['remetenteNome'] ?? 'Direção / Professor',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDireto ? Colors.orange.shade900 : Colors.black87),
                                              ),
                                            ],
                                          ),
                                          Text(textoData, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(height: 1),
                                      ),
                                      Text(
                                        aviso['mensagem'] ?? '',
                                        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                                      )
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                        ),
                        
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      )
    );
  }

  String _formatarDataDisplay(String dataBanco) {
    try {
      final partes = dataBanco.split('-');
      if (partes.length == 3) {
        return "${partes[2]}/${partes[1]}";
      }
    } catch (_) {}
    return dataBanco;
  }
}