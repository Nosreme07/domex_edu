import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

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
  // BUSCAR DADOS DO ALUNO (Com Isolamento da Escola - TenantID)
  // ==========================================================================
  Future<Map<String, dynamic>?> _buscarDadosAluno(String tenantId, String alunoIdSeguro, String email) async {
    try {
      // 1ª Tentativa: Busca diretamente pelo ID validado no Auth
      var snap = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('alunos')
          .where('matricula', isEqualTo: alunoIdSeguro)
          .limit(1)
          .get();
          
      // 2ª Tentativa: Busca pelo E-mail real (caso tenha)
      if (snap.docs.isEmpty && email.isNotEmpty && !email.contains('@domex.com') && !email.contains(tenantId.toLowerCase())) {
        snap = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('alunos')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      }

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
        if (extensao != 'png' && extensao != 'jpg' && extensao != 'jpeg') {
          extensao = 'jpg';
        }

        final nomeArquivo = 'aluno_${alunoDocId}_${DateTime.now().millisecondsSinceEpoch}.$extensao';
        final refStorage = FirebaseStorage.instance.ref('tenants/$tenantId/alunos_fotos/$nomeArquivo');

        final metadata = SettableMetadata(contentType: 'image/$extensao');
        await refStorage.putData(bytes, metadata); 
        final novaUrl = await refStorage.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tenantId)
            .collection('alunos')
            .doc(alunoDocId)
            .update({'fotoUrl': novaUrl});

        messenger.showSnackBar(const SnackBar(content: Text('Foto de perfil atualizada com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao processar foto: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _atualizandoFoto = false);
    }
  }

  // Widget para os Botões de Atalho Rápidos
  Widget _buildAtalho(String titulo, IconData icone, Color corPrimaria, VoidCallback onTap) {
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

    if (usuarioLogado == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tenantId = usuarioLogado.tenantId; 
    final alunoIdSeguro = usuarioLogado.id; 
    final emailUsuario = usuarioLogado.email.trim().toLowerCase();
    final nomeEscola = usuarioLogado.nomeEscola ?? 'Escola Domex Edu';
    
    // COR DA ESCOLA APLICADA AQUI
    final corPrimaria = usuarioLogado.corPrimaria;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Portal do Aluno', style: TextStyle(fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _buscarDadosAluno(tenantId, alunoIdSeguro, emailUsuario),
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
                  Text('As credenciais não estão vinculadas a nenhuma matrícula válida.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final nomeCompleto = aluno['nome'] ?? 'Estudante';
          final primeiroNome = nomeCompleto.split(' ').first;
          final turmaNome = aluno['turma'] ?? 'Sem Turma';
          final turmaId = aluno['turmaId'];
          final fotoUrl = aluno['fotoUrl'] ?? '';
          final alunoDocId = aluno['docId'];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================================
                // CABEÇALHO HERO (Ajustado)
                // ============================================================
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(isMobile ? 24 : 40, 24, isMobile ? 24 : 40, 40),
                  decoration: BoxDecoration(
                    color: corPrimaria,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(color: corPrimaria.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))
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
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Olá, $primeiroNome 👋', // Apenas o primeiro nome para não ficar gigante
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school_rounded, color: Colors.white, size: 12),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      turmaNome, 
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // FOTO COM OPÇÃO DE CLICK
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
                            const Positioned.fill(
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            )
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
                          _buildAtalho('Boletim', Icons.analytics_rounded, corPrimaria, () {
                            // Ação: Abrir Boletim
                          }),
                          const SizedBox(width: 16),
                          _buildAtalho('Calendário', Icons.calendar_month_rounded, corPrimaria, () {
                            // Ação: Abrir Calendário
                          }),
                          const SizedBox(width: 16),
                          _buildAtalho('Frequência', Icons.fact_check_rounded, corPrimaria, () {
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
                              return Center(child: CircularProgressIndicator(color: corPrimaria));
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
                      // MURAL DE AVISOS (Turma e Direção) - OVERFLOW CORRIGIDO
                      // ============================================================
                      Row(
                        children: [
                          Icon(Icons.campaign_rounded, color: corPrimaria),
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
                              return Center(child: CircularProgressIndicator(color: corPrimaria));
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
                                                    maxLines: 2, // Permite quebra de linha
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8), // Espaçamento de segurança
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