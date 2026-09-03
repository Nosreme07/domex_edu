import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../estado/secretaria_provider.dart';

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

class AdminSecretariaFormTela extends ConsumerStatefulWidget {
  final Map<String, dynamic>? membroParaEditar;
  const AdminSecretariaFormTela({super.key, this.membroParaEditar});

  @override
  ConsumerState<AdminSecretariaFormTela> createState() => _AdminSecretariaFormTelaState();
}

class _AdminSecretariaFormTelaState extends ConsumerState<AdminSecretariaFormTela> {
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

  // === NOVO CAMPO: FUNÇÃO ===
  String? _funcaoSelecionada;
  final _funcaoCustomizadaCtrl = TextEditingController();
  final List<String> _funcoesPadrao = ['SECRETÁRIA', 'AUXILIAR ADMINISTRATIVO', 'PORTEIRO', 'ZELADOR', 'MONITOR(A)', 'COORDENADOR(A)', 'DIRETOR(A)', 'OUTROS'];

  bool _isAtivo = true;

  @override
  void initState() {
    super.initState();
    if (widget.membroParaEditar != null) {
      final mem = widget.membroParaEditar!;
      _fotoUrlExistente = mem['fotoUrl'];
      _nomeCtrl.text = mem['nome'] ?? '';
      _dataNascimentoCtrl.text = mem['dataNascimento'] ?? '';
      _cpfCtrl.text = mem['cpf'] ?? '';
      _telefoneCtrl.text = mem['telefone'] ?? '';
      _emailCtrl.text = mem['email'] ?? '';
      
      if (mem['endereco'] != null) {
        _ruaCtrl.text = mem['endereco']['rua'] ?? '';
        _numeroCtrl.text = mem['endereco']['numero'] ?? '';
        _bairroCtrl.text = mem['endereco']['bairro'] ?? '';
        _cidadeCtrl.text = mem['endereco']['cidade'] ?? '';
      }
      _isAtivo = mem['status'] == 'Ativo';

      // Tratamento do Cargo/Função
      final funcaoSalva = mem['funcao'] ?? '';
      if (funcaoSalva.isNotEmpty) {
        if (_funcoesPadrao.contains(funcaoSalva)) {
          _funcaoSelecionada = funcaoSalva;
        } else {
          _funcaoSelecionada = 'OUTROS';
          _funcaoCustomizadaCtrl.text = funcaoSalva;
        }
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _dataNascimentoCtrl.dispose();
    _cpfCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _ruaCtrl.dispose();
    _numeroCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    _funcaoCustomizadaCtrl.dispose();
    super.dispose();
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
        AndroidUiSettings(toolbarTitle: 'Enquadrar Foto 3x4', toolbarColor: Theme.of(context).primaryColor, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.original, lockAspectRatio: true),
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
      if (_funcaoSelecionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione a função/cargo.'), backgroundColor: Colors.red));
        return;
      }

      final isEdicao = widget.membroParaEditar != null;
      String idParaSalvar;

      if (isEdicao) {
        idParaSalvar = widget.membroParaEditar!['id'];
      } else {
        final listaSecretaria = ref.read(secretariaStreamProvider).value ?? [];
        int maiorSequencial = 0;
        for (var mem in listaSecretaria) {
          final idMem = mem['id']?.toString() ?? '';
          if (idMem.startsWith('SEC-')) {
            final sequencialStr = idMem.substring(4); 
            final sequencial = int.tryParse(sequencialStr) ?? 0;
            if (sequencial > maiorSequencial) maiorSequencial = sequencial;
          }
        }
        idParaSalvar = 'SEC-${(maiorSequencial + 1).toString().padLeft(2, '0')}'; 
      }

      final funcaoFinal = _funcaoSelecionada == 'OUTROS' ? _funcaoCustomizadaCtrl.text.trim() : _funcaoSelecionada!;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Row(children: [Icon(Icons.support_agent_rounded, color: Theme.of(context).primaryColor), const SizedBox(width: 8), Text(isEdicao ? 'Revisão da Edição' : 'Revisão do Cadastro', style: const TextStyle(fontWeight: FontWeight.bold))]),
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
                    Padding(padding: const EdgeInsets.only(bottom: 8.0), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [const TextSpan(text: 'Função: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: funcaoFinal)]))),
                    Padding(padding: const EdgeInsets.only(bottom: 8.0), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [const TextSpan(text: 'Status: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: _isAtivo ? 'Ativo' : 'Inativo')]))),
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
                      urlFinalFoto = await ref.read(secretariaServiceProvider).fazerUploadFoto(idParaSalvar, bytesFoto, extensao);
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
                      'funcao': funcaoFinal, // Salvando a nova função no banco de dados
                      'endereco': {'rua': _ruaCtrl.text, 'numero': _numeroCtrl.text, 'bairro': _bairroCtrl.text, 'cidade': _cidadeCtrl.text},
                      'status': _isAtivo ? 'Ativo' : 'Inativo',
                      'dataCadastro': isEdicao ? widget.membroParaEditar!['dataCadastro'] : DateTime.now().toIso8601String(),
                    };

                    await ref.read(secretariaServiceProvider).salvarSecretaria(dadosSalvar);
                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pop(); 
                    Navigator.pop(context); 
                    context.pop(); 
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdicao ? 'Atualizado!' : 'Membro da equipe salvo! ID: $idParaSalvar', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
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
    final isEdicao = widget.membroParaEditar != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdicao ? 'Editar Equipe' : 'Novo Cadastro de Equipe'), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1),
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
                              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)), child: Text(isEdicao ? 'ID: ${widget.membroParaEditar!['id']}' : 'ID: Gerado ao Salvar', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
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
                                        Expanded(flex: 2, child: TextFormField(controller: _emailCtrl, textInputAction: TextInputAction.next, inputFormatters: [_lowerCase], decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()), validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null)),
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
                          Row(children: [Icon(Icons.location_on_rounded, color: corPrimaria), const SizedBox(width: 8), const Text('Endereço & Atuação', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          
                          // ==========================================================
                          // NOVO BLOCO: FUNÇÃO / CARGO
                          // ==========================================================
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: _funcaoSelecionada,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Cargo / Função', border: OutlineInputBorder()),
                                  items: _funcoesPadrao.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                  onChanged: (v) => setState(() => _funcaoSelecionada = v),
                                  validator: (v) => v == null ? 'Selecione a função' : null,
                                ),
                              ),
                              if (_funcaoSelecionada == 'OUTROS') ...[
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _funcaoCustomizadaCtrl,
                                    inputFormatters: [_upperCase],
                                    decoration: InputDecoration(
                                      labelText: 'Qual é a função?', 
                                      filled: true, 
                                      fillColor: Colors.orange.shade50,
                                      border: const OutlineInputBorder()
                                    ),
                                    validator: (v) => v!.isEmpty ? 'Informe a função' : null,
                                  )
                                )
                              ]
                            ],
                          ),
                          const SizedBox(height: 24),

                          Row(children: [Expanded(flex: 3, child: TextFormField(controller: _ruaCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Rua', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(flex: 1, child: TextFormField(controller: _numeroCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Nº', border: OutlineInputBorder())))]),
                          const SizedBox(height: 16),
                          Row(children: [Expanded(child: TextFormField(controller: _bairroCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(child: TextFormField(controller: _cidadeCtrl, textInputAction: TextInputAction.done, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder())))]),
                          const SizedBox(height: 24),
                          SwitchListTile(
                            title: const Text('Status do Colaborador (Ativo/Inativo)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      label: Text(isEdicao ? 'ATUALIZAR CADASTRO' : 'SALVAR CADASTRO DA EQUIPE', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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