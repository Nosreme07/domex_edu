import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';
import '../estado/aluno_dashboard_provider.dart'; // <--- O NOSSO NOVO PROVIDER

// ============================================================================
// FUNÇÃO GLOBAL: ABRIR FOTO EM TELA CHEIA 
// ============================================================================
void _mostrarFotoAmpliadaGlobal(BuildContext context, String? url) {
  if (url == null || url.isEmpty) return;
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    ),
  );
}

class AlunoDashboardTela extends ConsumerStatefulWidget {
  const AlunoDashboardTela({super.key});

  @override
  ConsumerState<AlunoDashboardTela> createState() => _AlunoDashboardTelaState();
}

class _AlunoDashboardTelaState extends ConsumerState<AlunoDashboardTela> {
  bool _atualizandoFoto = false;

  // ==========================================================================
  // LÓGICA DE FOTO (CÂMERA, GALERIA E CORTE)
  // ==========================================================================
  void _abrirOpcoesFoto(String tenantId, String alunoDocId, String urlAtual) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Foto do Aluno', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (urlAtual.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.zoom_in_rounded, color: Colors.purple),
                title: const Text('Ver foto ampliada'),
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarFotoAmpliadaGlobal(context, urlAtual);
                },
              ),
            if (urlAtual.isNotEmpty) const Divider(),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
              title: const Text('Tirar Foto Agora (Câmera)'),
              onTap: () {
                Navigator.pop(ctx);
                _capturarERecortarFoto(ImageSource.camera, tenantId, alunoDocId);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.orange),
              title: const Text('Escolher da Galeria'),
              onTap: () {
                Navigator.pop(ctx);
                _capturarERecortarFoto(ImageSource.gallery, tenantId, alunoDocId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturarERecortarFoto(ImageSource source, String tenantId, String alunoDocId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final XFile? fotoOriginal = await picker.pickImage(source: source, imageQuality: 70);
      
      if (fotoOriginal == null) return;
      if (!mounted) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: fotoOriginal.path,
        aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 4),
        uiSettings: kIsWeb 
          ? [WebUiSettings(context: context)]
          : [
              AndroidUiSettings(
                toolbarTitle: 'Enquadrar Foto 3x4',
                toolbarColor: Theme.of(context).primaryColor,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.original,
                lockAspectRatio: true,
              ),
              IOSUiSettings(title: 'Enquadrar Foto'),
            ],
      );

      if (croppedFile != null) {
        setState(() => _atualizandoFoto = true);
        final bytes = await croppedFile.readAsBytes();
        String extensao = croppedFile.path.split('.').last.toLowerCase();
        if (extensao != 'png' && extensao != 'jpg' && extensao != 'jpeg') extensao = 'jpg';

        final nomeArquivo = 'aluno_${alunoDocId}_${DateTime.now().millisecondsSinceEpoch}.$extensao';
        final refStorage = FirebaseStorage.instance.ref('tenants/$tenantId/alunos_fotos/$nomeArquivo');

        final metadata = SettableMetadata(contentType: 'image/$extensao');
        await refStorage.putData(bytes, metadata); 
        final novaUrl = await refStorage.getDownloadURL();

        await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('alunos').doc(alunoDocId).update({'fotoUrl': novaUrl});
        
        // Atualiza a tela automaticamente buscando os novos dados
        ref.invalidate(dadosAlunoProvider);
        
        messenger.showSnackBar(const SnackBar(content: Text('Foto de perfil atualizada com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao processar foto: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _atualizandoFoto = false);
    }
  }

  // ==========================================================================
  // LÓGICA DE GRADE DE AULAS COM CASCATA (ACCORDION)
  // ==========================================================================
  String _obterDiaSemanaAtual() {
    switch (DateTime.now().weekday) {
      case 1: return 'SEGUNDA';
      case 2: return 'TERÇA';
      case 3: return 'QUARTA';
      case 4: return 'QUINTA';
      case 5: return 'SEXTA';
      case 6: return 'SÁBADO';
      case 7: return 'DOMINGO';
      default: return 'SEGUNDA';
    }
  }

  void _abrirGradeDeAulas(String? turmaId, String turmaNome, Color corPrimaria) {
    if (turmaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sua matrícula não está vinculada a uma turma.'), backgroundColor: Colors.red));
      return;
    }

    final String diaAtual = _obterDiaSemanaAtual();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) {
            return FutureBuilder<List<dynamic>>(
              future: ref.read(gradeAulasAlunoProvider(turmaId).future), // <--- USANDO O NOSSO PROVIDER
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: corPrimaria));
                }
                
                final horariosRaw = snapshot.data ?? [];
                
                if (horariosRaw.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('A coordenação ainda não cadastrou a grade de aulas.', style: TextStyle(color: Colors.grey, fontSize: 15)),
                    ],
                  );
                }

                final ordemDias = {'SEGUNDA': 1, 'TERÇA': 2, 'QUARTA': 3, 'QUINTA': 4, 'SEXTA': 5, 'SÁBADO': 6, 'DOMINGO': 7};
                final Map<String, List<Map<String, dynamic>>> horariosPorDia = {
                  'SEGUNDA': [], 'TERÇA': [], 'QUARTA': [], 'QUINTA': [], 'SEXTA': [], 'SÁBADO': [], 'DOMINGO': []
                };
                
                for (var h in horariosRaw) {
                  final dia = (h['dia'] ?? '').toString().toUpperCase();
                  if (horariosPorDia.containsKey(dia)) {
                    horariosPorDia[dia]!.add(Map<String, dynamic>.from(h));
                  }
                }
                
                for (var dia in horariosPorDia.keys) {
                  horariosPorDia[dia]!.sort((a, b) => (a['inicio'] ?? '').toString().compareTo((b['inicio'] ?? '').toString()));
                }

                final diasComAula = horariosPorDia.entries.where((e) => e.value.isNotEmpty).toList();
                diasComAula.sort((a, b) => (ordemDias[a.key] ?? 99).compareTo(ordemDias[b.key] ?? 99));

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.view_list_rounded, color: corPrimaria)),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Grade de Aulas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(turmaNome, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ])),
                          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: diasComAula.length,
                        itemBuilder: (context, index) {
                          final dia = diasComAula[index].key;
                          final aulas = diasComAula[index].value;
                          final isExpandidoPadrao = dia == diaAtual;
                          
                          return _DiaGradeItem(
                            dia: dia, 
                            aulas: aulas, 
                            expandidoPorPadrao: isExpandidoPadrao, 
                            corPrimaria: corPrimaria
                          );
                        },
                      ),
                    )
                  ],
                );
              }
            );
          }
        );
      }
    );
  }

  Widget _buildAtalho(String titulo, IconData icone, Color corPrimaria, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: corPrimaria.withAlpha(15), blurRadius: 8, offset: const Offset(0, 2))
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: corPrimaria.withAlpha(20), shape: BoxShape.circle),
                child: Icon(icone, color: corPrimaria, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarioLogado = ref.watch(authProvider).value;
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    if (usuarioLogado == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final tenantId = usuarioLogado.tenantId; 
    final nomeEscola = usuarioLogado.nomeEscola ?? 'Escola Domex Edu';
    final corPrimaria = usuarioLogado.corPrimaria;

    // Escutando o Provider do Perfil do Aluno
    final dadosAlunoAsync = ref.watch(dadosAlunoProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const SizedBox.shrink(),
        leading: isMobile 
            ? IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () {
                  Scaffold.maybeOf(context)?.openDrawer();
                },
              )
            : null,
      ),
      body: dadosAlunoAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
        error: (e, s) => Center(child: Text('Erro: $e')),
        data: (aluno) {
          if (aluno == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Perfil de aluno não encontrado.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('As credenciais não estão vinculadas a nenhuma matrícula válida.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final nomeCompleto = aluno['nome'] ?? 'Estudante';
          final primeiroNome = nomeCompleto.split(' ').first;
          final turmaNome = aluno['turma'] ?? 'Sem Turma';
          final turmaId = aluno['turmaId']?.toString() ?? '';
          final fotoUrl = aluno['fotoUrl'] ?? '';
          final alunoDocId = aluno['docId'];

          // Escutando Avaliações e Avisos através dos nossos Providers
          final avaliacoesAsync = ref.watch(avaliacoesAlunoStreamProvider(turmaId));
          final avisosAsync = ref.watch(avisosAlunoStreamProvider(turmaId));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================================
                // CABEÇALHO HERO ULTRA-COMPACTO E OTIMIZADO
                // ============================================================
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(isMobile ? 24 : 40, 0, isMobile ? 24 : 40, 32),
                  decoration: BoxDecoration(
                    color: corPrimaria,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                    boxShadow: [BoxShadow(color: corPrimaria.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nomeEscola.toUpperCase(),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Olá, $primeiroNome 👋',
                                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              InkWell(
                                onTap: () => _abrirOpcoesFoto(tenantId, alunoDocId, fotoUrl),
                                borderRadius: BorderRadius.circular(45),
                                child: CircleAvatar(
                                  radius: isMobile ? 35 : 45,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: isMobile ? 32 : 42,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
                                    child: fotoUrl.isEmpty ? Icon(Icons.person, size: 40, color: corPrimaria) : null,
                                  ),
                                ),
                              ),
                              if (_atualizandoFoto)
                                const Positioned.fill(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              else
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: Icon(Icons.camera_alt_rounded, color: corPrimaria, size: 14),
                                )
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                turmaNome, 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
                          _buildAtalho('Grade de\nAulas', Icons.view_list_rounded, corPrimaria, () {
                            _abrirGradeDeAulas(turmaId, turmaNome, corPrimaria);
                          }),
                          const SizedBox(width: 16),
                          _buildAtalho('Meu\nBoletim', Icons.analytics_rounded, corPrimaria, () {
                            context.go('/aluno/boletim');
                          }),
                          const SizedBox(width: 16),
                          _buildAtalho('Calendário\nEscolar', Icons.calendar_month_rounded, corPrimaria, () {
                            context.go('/aluno/calendario');
                          }),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // ============================================================
                      // PRÓXIMAS AVALIAÇÕES
                      // ============================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Próximas Avaliações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400)
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      avaliacoesAsync.when(
                        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
                        error: (err, stack) => const Text('Erro ao carregar avaliações'),
                        data: (avaliacoes) {
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
                                final aval = avaliacoes[index];
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
                        },
                      ),

                      const SizedBox(height: 40),

                      // ============================================================
                      // MURAL DE AVISOS
                      // ============================================================
                      Row(
                        children: [
                          Icon(Icons.campaign_rounded, color: corPrimaria),
                          const SizedBox(width: 8),
                          const Text('Mural de Avisos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      avisosAsync.when(
                        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
                        error: (err, stack) => const Text('Erro ao carregar avisos'),
                        data: (todosAvisos) {
                          final avisosAluno = todosAvisos.where((aviso) {
                            final tipoDest = aviso['tipoDestinatario'];
                            final alvoId = aviso['alunoId'];

                            if (tipoDest == 'TURMA' || tipoDest == 'TODOS') return true;
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
                              final aviso = avisosAluno[index];
                              final dataEnvio = aviso['dataEnvio'];
                              final textoData = dataEnvio != null ? DateFormat('dd/MM HH:mm').format((dataEnvio as dynamic).toDate()) : '';
                              final isDireto = aviso['tipoDestinatario'] == 'ALUNO' || aviso['tipoDestinatario'] == 'RESPONSAVEL';
                              
                              final remetenteOriginal = (aviso['remetenteNome'] ?? 'Direção / Professor').toString();
                              bool isProfessor = remetenteOriginal.contains('Professor(a)');

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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(isProfessor ? Icons.assignment_ind_rounded : Icons.admin_panel_settings_rounded, size: 16, color: isDireto ? Colors.orange.shade800 : corPrimaria),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  remetenteOriginal,
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDireto ? Colors.orange.shade900 : Colors.black87),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
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

// ============================================================================
// WIDGET INTERNO: ITEM DA GRADE DE AULAS (ACCORDION COM CORES DINÂMICAS)
// ============================================================================
class _DiaGradeItem extends StatefulWidget {
  final String dia;
  final List<Map<String, dynamic>> aulas;
  final bool expandidoPorPadrao;
  final Color corPrimaria;

  const _DiaGradeItem({
    required this.dia,
    required this.aulas,
    required this.expandidoPorPadrao,
    required this.corPrimaria,
  });

  @override
  State<_DiaGradeItem> createState() => _DiaGradeItemState();
}

class _DiaGradeItemState extends State<_DiaGradeItem> {
  late bool _expandido;

  @override
  void initState() {
    super.initState();
    _expandido = widget.expandidoPorPadrao;
  }

  // Gera uma cor consistente para cada disciplina
  Color _getCorDisciplina(String nome) {
    final cores = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
      Colors.brown, Colors.cyan, Colors.deepOrange
    ];
    if (nome.isEmpty) return Colors.grey;
    int hash = 0;
    for (int i = 0; i < nome.length; i++) {
      hash = nome.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return cores[hash.abs() % cores.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _expandido ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _expandido ? widget.corPrimaria.withAlpha(100) : Colors.grey.shade200),
        boxShadow: _expandido ? [BoxShadow(color: widget.corPrimaria.withAlpha(20), blurRadius: 8, offset: const Offset(0, 4))] : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandido = !_expandido;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 20, color: _expandido ? widget.corPrimaria : Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.dia, 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _expandido ? widget.corPrimaria : Colors.black87)
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expandido ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: _expandido ? widget.corPrimaria : Colors.grey),
                  )
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: widget.aulas.map((aula) {
                  final String nomeDisciplina = aula['disciplina'] ?? 'Disciplina';
                  final Color corMateria = _getCorDisciplina(nomeDisciplina);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(width: 6, decoration: BoxDecoration(color: corMateria, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: corMateria.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                    child: Icon(Icons.class_rounded, color: corMateria, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(nomeDisciplina, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(aula['professorNome'] ?? 'Professor', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                    child: Text('${aula['inicio']} às ${aula['fim']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _expandido ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}