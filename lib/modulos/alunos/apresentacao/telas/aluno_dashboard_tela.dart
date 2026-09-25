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
import '../estado/aluno_dashboard_provider.dart'; 

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

// ============================================================================
// CONTROLLER GLOBAL PARA O MENU LATERAL ACESSAR OS POPUPS
// ============================================================================
class AlunoDashboardController {
  static void Function(String tenantId, String turmaId, String alunoDocId, Color cor)? abrirBoletim;
  static void Function(String tenantId, String turmaId, String matricula, Color cor)? abrirFrequencia;
  
  static String tenantId = '';
  static String turmaId = '';
  static String alunoDocId = '';
  static String matricula = '';
  static Color corPrimaria = Colors.blue;
}

class AlunoDashboardTela extends ConsumerStatefulWidget {
  const AlunoDashboardTela({super.key});

  @override
  ConsumerState<AlunoDashboardTela> createState() => _AlunoDashboardTelaState();
}

class _AlunoDashboardTelaState extends ConsumerState<AlunoDashboardTela> {
  bool _atualizandoFoto = false;
  bool _muralExpandido = false;
  bool _avaliacoesExpandidas = false;

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
      final XFile? fotoOriginal = await picker.pickImage(
        source: source, 
        imageQuality: 50,  
        maxWidth: 600,     
        maxHeight: 600,    
      );
      
      if (fotoOriginal == null) return;
      if (!mounted) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: fotoOriginal.path,
        aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 4),
        compressQuality: 50,
        compressFormat: ImageCompressFormat.jpg,
        maxWidth: 600,
        maxHeight: 800,
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
              IOSUiSettings(title: 'Enquadrar Foto 3x4', aspectRatioLockEnabled: true),
            ],
      );

      if (croppedFile != null) {
        setState(() => _atualizandoFoto = true);
        final bytes = await croppedFile.readAsBytes();
        
        final nomeArquivo = 'aluno_portal_${alunoDocId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final refStorage = FirebaseStorage.instance.ref('tenants/$tenantId/alunos_fotos_portal/$nomeArquivo');

        final metadata = SettableMetadata(contentType: 'image/jpeg');
        await refStorage.putData(bytes, metadata); 
        final novaUrl = await refStorage.getDownloadURL();

        await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('alunos').doc(alunoDocId).update({'fotoPortalUrl': novaUrl});
        
        ref.invalidate(dadosAlunoProvider);
        
        messenger.showSnackBar(const SnackBar(content: Text('Sua foto de perfil foi atualizada!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao processar foto: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _atualizandoFoto = false);
    }
  }

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
              future: ref.read(gradeAulasAlunoProvider(turmaId).future),
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

  void _abrirBoletim(String tenantId, String turmaId, String alunoDocId, Color corPrimaria) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) {
            return _BoletimModal(
              tenantId: tenantId,
              turmaId: turmaId,
              alunoDocId: alunoDocId,
              corPrimaria: corPrimaria,
              scrollController: scrollController,
            );
          }
        );
      }
    );
  }

  void _abrirFrequencia(String tenantId, String turmaId, String matricula, Color corPrimaria) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) {
            return _FrequenciaModal(
              tenantId: tenantId,
              turmaId: turmaId,
              alunoMatricula: matricula,
              corPrimaria: corPrimaria,
              scrollController: scrollController,
            );
          }
        );
      }
    );
  }

  void _abrirTodasAvaliacoes(String tenantId, String? turmaId, String alunoDocId, Color corPrimaria) {
    if (turmaId == null || turmaId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.grading_rounded, color: corPrimaria)),
                      const SizedBox(width: 16),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Histórico de Avaliações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Todos os testes e trabalhos', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ])),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId).collection('avaliacoes').orderBy('dataAvaliacao', descending: true).get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: corPrimaria));
                      
                      final avaliacoes = snapshot.data?.docs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        data['id'] = d.id;
                        return data;
                      }).toList() ?? [];
                      
                      if (avaliacoes.isEmpty) {
                        return Center(child: Text('Nenhuma avaliação encontrada.', style: TextStyle(color: Colors.grey.shade500)));
                      }

                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: avaliacoes.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final aval = avaliacoes[index];
                          final notas = Map<String, dynamic>.from(aval['notas'] ?? {});
                          final notaDoAluno = notas[alunoDocId];
                          
                          final max = double.tryParse(aval['pontuacaoMaxima']?.toString() ?? '10') ?? 10.0;
                          
                          Color corNota = Colors.grey.shade600;
                          String textoNota = 'Valendo $max pts';
                          
                          if (notaDoAluno != null) {
                            final double notaNum = double.tryParse(notaDoAluno.toString()) ?? 0.0;
                            final bool acimaMedia = notaNum >= (max * 0.6);
                            corNota = acimaMedia ? Colors.green.shade700 : Colors.red.shade700;
                            textoNota = 'Nota: $notaDoAluno / $max';
                          }

                          return InkWell(
                            onTap: () => _mostrarDetalhesAvaliacao(aval, notaDoAluno, max, corNota, corPrimaria),
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
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.blueGrey.shade50, shape: BoxShape.circle),
                                    child: Icon(Icons.edit_document, color: Colors.blueGrey.shade400, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(aval['nome'] ?? 'Avaliação', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text('${aval['disciplina'] ?? 'Geral'} • ${_formatarDataDisplay(aval['dataAvaliacao'] ?? '')}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: notaDoAluno != null ? corNota.withAlpha(20) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                    child: Text(textoNota, style: TextStyle(color: notaDoAluno != null ? corNota : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
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
        );
      }
    );
  }

  void _mostrarDetalhesAvaliacao(Map<String, dynamic> aval, dynamic notaDoAluno, double max, Color corNota, Color corPrimaria) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(aval['nome'] ?? 'Detalhes', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Disciplina: ${aval['disciplina'] ?? 'Geral'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Data: ${_formatarDataDisplay(aval['dataAvaliacao'] ?? '')}'),
            const SizedBox(height: 8),
            Text('Bimestre: ${aval['bimestre'] ?? ''}'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            if (aval['descricao'] != null && aval['descricao'].toString().isNotEmpty) ...[
              const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              Text(aval['descricao']),
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: notaDoAluno != null ? corNota.withAlpha(20) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Text('Sua Nota', style: TextStyle(fontSize: 12, color: notaDoAluno != null ? corNota : Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    notaDoAluno != null ? '$notaDoAluno / $max' : 'Aguardando Correção\n(Valendo $max pts)', 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: notaDoAluno != null ? corNota : Colors.grey.shade700)
                  ),
                ],
              ),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      )
    );
  }

  void _abrirHistoricoAvisos(List<dynamic> avisosAluno, String tenantId, String turmaId, String alunoDocId, Color corPrimaria) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.history_edu_rounded, color: corPrimaria)),
                      const SizedBox(width: 16),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Histórico de Avisos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Todas as mensagens recebidas', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ])),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: avisosAluno.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildAvisoCard(avisosAluno[index], tenantId, turmaId, alunoDocId, corPrimaria);
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
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

  Widget _buildAvisoCard(dynamic avisoData, String tenantId, String turmaId, String alunoDocId, Color corPrimaria) {
    final aviso = avisoData as Map<String, dynamic>;
    final dataEnvio = aviso['dataEnvio'];
    final textoData = dataEnvio != null ? DateFormat('dd/MM HH:mm').format((dataEnvio as dynamic).toDate()) : '';
    final isDireto = aviso['tipoDestinatario'] == 'ALUNO' || aviso['tipoDestinatario'] == 'RESPONSAVEL';
    
    final remetenteOriginal = (aviso['remetenteNome'] ?? 'Direção / Professor').toString();
    bool isProfessor = remetenteOriginal.contains('Professor(a)');

    final tagDestino = isDireto ? 'Apenas para você' : 'Para toda a turma';
    final corDestino = isDireto ? Colors.red : Colors.blue;

    final lidosPor = List<String>.from(aviso['lidosPor'] ?? []);
    final isLido = lidosPor.contains(alunoDocId);

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(textoData, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (!isLido) ...[
                    const SizedBox(height: 8),
                    Tooltip(
                      message: 'Marcar como lido',
                      child: InkWell(
                        onTap: () {
                          FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId).collection('avisos').doc(aviso['id']).update({
                            'lidosPor': FieldValue.arrayUnion([alunoDocId])
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle, border: Border.all(color: Colors.green.shade200)),
                          child: Icon(Icons.remove_red_eye_rounded, size: 16, color: Colors.green.shade600),
                        ),
                      ),
                    )
                  ]
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: corDestino.withAlpha(20), borderRadius: BorderRadius.circular(6)),
            child: Text(tagDestino, style: TextStyle(color: corDestino, fontSize: 10, fontWeight: FontWeight.bold)),
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
  }

  @override
  Widget build(BuildContext context) {
    final usuarioLogado = ref.watch(authProvider).value;
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    if (usuarioLogado == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final tenantId = usuarioLogado.tenantId; 
    final corPrimaria = usuarioLogado.corPrimaria;

    final dadosAlunoAsync = ref.watch(dadosAlunoProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Portal do Aluno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          final turmaNome = aluno['turma'] ?? 'Sem Turma';
          final turmaId = aluno['turmaId']?.toString() ?? '';
          
          final fotoOficial = aluno['fotoUrl'] ?? '';
          final fotoPortal = aluno['fotoPortalUrl'] ?? '';
          final fotoUrl = fotoPortal.isNotEmpty ? fotoPortal : fotoOficial;
          
          final alunoDocId = aluno['docId'];
          final matricula = (aluno['matricula'] ?? '').toString();
          final nomeEscola = usuarioLogado.nomeEscola ?? 'Escola Domex Edu';

          // Popula os dados no Controlador Global para o Menu Lateral acessar
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AlunoDashboardController.tenantId = tenantId;
            AlunoDashboardController.turmaId = turmaId;
            AlunoDashboardController.alunoDocId = alunoDocId;
            AlunoDashboardController.matricula = matricula;
            AlunoDashboardController.corPrimaria = corPrimaria;
            AlunoDashboardController.abrirBoletim = _abrirBoletim;
            AlunoDashboardController.abrirFrequencia = _abrirFrequencia;
          });

          final avaliacoesAsync = ref.watch(avaliacoesAlunoStreamProvider(turmaId));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(isMobile ? 24 : 40, 16, isMobile ? 24 : 40, 32),
                  decoration: BoxDecoration(
                    color: corPrimaria,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                    boxShadow: [BoxShadow(color: corPrimaria.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomeEscola.toUpperCase(),
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Olá,\n$nomeCompleto 👋',
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2),
                                maxLines: 3, 
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.school_rounded, color: Colors.white, size: 12),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        turmaNome, 
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          InkWell(
                            onTap: () => _abrirOpcoesFoto(tenantId, alunoDocId, fotoUrl),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 80,
                              height: 106, 
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: fotoUrl.isNotEmpty 
                                  ? Image.network(fotoUrl, fit: BoxFit.cover) 
                                  : Container(color: Colors.grey.shade200, child: Icon(Icons.person, size: 40, color: corPrimaria)),
                              ),
                            ),
                          ),
                          if (_atualizandoFoto)
                            const Positioned.fill(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          else
                            Transform.translate(
                              offset: const Offset(8, 8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                                child: Icon(Icons.camera_alt_rounded, color: corPrimaria, size: 14),
                              ),
                            )
                        ],
                      )
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
                          _buildAtalho('Grade de\nAulas', Icons.view_list_rounded, corPrimaria, () {
                            _abrirGradeDeAulas(turmaId, turmaNome, corPrimaria);
                          }),
                          const SizedBox(width: 16),
                          _buildAtalho('Meu\nBoletim', Icons.analytics_rounded, corPrimaria, () {
                            _abrirBoletim(tenantId, turmaId, alunoDocId, corPrimaria);
                          }),
                          const SizedBox(width: 16),
                          _buildAtalho('Frequência\nEscolar', Icons.fact_check_rounded, corPrimaria, () {
                            _abrirFrequencia(tenantId, turmaId, matricula, corPrimaria);
                          }),
                        ],
                      ),
                      const SizedBox(height: 40),

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

                          final hoje = DateTime.now();
                          final dataCorte = DateTime(hoje.year, hoje.month, hoje.day).subtract(const Duration(days: 1)); 
                          
                          final proximasAvaliacoes = avaliacoes.where((a) {
                            final dataStr = a['dataAvaliacao']?.toString() ?? '';
                            if (dataStr.isEmpty) return false;
                            final partes = dataStr.split('-');
                            if (partes.length == 3) {
                              final dataAval = DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
                              return dataAval.isAfter(dataCorte);
                            }
                            return false;
                          }).toList();
                          
                          proximasAvaliacoes.sort((a, b) => (a['dataAvaliacao'] ?? '').toString().compareTo((b['dataAvaliacao'] ?? '').toString()));

                          return Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _avaliacoesExpandidas = !_avaliacoesExpandidas;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: _avaliacoesExpandidas ? [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 4))] : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_document, color: corPrimaria),
                                      const SizedBox(width: 12),
                                      const Text('Próximas Avaliações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      if (proximasAvaliacoes.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                                          child: Text('${proximasAvaliacoes.length}', style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      const Spacer(),
                                      AnimatedRotation(
                                        turns: _avaliacoesExpandidas ? 0.5 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedCrossFade(
                                firstChild: const SizedBox(width: double.infinity),
                                secondChild: Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    if (proximasAvaliacoes.isEmpty)
                                      Container(
                                        width: double.infinity, padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                                        child: Column(
                                          children: [
                                            Icon(Icons.event_available_rounded, size: 40, color: Colors.grey.shade300),
                                            const SizedBox(height: 8),
                                            Text('Nenhuma avaliação futura agendada.', style: TextStyle(color: Colors.grey.shade500)),
                                          ],
                                        ),
                                      )
                                    else ...[
                                      ...proximasAvaliacoes.take(5).map((aval) {
                                        final max = double.tryParse(aval['pontuacaoMaxima']?.toString() ?? '10') ?? 10.0;
                                        
                                        final notasMap = Map<String, dynamic>.from(aval['notas'] ?? {});
                                        final notaDoAluno = notasMap[alunoDocId];
                                        
                                        Color corNota = Colors.grey.shade600;
                                        String textoNota = 'Valendo $max pts';
                                        
                                        if (notaDoAluno != null) {
                                          final double notaNum = double.tryParse(notaDoAluno.toString()) ?? 0.0;
                                          final bool acimaMedia = notaNum >= (max * 0.6); 
                                          corNota = acimaMedia ? Colors.green.shade700 : Colors.red.shade700;
                                          textoNota = 'Nota: $notaDoAluno / $max';
                                        }

                                        return InkWell(
                                          onTap: () => _mostrarDetalhesAvaliacao(aval, notaDoAluno, max, corNota, corPrimaria),
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(aval['nome'] ?? 'Avaliação', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      const SizedBox(height: 4),
                                                      Text('${aval['disciplina'] ?? 'Geral'} • ${_formatarDataDisplay(aval['dataAvaliacao'] ?? '')}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(color: notaDoAluno != null ? corNota.withAlpha(20) : Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                                                  child: Text(textoNota, style: TextStyle(color: notaDoAluno != null ? corNota : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
                                                )
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: TextButton.icon(
                                        onPressed: () => _abrirTodasAvaliacoes(tenantId, turmaId, alunoDocId, corPrimaria), 
                                        icon: Icon(Icons.format_list_bulleted_rounded, color: corPrimaria),
                                        label: Text('Mostrar todas as avaliações e notas', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria)),
                                      ),
                                    )
                                  ],
                                ),
                                crossFadeState: _avaliacoesExpandidas ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 300),
                              )
                            ],
                          );
                        }
                      ),

                      const SizedBox(height: 40),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId).collection('avisos').orderBy('dataEnvio', descending: true).limit(10).snapshots(),
                        builder: (context, snapAvisos) {
                          if (snapAvisos.connectionState == ConnectionState.waiting && !snapAvisos.hasData) {
                            return Center(child: CircularProgressIndicator(color: corPrimaria));
                          }

                          final todosAvisos = snapAvisos.data?.docs.map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            data['id'] = d.id;
                            return data;
                          }).toList() ?? [];
                          
                          final avisosAluno = todosAvisos.where((aviso) {
                            final tipoDest = aviso['tipoDestinatario'];
                            final alvoId = aviso['alunoId'];

                            if (tipoDest == 'TURMA' || tipoDest == 'TODOS') return true;
                            if ((tipoDest == 'ALUNO' || tipoDest == 'RESPONSAVEL') && alvoId == alunoDocId) return true;
                            
                            return false;
                          }).toList();

                          int qtdNaoLidos = avisosAluno.where((a) => !(List<String>.from(a['lidosPor'] ?? [])).contains(alunoDocId)).length;

                          return Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _muralExpandido = !_muralExpandido;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: _muralExpandido ? [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 4))] : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.campaign_rounded, color: corPrimaria),
                                      const SizedBox(width: 12),
                                      const Text('Mural de Avisos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      
                                      if (qtdNaoLidos > 0)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: Text('$qtdNaoLidos', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      const Spacer(),
                                      AnimatedRotation(
                                        turns: _muralExpandido ? 0.5 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedCrossFade(
                                firstChild: const SizedBox(width: double.infinity),
                                secondChild: Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    if (avisosAluno.isEmpty)
                                      Container(
                                        width: double.infinity, padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                                        child: Column(
                                          children: [
                                            Icon(Icons.notifications_off_rounded, size: 40, color: Colors.grey.shade300),
                                            const SizedBox(height: 8),
                                            Text('Nenhum aviso no mural.', style: TextStyle(color: Colors.grey.shade500)),
                                          ],
                                        ),
                                      )
                                    else ...[
                                      ...avisosAluno.take(5).map((aviso) => _buildAvisoCard(aviso, tenantId, turmaId, alunoDocId, corPrimaria)),
                                      if (avisosAluno.length > 5)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: TextButton.icon(
                                            onPressed: () => _abrirHistoricoAvisos(avisosAluno, tenantId, turmaId, alunoDocId, corPrimaria), 
                                            icon: Icon(Icons.history_rounded, color: corPrimaria),
                                            label: Text('Ver todo o histórico', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria)),
                                          ),
                                        )
                                    ]
                                  ],
                                ),
                                crossFadeState: _muralExpandido ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 300),
                              )
                            ],
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
      if (partes.length == 3) return "${partes[2]}/${partes[1]}";
    } catch (_) {}
    return dataBanco;
  }
}

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

class _BoletimModal extends StatefulWidget {
  final String tenantId;
  final String turmaId;
  final String alunoDocId;
  final Color corPrimaria;
  final ScrollController scrollController;

  const _BoletimModal({
    required this.tenantId,
    required this.turmaId,
    required this.alunoDocId,
    required this.corPrimaria,
    required this.scrollController,
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
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.analytics_rounded, color: widget.corPrimaria)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Meu Boletim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId).collection('avaliacoes').where('bimestre', isEqualTo: _bimestreAtivo).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
              
              final avaliacoes = snapshot.data?.docs.map((d) => d.data() as Map<String, dynamic>).toList() ?? [];
              
              if (avaliacoes.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Nenhuma nota neste bimestre.', style: TextStyle(color: Colors.grey.shade500))]));
              }

              Map<String, List<Map<String, dynamic>>> avaliacoesPorDisciplina = {};
              
              for (var aval in avaliacoes) {
                final disciplina = aval['disciplina'] ?? 'Geral';
                final maximo = double.tryParse(aval['pontuacaoMaxima']?.toString() ?? '10') ?? 10.0;
                final isRecuperacao = aval['isRecuperacao'] == true;
                final notasMap = Map<String, dynamic>.from(aval['notas'] ?? {});
                final notaAluno = double.tryParse(notasMap[widget.alunoDocId]?.toString() ?? '0') ?? 0.0;

                if (!avaliacoesPorDisciplina.containsKey(disciplina)) {
                  avaliacoesPorDisciplina[disciplina] = [];
                }
                
                avaliacoesPorDisciplina[disciplina]!.add({
                  'nota': notaAluno,
                  'maximo': maximo,
                  'isRecuperacao': isRecuperacao,
                  'valida': true
                });
              }

              Map<String, Map<String, double>> boletim = {};

              for (var disciplina in avaliacoesPorDisciplina.keys) {
                var notasDaDisciplina = avaliacoesPorDisciplina[disciplina]!;
                
                var recuperacoes = notasDaDisciplina.where((n) => n['isRecuperacao'] == true).toList();
                var normais = notasDaDisciplina.where((n) => n['isRecuperacao'] != true).toList();

                for (var rec in recuperacoes) {
                  if (normais.isEmpty) continue;
                  
                  normais.sort((a, b) => ((a['nota'] / a['maximo']).compareTo(b['nota'] / b['maximo'])));
                  var piorNormal = normais.first;

                  double aproveitamentoRec = rec['nota'] / rec['maximo'];
                  double aproveitamentoPiorNormal = piorNormal['nota'] / piorNormal['maximo'];

                  if (aproveitamentoRec > aproveitamentoPiorNormal) {
                    piorNormal['valida'] = false; 
                  } else {
                    rec['valida'] = false; 
                  }
                }

                double somaNotas = 0.0;
                for (var n in notasDaDisciplina) {
                  if (n['valida'] == true) {
                    somaNotas += n['nota'];
                  }
                }
                
                if (somaNotas > 10.0) somaNotas = 10.0;

                boletim[disciplina] = {'notaAluno': somaNotas, 'maximo': 10.0};
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
                  final notaAluno = dados['notaAluno']!;
                  
                  final bool acimaMedia = notaAluno >= 6.0; 
                  final Color corNota = notaAluno == 0 ? Colors.grey : (acimaMedia ? Colors.green.shade700 : Colors.red.shade700);

                  return Container(
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
                        Row(
                          children: [
                            Icon(Icons.menu_book_rounded, color: Colors.blueGrey.shade300, size: 20),
                            const SizedBox(width: 12),
                            Text(disciplina, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: corNota.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '${notaAluno.toStringAsFixed(1)} / 10.0', 
                            style: TextStyle(color: corNota, fontWeight: FontWeight.bold, fontSize: 16)
                          ),
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

class _FrequenciaModal extends StatefulWidget {
  final String tenantId;
  final String turmaId;
  final String alunoMatricula;
  final Color corPrimaria;
  final ScrollController scrollController;

  const _FrequenciaModal({
    required this.tenantId,
    required this.turmaId,
    required this.alunoMatricula,
    required this.corPrimaria,
    required this.scrollController,
  });

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
    } catch (_) {
      return false;
    }
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
                Text('Acompanhamento de faltas', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
              
              List<Map<String, String>> frequenciaBimestre = [];

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['status'] != 'NAO_INICIADA' && _isDataNoBimestre(doc.id, _bimestreAtivo)) {
                    final freq = Map<String, String>.from(data['frequencia'] ?? {});
                    final st = freq[widget.alunoMatricula] ?? 'P';
                    
                    final p = doc.id.split('-');
                    frequenciaBimestre.add({
                      'idSort': doc.id,
                      'data': "${p[2]}/${p[1]}/${p[0]}", 
                      'status': st 
                    });
                  }
                }
              }

              frequenciaBimestre.sort((a,b) => b['idSort']!.compareTo(a['idSort']!));
              
              final int aulasBimestre = frequenciaBimestre.length;
              final int faltas = frequenciaBimestre.where((f) => f['status'] == 'A' || f['status'] == 'J').length;

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: faltas > 0 ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: faltas > 0 ? Colors.red.shade200 : Colors.green.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total de Faltas no $_bimestreAtivo:', style: TextStyle(fontWeight: FontWeight.bold, color: faltas > 0 ? Colors.red.shade900 : Colors.green.shade900)),
                        Text('$faltas / $aulasBimestre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: faltas > 0 ? Colors.red.shade900 : Colors.green.shade900)),
                      ],
                    ),
                  ),

                  if (frequenciaBimestre.isEmpty)
                    Expanded(child: Center(child: Text('Nenhuma aula registrada neste bimestre.', style: TextStyle(color: Colors.grey.shade500))))
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: frequenciaBimestre.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final f = frequenciaBimestre[index];
                          final status = f['status'];
                          
                          Color corStatus = Colors.green;
                          String textoStatus = 'Presente';
                          IconData iconeStatus = Icons.check_circle_rounded;

                          if (status == 'A') {
                            corStatus = Colors.red;
                            textoStatus = 'Falta';
                            iconeStatus = Icons.cancel_rounded;
                          } else if (status == 'J') {
                            corStatus = Colors.orange;
                            textoStatus = 'Falta Justificada';
                            iconeStatus = Icons.info_rounded;
                          }

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.event_available_rounded, color: Colors.grey.shade400),
                            title: Text(f['data'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                              decoration: BoxDecoration(color: corStatus.withAlpha(30), borderRadius: BorderRadius.circular(8)), 
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(iconeStatus, color: corStatus, size: 14),
                                  const SizedBox(width: 4),
                                  Text(textoStatus, style: TextStyle(color: corStatus, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        )
      ],
    );
  }
}