import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../estado/professor_provider.dart';

// ============================================================================
// FORMATADORES DE TEXTO (MAIÚSCULO E MINÚSCULO)
// ============================================================================
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toLowerCase(), selection: newValue.selection);
  }
}

class AdminProfessorFormTela extends ConsumerStatefulWidget {
  final Map<String, dynamic>? professorParaEditar;
  
  const AdminProfessorFormTela({super.key, this.professorParaEditar});

  @override
  ConsumerState<AdminProfessorFormTela> createState() => _AdminProfessorFormTelaState();
}

class _AdminProfessorFormTelaState extends ConsumerState<AdminProfessorFormTela> {
  final _formKey = GlobalKey<FormState>();
  
  final _upperCase = UpperCaseTextFormatter(); 
  final _lowerCase = LowerCaseTextFormatter(); // <-- Novo formatador instanciado aqui!

  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _telMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _dataMask = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

  XFile? _fotoSelecionada;
  String? _fotoUrlExistente;
  final ImagePicker _picker = ImagePicker();

  final _nomeCtrl = TextEditingController();
  final _dataNascimentoCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _ruaCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();

  bool _isAtivo = true;
  List<String> _disciplinasDisponiveis = [];
  final Set<String> _disciplinasSelecionadas = {};
  final _outraDisciplinaCtrl = TextEditingController();

  List<Map<String, dynamic>> _anexos = [];

  @override
  void initState() {
    super.initState();
    
    _disciplinasDisponiveis = [
      'MATEMÁTICA', 'PORTUGUÊS', 'HISTÓRIA', 'GEOGRAFIA', 
      'FÍSICA', 'QUÍMICA', 'BIOLOGIA', 'INGLÊS', 'ESPANHOL', 'MÚSICA', 'INFORMÁTICA', 'ENSINO RELIGIOSO',
      'EDUCAÇÃO FÍSICA', 'ARTES', 'FILOSOFIA', 'SOCIOLOGIA', 'OUTROS'
    ];

    if (widget.professorParaEditar != null) {
      final prof = widget.professorParaEditar!;
      
      _fotoUrlExistente = prof['fotoUrl'];
      _nomeCtrl.text = prof['nome'] ?? '';
      _dataNascimentoCtrl.text = prof['dataNascimento'] ?? '';
      _cpfCtrl.text = prof['cpf'] ?? '';
      _telefoneCtrl.text = prof['telefone'] ?? '';
      _emailCtrl.text = prof['email'] ?? '';
      
      if (prof['endereco'] != null) {
        _ruaCtrl.text = prof['endereco']['rua'] ?? '';
        _numeroCtrl.text = prof['endereco']['numero'] ?? '';
        _bairroCtrl.text = prof['endereco']['bairro'] ?? '';
        _cidadeCtrl.text = prof['endereco']['cidade'] ?? '';
      }
      
      _isAtivo = prof['status'] == 'Ativo';
      
      if (prof['disciplinas'] != null) {
        for (var d in prof['disciplinas']) {
          String disc = d.toString().toUpperCase();
          if (disc != 'OUTROS') {
            _disciplinasSelecionadas.add(disc);
            if (!_disciplinasDisponiveis.contains(disc)) {
              _disciplinasDisponiveis.insert(_disciplinasDisponiveis.length - 1, disc);
            }
          }
        }
      }

      if (prof['anexos'] != null) {
        _anexos = List<Map<String, dynamic>>.from(prof['anexos']);
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose(); _dataNascimentoCtrl.dispose(); _cpfCtrl.dispose();
    _telefoneCtrl.dispose(); _emailCtrl.dispose();
    _ruaCtrl.dispose(); _numeroCtrl.dispose(); _bairroCtrl.dispose(); _cidadeCtrl.dispose();
    _outraDisciplinaCtrl.dispose();
    super.dispose();
  }

  void _adicionarDisciplinaCustomizada() {
    final nova = _outraDisciplinaCtrl.text.trim().toUpperCase();
    if (nova.isNotEmpty && !_disciplinasDisponiveis.contains(nova)) {
      setState(() {
        _disciplinasDisponiveis.insert(_disciplinasDisponiveis.length - 1, nova);
        _disciplinasSelecionadas.add(nova);
        _outraDisciplinaCtrl.clear();
      });
    } else if (nova.isNotEmpty && _disciplinasDisponiveis.contains(nova)) {
      setState(() {
        _disciplinasSelecionadas.add(nova);
        _outraDisciplinaCtrl.clear();
      });
    }
  }

  Future<void> _escolherFoto() async {
    try {
      final XFile? imagem = await _picker.pickImage(source: ImageSource.gallery);
      if (imagem != null) {
        await _recortarEEnquadrar(imagem.path);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao acessar a galeria.')));
    }
  }

  Future<void> _recortarEEnquadrar(String path) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 4), 
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Enquadrar Foto 3x4', 
          toolbarColor: Theme.of(context).primaryColor, 
          toolbarWidgetColor: Colors.white, 
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: true
        ),
        WebUiSettings(context: context),
      ],
    );
    if (croppedFile != null && mounted) {
      setState(() {
        _fotoSelecionada = XFile(croppedFile.path);
      });
    }
  }

  void _abrirOpcoesFoto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: _fotoSelecionada != null 
                  ? (kIsWeb ? Image.network(_fotoSelecionada!.path, fit: BoxFit.cover, width: 300, height: 400) : Image.file(File(_fotoSelecionada!.path), fit: BoxFit.cover, width: 300, height: 400))
                  : Image.network(_fotoUrlExistente!, fit: BoxFit.cover, width: 300, height: 400),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(children: [IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 28), onPressed: () { Navigator.pop(ctx); _escolherFoto(); }), const Text('Trocar', style: TextStyle(fontSize: 12, color: Colors.blue))]),
                  if (_fotoSelecionada != null) Column(children: [IconButton(icon: const Icon(Icons.crop_free_rounded, color: Colors.orange, size: 28), onPressed: () { Navigator.pop(ctx); _recortarEEnquadrar(_fotoSelecionada!.path); }), const Text('Recortar', style: TextStyle(fontSize: 12, color: Colors.orange))]),
                  Column(children: [IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 28), onPressed: () { setState(() { _fotoSelecionada = null; _fotoUrlExistente = null; }); Navigator.pop(ctx); }), const Text('Excluir', style: TextStyle(fontSize: 12, color: Colors.red))]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _escolherAnexos() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, 
      );

      if (result != null) {
        setState(() {
          for (var file in result.files) {
            _anexos.add({
              'idLocal': DateTime.now().microsecondsSinceEpoch.toString(), 
              'nome': file.name,
              'bytes': file.bytes, 
              'extensao': file.extension?.toLowerCase() ?? 'pdf',
              'url': null, 
            });
          }
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao selecionar arquivos: $e')));
    }
  }

  void _removerAnexo(int index) {
    setState(() {
      _anexos.removeAt(index);
    });
  }

  Future<void> _abrirAnexoUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o arquivo.')));
      }
    }
  }

  void _revisarESalvar() {
    if (_formKey.currentState!.validate()) {
      
      final disciplinasParaSalvar = _disciplinasSelecionadas.where((d) => d != 'OUTROS').toList();

      if (disciplinasParaSalvar.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione ou adicione ao menos uma disciplina.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
        return;
      }

      final isEdicao = widget.professorParaEditar != null;
      String idParaSalvar;

      if (isEdicao) {
        idParaSalvar = widget.professorParaEditar!['id'];
      } else {
        final listaProfessores = ref.read(professoresStreamProvider).value ?? [];
        int maiorSequencial = 0;
        for (var prof in listaProfessores) {
          final idProf = prof['id']?.toString() ?? '';
          if (idProf.startsWith('PROF-')) {
            final sequencialStr = idProf.substring(5); 
            final sequencial = int.tryParse(sequencialStr) ?? 0;
            if (sequencial > maiorSequencial) {
              maiorSequencial = sequencial;
            }
          }
        }
        idParaSalvar = 'PROF-${(maiorSequencial + 1).toString().padLeft(2, '0')}'; 
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.assignment_ind_rounded, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(isEdicao ? 'Revisão da Edição' : 'Revisão do Professor', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('ID: ', style: TextStyle(fontSize: 16, color: Colors.blue)),
                          Text(idParaSalvar, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _resumoLinha('Nome', _nomeCtrl.text),
                    _resumoLinha('CPF', _cpfCtrl.text),
                    _resumoLinha('Status', _isAtivo ? 'Ativo (Disponível para aulas)' : 'Inativo'),
                    _resumoLinha('Anexos', '${_anexos.length} documento(s)'),
                    const Divider(),
                    const Text('Disciplinas Habilitadas:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: disciplinasParaSalvar.map((d) => Chip(label: Text(d, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.grey.shade200, side: BorderSide.none)).toList(),
                    )
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar e Editar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  
                  showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.white)));

                  try {
                    String? urlFinalFoto = _fotoUrlExistente;
                    if (_fotoSelecionada != null) {
                      final bytesFoto = await _fotoSelecionada!.readAsBytes();
                      String extensao = _fotoSelecionada!.name.split('.').last.toLowerCase();
                      if (extensao != 'png' && extensao != 'jpg' && extensao != 'jpeg') {
                        extensao = 'png';
                      }
                      urlFinalFoto = await ref.read(professorServiceProvider).fazerUploadFoto(idParaSalvar, bytesFoto, extensao);
                    } else if (_fotoUrlExistente == null) {
                      urlFinalFoto = null;
                    }

                    List<Map<String, dynamic>> anexosParaSalvar = [];
                    for (var anexo in _anexos) {
                      if (anexo['url'] == null && anexo['bytes'] != null) {
                        String nomeUnico = '${idParaSalvar}_anexo_${DateTime.now().millisecondsSinceEpoch}';
                        String? urlDownload = await ref.read(professorServiceProvider).fazerUploadFoto(nomeUnico, anexo['bytes'], anexo['extensao']);
                        
                        anexosParaSalvar.add({
                          'nome': anexo['nome'],
                          'url': urlDownload,
                          'extensao': anexo['extensao'],
                        });
                      } else {
                        anexosParaSalvar.add({
                          'nome': anexo['nome'],
                          'url': anexo['url'],
                          'extensao': anexo['extensao'],
                        });
                      }
                    }

                    final dadosProfessor = {
                      'id': idParaSalvar,
                      'nome': _nomeCtrl.text,
                      'dataNascimento': _dataNascimentoCtrl.text,
                      'cpf': _cpfCtrl.text,
                      'telefone': _telefoneCtrl.text,
                      'email': _emailCtrl.text,
                      'fotoUrl': urlFinalFoto,
                      'anexos': anexosParaSalvar, 
                      'endereco': {
                        'rua': _ruaCtrl.text, 'numero': _numeroCtrl.text,
                        'bairro': _bairroCtrl.text, 'cidade': _cidadeCtrl.text,
                      },
                      'status': _isAtivo ? 'Ativo' : 'Inativo',
                      'disciplinas': disciplinasParaSalvar,
                      'dataCadastro': isEdicao ? widget.professorParaEditar!['dataCadastro'] : DateTime.now().toIso8601String(),
                    };

                    await ref.read(professorServiceProvider).salvarProfessor(dadosProfessor);
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context, rootNavigator: true).pop(); 
                    Navigator.pop(context); 
                    context.pop(); 
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdicao ? 'Professor atualizado!' : 'Professor salvo no Firebase! ID: $idParaSalvar', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); 
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                    }
                  }
                },
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                label: const Text('Confirmar Cadastro', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _resumoLinha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final isEdicao = widget.professorParaEditar != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdicao ? 'Editar Professor' : 'Novo Cadastro de Professor'), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [Icon(Icons.person, color: corPrimaria), const SizedBox(width: 8), const Text('Dados Pessoais e Contato', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                                child: Text(isEdicao ? 'ID: ${widget.professorParaEditar!['id']}' : 'ID: Gerado ao Salvar', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              ),
                            ]
                          ),
                          const Divider(height: 32),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: (_fotoSelecionada == null && _fotoUrlExistente == null) ? _escolherFoto : _abrirOpcoesFoto,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 120, height: 160, 
                                  decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
                                  child: (_fotoSelecionada == null && _fotoUrlExistente == null)
                                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Colors.grey.shade400, size: 40), const SizedBox(height: 8), const Text('Foto 3x4', style: TextStyle(color: Colors.grey, fontSize: 12))])
                                      : ClipRRect(borderRadius: BorderRadius.circular(12), child: _fotoSelecionada != null ? (kIsWeb ? Image.network(_fotoSelecionada!.path, fit: BoxFit.cover) : Image.file(File(_fotoSelecionada!.path), fit: BoxFit.cover)) : Image.network(_fotoUrlExistente!, fit: BoxFit.cover)),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(flex: 3, child: TextFormField(controller: _nomeCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                                        const SizedBox(width: 16),
                                        Expanded(flex: 2, child: TextFormField(controller: _cpfCtrl, textInputAction: TextInputAction.next, inputFormatters: [_cpfMask, _upperCase], decoration: const InputDecoration(labelText: 'CPF', hintText: 'xxx.xxx.xxx-xx', border: OutlineInputBorder()), validator: (v) => v!.length < 14 ? 'Inválido' : null)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(child: TextFormField(controller: _dataNascimentoCtrl, textInputAction: TextInputAction.next, inputFormatters: [_dataMask, _upperCase], decoration: const InputDecoration(labelText: 'Nascimento', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                                        const SizedBox(width: 16),
                                        Expanded(child: TextFormField(controller: _telefoneCtrl, textInputAction: TextInputAction.next, inputFormatters: [_telMask, _upperCase], decoration: const InputDecoration(labelText: 'Telefone/WhatsApp', hintText: '(xx) xxxxx-xxxx', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                                        const SizedBox(width: 16),
                                        // ==========================================
                                        // CAMPO DE E-MAIL USANDO O FORMATADOR MINÚSCULO
                                        // ==========================================
                                        Expanded(
                                          flex: 2, 
                                          child: TextFormField(
                                            controller: _emailCtrl, 
                                            textInputAction: TextInputAction.next, 
                                            inputFormatters: [_lowerCase], // <-- Aqui está a trava visual minúscula!
                                            decoration: const InputDecoration(labelText: 'E-mail Profissional', border: OutlineInputBorder()), 
                                            validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null
                                          )
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.work_history_rounded, color: corPrimaria), const SizedBox(width: 8), const Text('Atuação Profissional', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          SwitchListTile(
                            title: const Text('Status do Professor (Ativo/Inativo)', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Apenas professores ativos podem ser vinculados a turmas e diários.'),
                            activeThumbColor: corPrimaria,
                            value: _isAtivo,
                            onChanged: (v) => setState(() => _isAtivo = v),
                          ),
                          const SizedBox(height: 24),
                          const Text('Disciplinas Habilitadas (Selecione uma ou mais)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _disciplinasDisponiveis.map((disciplina) {
                              final isSelecionada = _disciplinasSelecionadas.contains(disciplina);
                              return FilterChip(
                                label: Text(disciplina),
                                selected: isSelecionada,
                                selectedColor: disciplina == 'OUTROS' ? Colors.orange.shade100 : corPrimaria.withAlpha(51),
                                checkmarkColor: disciplina == 'OUTROS' ? Colors.orange : corPrimaria,
                                side: BorderSide(color: isSelecionada ? (disciplina == 'OUTROS' ? Colors.orange : corPrimaria) : Colors.grey.shade300),
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      _disciplinasSelecionadas.add(disciplina);
                                    } else {
                                      _disciplinasSelecionadas.remove(disciplina);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          if (_disciplinasSelecionadas.contains('OUTROS')) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _outraDisciplinaCtrl,
                                      inputFormatters: [_upperCase],
                                      decoration: const InputDecoration(labelText: 'Qual outra disciplina quer adicionar?', filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                                      onFieldSubmitted: (v) => _adicionarDisciplinaCustomizada(),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24)),
                                    onPressed: _adicionarDisciplinaCustomizada,
                                    icon: const Icon(Icons.add, color: Colors.white),
                                    label: const Text('ADICIONAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(children: [Icon(Icons.folder_shared_rounded, color: Colors.deepPurple), SizedBox(width: 8), Text('Documentos e Certificados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple))]),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                                onPressed: _escolherAnexos,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Adicionar Arquivo'),
                              )
                            ],
                          ),
                          const Divider(height: 32),
                          if (_anexos.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
                              child: Column(
                                children: [
                                  Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text('Nenhum documento anexado.', style: TextStyle(color: Colors.grey.shade600)),
                                  const Text('Clique no botão acima para enviar PDFs, fotos ou certificados.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _anexos.length,
                              separatorBuilder: (ctx, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final anexo = _anexos[index];
                                final isPDF = anexo['extensao'] == 'pdf';
                                final isSalvo = anexo['url'] != null;

                                return Container(
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                  child: ListTile(
                                    leading: Icon(isPDF ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: isPDF ? Colors.red : Colors.blue, size: 32),
                                    title: Text(anexo['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(isSalvo ? 'Salvo nas nuvens' : 'Pronto para enviar (Aguardando Salvar Cadastro)', style: TextStyle(color: isSalvo ? Colors.green : Colors.orange, fontSize: 12)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSalvo)
                                          IconButton(
                                            icon: const Icon(Icons.download_rounded, color: Colors.blue),
                                            tooltip: 'Baixar / Visualizar Arquivo',
                                            onPressed: () => _abrirAnexoUrl(anexo['url']),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                          tooltip: 'Remover Anexo',
                                          onPressed: () => _removerAnexo(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.location_on_rounded, color: corPrimaria), const SizedBox(width: 8), const Text('Endereço', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          Row(children: [Expanded(flex: 3, child: TextFormField(controller: _ruaCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Rua', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(flex: 1, child: TextFormField(controller: _numeroCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Nº', border: OutlineInputBorder())))]),
                          const SizedBox(height: 16),
                          Row(children: [Expanded(child: TextFormField(controller: _bairroCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(child: TextFormField(controller: _cidadeCtrl, textInputAction: TextInputAction.done, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder())))]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _revisarESalvar,
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: Text(isEdicao ? 'ATUALIZAR CADASTRO' : 'SALVAR CADASTRO DO PROFESSOR', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}