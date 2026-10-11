import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// Importações para a geração do PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// FUNÇÕES GLOBAIS DE VISUALIZAÇÃO E DOWNLOAD DE ANEXOS
// ============================================================================
Future<void> _abrirLink(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// Visualizador com Zoom e Download Embutido
void _mostrarAnexoAmpliadoGlobal(BuildContext context, String url, bool isPdf, Color corPrimaria) {
  if (url.isEmpty) return;
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: corPrimaria, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isPdf ? 'Visualizador de PDF' : 'Visualizador de Imagem', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Flexible(
              child: Container(
                width: double.infinity,
                color: Colors.grey.shade100,
                child: isPdf
                    ? Padding(
                        padding: const EdgeInsets.all(48.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 80),
                            const SizedBox(height: 16),
                            const Text('Arquivo em formato PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 8),
                            const Text('Toque no botão abaixo para baixar ou visualizar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      )
                    : ClipRRect(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48)),
                          ),
                        ),
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _abrirLink(url),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(isPdf ? 'Fazer Download / Abrir PDF' : 'Baixar Imagem', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            )
          ],
        ),
      ),
    ),
  );
}

class ResponsavelDashboardTela extends ConsumerStatefulWidget {
  const ResponsavelDashboardTela({super.key});

  @override
  ConsumerState<ResponsavelDashboardTela> createState() => _ResponsavelDashboardTelaState();
}

class _ResponsavelDashboardTelaState extends ConsumerState<ResponsavelDashboardTela> {
  
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

  void _abrirBoletim(String tenantId, String turmaId, String alunoDocId, String matricula, String nomeAluno, Color corPrimaria) {
    if (turmaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aluno sem turma vinculada.')));
      return;
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollController) => _BoletimModal(
          tenantId: tenantId, 
          turmaId: turmaId, 
          alunoDocId: alunoDocId, 
          alunoMatricula: matricula,
          nomeAluno: nomeAluno,
          corPrimaria: corPrimaria, 
          scrollController: scrollController
        )
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

  void _abrirAvisos(String tenantId, String turmaId, String alunoDocId, Color corPrimaria, String meuId, String nomeResp, String nomeAluno) {
    if (turmaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aluno sem turma vinculada.')));
      return;
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollController) => _AvisosModal(
          tenantId: tenantId, 
          turmaId: turmaId, 
          alunoDocId: alunoDocId, 
          corPrimaria: corPrimaria, 
          scrollController: scrollController,
          meuId: meuId,
          nomeResp: nomeResp,
          nomeAluno: nomeAluno,
        )
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
    final String nomeResponsavel = usuarioLogado.nome.toString().isNotEmpty ? usuarioLogado.nome.toString() : 'Responsável';
    final String meuId = usuarioLogado.id.toString();
    final corPrimaria = Theme.of(context).primaryColor; 

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bem-vindo(a),', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(nomeResponsavel, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
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
                          final turmaId = (aluno['turmaId'] ?? '').toString();
                          final alunoDocId = (aluno['id'] ?? '').toString();
                          final matricula = (aluno['matricula'] ?? '').toString();
                          final nomeAluno = (aluno['nome'] ?? 'Aluno').toString();
                          
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
                                  backgroundImage: fotoUrl.toString().isNotEmpty ? NetworkImage(fotoUrl.toString()) : null,
                                  child: fotoUrl.toString().isEmpty ? Icon(Icons.person, color: corPrimaria) : null,
                                ),
                                title: Text(nomeAluno, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                                        _buildAcaoBotao(Icons.analytics_rounded, 'Boletim', Colors.blue.shade700, () {
                                          _abrirBoletim(tenantId, turmaId, alunoDocId, matricula, nomeAluno, corPrimaria);
                                        }),
                                        _buildAcaoBotao(Icons.fact_check_rounded, 'Frequência', Colors.green.shade700, () {
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
                                        _buildAcaoBotao(
                                          Icons.campaign_rounded, 
                                          'Avisos e\nMensagens', 
                                          Colors.purple.shade700, 
                                          () {
                                            _abrirAvisos(tenantId, turmaId, alunoDocId, corPrimaria, meuId, nomeResponsavel, nomeAluno);
                                          },
                                          badge: _BalaoNotificacaoAvisos(tenantId: tenantId, turmaId: turmaId, alunoDocId: alunoDocId, meuId: meuId)
                                        ),
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

  Widget _buildAcaoBotao(IconData icone, String titulo, Color cor, VoidCallback onTap, {Widget? badge}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90, 
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: cor.withAlpha(25), shape: BoxShape.circle),
                  child: Icon(icone, color: cor, size: 42),
                ),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: badge,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.1), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET DO BALÃO DE NOTIFICAÇÃO (BOLINHA VERMELHA)
// ============================================================================
class _BalaoNotificacaoAvisos extends StatefulWidget {
  final String tenantId;
  final String turmaId;
  final String alunoDocId;
  final String meuId;

  const _BalaoNotificacaoAvisos({required this.tenantId, required this.turmaId, required this.alunoDocId, required this.meuId});

  @override
  State<_BalaoNotificacaoAvisos> createState() => _BalaoNotificacaoAvisosState();
}

class _BalaoNotificacaoAvisosState extends State<_BalaoNotificacaoAvisos> {
  int _naoLidos = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarMensagens();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _carregarMensagens());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarMensagens() async {
    if (!mounted || widget.turmaId.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId).collection('avisos').get();
      if (!mounted) return;

      int naoLidos = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tipoDest = data['tipoDestinatario'];
        final alvoId = data['alunoId']?.toString() ?? '';
        
        bool isParaMim = false;
        if (tipoDest == 'TURMA' || tipoDest == 'TODOS' || tipoDest == 'TURMA_RESPONSAVEIS') isParaMim = true;
        if ((tipoDest == 'ALUNO' || tipoDest == 'RESPONSAVEL') && alvoId == widget.alunoDocId) isParaMim = true;
        if (data['remetenteId'] == widget.meuId) isParaMim = true; 

        if (isParaMim) {
          final lidos = List<String>.from(data['lidosPor'] ?? []);
          // Se eu não li e a mensagem NÃO fui eu que enviei
          if (!lidos.contains(widget.alunoDocId) && data['remetenteId'] != widget.meuId) {
            naoLidos++;
          }

          final respostasSnap = await doc.reference.collection('respostas').where('lidaPorResponsavel', isEqualTo: false).get();
          naoLidos += respostasSnap.docs.where((r) {
             final rData = r.data();
             return (rData['remetenteId'] ?? '') != widget.meuId;
          }).length;
        }
      }
      
      if (mounted) {
        setState(() {
          _naoLidos = naoLidos;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.turmaId.isEmpty || _naoLidos == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
      ),
      child: Text(
        _naoLidos > 9 ? '9+' : _naoLidos.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.1),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ============================================================================
// MODAL DE BOLETIM COM EXPORTAÇÃO PDF INTEGRADA
// ============================================================================
class _BoletimModal extends StatefulWidget {
  final String tenantId;
  final String turmaId;
  final String alunoDocId;
  final String alunoMatricula;
  final String nomeAluno;
  final Color corPrimaria;
  final ScrollController scrollController;
  
  const _BoletimModal({
    required this.tenantId, 
    required this.turmaId, 
    required this.alunoDocId, 
    required this.alunoMatricula,
    required this.nomeAluno,
    required this.corPrimaria, 
    required this.scrollController
  });
  
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

  String _calcularBimestrePorMes(int mes) {
    if (mes >= 1 && mes <= 4) return '1º Bimestre';
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
      'avaliacoes': avaliacoesSnap.docs.map((d) => d.data()).toList(),
    };
  }

  // ==========================================================================
  // GERAÇÃO DO BOLETIM EM PDF PROFISSIONAL (TODOS OS BIMESTRES)
  // ==========================================================================
  Future<void> _exportarBoletimPdf(BuildContext context) async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final db = FirebaseFirestore.instance;
      
      // 1. Dados da Escola
      final tenantDoc = await db.collection('tenants').doc(widget.tenantId).get();
      final tenantData = tenantDoc.data() ?? <String, dynamic>{};
      final nomeEscola = (tenantData['nomeEscola'] ?? 'ESCOLA').toString();
      final logoUrl = (tenantData['logoUrl'] ?? tenantData['fotoUrl'] ?? tenantData['logo'] ?? '').toString();

      pw.ImageProvider? logoProvider;
      if (logoUrl.isNotEmpty) {
        try { logoProvider = await networkImage(logoUrl); } catch (_) {}
      }

      // 2. Dados da Turma
      final turmaDoc = await db.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId).get();
      final turmaData = turmaDoc.data() ?? <String, dynamic>{};
      final turmaNome = (turmaData['nome'] ?? '').toString();
      final turmaTurno = (turmaData['turno'] ?? '').toString();
      final disciplinas = List<String>.from(turmaData['disciplinas'] ?? []);

      // 3. Buscar todas as Avaliações e Diários de todos os bimestres
      final avalsSnap = await db.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId).collection('avaliacoes').get();
      final diariosSnap = await db.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId).collection('diarios').get();

      // Mapeamento Global para Frequências: [Bimestre] -> [Disciplina] -> {aulas, faltas}
      Map<String, Map<String, Map<String, int>>> freqGlobal = {
        '1º Bimestre': {}, '2º Bimestre': {}, '3º Bimestre': {}, '4º Bimestre': {}
      };
      
      for (var d in diariosSnap.docs) {
        final data = d.data();
        if(data['status'] == 'NAO_INICIADA') continue;

        final dateStr = d.id.split('_')[0];
        final p = dateStr.split('-');
        if(p.length < 3) continue;
        
        final mes = int.parse(p[1]);
        final bimestre = _calcularBimestrePorMes(mes);
        final disciplina = (data['disciplina'] ?? 'Geral').toString();

        if (!freqGlobal[bimestre]!.containsKey(disciplina)) {
          freqGlobal[bimestre]![disciplina] = {'aulas': 0, 'faltas': 0};
        }

        freqGlobal[bimestre]![disciplina]!['aulas'] = freqGlobal[bimestre]![disciplina]!['aulas']! + 1;

        final freqMap = Map<String, String>.from(data['frequencia'] ?? {});
        final statusAluno = freqMap[widget.alunoMatricula] ?? 'P';
        
        if (statusAluno == 'A' || statusAluno == 'J') {
          freqGlobal[bimestre]![disciplina]!['faltas'] = freqGlobal[bimestre]![disciplina]!['faltas']! + 1;
        }
      }

      // Função Auxiliar para calcular nota limpa da disciplina num bimestre
      double? calcularNotaDisciplina(String bim, String disc) {
        var avalsBim = avalsSnap.docs.map((d)=>d.data()).where((a) => a['bimestre'] == bim && a['disciplina'] == disc).toList();
        if (avalsBim.isEmpty) return null;

        var avalsValidas = avalsBim.where((a) => a['contaParaMedia'] != false).toList();

        // Extrai as notas brutas do Aluno
        List<Map<String, dynamic>> notasTratadas = [];
        for (var a in avalsValidas) {
          final maximo = double.tryParse((a['pontuacaoMaxima'] ?? '10').toString()) ?? 10.0;
          final isRec = a['isRecuperacao'] == true;
          final nMap = Map<String, dynamic>.from(a['notas'] ?? {});
          final nRaw = nMap[widget.alunoDocId];
          final notaAluno = double.tryParse((nRaw ?? '0').toString()) ?? 0.0;
          final temNota = nRaw != null && nRaw.toString().isNotEmpty;

          notasTratadas.add({
            'nota': notaAluno, 'maximo': maximo, 'isRec': isRec, 'temNota': temNota, 'valida': true
          });
        }

        var recsTratadas = notasTratadas.where((n) => n['isRec'] == true).toList();
        var normaisTratadas = notasTratadas.where((n) => n['isRec'] != true).toList();

        for (var rec in recsTratadas) {
          if (normaisTratadas.isEmpty) continue;
          normaisTratadas.sort((a, b) => ((a['nota'] / a['maximo']).compareTo(b['nota'] / b['maximo'])));
          var piorNormal = normaisTratadas.first;

          double aproveitamentoRec = rec['maximo'] > 0 ? rec['nota'] / rec['maximo'] : 0.0;
          double aproveitamentoPiorNormal = piorNormal['maximo'] > 0 ? piorNormal['nota'] / piorNormal['maximo'] : 0.0;

          if (aproveitamentoRec > aproveitamentoPiorNormal) {
            piorNormal['valida'] = false; 
          } else {
            rec['valida'] = false; 
          }
        }

        double somaNotas = 0.0;
        bool possuiAlgumaNota = false;

        for (var n in notasTratadas) {
          if (n['valida'] == true) {
            if (n['temNota'] == true) possuiAlgumaNota = true;
            somaNotas += n['nota'];
          }
        }
        
        if (!possuiAlgumaNota) return null;
        return somaNotas > 10.0 ? 10.0 : somaNotas;
      }

      // 4. Montar o PDF
      final pdf = pw.Document();
      final pdfCorPrimaria = PdfColor.fromInt(widget.corPrimaria.toARGB32());
      final dataGeracao = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final bimestres = ['1º Bimestre', '2º Bimestre', '3º Bimestre', '4º Bimestre'];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          
          header: (context) {
            return pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoProvider != null) pw.Container(width: 50, height: 50, child: pw.Image(logoProvider)),
                    if (logoProvider != null) pw.SizedBox(width: 12),
                    pw.Expanded(child: pw.Text(nomeEscola.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: pdfCorPrimaria))),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                pw.SizedBox(height: 16),
              ],
            );
          },
          
          footer: (context) {
            return pw.Column(
              children: [
                pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text('Gerado pelo sistema DOMEX EDU - $dataGeracao', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
                pw.SizedBox(height: 2),
                pw.Center(child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
              ],
            );
          },
          
          build: (context) {
            List<pw.Widget> content = [];

            content.add(pw.Center(child: pw.Text('BOLETIM ESCOLAR E FREQUÊNCIA', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: pdfCorPrimaria))));
            content.add(pw.SizedBox(height: 16));
            
            // Dados do Aluno
            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)), border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Nome do Aluno(a):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                          pw.Text(widget.nomeAluno, style: const pw.TextStyle(fontSize: 11)),
                        ]
                      )
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Turma / Turno:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                          pw.Text('$turmaNome - $turmaTurno', style: const pw.TextStyle(fontSize: 11)),
                        ]
                      )
                    ),
                  ]
                )
              )
            );
            content.add(pw.SizedBox(height: 24));

            // Tabelas por Bimestre
            for (var bim in bimestres) {
              content.add(pw.Text(bim, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: pdfCorPrimaria)));
              content.add(pw.SizedBox(height: 8));

              content.add(
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                    4: const pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    // Header da Tabela
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: pdfCorPrimaria),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Disciplina', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Nota', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Aulas', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Faltas', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('Freq. (%)', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)))),
                      ]
                    ),
                    // Linhas da Tabela
                    for (var disc in disciplinas) ...[
                      () {
                        // Lógica de Nota
                        final nota = calcularNotaDisciplina(bim, disc);
                        final String txtNota = nota != null ? nota.toStringAsFixed(1) : '-';
                        final PdfColor corNota = nota == null ? PdfColors.grey800 : (nota >= 6.0 ? PdfColors.green700 : PdfColors.red700);

                        // Lógica de Frequência
                        final freqDisc = freqGlobal[bim]![disc] ?? {'aulas': 0, 'faltas': 0};
                        final int aulas = freqDisc['aulas'] ?? 0;
                        final int faltas = freqDisc['faltas'] ?? 0;
                        final int presencas = aulas - faltas;
                        final double perc = aulas == 0 ? 100.0 : (presencas / aulas) * 100;
                        final String txtPerc = aulas == 0 ? '-' : '${perc.toStringAsFixed(0)}%';

                        return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(disc, style: const pw.TextStyle(fontSize: 9))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(txtNota, style: pw.TextStyle(color: corNota, fontWeight: pw.FontWeight.bold, fontSize: 9)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(aulas.toString(), style: const pw.TextStyle(fontSize: 9)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(faltas.toString(), style: const pw.TextStyle(fontSize: 9)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(txtPerc, style: const pw.TextStyle(fontSize: 9)))),
                          ]
                        );
                      }()
                    ]
                  ]
                )
              );
              content.add(pw.SizedBox(height: 20));
            }

            return content;
          },
        ),
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Boletim_${widget.nomeAluno.replaceAll(' ', '_')}.pdf',
      );

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    }
  }

  void _mostrarDetalhesDisciplina(String disciplina, List<Map<String, dynamic>> avaliacoes) {
    final avaliacoesFiltradas = avaliacoes.where((a) => a['contaParaMedia'] != false).toList();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(disciplina, style: TextStyle(fontWeight: FontWeight.bold, color: widget.corPrimaria)),
        content: SizedBox(
          width: double.maxFinite,
          child: avaliacoesFiltradas.isEmpty 
            ? const Text('Nenhuma avaliação lançada para a média nesta disciplina.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: avaliacoesFiltradas.length,
                separatorBuilder: (ctx, idx) => const Divider(),
                itemBuilder: (context, index) {
                  final a = avaliacoesFiltradas[index];
                  final nota = a['nota'];
                  final double max = a['maximo'];
                  final bool valida = a['valida'];
                  final bool isRec = a['isRecuperacao'];
                  final bool temNota = a['temNota'] ?? false;
                  
                  String sub = '';
                  if (isRec && valida) {
                    sub = 'Nota Substituta (Recuperação)';
                  }
                  if (isRec && !valida) {
                    sub = 'Descartada (Recuperação)';
                  }
                  if (!isRec && !valida) {
                    sub = 'Substituída';
                  }

                  final String textoNota = temNota ? '${nota.toStringAsFixed(1)} / ${max.toStringAsFixed(1)}' : '-';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a['nome'] ?? 'Avaliação', style: TextStyle(decoration: valida ? null : TextDecoration.lineThrough, color: valida ? Colors.black : Colors.grey)),
                    subtitle: sub.isNotEmpty ? Text(sub, style: TextStyle(color: valida ? Colors.purple : Colors.grey)) : null,
                    trailing: Text(textoNota, style: TextStyle(fontWeight: FontWeight.bold, decoration: valida ? null : TextDecoration.lineThrough, color: valida ? widget.corPrimaria : Colors.grey)),
                  );
                }
            )
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))
        ]
      )
    );
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
                Text('Meu Boletim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Notas consolidadas por disciplina', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ])),
              // BOTÃO EXPORTAR PDF
              IconButton(
                tooltip: 'Exportar para PDF',
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red), 
                onPressed: () => _exportarBoletimPdf(context)
              ),
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
              
              for (var d in disciplinasTurma) {
                avaliacoesPorDisciplina[d] = [];
              }
              
              for (var aval in avaliacoes) {
                final disciplina = aval['disciplina'] ?? 'Geral';
                final maximo = double.tryParse((aval['pontuacaoMaxima'] ?? '10').toString()) ?? 10.0;
                final isRecuperacao = aval['isRecuperacao'] == true;
                final contaParaMedia = aval['contaParaMedia'] ?? true;
                
                final notasMap = Map<String, dynamic>.from(aval['notas'] ?? {});
                final notaRaw = notasMap[widget.alunoDocId];
                final bool temNotaLancada = notaRaw != null && notaRaw.toString().isNotEmpty;
                final notaAluno = double.tryParse((notaRaw ?? '0').toString()) ?? 0.0;

                if (!avaliacoesPorDisciplina.containsKey(disciplina)) {
                  avaliacoesPorDisciplina[disciplina] = [];
                }
                
                avaliacoesPorDisciplina[disciplina]!.add({
                  'nome': aval['nome'] ?? 'Avaliação',
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

                  if (aproveitamentoRec > aproveitamentoPiorNormal) {
                    piorNormal['valida'] = false; 
                  } else {
                    rec['valida'] = false; 
                  }
                }

                double somaNotas = 0.0;
                double somaMaximos = 0.0;
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
                
                double notaBoletim = somaNotas;
                if (notaBoletim > 10.0) notaBoletim = 10.0;

                boletim[disciplina] = {
                  'notaAluno': possuiAlgumaNota ? notaBoletim : null, 
                  'maximo': somaMaximos, 
                  'somaBruta': somaNotas,
                  'avaliacoes': notasDaDisciplina
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
                  final somaBruta = dados['somaBruta'] as double;
                  final listaAvals = dados['avaliacoes'] as List<Map<String, dynamic>>;
                  
                  final bool acimaMedia = notaAluno != null && notaAluno >= 6.0; 
                  final Color corNota = notaAluno == null ? Colors.grey : (acimaMedia ? Colors.green.shade700 : Colors.red.shade700);
                  
                  final String textoNota = notaAluno != null ? '${notaAluno.toStringAsFixed(1)} / 10.0' : '-';

                  return InkWell(
                    onTap: () => _mostrarDetalhesDisciplina(disciplina, listaAvals),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
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
                                      Text(notaAluno == null ? 'Aguardando lançamento de notas' : 'Pontos: ${somaBruta.toStringAsFixed(1)} / ${maximo.toStringAsFixed(1)} distribuídos', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                    ]
                                  )
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: corNota.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              textoNota, 
                              style: TextStyle(color: corNota, fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                          )
                        ],
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

// ============================================================================
// MODAL DE FREQUÊNCIA
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
  int _mesAtivo = DateTime.now().month;

  List<int> _getMesesDoBimestre(String bimestre) {
    if (bimestre == '1º Bimestre') return [1, 2, 3, 4];
    if (bimestre == '2º Bimestre') return [5, 6];
    if (bimestre == '3º Bimestre') return [7, 8, 9];
    return [10, 11, 12];
  }

  String _getNomeMes(int mes) {
    const nomes = {1: 'Jan', 2: 'Fev', 3: 'Mar', 4: 'Abr', 5: 'Mai', 6: 'Jun', 7: 'Jul', 8: 'Ago', 9: 'Set', 10: 'Out', 11: 'Nov', 12: 'Dez'};
    return nomes[mes] ?? '';
  }

  String _calcularBimestre(DateTime data) {
    int mes = data.month;
    if (mes >= 1 && mes <= 4) return '1º Bimestre';
    if (mes >= 5 && mes <= 6) return '2º Bimestre';
    if (mes >= 7 && mes <= 9) return '3º Bimestre';
    return '4º Bimestre';
  }

  String _obterDiaSemanaAbrev(int weekday) {
    switch (weekday) {
      case 1: return 'Seg'; case 2: return 'Ter'; case 3: return 'Qua'; case 4: return 'Qui'; case 5: return 'Sex'; case 6: return 'Sáb'; case 7: return 'Dom';
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _bimestreAtivo = _calcularBimestre(DateTime.now());
    final mesesDoBimestre = _getMesesDoBimestre(_bimestreAtivo);
    if (!mesesDoBimestre.contains(_mesAtivo)) {
      _mesAtivo = mesesDoBimestre.last;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesesValidos = _getMesesDoBimestre(_bimestreAtivo);

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
              onSelectionChanged: (s) {
                setState(() {
                  _bimestreAtivo = s.first;
                  _mesAtivo = _getMesesDoBimestre(_bimestreAtivo).first;
                });
              },
              style: SegmentedButton.styleFrom(selectedBackgroundColor: widget.corPrimaria.withAlpha(40), selectedForegroundColor: widget.corPrimaria),
            ),
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: mesesValidos.map((m) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_getNomeMes(m)),
                selected: _mesAtivo == m,
                selectedColor: widget.corPrimaria.withAlpha(40),
                labelStyle: TextStyle(
                  color: _mesAtivo == m ? widget.corPrimaria : Colors.black87,
                  fontWeight: _mesAtivo == m ? FontWeight.bold : FontWeight.normal
                ),
                onSelected: (val) {
                  if (val) setState(() => _mesAtivo = m);
                }
              ),
            )).toList(),
          ),
        ),

        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId).collection('diarios').get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
              
              int currentYear = DateTime.now().year;
              Map<String, List<Map<String, dynamic>>> diariPorDiaGeral = {}; 
              Map<String, List<Map<String, dynamic>>> frequenciaPorDisciplina = {};

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final docIdPartes = doc.id.split('_');
                  final dataDiarioStr = docIdPartes[0]; 
                  
                  try {
                    final p = dataDiarioStr.split('-');
                    final docYear = int.parse(p[0]);
                    final docMonth = int.parse(p[1]);
                    currentYear = docYear; 

                    if (data['status'] != 'NAO_INICIADA' && docMonth == _mesAtivo) {
                      final freq = Map<String, String>.from(data['frequencia'] ?? {});
                      final st = freq[widget.alunoMatricula] ?? 'P';
                      final disciplina = (data['disciplina'] ?? 'Geral').toString();
                      
                      if (!frequenciaPorDisciplina.containsKey(disciplina)) frequenciaPorDisciplina[disciplina] = [];
                      frequenciaPorDisciplina[disciplina]!.add({
                        'idSort': dataDiarioStr,
                        'data': "${p[2]}/${p[1]} (${_obterDiaSemanaAbrev(DateTime(docYear, docMonth, int.parse(p[2])).weekday)})", 
                        'status': st 
                      });

                      if (!diariPorDiaGeral.containsKey(dataDiarioStr)) diariPorDiaGeral[dataDiarioStr] = [];
                      diariPorDiaGeral[dataDiarioStr]!.add(data);
                    }
                  } catch (_) {}
                }
              }

              int daysInMonth = DateUtils.getDaysInMonth(currentYear, _mesAtivo);
              List<Map<String, dynamic>> diasGeralList = [];
              int totalDiasComAula = 0;
              int faltasGeral = 0;
              int presencasGeral = 0;

              for (int d = 1; d <= daysInMonth; d++) {
                final dataAtual = DateTime(currentYear, _mesAtivo, d);
                final dateStr = "$currentYear-${_mesAtivo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
                final diaSemana = _obterDiaSemanaAbrev(dataAtual.weekday);
                final displayDate = "${d.toString().padLeft(2, '0')}/${_mesAtivo.toString().padLeft(2, '0')} ($diaSemana)";

                if (diariPorDiaGeral.containsKey(dateStr)) {
                  totalDiasComAula++;
                  final aulasDoDia = diariPorDiaGeral[dateStr]!;
                  bool temP = false;
                  bool temA = false;
                  
                  for (var aula in aulasDoDia) {
                    final freq = Map<String, String>.from(aula['frequencia'] ?? {});
                    final st = freq[widget.alunoMatricula] ?? 'P';
                    if (st == 'P') temP = true;
                    else if (st == 'A') temA = true;
                  }

                  String statusDia = 'P';
                  if (temP) { statusDia = 'P'; presencasGeral++; }
                  else if (temA) { statusDia = 'A'; faltasGeral++; }
                  else { statusDia = 'J'; faltasGeral++; }

                  diasGeralList.add({'display': displayDate, 'status': statusDia});
                } else {
                  diasGeralList.add({'display': displayDate, 'status': 'SEM_AULA'});
                }
              }

              final double percPresencaGeral = totalDiasComAula == 0 ? 100.0 : (presencasGeral / totalDiasComAula) * 100;
              final disciplinasKeys = frequenciaPorDisciplina.keys.where((k) => k.toUpperCase() != 'GERAL').toList()..sort();
              
              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: disciplinasKeys.length + 1, 
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Card(
                      elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: faltasGeral > 0, 
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: const Text('Visão Geral do Mês', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Text('Faltas: $faltasGeral / $totalDiasComAula', style: TextStyle(color: faltasGeral > 0 ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(width: 12),
                                Text('Presença: ${percPresencaGeral.toStringAsFixed(1)}%', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          children: diasGeralList.map((d) {
                            final status = d['status'];
                            if (status == 'SEM_AULA') {
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16), leading: Icon(Icons.event_busy_rounded, color: Colors.grey.shade300, size: 20),
                                title: Text((d['display'] ?? '').toString(), style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500, fontSize: 13)), trailing: Text('-', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 16)),
                              );
                            }
                            Color corStatus = Colors.green; String textoStatus = 'Presente'; IconData iconeStatus = Icons.check_circle_rounded;
                            if (status == 'A') { corStatus = Colors.red; textoStatus = 'Falta'; iconeStatus = Icons.cancel_rounded; } 
                            else if (status == 'J') { corStatus = Colors.orange; textoStatus = 'Falta Justificada'; iconeStatus = Icons.info_rounded; }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16), leading: Icon(Icons.event_available_rounded, color: Colors.grey.shade400, size: 20),
                              title: Text((d['display'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: corStatus.withAlpha(30), borderRadius: BorderRadius.circular(8)), 
                                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(iconeStatus, color: corStatus, size: 14), const SizedBox(width: 4), Text(textoStatus, style: TextStyle(color: corStatus, fontSize: 12, fontWeight: FontWeight.bold))])
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }

                  final disc = disciplinasKeys[index - 1];
                  final aulas = frequenciaPorDisciplina[disc]!..sort((a,b) => (b['idSort'] ?? '').toString().compareTo((a['idSort'] ?? '').toString()));
                  final int totalAulas = aulas.length;
                  final int faltas = aulas.where((f) => f['status'] == 'A' || f['status'] == 'J').length;
                  final int presencas = totalAulas - faltas;
                  final double percPresenca = totalAulas == 0 ? 100.0 : (presencas / totalAulas) * 100;

                  return Card(
                    elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: faltas > 0, 
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(disc.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text('Faltas: $faltas / $totalAulas', style: TextStyle(color: faltas > 0 ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(width: 12),
                              Text('Presença: ${percPresenca.toStringAsFixed(1)}%', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                        children: aulas.map((f) {
                          final status = f['status'];
                          Color corStatus = Colors.green; String textoStatus = 'Presente'; IconData iconeStatus = Icons.check_circle_rounded;
                          if (status == 'A') { corStatus = Colors.red; textoStatus = 'Falta'; iconeStatus = Icons.cancel_rounded; } 
                          else if (status == 'J') { corStatus = Colors.orange; textoStatus = 'Falta Justificada'; iconeStatus = Icons.info_rounded; }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16), leading: Icon(Icons.event_available_rounded, color: Colors.grey.shade400, size: 20),
                            title: Text((f['data'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: corStatus.withAlpha(30), borderRadius: BorderRadius.circular(8)), 
                              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(iconeStatus, color: corStatus, size: 14), const SizedBox(width: 4), Text(textoStatus, style: TextStyle(color: corStatus, fontSize: 12, fontWeight: FontWeight.bold))])
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

// ============================================================================
// MURAL DE AVISOS E CHAT COM ABAS (Para o Responsável)
// ============================================================================
class _AvisosModal extends StatefulWidget {
  final String tenantId;
  final String turmaId;
  final String alunoDocId;
  final Color corPrimaria;
  final ScrollController scrollController;
  final String meuId;
  final String nomeResp;
  final String nomeAluno;

  const _AvisosModal({
    required this.tenantId, 
    required this.turmaId, 
    required this.alunoDocId, 
    required this.corPrimaria, 
    required this.scrollController,
    required this.meuId,
    required this.nomeResp,
    required this.nomeAluno,
  });

  @override
  State<_AvisosModal> createState() => _AvisosModalState();
}

class _AvisosModalState extends State<_AvisosModal> {
  int _abaAtual = 0;
  int _limiteAvisos = 5;

  final _formKey = GlobalKey<FormState>();
  final String _destinatario = 'ADMINISTRACAO'; 
  final _tituloCtrl = TextEditingController();
  final _mensagemCtrl = TextEditingController();
  bool _enviando = false;
  
  final List<PlatformFile> _anexosAviso = [];

  Future<void> _escolherAnexos() async {
    if (_anexosAviso.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limite de 3 anexos atingido.'), backgroundColor: Colors.red));
      return;
    }
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (_anexosAviso.length < 3) {
              _anexosAviso.add(file);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao selecionar anexo: $e')));
    }
  }

  Future<void> _enviarAviso() async {
    if (!_formKey.currentState!.validate() && _anexosAviso.isEmpty) return;
    setState(() => _enviando = true);
    
    try {
      final titulo = _tituloCtrl.text.trim();
      final msgBase = _mensagemCtrl.text.trim();
      final msgComTitulo = titulo.isNotEmpty ? "📍 *$titulo*\n\n$msgBase" : msgBase;

      List<Map<String, String>> anexosFinais = [];

      for (var f in _anexosAviso) {
        Uint8List? arquivoBytes;
        File? arquivoFisico;

        if (!kIsWeb && f.path != null) arquivoFisico = File(f.path!);
        arquivoBytes = f.bytes;

        final nomeArquivo = 'anexo_resp_${DateTime.now().millisecondsSinceEpoch}_${f.name.replaceAll(' ', '_')}';
        final storageRef = FirebaseStorage.instance.ref().child('tenants/${widget.tenantId}/avisos_anexos/$nomeArquivo');
        
        if (kIsWeb && arquivoBytes != null) {
          await storageRef.putData(arquivoBytes);
        } else if (arquivoFisico != null) {
          await storageRef.putFile(arquivoFisico);
        } else if (arquivoBytes != null) {
          await storageRef.putData(arquivoBytes);
        }
        
        final url = await storageRef.getDownloadURL();
        
        anexosFinais.add({
          'nome': f.name,
          'url': url,
        });
      }

      final Map<String, dynamic> payload = {
        'titulo': titulo,
        'mensagem': msgComTitulo,
        'dataEnvio': FieldValue.serverTimestamp(),
        'remetenteNome': '${widget.nomeResp} (Resp. por ${widget.nomeAluno})',
        'remetenteId': widget.meuId,
        'tipoDestinatario': _destinatario,
        'alunoId': widget.alunoDocId,
        'alunoNome': widget.nomeAluno,
        'responsavelNome': widget.nomeResp,
        'lidosPor': [widget.alunoDocId, widget.meuId], // LÓGICA DE MARCAR COMO LIDO: O remetente já tem a msg lida
      };

      if (anexosFinais.isNotEmpty) payload['anexos'] = anexosFinais;

      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(widget.tenantId)
          .collection('turmas')
          .doc(widget.turmaId)
          .collection('avisos')
          .add(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensagem enviada com sucesso!'), backgroundColor: Colors.green));
        _tituloCtrl.clear();
        _mensagemCtrl.clear();
        setState(() {
           _anexosAviso.clear();
           _abaAtual = 0; 
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _buildFeedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId).collection('avisos').orderBy('dataEnvio', descending: true).snapshots(),
      builder: (context, snapAvisos) {
        if (snapAvisos.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: widget.corPrimaria));

        final todosAvisos = snapAvisos.data?.docs.map((d) {
          final data = d.data() as Map<String, dynamic>; data['id'] = d.id; return data;
        }).toList() ?? [];
        
        final avisosValidos = todosAvisos.where((aviso) {
          final tipoDest = aviso['tipoDestinatario'];
          final alvoId = aviso['alunoId']?.toString() ?? '';
          final meuAlunoIdStr = widget.alunoDocId.toString();

          if (tipoDest == 'TURMA' || tipoDest == 'TODOS' || tipoDest == 'TURMA_RESPONSAVEIS') return true;
          if ((tipoDest == 'ALUNO' || tipoDest == 'RESPONSAVEL') && alvoId == meuAlunoIdStr) return true;
          if (aviso['remetenteId'] == widget.meuId) return true; 
          
          return false;
        }).toList();

        if (avisosValidos.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.notifications_off_rounded, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Nenhum aviso no mural.', style: TextStyle(color: Colors.grey.shade500))]));
        }

        final int totalItens = avisosValidos.length;
        final int qtdExibidos = totalItens > _limiteAvisos ? _limiteAvisos : totalItens;
        final bool temMais = totalItens > _limiteAvisos;

        return ListView.separated(
          controller: widget.scrollController, padding: const EdgeInsets.all(20),
          itemCount: qtdExibidos + (temMais ? 1 : 0), 
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {

            if (index == qtdExibidos) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: widget.corPrimaria,
                    backgroundColor: widget.corPrimaria.withAlpha(20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  onPressed: () {
                    setState(() { _limiteAvisos = totalItens; });
                  },
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Carregar todos os avisos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              );
            }

            return AvisoCardWidget(
              aviso: avisosValidos[index],
              tenantId: widget.tenantId,
              turmaId: widget.turmaId,
              alunoDocId: widget.alunoDocId,
              corPrimaria: widget.corPrimaria,
              meuId: widget.meuId,
              meuNome: widget.nomeResp
            );
          },
        );
      },
    );
  }

  Widget _buildFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enviar Nova Mensagem', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Selecione para quem deseja enviar o comunicado.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),

            const InputDecorator(
              decoration: InputDecoration(
                labelText: 'Enviar para quem?', 
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.account_balance_rounded),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              child: Text(
                'Secretaria / Administração', 
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _tituloCtrl, 
              decoration: const InputDecoration(labelText: 'Assunto / Título (Opcional)', border: OutlineInputBorder()), 
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _mensagemCtrl, 
              maxLines: 5, 
              decoration: const InputDecoration(labelText: 'Escreva a sua mensagem...', alignLabelWithHint: true, border: OutlineInputBorder()), 
              validator: (v) => v!.isEmpty && _anexosAviso.isEmpty ? 'Escreva uma mensagem ou adicione um anexo.' : null
            ),
            
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _escolherAnexos,
                  icon: Icon(Icons.attach_file_rounded, color: widget.corPrimaria),
                  label: Text('Anexar Arquivos (${_anexosAviso.length}/3)', style: TextStyle(color: widget.corPrimaria, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: widget.corPrimaria),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  ),
                ),
              ],
            ),

            if (_anexosAviso.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: List.generate(_anexosAviso.length, (index) {
                    final anexo = _anexosAviso[index];
                    final isPdf = (anexo.extension ?? '').toLowerCase() == 'pdf';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.corPrimaria.withAlpha(50))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: isPdf ? Colors.red : widget.corPrimaria, size: 20),
                          const SizedBox(width: 8),
                          Flexible(child: Text(anexo.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: widget.corPrimaria), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() { _anexosAviso.removeAt(index); }),
                            child: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                          )
                        ],
                      ),
                    );
                  }),
                ),
              ),

            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: widget.corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _enviando ? null : _enviarAviso, 
                icon: _enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded), 
                label: Text(_enviando ? 'ENVIANDO...' : 'ENVIAR MENSAGEM', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: _abaAtual,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.campaign_rounded, color: widget.corPrimaria)),
                const SizedBox(width: 16),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mural de Avisos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Comunicações da escola', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ])),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          TabBar(
            labelColor: widget.corPrimaria,
            unselectedLabelColor: Colors.grey,
            indicatorColor: widget.corPrimaria,
            indicatorWeight: 3,
            onTap: (index) => setState(() => _abaAtual = index),
            tabs: const [
              Tab(icon: Icon(Icons.history_rounded), text: 'Histórico de Avisos'),
              Tab(icon: Icon(Icons.send_rounded), text: 'Nova Mensagem'),
            ]
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(), // Evita deslizar por engano quando digita
              children: [
                _buildFeedTab(),
                _buildFormTab(),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Widget isolado para os cards de aviso no feed (Formato Cascata/ExpansionTile)
class AvisoCardWidget extends StatelessWidget {
  final Map<String, dynamic> aviso;
  final String tenantId;
  final String turmaId;
  final String alunoDocId;
  final Color corPrimaria;
  final String meuId;
  final String meuNome;

  const AvisoCardWidget({
    super.key, 
    required this.aviso, 
    required this.tenantId, 
    required this.turmaId, 
    required this.alunoDocId, 
    required this.corPrimaria,
    required this.meuId,
    required this.meuNome
  });

  void _abrirChat(BuildContext context, DocumentReference avisoRef) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatAvisoModal(
        avisoRef: avisoRef,
        avisoData: aviso,
        meuId: meuId,
        meuNome: meuNome,
        corPrimaria: corPrimaria,
        alunoId: alunoDocId,
        tenantId: tenantId,
      ),
    );

    // LÓGICA DE MARCAR COMO LIDO: Marca as respostas não lidas como lidas assim que abre
    avisoRef.collection('respostas').get().then((snap) {
      final batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['remetenteId'] != meuId && data['lidaPorResponsavel'] != true) {
          batch.update(doc.reference, {'lidaPorResponsavel': true});
          hasUpdates = true;
        }
      }
      if (hasUpdates) batch.commit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataEnvio = aviso['dataEnvio'];
    final textoData = dataEnvio != null && dataEnvio is Timestamp ? DateFormat('dd/MM HH:mm').format(dataEnvio.toDate()) : '';
    
    final tipoDest = aviso['tipoDestinatario'];
    final isMeu = aviso['remetenteId'] == meuId;
    
    final remetenteOriginal = isMeu ? 'Enviado por você' : (aviso['remetenteNome'] ?? 'Direção / Professor').toString();
    bool isProfessor = remetenteOriginal.contains('Professor(a)');

    String tagDestino = 'Para toda a turma';
    Color corTag = Colors.blue;
    
    if (isMeu) {
      tagDestino = tipoDest == 'ADMINISTRACAO' ? 'Enviado para: Administração' : 'Enviado para: Professores';
      corTag = Colors.teal;
    } else if (tipoDest == 'ALUNO') {
      tagDestino = 'Direcionado ao Aluno';
      corTag = Colors.purple;
    } else if (tipoDest == 'RESPONSAVEL') {
      tagDestino = 'Apenas para você';
      corTag = Colors.red;
    } else if (tipoDest == 'TODOS') {
      tagDestino = 'Para Toda a Escola';
      corTag = Colors.green;
    }

    final lidosPor = List<String>.from(aviso['lidosPor'] ?? []);
    final isLidoMsgOriginal = isMeu || lidosPor.contains(alunoDocId);

    final avisoRef = FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId).collection('avisos').doc(aviso['id']);

    List<dynamic> anexosList = aviso['anexos'] as List<dynamic>? ?? [];
    if (aviso['anexoUrl'] != null && aviso['anexoUrl'].toString().isNotEmpty && anexosList.isEmpty) {
       anexosList.add({
         'nome': (aviso['anexoNome'] ?? 'Anexo').toString(),
         'url': aviso['anexoUrl'].toString(),
       });
    }

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLidoMsgOriginal ? Colors.grey.shade300 : Colors.blue.shade300, 
          width: isLidoMsgOriginal ? 1 : 1.5
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: corTag.withAlpha(20), borderRadius: BorderRadius.circular(12)),
            child: Icon(isProfessor ? Icons.assignment_ind_rounded : Icons.admin_panel_settings_rounded, color: isMeu ? corTag : corPrimaria, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  remetenteOriginal,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isMeu ? corTag : Colors.black87),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isLidoMsgOriginal)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                  child: const Text('NOVA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                )
            ]
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(textoData, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: corTag.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                  child: Text(tagDestino, style: TextStyle(color: corTag, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          onExpansionChanged: (expanded) {
            // LÓGICA DE MARCAR COMO LIDO: O utilizador abriu a cascata, o sistema marca logo como lido!
            if (expanded && !isLidoMsgOriginal) {
              avisoRef.update({'lidosPor': FieldValue.arrayUnion([alunoDocId])});
            }
          },
          children: [
            const Divider(),
            const SizedBox(height: 8),
            
            if ((aviso['mensagem'] ?? '').toString().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  (aviso['mensagem'] ?? '').toString(),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
              ),

            if (anexosList.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 12, runSpacing: 12,
                  children: anexosList.map((anexo) {
                    final String url = (anexo['url'] ?? '').toString();
                    final String nome = (anexo['nome'] ?? 'Anexo').toString();
                    final bool isPdf = nome.toLowerCase().endsWith('.pdf');

                    return Tooltip(
                      message: 'Clique para expandir e baixar',
                      child: InkWell(
                        onTap: () => _mostrarAnexoAmpliadoGlobal(context, url, isPdf, corPrimaria),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: isPdf ? Colors.red.shade50 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            image: !isPdf 
                                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                                : null,
                          ),
                          child: Stack(
                            children: [
                              if (isPdf)
                                const Center(child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 36)),
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(150),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                                  ),
                                  child: Text(isPdf ? 'PDF' : 'FOTO', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: avisoRef.collection('respostas').snapshots(),
                  builder: (context, snapRespostas) {
                    int naoLidos = 0;
                    if (snapRespostas.hasData) {
                      for (var doc in snapRespostas.data!.docs) {
                        final rData = doc.data() as Map<String, dynamic>;
                        if (rData['remetenteId'] != meuId && rData['lidaPorResponsavel'] != true) {
                          naoLidos++;
                        }
                      }
                    }
                    
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: corPrimaria,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            backgroundColor: corPrimaria.withAlpha(10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                          ),
                          onPressed: () {
                            if (!isLidoMsgOriginal) {
                              avisoRef.update({'lidosPor': FieldValue.arrayUnion([alunoDocId])});
                            }
                            _abrirChat(context, avisoRef);
                          },
                          icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: corPrimaria),
                          label: Text('Ver Respostas / Responder', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (naoLidos > 0)
                          Positioned(
                            top: -4, right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                              child: Text(naoLidos > 9 ? '9+' : naoLidos.toString(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            ),
                          )
                      ],
                    );
                  }
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CHAT DO AVISO COM ANEXOS E MINIATURAS (Para o Responsável)
// ============================================================================
class _ChatAvisoModal extends StatefulWidget {
  final DocumentReference avisoRef;
  final Map<String, dynamic> avisoData;
  final String meuId;
  final String meuNome;
  final Color corPrimaria;
  final String tenantId;
  final String alunoId;

  const _ChatAvisoModal({required this.avisoRef, required this.avisoData, required this.meuId, required this.meuNome, required this.corPrimaria, required this.tenantId, required this.alunoId});

  @override
  State<_ChatAvisoModal> createState() => _ChatAvisoModalState();
}

class _ChatAvisoModalState extends State<_ChatAvisoModal> {
  final TextEditingController _msgCtrl = TextEditingController();
  bool _enviando = false;
  
  final List<PlatformFile> _anexosChat = [];

  Future<void> _escolherAnexosChat() async {
    if (_anexosChat.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limite de 3 anexos atingido.'), backgroundColor: Colors.red));
      return;
    }
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (_anexosChat.length < 3) {
              _anexosChat.add(file);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao selecionar anexo: $e')));
    }
  }

  Future<void> _enviarResposta() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty && _anexosChat.isEmpty) return;

    setState(() => _enviando = true);
    try {
      List<Map<String, String>> anexosFinais = [];

      for (var f in _anexosChat) {
        Uint8List? arquivoBytes;
        File? arquivoFisico;

        if (!kIsWeb && f.path != null) arquivoFisico = File(f.path!);
        arquivoBytes = f.bytes;

        final nomeArquivo = 'anexo_resp_${DateTime.now().millisecondsSinceEpoch}_${f.name.replaceAll(' ', '_')}';
        final storageRef = FirebaseStorage.instance.ref().child('tenants/${widget.tenantId}/avisos_anexos/$nomeArquivo');
        
        if (kIsWeb && arquivoBytes != null) {
          await storageRef.putData(arquivoBytes);
        } else if (arquivoFisico != null) {
          await storageRef.putFile(arquivoFisico);
        } else if (arquivoBytes != null) {
          await storageRef.putData(arquivoBytes);
        }
        
        final url = await storageRef.getDownloadURL();
        
        anexosFinais.add({
          'nome': f.name,
          'url': url,
        });
      }

      final Map<String, dynamic> payload = {
        'texto': texto,
        'dataEnvio': FieldValue.serverTimestamp(),
        'remetenteId': widget.meuId,
        'remetenteNome': widget.meuNome,
        'alunoIdReferencia': widget.alunoId,
        'lidaPorResponsavel': true, // Pai enviou, já leu
      };

      if (anexosFinais.isNotEmpty) payload['anexos'] = anexosFinais;

      await widget.avisoRef.collection('respostas').add(payload);
      
      _msgCtrl.clear();
      setState(() {
        _anexosChat.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    
    // Traz os anexos originais do aviso para exibir no topo do chat
    List<dynamic> anexosOriginalList = widget.avisoData['anexos'] as List<dynamic>? ?? [];
    if (widget.avisoData['anexoUrl'] != null && widget.avisoData['anexoUrl'].toString().isNotEmpty && anexosOriginalList.isEmpty) {
       anexosOriginalList.add({
         'nome': (widget.avisoData['anexoNome'] ?? 'Anexo').toString(),
         'url': widget.avisoData['anexoUrl'].toString(),
       });
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), shape: BoxShape.circle), child: Icon(Icons.forum_rounded, color: widget.corPrimaria, size: 20)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Respostas ao Aviso', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),

            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aviso Original de ${(widget.avisoData['remetenteNome'] ?? '').toString()}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text((widget.avisoData['mensagem'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  
                  if (anexosOriginalList.isNotEmpty) 
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Wrap(
                        spacing: 12, runSpacing: 12,
                        children: anexosOriginalList.map((anexo) {
                          final String url = (anexo['url'] ?? '').toString();
                          final String nome = (anexo['nome'] ?? 'Anexo').toString();
                          final bool isPdf = nome.toLowerCase().endsWith('.pdf');

                          return Tooltip(
                            message: 'Clique para expandir e baixar',
                            child: InkWell(
                              onTap: () => _mostrarAnexoAmpliadoGlobal(context, url, isPdf, widget.corPrimaria),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 70, height: 70,
                                decoration: BoxDecoration(
                                  color: isPdf ? Colors.red.shade50 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                  image: !isPdf ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
                                ),
                                child: Stack(
                                  children: [
                                    if (isPdf) const Center(child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 30)),
                                    Positioned(
                                      bottom: 0, left: 0, right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.black.withAlpha(150), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11))),
                                        child: Text(isPdf ? 'PDF' : 'FOTO', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.black12),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.avisoRef.collection('respostas').orderBy('dataEnvio', descending: false).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
                  
                  final respostas = snapshot.data?.docs ?? [];
                  if (respostas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Nenhuma resposta ainda.', style: TextStyle(color: Colors.grey.shade500)),
                          Text('Seja o primeiro a enviar uma mensagem!', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      )
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: respostas.length,
                    itemBuilder: (context, index) {
                      final resp = respostas[index].data() as Map<String, dynamic>;
                      final isMeu = (resp['remetenteId'] ?? '').toString() == widget.meuId;
                      final dataTime = resp['dataEnvio'] as Timestamp?;
                      final hora = dataTime != null ? DateFormat('HH:mm').format(dataTime.toDate()) : '...';
                      String remetenteExibicao = (resp['remetenteNome'] ?? 'Usuário').toString();

                      // Extrair anexos das respostas (Formato novo list vs Formato antigo map)
                      List<dynamic> anexosRespList = resp['anexos'] as List<dynamic>? ?? [];
                      if (resp['anexoUrl'] != null && resp['anexoUrl'].toString().isNotEmpty && anexosRespList.isEmpty) {
                        anexosRespList.add({
                          'nome': (resp['anexoNome'] ?? 'Anexo').toString(),
                          'url': resp['anexoUrl'].toString(),
                        });
                      }

                      return Align(
                        alignment: isMeu ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMeu ? widget.corPrimaria.withAlpha(20) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMeu ? const Radius.circular(0) : null,
                              bottomLeft: !isMeu ? const Radius.circular(0) : null,
                            )
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMeu ? 'Você' : remetenteExibicao, 
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMeu ? widget.corPrimaria : Colors.grey.shade700)
                              ),
                              const SizedBox(height: 4),

                              if (anexosRespList.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Wrap(
                                    spacing: 8, runSpacing: 8,
                                    children: anexosRespList.map((anx) {
                                      final String urlAnx = (anx['url'] ?? '').toString();
                                      final String nomeAnx = (anx['nome'] ?? 'Anexo').toString();
                                      final bool isPdfAnx = nomeAnx.toLowerCase().endsWith('.pdf');

                                      return Tooltip(
                                        message: 'Clique para expandir e baixar',
                                        child: InkWell(
                                          onTap: () => _mostrarAnexoAmpliadoGlobal(context, urlAnx, isPdfAnx, widget.corPrimaria),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 60, height: 60,
                                            decoration: BoxDecoration(
                                              color: isPdfAnx ? Colors.red.shade50 : Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade300),
                                              image: !isPdfAnx ? DecorationImage(image: NetworkImage(urlAnx), fit: BoxFit.cover) : null,
                                            ),
                                            child: Stack(
                                              children: [
                                                if (isPdfAnx) const Center(child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 24)),
                                                Positioned(
                                                  bottom: 0, left: 0, right: 0,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.black.withAlpha(150), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7))),
                                                    child: Text(isPdfAnx ? 'PDF' : 'FOTO', style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),

                              if ((resp['texto'] ?? '').toString().isNotEmpty)
                                Text((resp['texto'] ?? '').toString(), style: const TextStyle(fontSize: 14)),
                              
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(hora, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            if (_anexosChat.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.blue.shade50,
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: List.generate(_anexosChat.length, (index) {
                    final anexo = _anexosChat[index];
                    final isPdf = (anexo.extension ?? '').toLowerCase() == 'pdf';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: isPdf ? Colors.red : Colors.blue, size: 16),
                          const SizedBox(width: 6),
                          Flexible(child: Text(anexo.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() { _anexosChat.removeAt(index); }),
                            child: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
                          )
                        ],
                      ),
                    );
                  }),
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]),
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.attach_file_rounded, color: Colors.grey.shade600), onPressed: _escolherAnexosChat, tooltip: 'Anexar Arquivos (${_anexosChat.length}/3)'),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Escreva uma resposta...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: widget.corPrimaria, shape: BoxShape.circle),
                    child: IconButton(
                      icon: _enviando 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _enviando ? null : _enviarResposta,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}