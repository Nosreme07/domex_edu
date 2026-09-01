import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/responsavel_provider.dart';
import '../estado/aluno_provider.dart'; // <-- IMPORT DO PROVIDER DE ALUNOS

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

class AdminResponsavelFormTela extends ConsumerStatefulWidget {
  final Map<String, dynamic>? responsavelParaEditar;
  const AdminResponsavelFormTela({super.key, this.responsavelParaEditar});

  @override
  ConsumerState<AdminResponsavelFormTela> createState() => _AdminResponsavelFormTelaState();
}

class _AdminResponsavelFormTelaState extends ConsumerState<AdminResponsavelFormTela> {
  final _formKey = GlobalKey<FormState>();
  final _upperCase = UpperCaseTextFormatter(); 
  final _lowerCase = LowerCaseTextFormatter();

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
  
  // Lista para armazenar os alunos vinculados neste cadastro
  final List<Map<String, dynamic>> _alunosSelecionados = [];

  @override
  void initState() {
    super.initState();
    if (widget.responsavelParaEditar != null) {
      final resp = widget.responsavelParaEditar!;
      _fotoUrlExistente = resp['fotoUrl'];
      _nomeCtrl.text = resp['nome'] ?? '';
      _dataNascimentoCtrl.text = resp['dataNascimento'] ?? '';
      _cpfCtrl.text = resp['cpf'] ?? '';
      _telefoneCtrl.text = resp['telefone'] ?? '';
      _emailCtrl.text = resp['email'] ?? '';
      
      if (resp['endereco'] != null) {
        _ruaCtrl.text = resp['endereco']['rua'] ?? '';
        _numeroCtrl.text = resp['endereco']['numero'] ?? '';
        _bairroCtrl.text = resp['endereco']['bairro'] ?? '';
        _cidadeCtrl.text = resp['endereco']['cidade'] ?? '';
      }
      _isAtivo = resp['status'] == 'Ativo';

      // Recupera os alunos que já estavam vinculados a este responsável
      if (resp['alunosVinculadosRaw'] != null) {
        final listaRaw = resp['alunosVinculadosRaw'] as List;
        for (var item in listaRaw) {
          _alunosSelecionados.add(Map<String, dynamic>.from(item));
        }
      }
    }
  }

  void _confirmarZerarSenha() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.lock_reset, color: Colors.blue), SizedBox(width: 8), Text('Zerar Senha de Acesso')]),
        content: Text('Tem certeza que deseja redefinir a senha de ${_nomeCtrl.text}?\n\nA senha voltará a ser o padrão: Domex@123'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha redefinida para Domex@123 com sucesso!'), backgroundColor: Colors.green));
            },
            child: const Text('Sim, Zerar Senha'),
          ),
        ],
      ),
    );
  }

  Future<void> _escolherFoto() async {
    try {
      final XFile? imagem = await _picker.pickImage(source: ImageSource.gallery);
      if (imagem != null) await _recortarEEnquadrar(imagem.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao acessar a galeria.')));
    }
  }

  Future<void> _recortarEEnquadrar(String path) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 4), 
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Enquadrar Foto', toolbarColor: Theme.of(context).primaryColor, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.original, lockAspectRatio: true),
        WebUiSettings(context: context),
      ],
    );
    if (croppedFile != null && mounted) setState(() => _fotoSelecionada = XFile(croppedFile.path));
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

  void _revisarESalvar() {
    if (_formKey.currentState!.validate()) {
      final isEdicao = widget.responsavelParaEditar != null;
      String idParaSalvar;

      if (!isEdicao && _alunosSelecionados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione pelo menos um aluno para gerar o ID do responsável.'), backgroundColor: Colors.red)
        );
        return;
      }

      if (isEdicao) {
        idParaSalvar = widget.responsavelParaEditar!['id'];
      } else {
        // Gera o ID com base na matrícula do primeiro aluno vinculado
        final matriculaBase = _alunosSelecionados.first['matricula'].toString();
        final listaResp = ref.read(responsavelStreamProvider).value ?? [];
        
        int ocorrencias = 0;
        for (var r in listaResp) {
          if (r['id'].toString().startsWith('RESP-$matriculaBase')) {
            ocorrencias++;
          }
        }
        
        if (ocorrencias == 0) {
          idParaSalvar = 'RESP-$matriculaBase';
        } else {
          idParaSalvar = 'RESP-$matriculaBase-${ocorrencias + 1}';
        }
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Row(children: [Icon(Icons.family_restroom_rounded, color: Theme.of(context).primaryColor), const SizedBox(width: 8), Text(isEdicao ? 'Revisão da Edição' : 'Revisão do Cadastro', style: const TextStyle(fontWeight: FontWeight.bold))]),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('ID: ', style: TextStyle(fontSize: 16, color: Colors.blue)), Text(idParaSalvar, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue))]),
                    ),
                    const SizedBox(height: 16),
                    Padding(padding: const EdgeInsets.only(bottom: 8.0), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [const TextSpan(text: 'Nome: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: _nomeCtrl.text)]))),
                    Padding(padding: const EdgeInsets.only(bottom: 8.0), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [const TextSpan(text: 'CPF: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: _cpfCtrl.text)]))),
                    Padding(padding: const EdgeInsets.only(bottom: 8.0), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [const TextSpan(text: 'Status: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: _isAtivo ? 'Ativo' : 'Inativo')]))),
                    const Divider(),
                    const Text('Alunos Vinculados:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _alunosSelecionados.map((a) => Chip(label: Text('${a['nome']} (${a['matricula']})', style: const TextStyle(fontSize: 12)), backgroundColor: Colors.grey.shade200, side: BorderSide.none)).toList(),
                    )
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar e Editar', style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.white)));
                  try {
                    String? urlFinalFoto = _fotoUrlExistente;
                    if (_fotoSelecionada != null) {
                      final bytesFoto = await _fotoSelecionada!.readAsBytes();
                      String extensao = _fotoSelecionada!.name.split('.').last.toLowerCase();
                      if (extensao != 'png' && extensao != 'jpg' && extensao != 'jpeg') extensao = 'png';
                      urlFinalFoto = await ref.read(responsavelServiceProvider).fazerUploadFoto(idParaSalvar, bytesFoto, extensao);
                    } else if (_fotoUrlExistente == null) {
                      urlFinalFoto = null;
                    }

                    final dadosSalvar = {
                      'id': idParaSalvar,
                      'nome': _nomeCtrl.text,
                      'dataNascimento': _dataNascimentoCtrl.text,
                      'cpf': _cpfCtrl.text,
                      'telefone': _telefoneCtrl.text,
                      'email': _emailCtrl.text,
                      'fotoUrl': urlFinalFoto,
                      'endereco': {'rua': _ruaCtrl.text, 'numero': _numeroCtrl.text, 'bairro': _bairroCtrl.text, 'cidade': _cidadeCtrl.text},
                      'status': _isAtivo ? 'Ativo' : 'Inativo',
                      'dataCadastro': isEdicao ? widget.responsavelParaEditar!['dataCadastro'] : DateTime.now().toIso8601String(),
                      'alunosVinculados': _alunosSelecionados.map((a) => '${a['nome']} (${a['matricula']})'.toUpperCase()).toList(),
                      'alunosVinculadosRaw': _alunosSelecionados.map((a) => {'nome': a['nome'], 'matricula': a['matricula']}).toList(),
                    };

                    await ref.read(responsavelServiceProvider).salvarResponsavel(dadosSalvar);
                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pop(); 
                    Navigator.pop(context); 
                    context.pop(); 
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdicao ? 'Atualizado!' : 'Responsável salvo! ID: $idParaSalvar', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
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

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final isEdicao = widget.responsavelParaEditar != null;
    final estadoAlunos = ref.watch(alunosStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdicao ? 'Editar Responsável' : 'Novo Cadastro de Responsável'), 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black87, 
        elevation: 1,
        actions: [
          if (isEdicao)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton.icon(icon: const Icon(Icons.lock_reset_rounded, color: Colors.red), label: const Text('Zerar Senha', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onPressed: _confirmarZerarSenha),
            )
        ],
      ),
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
                              Row(children: [Icon(Icons.family_restroom, color: corPrimaria), const SizedBox(width: 8), const Text('Dados Pessoais e Contato', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)), child: Text(isEdicao ? 'ID: ${widget.responsavelParaEditar!['id']}' : 'ID: Gerado ao Salvar', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
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
                                        Expanded(flex: 2, child: TextFormField(controller: _emailCtrl, textInputAction: TextInputAction.next, inputFormatters: [_lowerCase], decoration: const InputDecoration(labelText: 'E-mail (Para Login)', border: OutlineInputBorder()), validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null)),
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
                          Row(children: [Icon(Icons.school_rounded, color: corPrimaria), const SizedBox(width: 8), const Text('Vínculo Acadêmico (Alunos)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          if (!isEdicao)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16.0),
                              child: Text('Selecione o aluno para vincular. O ID de acesso do responsável será gerado automaticamente com base na matrícula do primeiro aluno selecionado.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ),
                          estadoAlunos.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (err, _) => Text('Erro: $err'),
                            data: (listaAlunosRaw) {
                              final listaAlunos = List<Map<String, dynamic>>.from(listaAlunosRaw);
                              listaAlunos.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

                              if (listaAlunos.isEmpty) return const Text('Nenhum aluno matriculado na escola.', style: TextStyle(color: Colors.red));
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return DropdownMenu<String>(
                                        width: constraints.maxWidth,
                                        enableFilter: true,
                                        enableSearch: true,
                                        requestFocusOnTap: true,
                                        leadingIcon: const Icon(Icons.person_search_rounded),
                                        label: const Text('Pesquisar Aluno (Nome ou Matrícula)'),
                                        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
                                        dropdownMenuEntries: listaAlunos.map((aluno) {
                                          return DropdownMenuEntry<String>(
                                            value: aluno['matricula'].toString(),
                                            label: '${aluno['nome']} (Matrícula: ${aluno['matricula']})'.toUpperCase(),
                                          );
                                        }).toList(),
                                        onSelected: (matriculaSelecionada) {
                                          if (matriculaSelecionada != null) {
                                            final aluno = listaAlunos.firstWhere((a) => a['matricula'].toString() == matriculaSelecionada);
                                            if (!_alunosSelecionados.any((a) => a['matricula'] == aluno['matricula'])) {
                                              setState(() {
                                                _alunosSelecionados.add(aluno);
                                              });
                                            }
                                          }
                                        },
                                      );
                                    }
                                  ),
                                  const SizedBox(height: 12),
                                  if (_alunosSelecionados.isNotEmpty) ...[
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _alunosSelecionados.map((aluno) {
                                        return Chip(
                                          avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                          label: Text('${aluno['nome']} (${aluno['matricula']})'.toUpperCase()),
                                          onDeleted: () {
                                            setState(() {
                                              _alunosSelecionados.removeWhere((a) => a['matricula'] == aluno['matricula']);
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
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
                          const SizedBox(height: 24),
                          SwitchListTile(
                            title: const Text('Cadastro Ativo?', style: TextStyle(fontWeight: FontWeight.bold)),
                            activeThumbColor: corPrimaria,
                            value: _isAtivo,
                            onChanged: (v) => setState(() => _isAtivo = v),
                          ),
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
                      label: Text(isEdicao ? 'ATUALIZAR CADASTRO' : 'SALVAR CADASTRO DO RESPONSÁVEL', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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