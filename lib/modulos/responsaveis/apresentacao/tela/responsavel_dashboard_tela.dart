import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Import com o caminho corrigido (dois níveis ../../)
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class ResponsavelDashboardTela extends ConsumerStatefulWidget {
  const ResponsavelDashboardTela({super.key});

  @override
  ConsumerState<ResponsavelDashboardTela> createState() => _ResponsavelDashboardTelaState();
}

class _ResponsavelDashboardTelaState extends ConsumerState<ResponsavelDashboardTela> {
  
  // Função para buscar os alunos vinculados a este responsável
  Future<List<Map<String, dynamic>>> _buscarDependentes(String tenantId, String emailLogado) async {
    try {
      final loginChave = emailLogado.toLowerCase().trim();
      final cpfPossivel = loginChave.split('@')[0].replaceAll(RegExp(r'[^0-9]'), '');

      final snapshot = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('alunos')
          .where('status', isEqualTo: 'Ativo')
          .get();

      List<Map<String, dynamic>> dependentes = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final resps = data['responsaveis'] as List? ?? [];
        
        bool isMeuFilho = resps.any((r) {
          final cpfLimpo = (r['cpf']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), '');
          final emailLimpo = (r['email']?.toString() ?? '').toLowerCase().trim();
          
          return (cpfLimpo.isNotEmpty && cpfLimpo == cpfPossivel) || 
                 (emailLimpo.isNotEmpty && emailLimpo == loginChave);
        });

        if (isMeuFilho) {
          data['id'] = doc.id;
          dependentes.add(data);
        }
      }
      return dependentes;
    } catch (e) {
      return [];
    }
  }

  void _abrirBoletim(String tenantId, String turmaId, String alunoDocId, Color corPrimaria) {
    if (turmaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aluno sem turma vinculada.')));
      return;
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollController) => _BoletimModal(tenantId: tenantId, turmaId: turmaId, alunoDocId: alunoDocId, corPrimaria: corPrimaria, scrollController: scrollController)
      )
    );
  }

  void _abrirFrequencia(String tenantId, String turmaId, String matricula, Color corPrimaria) {
    if (turmaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aluno sem turma vinculada.')));
      return;
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollController) => _FrequenciaModal(tenantId: tenantId, turmaId: turmaId, alunoMatricula: matricula, corPrimaria: corPrimaria, scrollController: scrollController)
      )
    );
  }

  void _abrirAvisos(String tenantId, String turmaId, String alunoDocId, Color corPrimaria) {
    if (turmaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aluno sem turma vinculada.')));
      return;
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollController) => _AvisosModal(tenantId: tenantId, turmaId: turmaId, alunoDocId: alunoDocId, corPrimaria: corPrimaria, scrollController: scrollController)
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarioLogado = ref.watch(authProvider).value;
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    if (usuarioLogado == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final tenantId = usuarioLogado.tenantId; 
    final emailLogado = usuarioLogado.email;
    final nomeResponsavel = usuarioLogado.nome ?? 'Responsável';
    final corPrimaria = Theme.of(context).primaryColor; 

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Portal da Família', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: isMobile 
            ? IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: () => Scaffold.maybeOf(context)?.openDrawer())
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(isMobile ? 20 : 40, 16, isMobile ? 20 : 40, 32),
              decoration: BoxDecoration(
                color: corPrimaria,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [BoxShadow(color: corPrimaria.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bem-vindo(a),', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(nomeResponsavel, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(isMobile ? 24.0 : 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.family_restroom_rounded, color: corPrimaria, size: 24),
                      const SizedBox(width: 8),
                      const Text('Meus Dependentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _buscarDependentes(tenantId, emailLogado),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: corPrimaria));
                      }
                      
                      final alunos = snapshot.data ?? [];

                      if (alunos.isEmpty) {
                        return Center(
                          child: Column(
                            children: [
                              Icon(Icons.person_search_rounded, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text('Nenhum aluno vinculado ao seu perfil.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Procure a secretaria para vincular seu cadastro aos seus filhos.', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: alunos.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final aluno = alunos[index];
                          final fotoUrl = aluno['fotoPortalUrl'] ?? aluno['fotoUrl'] ?? '';
                          final turmaId = aluno['turmaId']?.toString() ?? '';
                          final alunoDocId = aluno['id'];
                          final matricula = (aluno['matricula'] ?? '').toString();
                          
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                childrenPadding: const EdgeInsets.all(20),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: fotoUrl.toString().isNotEmpty ? NetworkImage(fotoUrl) : null,
                                  child: fotoUrl.toString().isEmpty ? Icon(Icons.person, color: corPrimaria) : null,
                                ),
                                title: Text(aluno['nome'] ?? 'Aluno', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Text('${aluno['turma'] ?? 'Turma não definida'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                                    child: Wrap(
                                      spacing: 12, runSpacing: 12,
                                      alignment: WrapAlignment.spaceEvenly,
                                      children: [
                                        _buildAcaoBotao(Icons.analytics_rounded, 'Boletim', corPrimaria, () {
                                          _abrirBoletim(tenantId, turmaId, alunoDocId, corPrimaria);
                                        }),
                                        _buildAcaoBotao(Icons.fact_check_rounded, 'Frequência', corPrimaria, () {
                                          _abrirFrequencia(tenantId, turmaId, matricula, corPrimaria);
                                        }),
                                        _buildAcaoBotao(Icons.payments_rounded, 'Financeiro', Colors.orange.shade700, () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.construction_rounded, color: Colors.white),
                                                  SizedBox(width: 8),
                                                  Text('Módulo Financeiro em desenvolvimento! 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              backgroundColor: Colors.orange.shade800,
                                            )
                                          );
                                        }),
                                        _buildAcaoBotao(Icons.campaign_rounded, 'Avisos', Colors.blue.shade700, () {
                                          _abrirAvisos(tenantId, turmaId, alunoDocId, corPrimaria);
                                        }),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAcaoBotao(IconData icone, String titulo, Color cor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cor.withAlpha(20), shape: BoxShape.circle),
              child: Icon(icone, color: cor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODAL DE BOLETIM
// ============================================================================
class _BoletimModal extends StatefulWidget {
  final String tenantId;
  final String turmaId;
  final String alunoDocId;
  final Color corPrimaria;
  final ScrollController scrollController;

  const _BoletimModal({required this.tenantId, required this.turmaId, required this.alunoDocId, required this.corPrimaria, required this.scrollController});

  @override
  State<_BoletimModal> createState() => _BoletimModalState();
}

class _BoletimModalState extends State<_BoletimModal> {
  String _bimestreAtivo = '1º Bimestre';

  String _calcularBimestre(DateTime data) {
    int mes = data.month;
    if (mes >= 2 && mes <= 4) return '1º Bimestre';
    if (mes >= 5 && mes <= 6) return '2º Bimestre';
    if (mes >= 7 && mes <= 9) return '3º Bimestre';
    return '4º Bimestre';
  }

  @override
  void initState() {
    super.initState();
    _bimestreAtivo = _calcularBimestre(DateTime.now());
  }

  Future<Map<String, dynamic>> _buscarDadosBoletim() async {
    final db = FirebaseFirestore.instance;
    final turmaRef = db.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId);
    
    final turmaSnap = await turmaRef.get();
    final avaliacoesSnap = await turmaRef.collection('avaliacoes').where('bimestre', isEqualTo: _bimestreAtivo).get();
    
    List<String> disciplinas = [];
    if (turmaSnap.exists) {
      final data = turmaSnap.data() as Map<String, dynamic>;
      if (data.containsKey('disciplinas') && data['disciplinas'] is List) {
        disciplinas = List<String>.from(data['disciplinas']);
      }
    }
    
    return {
      'disciplinas': disciplinas,
      'avaliacoes': avaliacoesSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.analytics_rounded, color: widget.corPrimaria)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Boletim do Aluno', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Notas consolidadas por disciplina', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ])),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '1º Bimestre', label: Text('1º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '2º Bimestre', label: Text('2º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '3º Bimestre', label: Text('3º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '4º Bimestre', label: Text('4º Bim', style: TextStyle(fontSize: 12)))
              ],
              selected: {_bimestreAtivo}, 
              onSelectionChanged: (s) => setState(() => _bimestreAtivo = s.first),
              style: SegmentedButton.styleFrom(selectedBackgroundColor: widget.corPrimaria.withAlpha(40), selectedForegroundColor: widget.corPrimaria),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _buscarDadosBoletim(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
              
              final dados = snapshot.data ?? {};
              final List<String> disciplinasTurma = dados['disciplinas'] ?? [];
              final List<Map<String, dynamic>> avaliacoes = dados['avaliacoes'] ?? [];

              Map<String, List<Map<String, dynamic>>> avaliacoesPorDisciplina = {};
              for (var d in disciplinasTurma) avaliacoesPorDisciplina[d] = [];
              
              for (var aval in avaliacoes) {
                final disciplina = aval['disciplina'] ?? 'Geral';
                final maximo = double.tryParse(aval['pontuacaoMaxima']?.toString() ?? '10') ?? 10.0;
                final isRecuperacao = aval['isRecuperacao'] == true;
                final contaParaMedia = aval['contaParaMedia'] ?? true;
                
                final notasMap = Map<String, dynamic>.from(aval['notas'] ?? {});
                final notaRaw = notasMap[widget.alunoDocId];
                final bool temNotaLancada = notaRaw != null && notaRaw.toString().isNotEmpty;
                final notaAluno = double.tryParse(notaRaw?.toString() ?? '0') ?? 0.0;

                if (!avaliacoesPorDisciplina.containsKey(disciplina)) avaliacoesPorDisciplina[disciplina] = [];
                
                avaliacoesPorDisciplina[disciplina]!.add({
                  'nota': notaAluno, 
                  'maximo': maximo, 
                  'isRecuperacao': isRecuperacao, 
                  'contaParaMedia': contaParaMedia, 
                  'valida': true,
                  'temNota': temNotaLancada,
                });
              }

              if (avaliacoesPorDisciplina.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Nenhuma disciplina ou nota neste bimestre.', style: TextStyle(color: Colors.grey.shade500))]));
              }

              Map<String, Map<String, dynamic>> boletim = {};

              for (var disciplina in avaliacoesPorDisciplina.keys) {
                var notasDaDisciplina = avaliacoesPorDisciplina[disciplina]!;
                var recuperacoes = notasDaDisciplina.where((n) => n['isRecuperacao'] == true && n['contaParaMedia'] != false).toList();
                var normais = notasDaDisciplina.where((n) => n['isRecuperacao'] != true && n['contaParaMedia'] != false).toList();

                for (var rec in recuperacoes) {
                  if (normais.isEmpty) continue;
                  normais.sort((a, b) => ((a['nota'] / a['maximo']).compareTo(b['nota'] / b['maxima'])));
                  var piorNormal = normais.first;

                  double aproveitamentoRec = rec['maximo'] > 0 ? rec['nota'] / rec['maximo'] : 0.0;
                  double aproveitamentoPiorNormal = piorNormal['maximo'] > 0 ? piorNormal['nota'] / piorNormal['maximo'] : 0.0;

                  if (aproveitamentoRec > aproveitamentoPiorNormal) piorNormal['valida'] = false; 
                  else rec['valida'] = false; 
                }

                double somaNotas = 0.0, somaMaximos = 0.0;
                bool possuiAlgumaNota = false;
                
                for (var n in notasDaDisciplina) {
                  if (n['contaParaMedia'] != false && n['valida'] == true) {
                    if (n['temNota'] == true) {
                      possuiAlgumaNota = true;
                    }
                    somaNotas += n['nota']; 
                    somaMaximos += n['maximo'];
                  }
                }
                double notaBoletim = somaNotas > 10.0 ? 10.0 : somaNotas;

                boletim[disciplina] = {
                  'notaAluno': possuiAlgumaNota ? notaBoletim : null, // Se for nulo, ainda não foi avaliado
                  'maximo': somaMaximos, 
                  'somaBruta': somaNotas,
                };
              }

              final disciplinasOrdem = boletim.keys.toList()..sort();

              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: disciplinasOrdem.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final disciplina = disciplinasOrdem[index];
                  final dados = boletim[disciplina]!;
                  final notaAluno = dados['notaAluno'] as double?;
                  final maximo = dados['maximo'] as double;
                  
                  final bool acimaMedia = notaAluno != null && notaAluno >= 6.0; 
                  final Color corNota = notaAluno == null ? Colors.grey : (acimaMedia ? Colors.green.shade700 : Colors.red.shade700);
                  
                  final String textoNota = notaAluno != null ? '${notaAluno.toStringAsFixed(1)} / 10.0' : '-';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.menu_book_rounded, color: Colors.blueGrey.shade300, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(disciplina, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(notaAluno == null ? 'Aguardando lançamento de notas' : 'Pontos: ${(dados['somaBruta'] as double).toStringAsFixed(1)} / ${maximo.toStringAsFixed(1)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                  ]
                                )
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: corNota.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                          child: Text(textoNota, style: TextStyle(color: corNota, fontWeight: FontWeight.bold, fontSize: 16)),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}

// ============================================================================
// MODAL DE FREQUENCIA POR DISCIPLINA
// ============================================================================
class _FrequenciaModal extends StatefulWidget {
  final String tenantId;
  final String turmaId;
  final String alunoMatricula;
  final Color corPrimaria;
  final ScrollController scrollController;

  const _FrequenciaModal({required this.tenantId, required this.turmaId, required this.alunoMatricula, required this.corPrimaria, required this.scrollController});

  @override
  State<_FrequenciaModal> createState() => _FrequenciaModalState();
}

class _FrequenciaModalState extends State<_FrequenciaModal> {
  String _bimestreAtivo = '1º Bimestre';

  String _calcularBimestre(DateTime data) {
    int mes = data.month;
    if (mes >= 2 && mes <= 4) return '1º Bimestre';
    if (mes >= 5 && mes <= 6) return '2º Bimestre';
    if (mes >= 7 && mes <= 9) return '3º Bimestre';
    return '4º Bimestre';
  }

  bool _isDataNoBimestre(String dataStr, String bimestreAlvo) {
    try {
      final partes = dataStr.split('-');
      final data = DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
      return _calcularBimestre(data) == bimestreAlvo;
    } catch (_) { return false; }
  }

  @override
  void initState() {
    super.initState();
    _bimestreAtivo = _calcularBimestre(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.fact_check_rounded, color: widget.corPrimaria)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Frequência Escolar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Acompanhamento de faltas por matéria', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ])),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '1º Bimestre', label: Text('1º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '2º Bimestre', label: Text('2º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '3º Bimestre', label: Text('3º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '4º Bimestre', label: Text('4º Bim', style: TextStyle(fontSize: 12)))
              ],
              selected: {_bimestreAtivo}, 
              onSelectionChanged: (s) => setState(() => _bimestreAtivo = s.first),
              style: SegmentedButton.styleFrom(selectedBackgroundColor: widget.corPrimaria.withAlpha(40), selectedForegroundColor: widget.corPrimaria),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId).collection('diarios').get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
              
              Map<String, List<Map<String, dynamic>>> frequenciaPorDisciplina = {};

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dataDiarioStr = doc.id.split('_')[0]; // Extração limpa garantindo suporte retroativo
                  
                  if (data['status'] != 'NAO_INICIADA' && _isDataNoBimestre(dataDiarioStr, _bimestreAtivo)) {
                    final freq = Map<String, String>.from(data['frequencia'] ?? {});
                    final st = freq[widget.alunoMatricula] ?? 'P';
                    final p = dataDiarioStr.split('-');
                    final disciplina = data['disciplina']?.toString() ?? 'Geral';
                    
                    if (!frequenciaPorDisciplina.containsKey(disciplina)) frequenciaPorDisciplina[disciplina] = [];
                    
                    frequenciaPorDisciplina[disciplina]!.add({
                      'idSort': dataDiarioStr, 
                      'data': "${p[2]}/${p[1]}/${p[0]}", 
                      'status': st
                    });
                  }
                }
              }

              if (frequenciaPorDisciplina.isEmpty) {
                return Center(child: Text('Nenhuma aula registrada neste bimestre.', style: TextStyle(color: Colors.grey.shade500)));
              }

              final disciplinasKeys = frequenciaPorDisciplina.keys.toList()..sort();

              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: disciplinasKeys.length,
                itemBuilder: (context, index) {
                  final disc = disciplinasKeys[index];
                  final aulas = frequenciaPorDisciplina[disc]!..sort((a,b) => b['idSort']!.compareTo(a['idSort']!));
                  
                  final int totalAulas = aulas.length;
                  final int faltas = aulas.where((f) => f['status'] == 'A' || f['status'] == 'J').length;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: faltas > 0, // Abre automaticamente as matérias onde o aluno faltou
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(disc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text(
                          'Faltas no $_bimestreAtivo: $faltas / $totalAulas', 
                          style: TextStyle(color: faltas > 0 ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)
                        ),
                        children: aulas.map((f) {
                          final status = f['status'];
                          Color corStatus = Colors.green; 
                          String textoStatus = 'Presente'; 
                          IconData iconeStatus = Icons.check_circle_rounded;

                          if (status == 'A') { corStatus = Colors.red; textoStatus = 'Falta'; iconeStatus = Icons.cancel_rounded; } 
                          else if (status == 'J') { corStatus = Colors.orange; textoStatus = 'Falta Justificada'; iconeStatus = Icons.info_rounded; }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            leading: Icon(Icons.event_available_rounded, color: Colors.grey.shade400, size: 20),
                            title: Text(f['data'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                              decoration: BoxDecoration(color: corStatus.withAlpha(30), borderRadius: BorderRadius.circular(8)), 
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(iconeStatus, color: corStatus, size: 14), const SizedBox(width: 4),
                                  Text(textoStatus, style: TextStyle(color: corStatus, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}

class _AvisosModal extends StatelessWidget {
  final String tenantId;
  final String turmaId;
  final String alunoDocId;
  final Color corPrimaria;
  final ScrollController scrollController;

  const _AvisosModal({required this.tenantId, required this.turmaId, required this.alunoDocId, required this.corPrimaria, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.campaign_rounded, color: corPrimaria)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mural de Avisos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Comunicações da escola', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ])),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId).collection('avisos').orderBy('dataEnvio', descending: true).snapshots(),
            builder: (context, snapAvisos) {
              if (snapAvisos.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: corPrimaria));

              final todosAvisos = snapAvisos.data?.docs.map((d) {
                final data = d.data() as Map<String, dynamic>; data['id'] = d.id; return data;
              }).toList() ?? [];
              
              final avisosAluno = todosAvisos.where((aviso) {
                final tipoDest = aviso['tipoDestinatario'];
                final alvoId = aviso['alunoId'];
                if (tipoDest == 'TURMA' || tipoDest == 'TODOS') return true;
                if ((tipoDest == 'ALUNO' || tipoDest == 'RESPONSAVEL') && alvoId == alunoDocId) return true;
                return false;
              }).toList();

              if (avisosAluno.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.notifications_off_rounded, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Nenhum aviso no mural.', style: TextStyle(color: Colors.grey.shade500))]));
              }

              return ListView.separated(
                controller: scrollController, padding: const EdgeInsets.all(20),
                itemCount: avisosAluno.length, separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final aviso = avisosAluno[index];
                  final dataEnvio = aviso['dataEnvio'];
                  final textoData = dataEnvio != null ? DateFormat('dd/MM HH:mm').format((dataEnvio as dynamic).toDate()) : '';
                  
                  final tipoDest = aviso['tipoDestinatario'];
                  final isDireto = tipoDest == 'ALUNO' || tipoDest == 'RESPONSAVEL';
                  
                  String tagDestino = 'Para toda a turma';
                  Color corTag = Colors.blue;
                  
                  if (tipoDest == 'ALUNO') {
                    tagDestino = 'Direcionado ao Aluno';
                    corTag = Colors.purple;
                  } else if (tipoDest == 'RESPONSAVEL') {
                    tagDestino = 'Apenas para você (Responsável)';
                    corTag = Colors.red;
                  }
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: isDireto ? corTag.withAlpha(10) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDireto ? corTag.withAlpha(50) : Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(aviso['remetenteNome'] ?? 'Direção', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDireto ? corTag.withAlpha(200) : Colors.black87)),
                            Text(textoData, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: corTag.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                          child: Text(tagDestino, style: TextStyle(color: corTag, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        Text(aviso['mensagem'] ?? '', style: TextStyle(fontSize: 14, color: Colors.grey.shade800))
                      ],
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}