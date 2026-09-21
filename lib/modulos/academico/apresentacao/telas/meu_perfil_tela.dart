import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';
import '../../../admin/apresentacao/estado/professor_provider.dart';
import '../../../admin/apresentacao/estado/turma_provider.dart';

// ============================================================================
// FORMATADOR DE TEXTO (MAIÚSCULO)
// ============================================================================
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class MeuPerfilTela extends ConsumerStatefulWidget {
  const MeuPerfilTela({super.key});

  @override
  ConsumerState<MeuPerfilTela> createState() => _MeuPerfilTelaState();
}

class _MeuPerfilTelaState extends ConsumerState<MeuPerfilTela> {
  bool _atualizandoFoto = false;
  bool _enviandoEmailSenha = false;

  // ==========================================================================
  // LÓGICA DE FOTO (CÂMERA, GALERIA E CORTE) COM SUPORTE WEB E MOBILE
  // ==========================================================================
  void _abrirOpcoesFoto(String tenantId, String professorDocId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Alterar Foto de Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
              title: const Text('Tirar Foto Agora (Câmera)'),
              onTap: () {
                Navigator.pop(ctx);
                _capturarERecortarFoto(ImageSource.camera, tenantId, professorDocId);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.orange),
              title: const Text('Escolher da Galeria'),
              onTap: () {
                Navigator.pop(ctx);
                _capturarERecortarFoto(ImageSource.gallery, tenantId, professorDocId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturarERecortarFoto(ImageSource source, String tenantId, String professorDocId) async {
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

        final nomeArquivo = 'perfil_${professorDocId}_${DateTime.now().millisecondsSinceEpoch}.$extensao';
        final refStorage = FirebaseStorage.instance.ref('tenants/$tenantId/professores_fotos/$nomeArquivo');

        final metadata = SettableMetadata(contentType: 'image/$extensao');
        await refStorage.putData(bytes, metadata); 
        final novaUrl = await refStorage.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tenantId)
            .collection('professores')
            .doc(professorDocId)
            .update({'fotoUrl': novaUrl});

        messenger.showSnackBar(const SnackBar(content: Text('Foto de perfil atualizada com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao processar foto: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _atualizandoFoto = false);
    }
  }

  // ==========================================================================
  // LÓGICA DE ALTERAR SENHA E ABRIR ANEXO
  // ==========================================================================
  Future<void> _solicitarAlteracaoSenha(String email) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _enviandoEmailSenha = true);
    
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('E-mail Enviado!'),
            ],
          ),
          content: Text(
            'Enviamos um link de redefinição de senha para:\n\n$email\n\nVerifique sua caixa de entrada (ou lixo eletrônico) para criar sua nova senha com segurança.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text('Entendi')
            )
          ],
        )
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao enviar e-mail: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _enviandoEmailSenha = false);
    }
  }

  Future<void> _abrirAnexoUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o arquivo.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================================================
  // MODAL PARA O PROFESSOR EDITAR OS PRÓPRIOS DADOS
  // ==========================================================================
  void _abrirModalEditarDados(Map<String, dynamic> professorAtual, Color corPrimaria) {
    final formKey = GlobalKey<FormState>();
    final upperCase = UpperCaseTextFormatter();
    
    final cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
    final telMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
    final dataMask = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

    final nomeCtrl = TextEditingController(text: professorAtual['nome'] ?? '');
    final dataNascimentoCtrl = TextEditingController(text: professorAtual['dataNascimento'] ?? '');
    final cpfCtrl = TextEditingController(text: professorAtual['cpf'] ?? '');
    final telefoneCtrl = TextEditingController(text: professorAtual['telefone'] ?? '');
    
    final endAtual = professorAtual['endereco'] ?? {};
    final ruaCtrl = TextEditingController(text: endAtual['rua'] ?? '');
    final numeroCtrl = TextEditingController(text: endAtual['numero'] ?? '');
    final bairroCtrl = TextEditingController(text: endAtual['bairro'] ?? '');
    final cidadeCtrl = TextEditingController(text: endAtual['cidade'] ?? '');

    bool salvando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit_document, color: corPrimaria),
              const SizedBox(width: 8),
              const Text('Editar Meus Dados', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informações Pessoais', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomeCtrl,
                      inputFormatters: [upperCase],
                      decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cpfCtrl,
                            inputFormatters: [cpfMask, upperCase],
                            decoration: const InputDecoration(labelText: 'CPF', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                            validator: (v) => v!.length < 14 ? 'Inválido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: dataNascimentoCtrl,
                            inputFormatters: [dataMask, upperCase],
                            decoration: const InputDecoration(labelText: 'Nascimento (DD/MM/AAAA)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                            validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telefoneCtrl,
                      inputFormatters: [telMask, upperCase],
                      decoration: const InputDecoration(labelText: 'Telefone / WhatsApp', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    
                    const Divider(height: 32),
                    const Text('Endereço', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: ruaCtrl,
                            inputFormatters: [upperCase],
                            decoration: const InputDecoration(labelText: 'Rua', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: numeroCtrl,
                            inputFormatters: [upperCase],
                            decoration: const InputDecoration(labelText: 'Nº', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: bairroCtrl,
                            inputFormatters: [upperCase],
                            decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: cidadeCtrl,
                            inputFormatters: [upperCase],
                            decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white),
              onPressed: salvando ? null : () async {
                if (formKey.currentState!.validate()) {
                  setModalState(() => salvando = true);
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  try {
                    final dadosAtualizados = Map<String, dynamic>.from(professorAtual);
                    dadosAtualizados['nome'] = nomeCtrl.text.trim();
                    dadosAtualizados['cpf'] = cpfCtrl.text.trim();
                    dadosAtualizados['dataNascimento'] = dataNascimentoCtrl.text.trim();
                    dadosAtualizados['telefone'] = telefoneCtrl.text.trim();
                    dadosAtualizados['endereco'] = {
                      'rua': ruaCtrl.text.trim(),
                      'numero': numeroCtrl.text.trim(),
                      'bairro': bairroCtrl.text.trim(),
                      'cidade': cidadeCtrl.text.trim(),
                    };

                    await ref.read(professorServiceProvider).salvarProfessor(dadosAtualizados);
                    nav.pop();
                    messenger.showSnackBar(const SnackBar(content: Text('Dados atualizados com sucesso!'), backgroundColor: Colors.green));
                  } catch (e) {
                    setModalState(() => salvando = false);
                    messenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              icon: salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded),
              label: Text(salvando ? 'Salvando...' : 'Salvar Alterações', style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        )
      )
    );
  }

  Widget _buildInfoRow(IconData icone, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(valor, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
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

    final emailUsuario = usuarioLogado.email.trim().toLowerCase();
    final tenantId = usuarioLogado.id; 

    final estadoProfessores = ref.watch(professoresStreamProvider);
    final estadoTurmas = ref.watch(turmasStreamProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: const Text('Meu Perfil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: estadoProfessores.when(
        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
        error: (e, s) => Center(child: Text('Erro ao carregar perfil: $e')),
        data: (professores) {
          final profMap = professores.where((p) {
            final emailProf = (p['email'] ?? '').toString().trim().toLowerCase();
            return emailProf == emailUsuario;
          }).toList();

          if (profMap.isEmpty) {
            return const Center(child: Text('Dados do professor não encontrados.'));
          }

          final professor = profMap.first;
          final profDocId = professor['id']; 
          final profNome = professor['nome'] ?? 'Professor(a)';
          final profFoto = professor['fotoUrl'];
          final profTelefone = professor['telefone'] ?? 'Não informado';
          final profCpf = professor['cpf'] ?? 'Não informado';
          final profDataNasc = professor['dataNascimento'] ?? 'Não informado';
          final status = professor['status'] ?? 'Inativo';
          
          final endereco = professor['endereco'] ?? {};
          final endCompleto = (endereco['rua'] ?? '').toString().isEmpty 
              ? 'Endereço não cadastrado' 
              : '${endereco['rua']}, ${endereco['numero']} - ${endereco['bairro']}, ${endereco['cidade']}';

          final disciplinas = (professor['disciplinas'] as List? ?? []).join(', ');
          final anexos = professor['anexos'] as List? ?? [];

          // ================================================================
          // WIDGET DO PERFIL (DADOS E FOTO)
          // ================================================================
          Widget painelPerfil = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: corPrimaria.withAlpha(30),
                            backgroundImage: profFoto != null && profFoto.toString().isNotEmpty ? NetworkImage(profFoto) : null,
                            child: profFoto == null || profFoto.toString().isEmpty 
                                ? Icon(Icons.person, size: 60, color: corPrimaria) 
                                : null,
                          ),
                          if (_atualizandoFoto)
                            const Positioned.fill(
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            )
                          else
                            InkWell(
                              onTap: () => _abrirOpcoesFoto(tenantId, profDocId),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: corPrimaria, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(profNome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'Ativo' ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: status == 'Ativo' ? Colors.green.shade200 : Colors.red.shade200)
                        ),
                        child: Text(status, style: TextStyle(color: status == 'Ativo' ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Informações Pessoais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                            tooltip: 'Editar Dados',
                            onPressed: () => _abrirModalEditarDados(professor, corPrimaria),
                          )
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.badge_rounded, 'CPF', profCpf),
                      _buildInfoRow(Icons.cake_rounded, 'Nascimento', profDataNasc),
                      _buildInfoRow(Icons.email_rounded, 'E-mail (Login)', emailUsuario),
                      _buildInfoRow(Icons.phone_android_rounded, 'Telefone', profTelefone),
                      _buildInfoRow(Icons.home_rounded, 'Endereço', endCompleto),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Informações Acadêmicas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.menu_book_rounded, 'Disciplinas Habilitadas', disciplinas.isEmpty ? 'Geral' : disciplinas),
                      
                      const SizedBox(height: 12),
                      const Text('Documentos e Certificados', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (anexos.isEmpty)
                        const Text('Nenhum documento anexado na secretaria.', style: TextStyle(color: Colors.black54, fontSize: 13))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: anexos.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final anexo = anexos[index];
                            final isPDF = anexo['extensao'] == 'pdf';
                            return Container(
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                              child: ListTile(
                                dense: true,
                                leading: Icon(isPDF ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: isPDF ? Colors.red : Colors.blue),
                                title: Text(anexo['nome'] ?? 'Documento', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.download_rounded, color: Colors.blueGrey),
                                  tooltip: 'Baixar Documento',
                                  onPressed: () {
                                    if (anexo['url'] != null) {
                                      _abrirAnexoUrl(anexo['url']);
                                    }
                                  },
                                ),
                              ),
                            );
                          }
                        )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  onPressed: _enviandoEmailSenha ? null : () => _solicitarAlteracaoSenha(emailUsuario),
                  icon: _enviandoEmailSenha 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.lock_reset_rounded),
                  label: Text(_enviandoEmailSenha ? 'Enviando...' : 'Redefinir Minha Senha'),
                ),
              )
            ],
          );

          // ================================================================
          // WIDGET DO MURAL (AVISOS DA DIREÇÃO)
          // ================================================================
          Widget painelAvisos = Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: isMobile ? Colors.transparent : Colors.grey.shade200),
                top: BorderSide(color: isMobile ? Colors.grey.shade200 : Colors.transparent),
              )
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.campaign_rounded, color: Colors.orange.shade800),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Avisos da Direção', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Comunicados oficiais para a equipe docente.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                estadoTurmas.when(
                  loading: () => Center(child: Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(color: corPrimaria))),
                  error: (e, s) => const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Erro ao buscar turmas'))),
                  data: (todasAsTurmas) {
                    final minhasTurmas = todasAsTurmas.where((t) {
                      if (t['status'] == 'Inativa') return false;
                      final vinculados = t['professoresVinculados'] as List? ?? [];
                      return vinculados.any((v) => v['professorId'] == profDocId);
                    }).toList();

                    if (minhasTurmas.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('Você não está vinculado a nenhuma turma ativa.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16), textAlign: TextAlign.center),
                            ],
                          ),
                        )
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true, // Garante que a lista não quebre o layout
                      physics: isMobile ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      itemCount: minhasTurmas.length,
                      itemBuilder: (context, index) {
                        final turma = minhasTurmas[index];
                        
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('tenants')
                              .doc(tenantId)
                              .collection('turmas')
                              .doc(turma['id'].toString())
                              .collection('avisos')
                              .snapshots(),
                          builder: (context, snapAvisos) {
                            if (!snapAvisos.hasData || snapAvisos.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            var avisosDaTurma = snapAvisos.data!.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final tipo = data['tipoDestinatario'];
                              final remetente = (data['remetenteNome'] ?? '').toString().toLowerCase();
                              
                              bool isAdmin = remetente.contains('admin') || remetente.contains('direção') || remetente.contains('coord');
                              return tipo == 'PROFESSORES' || (isAdmin && tipo == 'TURMA');
                            }).toList();

                            if (avisosDaTurma.isEmpty) return const SizedBox.shrink();
                            
                            avisosDaTurma.sort((a, b) {
                              final dataA = a.data() as Map<String, dynamic>;
                              final dataB = b.data() as Map<String, dynamic>;
                              final timeA = dataA['dataEnvio'];
                              final timeB = dataB['dataEnvio'];
                              if (timeA == null && timeB == null) return 0;
                              if (timeA == null) return 1;
                              if (timeB == null) return -1;
                              return (timeB as dynamic).compareTo(timeA as dynamic);
                            });

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                                  child: Text(
                                    'Turma: ${turma['nome']}', 
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade800)
                                  ),
                                ),
                                ...avisosDaTurma.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final dataEnvio = data['dataEnvio'];
                                  final textoData = dataEnvio != null ? DateFormat('dd/MM/yyyy HH:mm').format((dataEnvio as dynamic).toDate()) : '';
                                  final nomeRemetente = data['remetenteNome']?.toString().trim() ?? 'Direção';
                                  
                                  final isAvisoExclusivo = data['tipoDestinatario'] == 'PROFESSORES';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: isAvisoExclusivo ? Colors.orange.shade50 : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isAvisoExclusivo ? Colors.orange.shade200 : Colors.grey.shade300)
                                    ),
                                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(isAvisoExclusivo ? Icons.admin_panel_settings_rounded : Icons.groups_rounded, size: 16, color: isAvisoExclusivo ? Colors.orange.shade800 : Colors.deepPurple),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'De: $nomeRemetente', 
                                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isAvisoExclusivo ? Colors.orange.shade900 : Colors.deepPurple),
                                                      maxLines: 2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(textoData, style: TextStyle(color: isAvisoExclusivo ? Colors.orange.shade700 : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          child: Divider(height: 1),
                                        ),
                                        Text(
                                          data['mensagem'] ?? '', 
                                          style: TextStyle(fontSize: 14, color: isAvisoExclusivo ? Colors.black87 : Colors.black)
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        );
                      },
                    );
                  }
                )
              ],
            ),
          );

          // ================================================================
          // ESTRUTURA RESPONSIVA FINAL (CELULAR X COMPUTADOR)
          // ================================================================
          if (isMobile) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: painelPerfil,
                  ),
                  painelAvisos,
                ],
              ),
            );
          } else {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: painelPerfil,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: painelAvisos,
                  ),
                ),
              ],
            );
          }
        }
      ),
    );
  }
}