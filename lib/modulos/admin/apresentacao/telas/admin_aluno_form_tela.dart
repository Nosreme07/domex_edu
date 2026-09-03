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

import '../estado/aluno_provider.dart';
import '../estado/turma_provider.dart';

// ==========================================================
// FORMATADORES
// ==========================================================
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

class PessoaAutorizada {
  final TextEditingController nomeCtrl;
  final TextEditingController telCtrl;
  PessoaAutorizada({required this.nomeCtrl, required this.telCtrl});
}

class AdminAlunoFormTela extends ConsumerStatefulWidget {
  final Map<String, dynamic>? alunoParaEditar;
  
  const AdminAlunoFormTela({super.key, this.alunoParaEditar});

  @override
  ConsumerState<AdminAlunoFormTela> createState() => _AdminAlunoFormTelaState();
}

class _AdminAlunoFormTelaState extends ConsumerState<AdminAlunoFormTela> {
  final _formKey = GlobalKey<FormState>();

  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _telMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _dataMask = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
  final _upperCase = UpperCaseTextFormatter();
  final _lowerCase = LowerCaseTextFormatter();

  XFile? _fotoSelecionada;
  String? _fotoUrlExistente;
  final ImagePicker _picker = ImagePicker();

  final _nomeAlunoCtrl = TextEditingController();
  final _raCtrl = TextEditingController(); 
  final _telefoneAlunoCtrl = TextEditingController();
  final _cpfAlunoCtrl = TextEditingController();
  final _rgAlunoCtrl = TextEditingController();
  final _orgaoExpedidorCtrl = TextEditingController();
  final _naturalidadeCtrl = TextEditingController();
  String? _estadoNaturalidadeSelecionado;

  String? _sexoSelecionado;
  final _dataNascimentoCtrl = TextEditingController();
  String? _turmaSelecionada;
  bool _temIrmao = false;
  final List<Map<String, dynamic>> _irmaosSelecionados = []; 
  
  final _ruaCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  String? _estadoEnderecoSelecionado; 
  final _referenciaCtrl = TextEditingController();

  final _resp1NomeCtrl = TextEditingController();
  final _resp1CpfCtrl = TextEditingController();
  final _resp1TelCtrl = TextEditingController();
  final _resp1EmailCtrl = TextEditingController();

  final _resp2NomeCtrl = TextEditingController();
  final _resp2CpfCtrl = TextEditingController();
  final _resp2TelCtrl = TextEditingController();
  final _resp2EmailCtrl = TextEditingController();
  bool _autorizaSairSo = false;
  
  final List<PessoaAutorizada> _pessoasAutorizadas = []; 

  String? _tipoSanguineoSelecionado;
  bool _temProbSaude = false;
  final _probSaudeCtrl = TextEditingController();
  bool _tomaRemedio = false;
  final _remedioCtrl = TextEditingController();
  bool _temAlergia = false;
  final _alergiaCtrl = TextEditingController();
  final _obsMedicasCtrl = TextEditingController();

  final _emerg1NomeCtrl = TextEditingController();
  final _emerg1TelCtrl = TextEditingController();
  final _emerg2NomeCtrl = TextEditingController();
  final _emerg2TelCtrl = TextEditingController();
  final _emerg3NomeCtrl = TextEditingController();
  final _emerg3TelCtrl = TextEditingController();

  // === LISTA DE ANEXOS ===
  List<Map<String, dynamic>> _anexos = [];

  final List<String> _tiposSanguineos = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'NÃO SABE/NÃO INFORMADO'];
  final List<String> _estados = ['AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'];
  final List<String> _sexos = ['MASCULINO', 'FEMININO'];

  @override
  void initState() {
    super.initState();
    if (widget.alunoParaEditar != null) {
      final aluno = widget.alunoParaEditar!;
      
      _fotoUrlExistente = aluno['fotoUrl'];
      _nomeAlunoCtrl.text = aluno['nome'] ?? '';
      _raCtrl.text = aluno['ra'] ?? '';
      _telefoneAlunoCtrl.text = aluno['telefone'] ?? '';
      _cpfAlunoCtrl.text = aluno['cpf'] ?? '';
      _rgAlunoCtrl.text = aluno['rg'] ?? '';
      _orgaoExpedidorCtrl.text = aluno['orgaoExpedidor'] ?? '';
      _naturalidadeCtrl.text = aluno['naturalidade'] ?? '';
      _estadoNaturalidadeSelecionado = aluno['estadoNaturalidade'];
      _sexoSelecionado = aluno['sexo'];
      _dataNascimentoCtrl.text = aluno['dataNascimento'] ?? '';
      _turmaSelecionada = aluno['turma']; 
      _temIrmao = aluno['temIrmao'] ?? false;
      
      if (aluno['irmaosVinculadosRaw'] != null) {
        final listaRaw = aluno['irmaosVinculadosRaw'] as List;
        for (var item in listaRaw) {
          _irmaosSelecionados.add(Map<String, dynamic>.from(item));
        }
      } else if (aluno['irmaoSelecionado'] != null) {
        _irmaosSelecionados.add({'nome': aluno['irmaoSelecionado'].toString().split('(')[0].trim(), 'matricula': 'Desconhecida'});
      }

      if (aluno['endereco'] != null) {
        _ruaCtrl.text = aluno['endereco']['rua'] ?? '';
        _numeroCtrl.text = aluno['endereco']['numero'] ?? '';
        _bairroCtrl.text = aluno['endereco']['bairro'] ?? '';
        _cidadeCtrl.text = aluno['endereco']['cidade'] ?? '';
        _estadoEnderecoSelecionado = aluno['endereco']['estado'];
        _referenciaCtrl.text = aluno['endereco']['referencia'] ?? '';
      }

      if (aluno['responsaveis'] != null && aluno['responsaveis'] is List) {
        final resp = aluno['responsaveis'] as List;
        if (resp.isNotEmpty) {
          _resp1NomeCtrl.text = resp[0]['nome'] ?? '';
          _resp1CpfCtrl.text = resp[0]['cpf'] ?? '';
          _resp1TelCtrl.text = resp[0]['telefone'] ?? '';
          _resp1EmailCtrl.text = resp[0]['email'] ?? '';
        }
        if (resp.length > 1) {
          _resp2NomeCtrl.text = resp[1]['nome'] ?? '';
          _resp2CpfCtrl.text = resp[1]['cpf'] ?? '';
          _resp2TelCtrl.text = resp[1]['telefone'] ?? '';
          _resp2EmailCtrl.text = resp[1]['email'] ?? '';
        }
      }
      
      _autorizaSairSo = aluno['autorizaSairSo'] ?? false;

      if (aluno['pessoasAutorizadas'] != null && aluno['pessoasAutorizadas'] is List) {
        for (var p in aluno['pessoasAutorizadas']) {
          _pessoasAutorizadas.add(PessoaAutorizada(
            nomeCtrl: TextEditingController(text: p['nome'] ?? ''),
            telCtrl: TextEditingController(text: p['telefone'] ?? '')
          ));
        }
      }

      if (aluno['fichaMedica'] != null) {
        _tipoSanguineoSelecionado = aluno['fichaMedica']['tipoSanguineo'];
        _temProbSaude = aluno['fichaMedica']['temProblema'] ?? false;
        _probSaudeCtrl.text = aluno['fichaMedica']['problema'] ?? '';
        _tomaRemedio = aluno['fichaMedica']['tomaRemedio'] ?? false;
        _remedioCtrl.text = aluno['fichaMedica']['remedio'] ?? '';
        _temAlergia = aluno['fichaMedica']['temAlergia'] ?? false;
        _alergiaCtrl.text = aluno['fichaMedica']['alergia'] ?? '';
        _obsMedicasCtrl.text = aluno['fichaMedica']['observacoes'] ?? '';
      }

      if (aluno['emergencia'] != null && aluno['emergencia'] is List) {
        final emerg = aluno['emergencia'] as List;
        if (emerg.isNotEmpty) {
          _emerg1NomeCtrl.text = emerg[0]['nome'] ?? '';
          _emerg1TelCtrl.text = emerg[0]['telefone'] ?? '';
        }
        if (emerg.length > 1) {
          _emerg2NomeCtrl.text = emerg[1]['nome'] ?? '';
          _emerg2TelCtrl.text = emerg[1]['telefone'] ?? '';
        }
      }

      // CARREGA ANEXOS
      if (aluno['anexos'] != null) {
        _anexos = List<Map<String, dynamic>>.from(aluno['anexos']);
      }
    }
  }

  @override
  void dispose() {
    _nomeAlunoCtrl.dispose(); _raCtrl.dispose(); _telefoneAlunoCtrl.dispose(); _cpfAlunoCtrl.dispose(); _rgAlunoCtrl.dispose(); _orgaoExpedidorCtrl.dispose(); _naturalidadeCtrl.dispose();
    _dataNascimentoCtrl.dispose(); _ruaCtrl.dispose(); _numeroCtrl.dispose(); _bairroCtrl.dispose(); _cidadeCtrl.dispose(); _referenciaCtrl.dispose();
    _resp1NomeCtrl.dispose(); _resp1CpfCtrl.dispose(); _resp1TelCtrl.dispose(); _resp1EmailCtrl.dispose();
    _resp2NomeCtrl.dispose(); _resp2CpfCtrl.dispose(); _resp2TelCtrl.dispose(); _resp2EmailCtrl.dispose();
    _probSaudeCtrl.dispose(); _remedioCtrl.dispose(); _alergiaCtrl.dispose(); _obsMedicasCtrl.dispose();
    _emerg1NomeCtrl.dispose(); _emerg1TelCtrl.dispose(); _emerg2NomeCtrl.dispose(); _emerg2TelCtrl.dispose(); _emerg3NomeCtrl.dispose(); _emerg3TelCtrl.dispose();
    for (var p in _pessoasAutorizadas) {
      p.nomeCtrl.dispose();
      p.telCtrl.dispose();
    }
    super.dispose();
  }

  Widget _buildDropdownComBusca({
    required String label,
    required List<String> opcoes,
    required String? valorInicial,
    required Function(String) aoSelecionar,
    bool obrigatorio = false,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: valorInicial ?? ''),
      optionsBuilder: (TextEditingValue textoDigitado) {
        if (textoDigitado.text.isEmpty) return opcoes;
        return opcoes.where((opcao) => opcao.toUpperCase().contains(textoDigitado.text.toUpperCase()));
      },
      onSelected: (selecao) => aoSelecionar(selecao),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          inputFormatters: [_upperCase],
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          validator: (v) => obrigatorio && (v == null || v.isEmpty) ? 'Obrigatório' : null,
          onChanged: (val) => aoSelecionar(val),
        );
      },
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

  // === FUNÇÕES PARA ANEXOS ===
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
      if (!mounted) return;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o arquivo.')));
    }
  }

  void _revisarESalvar() {
    if (_formKey.currentState!.validate()) {
      final isEdicao = widget.alunoParaEditar != null;
      String matriculaParaSalvar;

      if (isEdicao) {
        matriculaParaSalvar = widget.alunoParaEditar!['matricula'];
      } else {
        final listaAlunos = ref.read(alunosStreamProvider).value ?? [];
        final anoAtual = DateTime.now().year.toString(); 
        int maiorSequencial = 0;
        for (var aluno in listaAlunos) {
          final mat = aluno['matricula']?.toString() ?? '';
          if (mat.startsWith(anoAtual) && mat.length >= 8) {
            final sequencialStr = mat.substring(4); 
            final sequencial = int.tryParse(sequencialStr) ?? 0;
            if (sequencial > maiorSequencial) maiorSequencial = sequencial;
          }
        }
        matriculaParaSalvar = '$anoAtual${(maiorSequencial + 1).toString().padLeft(4, '0')}'; 
      }

      // TRATAMENTO DA EXIBIÇÃO DE IRMÃOS NA REVISÃO
      String textoIrmaosRevisao = 'NÃO';
      if (_temIrmao) {
        if (_irmaosSelecionados.isNotEmpty) {
          textoIrmaosRevisao = 'SIM: ${_irmaosSelecionados.map((i) => i['nome']).join(', ')}';
        } else {
          textoIrmaosRevisao = 'SIM (Mas não vinculou no sistema)';
        }
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(isEdicao ? 'Confirmar Edição' : 'Revisão Completa de Cadastro', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 600, 
              height: 500, 
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Matrícula: ', style: TextStyle(fontSize: 16, color: Colors.blue)),
                          Text(matriculaParaSalvar, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    const Text('DADOS DO ALUNO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const Divider(),
                    _resumoLinha('Nome', _nomeAlunoCtrl.text),
                    if (_raCtrl.text.isNotEmpty) _resumoLinha('R.A.', _raCtrl.text),
                    _resumoLinha('Nascimento', _dataNascimentoCtrl.text),
                    _resumoLinha('Sexo', _sexoSelecionado ?? 'NÃO INFORMADO'),
                    if (_telefoneAlunoCtrl.text.isNotEmpty) _resumoLinha('Celular', _telefoneAlunoCtrl.text),
                    if (_cpfAlunoCtrl.text.isNotEmpty) _resumoLinha('CPF', _cpfAlunoCtrl.text),
                    if (_rgAlunoCtrl.text.isNotEmpty) _resumoLinha('RG', '${_rgAlunoCtrl.text} - Órgão: ${_orgaoExpedidorCtrl.text}'),
                    if (_naturalidadeCtrl.text.isNotEmpty) _resumoLinha('Naturalidade', '${_naturalidadeCtrl.text} / ${_estadoNaturalidadeSelecionado ?? ""}'),
                    
                    const SizedBox(height: 16),
                    
                    const Text('DADOS ACADÊMICOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const Divider(),
                    _resumoLinha('Turma', _turmaSelecionada ?? 'NÃO INFORMADA'),
                    _resumoLinha('Irmão(s)', textoIrmaosRevisao), // AGORA EXIBE OS NOMES AQUI NA REVISÃO

                    const SizedBox(height: 16),
                    
                    const Text('ENDEREÇO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const Divider(),
                    _resumoLinha('Logradouro', '${_ruaCtrl.text}, Nº ${_numeroCtrl.text}'),
                    _resumoLinha('Bairro/Cidade', '${_bairroCtrl.text} - ${_cidadeCtrl.text} / ${_estadoEnderecoSelecionado ?? ""}'),
                    if (_referenciaCtrl.text.isNotEmpty) _resumoLinha('Referência', _referenciaCtrl.text),

                    const SizedBox(height: 16),
                    
                    const Text('RESPONSÁVEIS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const Divider(),
                    _resumoLinha('Resp. Principal', '${_resp1NomeCtrl.text} (Tel: ${_resp1TelCtrl.text})'),
                    if (_resp1CpfCtrl.text.isNotEmpty) _resumoLinha('CPF Principal', _resp1CpfCtrl.text),
                    if (_resp2NomeCtrl.text.isNotEmpty) _resumoLinha('Resp. Secundário', '${_resp2NomeCtrl.text} (Tel: ${_resp2TelCtrl.text})'),
                    _resumoLinha('Autoriza Sair Só', _autorizaSairSo ? 'SIM' : 'NÃO'),
                    
                    if (_pessoasAutorizadas.where((p) => p.nomeCtrl.text.isNotEmpty).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('AUTORIZADOS A BUSCAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const Divider(),
                      ..._pessoasAutorizadas.where((p) => p.nomeCtrl.text.isNotEmpty).map((p) => 
                        _resumoLinha('Autorizado', '${p.nomeCtrl.text} (Tel: ${p.telCtrl.text})')
                      ),
                    ],

                    const SizedBox(height: 16),
                    
                    const Text('SAÚDE E EMERGÊNCIA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const Divider(),
                    _resumoLinha('Tipo Sanguíneo', _tipoSanguineoSelecionado ?? 'NÃO INFORMADO'),
                    _resumoLinha('Problema de Saúde', _temProbSaude ? 'SIM: ${_probSaudeCtrl.text}' : 'NÃO'),
                    _resumoLinha('Toma Remédio', _tomaRemedio ? 'SIM: ${_remedioCtrl.text}' : 'NÃO'),
                    _resumoLinha('Alergias', _temAlergia ? 'SIM: ${_alergiaCtrl.text}' : 'NÃO'),
                    if (_obsMedicasCtrl.text.isNotEmpty) _resumoLinha('Obs. Médicas', _obsMedicasCtrl.text),
                    
                    if (_emerg1NomeCtrl.text.isNotEmpty) _resumoLinha('Emergência 1', '${_emerg1NomeCtrl.text} (Tel: ${_emerg1TelCtrl.text})'),
                    if (_emerg2NomeCtrl.text.isNotEmpty) _resumoLinha('Emergência 2', '${_emerg2NomeCtrl.text} (Tel: ${_emerg2TelCtrl.text})'),
                    if (_emerg3NomeCtrl.text.isNotEmpty) _resumoLinha('Emergência 3', '${_emerg3NomeCtrl.text} (Tel: ${_emerg3TelCtrl.text})'),

                    const SizedBox(height: 16),
                    _resumoLinha('Documentos Anexados', '${_anexos.length} arquivo(s)'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar e Editar', style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  showDialog(context: context, barrierDismissible: false, builder: (dialogContext) => const Center(child: CircularProgressIndicator(color: Colors.white)));

                  try {
                    // Upload da Foto
                    String? urlFinalFoto = _fotoUrlExistente;
                    if (_fotoSelecionada != null) {
                      final bytesFoto = await _fotoSelecionada!.readAsBytes();
                      String extensao = _fotoSelecionada!.name.split('.').last.toLowerCase();
                      if (extensao != 'png' && extensao != 'jpg' && extensao != 'jpeg') extensao = 'png';
                      urlFinalFoto = await ref.read(alunoServiceProvider).fazerUploadFoto(matriculaParaSalvar, bytesFoto, extensao);
                    } else if (_fotoUrlExistente == null) {
                      urlFinalFoto = null;
                    }

                    // Upload dos Documentos Anexos
                    List<Map<String, dynamic>> anexosParaSalvar = [];
                    for (var anexo in _anexos) {
                      if (anexo['url'] == null && anexo['bytes'] != null) {
                        String nomeUnico = 'anexo_${DateTime.now().millisecondsSinceEpoch}.${anexo['extensao']}';
                        String? urlDownload = await ref.read(alunoServiceProvider).fazerUploadArquivo(matriculaParaSalvar, nomeUnico, anexo['bytes'], anexo['extensao']);
                        
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

                    String turmaIdSalvar = '';
                    if (isEdicao && widget.alunoParaEditar!['turmaId'] != null) {
                      turmaIdSalvar = widget.alunoParaEditar!['turmaId'];
                    }

                    final listaTurmas = ref.read(turmasStreamProvider).value ?? [];
                    for (var t in listaTurmas) {
                      final turnoFormatado = t['turno'] ?? '';
                      final nomeFormatado = '${t['nome']} (${t['anoLetivo']}) - $turnoFormatado'.toUpperCase();
                      
                      if (nomeFormatado == _turmaSelecionada?.toUpperCase()) {
                        turmaIdSalvar = t['id']?.toString() ?? '';
                        break;
                      }
                    }

                    final autorizadosSalvar = _pessoasAutorizadas
                        .where((p) => p.nomeCtrl.text.trim().isNotEmpty)
                        .map((p) => {'nome': p.nomeCtrl.text, 'telefone': p.telCtrl.text})
                        .toList();

                    final dadosAluno = {
                      'matricula': matriculaParaSalvar,
                      'nome': _nomeAlunoCtrl.text,
                      'ra': _raCtrl.text,
                      'telefone': _telefoneAlunoCtrl.text,
                      'cpf': _cpfAlunoCtrl.text,
                      'rg': _rgAlunoCtrl.text,
                      'orgaoExpedidor': _orgaoExpedidorCtrl.text,
                      'naturalidade': _naturalidadeCtrl.text,
                      'estadoNaturalidade': _estadoNaturalidadeSelecionado,
                      'sexo': _sexoSelecionado,
                      'dataNascimento': _dataNascimentoCtrl.text,
                      'turma': _turmaSelecionada,
                      'turmaId': turmaIdSalvar, 
                      'temIrmao': _temIrmao,
                      'irmaosVinculadosRaw': _irmaosSelecionados.map((a) => {'nome': a['nome'], 'matricula': a['matricula']}).toList(),
                      'irmaosVinculados': _irmaosSelecionados.map((a) => '${a['nome']} (${a['matricula']})'.toUpperCase()).toList(),
                      'fotoUrl': urlFinalFoto,
                      'anexos': anexosParaSalvar, // Salvando a lista de documentos no banco!
                      'endereco': {
                        'rua': _ruaCtrl.text, 'numero': _numeroCtrl.text,
                        'bairro': _bairroCtrl.text, 'cidade': _cidadeCtrl.text,
                        'estado': _estadoEnderecoSelecionado, 
                        'referencia': _referenciaCtrl.text,
                      },
                      'responsaveis': [
                        {'nome': _resp1NomeCtrl.text, 'cpf': _resp1CpfCtrl.text, 'telefone': _resp1TelCtrl.text, 'email': _resp1EmailCtrl.text, 'principal': true},
                        if (_resp2NomeCtrl.text.isNotEmpty) {'nome': _resp2NomeCtrl.text, 'cpf': _resp2CpfCtrl.text, 'telefone': _resp2TelCtrl.text, 'email': _resp2EmailCtrl.text, 'principal': false}
                      ],
                      'autorizaSairSo': _autorizaSairSo,
                      'pessoasAutorizadas': autorizadosSalvar,
                      'fichaMedica': {
                        'tipoSanguineo': _tipoSanguineoSelecionado,
                        'temProblema': _temProbSaude, 'problema': _probSaudeCtrl.text,
                        'tomaRemedio': _tomaRemedio, 'remedio': _remedioCtrl.text,
                        'temAlergia': _temAlergia, 'alergia': _alergiaCtrl.text,
                        'observacoes': _obsMedicasCtrl.text,
                      },
                      'emergencia': [
                        if (_emerg1NomeCtrl.text.isNotEmpty) {'nome': _emerg1NomeCtrl.text, 'telefone': _emerg1TelCtrl.text},
                        if (_emerg2NomeCtrl.text.isNotEmpty) {'nome': _emerg2NomeCtrl.text, 'telefone': _emerg2TelCtrl.text},
                        if (_emerg3NomeCtrl.text.isNotEmpty) {'nome': _emerg3NomeCtrl.text, 'telefone': _emerg3TelCtrl.text},
                      ],
                      'status': isEdicao ? widget.alunoParaEditar!['status'] : 'Ativo',
                      'dataCadastro': isEdicao ? widget.alunoParaEditar!['dataCadastro'] : DateTime.now().toIso8601String(),
                    };

                    await ref.read(alunoServiceProvider).salvarAluno(dadosAluno);
                    
                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pop(); 
                    Navigator.pop(context); 
                    context.pop(); 
                    
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdicao ? 'Atualizado com sucesso!' : 'Matriculado com sucesso!', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); 
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERRO: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red, duration: const Duration(seconds: 10)));
                    }
                  }
                },
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                label: Text(isEdicao ? 'Confirmar Edição' : 'Confirmar Matrícula', style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha os campos obrigatórios em vermelho.')));
    }
  }

  Widget _resumoLinha(String label, String valor) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: valor)])));
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final isEdicao = widget.alunoParaEditar != null;

    final estadoTurmas = ref.watch(turmasStreamProvider);
    List<String> turmasDisponiveis = [];
    
    estadoTurmas.whenData((turmas) { 
      turmasDisponiveis = turmas.map((t) {
        final turno = t['turno'] ?? '';
        return '${t['nome']} (${t['anoLetivo']}) - $turno'.toUpperCase();
      }).toList(); 
    });
    
    turmasDisponiveis.add('FUTURA TURMA');

    if (_turmaSelecionada != null && !turmasDisponiveis.contains(_turmaSelecionada)) {
      turmasDisponiveis.add(_turmaSelecionada!);
    }

    final estadoAlunos = ref.watch(alunosStreamProvider);
    List<Map<String, dynamic>> alunosCadastrados = [];
    estadoAlunos.whenData((alunos) => alunosCadastrados = alunos);

    return Scaffold(
      appBar: AppBar(title: Text(isEdicao ? 'Editar Matrícula do Aluno' : 'Nova Matrícula de Aluno'), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1),
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
                  // ==========================================================
                  // 1. DADOS DO ALUNO
                  // ==========================================================
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.person, color: corPrimaria), const SizedBox(width: 8), const Text('Dados do Aluno', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
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
                                        Expanded(flex: 3, child: TextFormField(controller: _nomeAlunoCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                                        const SizedBox(width: 16),
                                        Expanded(flex: 1, child: TextFormField(controller: _raCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'R.A. (Opcional)', border: OutlineInputBorder()))),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(child: TextFormField(controller: _dataNascimentoCtrl, textInputAction: TextInputAction.next, inputFormatters: [_dataMask, _upperCase], decoration: const InputDecoration(labelText: 'Nascimento', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _buildDropdownComBusca(label: 'Sexo', opcoes: _sexos, valorInicial: _sexoSelecionado, aoSelecionar: (v) => setState(() => _sexoSelecionado = v))),
                                        const SizedBox(width: 16),
                                        Expanded(child: TextFormField(controller: _telefoneAlunoCtrl, textInputAction: TextInputAction.next, inputFormatters: [_telMask, _upperCase], decoration: const InputDecoration(labelText: 'Celular (Opcional)', hintText: '(xx) xxxxx-xxxx', border: OutlineInputBorder()))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          Row(
                            children: [
                              Expanded(flex: 2, child: TextFormField(controller: _cpfAlunoCtrl, textInputAction: TextInputAction.next, inputFormatters: [_cpfMask, _upperCase], decoration: const InputDecoration(labelText: 'CPF (Opcional)', hintText: 'xxx.xxx.xxx-xx', border: OutlineInputBorder()))),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: TextFormField(controller: _rgAlunoCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'RG (Opcional)', border: OutlineInputBorder()))),
                              const SizedBox(width: 16),
                              Expanded(flex: 1, child: TextFormField(controller: _orgaoExpedidorCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Órg. Exp.', hintText: 'Ex: SSP', border: OutlineInputBorder()))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(flex: 3, child: TextFormField(controller: _naturalidadeCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Naturalidade (Cidade)', border: OutlineInputBorder()))),
                              const SizedBox(width: 16),
                              Expanded(flex: 1, child: _buildDropdownComBusca(label: 'Estado (UF)', opcoes: _estados, valorInicial: _estadoNaturalidadeSelecionado, aoSelecionar: (v) => setState(() => _estadoNaturalidadeSelecionado = v))),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          _buildDropdownComBusca(label: 'Turma (ou Futura Turma)', opcoes: turmasDisponiveis, valorInicial: _turmaSelecionada, obrigatorio: true, aoSelecionar: (v) => setState(() => _turmaSelecionada = v)),
                          const SizedBox(height: 24),
                          
                          SwitchListTile(title: const Text('Tem irmão(s) matriculado(s) nesta escola?'), activeThumbColor: corPrimaria, value: _temIrmao, onChanged: (v) => setState(() => _temIrmao = v)),
                          if (_temIrmao)
                            Container(
                              padding: const EdgeInsets.all(16), color: Colors.grey.shade50,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LayoutBuilder(builder: (context, constraints) {
                                    return Autocomplete<Map<String, dynamic>>(
                                      displayStringForOption: (aluno) => '${aluno['nome']} (Mat: ${aluno['matricula']})',
                                      optionsBuilder: (TextEditingValue v) {
                                        if (v.text.isEmpty) return alunosCadastrados;
                                        return alunosCadastrados.where((a) => a['nome'].toString().toLowerCase().contains(v.text.toLowerCase()) || a['matricula'].toString().contains(v.text));
                                      },
                                      onSelected: (aluno) {
                                        if (!_irmaosSelecionados.any((a) => a['matricula'] == aluno['matricula'])) {
                                          setState(() => _irmaosSelecionados.add(aluno));
                                        }
                                      },
                                      fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextFormField(controller: ctrl, focusNode: focus, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Pesquisar e Adicionar Irmão', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search_rounded))),
                                      optionsViewBuilder: (ctx, onSel, options) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), child: SizedBox(width: constraints.maxWidth, height: 200, child: ListView.builder(padding: EdgeInsets.zero, itemCount: options.length, itemBuilder: (ctx, idx) { final a = options.elementAt(idx); return ListTile(leading: CircleAvatar(backgroundImage: a['fotoUrl'] != null ? NetworkImage(a['fotoUrl']) : null), title: Text(a['nome'] ?? ''), subtitle: Text('Mat: ${a['matricula']}'), onTap: () => onSel(a));})))),
                                    );
                                  }),
                                  if (_irmaosSelecionados.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8, runSpacing: 8,
                                      children: _irmaosSelecionados.map((irmao) {
                                        return Chip(
                                          avatar: const Icon(Icons.group, size: 16, color: Colors.blue),
                                          label: Text('${irmao['nome']} (${irmao['matricula']})'.toUpperCase()),
                                          onDeleted: () => setState(() => _irmaosSelecionados.removeWhere((a) => a['matricula'] == irmao['matricula'])),
                                        );
                                      }).toList(),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                            
                          const SizedBox(height: 24),
                          const Text('Endereço', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          Row(children: [Expanded(flex: 3, child: TextFormField(controller: _ruaCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Rua / Avenida', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(flex: 1, child: TextFormField(controller: _numeroCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Nº', border: OutlineInputBorder())))]),
                          const SizedBox(height: 16),
                          Row(children: [Expanded(flex: 3, child: TextFormField(controller: _bairroCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(flex: 3, child: TextFormField(controller: _cidadeCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(flex: 1, child: _buildDropdownComBusca(label: 'UF', opcoes: _estados, valorInicial: _estadoEnderecoSelecionado, aoSelecionar: (v) => setState(() => _estadoEnderecoSelecionado = v)))]),
                          const SizedBox(height: 16),
                          TextFormField(controller: _referenciaCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Ponto de Referência', border: OutlineInputBorder())),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ==========================================================
                  // 2. DADOS DOS RESPONSÁVEIS
                  // ==========================================================
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.family_restroom, color: corPrimaria), const SizedBox(width: 8), const Text('Dados dos Responsáveis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          const Text('Responsável Principal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 16),
                          TextFormField(controller: _resp1NomeCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder())),
                          const SizedBox(height: 16),
                          Row(children: [Expanded(flex: 2, child: TextFormField(controller: _resp1CpfCtrl, textInputAction: TextInputAction.next, inputFormatters: [_cpfMask, _upperCase], decoration: const InputDecoration(labelText: 'CPF', hintText: 'xxx.xxx.xxx-xx', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(flex: 2, child: TextFormField(controller: _resp1TelCtrl, textInputAction: TextInputAction.next, inputFormatters: [_telMask, _upperCase], decoration: const InputDecoration(labelText: 'Telefone', hintText: '(xx) xxxxx-xxxx', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(flex: 3, child: TextFormField(controller: _resp1EmailCtrl, textInputAction: TextInputAction.next, inputFormatters: [_lowerCase], decoration: const InputDecoration(labelText: 'E-mail (Para Login)', border: OutlineInputBorder())))]),
                          const SizedBox(height: 32),
                          const Text('Segundo Responsável (Opcional)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 16),
                          TextFormField(controller: _resp2NomeCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder())),
                          const SizedBox(height: 16),
                          Row(children: [Expanded(flex: 2, child: TextFormField(controller: _resp2CpfCtrl, textInputAction: TextInputAction.next, inputFormatters: [_cpfMask, _upperCase], decoration: const InputDecoration(labelText: 'CPF', hintText: 'xxx.xxx.xxx-xx', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(flex: 2, child: TextFormField(controller: _resp2TelCtrl, textInputAction: TextInputAction.next, inputFormatters: [_telMask, _upperCase], decoration: const InputDecoration(labelText: 'Telefone', hintText: '(xx) xxxxx-xxxx', border: OutlineInputBorder()))), const SizedBox(width: 16), Expanded(flex: 3, child: TextFormField(controller: _resp2EmailCtrl, textInputAction: TextInputAction.next, inputFormatters: [_lowerCase], decoration: const InputDecoration(labelText: 'E-mail (Para Login)', border: OutlineInputBorder())))]),
                          const Divider(height: 32),
                          
                          SwitchListTile(title: const Text('Autoriza o aluno a sair SOZINHO da escola?'), subtitle: const Text('Válido para saída ao término das aulas.'), activeThumbColor: corPrimaria, value: _autorizaSairSo, onChanged: (v) => setState(() => _autorizaSairSo = v)),
                          
                          const SizedBox(height: 24),
                          const Text('Pessoas Autorizadas a Buscar o Aluno na Escola', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
                          const SizedBox(height: 16),
                          ..._pessoasAutorizadas.asMap().entries.map((entry) {
                            int index = entry.key;
                            var p = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: TextFormField(controller: p.nomeCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: InputDecoration(labelText: 'Nome da Pessoa Autorizada', border: const OutlineInputBorder(), prefixIcon: Icon(Icons.badge, color: Colors.grey.shade400)))),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 2, child: TextFormField(controller: p.telCtrl, textInputAction: TextInputAction.next, inputFormatters: [_telMask, _upperCase], decoration: InputDecoration(labelText: 'Telefone', hintText: '(xx) xxxxx-xxxx', border: const OutlineInputBorder(), prefixIcon: Icon(Icons.phone, color: Colors.grey.shade400)))),
                                  const SizedBox(width: 8),
                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Remover', onPressed: () => setState(() => _pessoasAutorizadas.removeAt(index))),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                            onPressed: () => setState(() => _pessoasAutorizadas.add(PessoaAutorizada(nomeCtrl: TextEditingController(), telCtrl: TextEditingController()))),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('ADICIONAR PESSOA AUTORIZADA', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ==========================================================
                  // 3. ANEXOS / DOCUMENTOS
                  // ==========================================================
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
                              const Row(children: [Icon(Icons.folder_shared_rounded, color: Colors.deepPurple), SizedBox(width: 8), Text('Documentos do Aluno (RG, Histórico, etc.)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple))]),
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
                                  const Text('Envie PDFs ou imagens (RG dos pais, Histórico Escolar, Laudo Médico).', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                                    subtitle: Text(isSalvo ? 'Salvo nas nuvens' : 'Pronto para enviar', style: TextStyle(color: isSalvo ? Colors.green : Colors.orange, fontSize: 12)),
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

                  // ==========================================================
                  // 4. FICHA MÉDICA E EMERGÊNCIA
                  // ==========================================================
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.medical_information, color: corPrimaria), const SizedBox(width: 8), const Text('Ficha Médica e Emergência', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          _buildDropdownComBusca(label: 'Tipo Sanguíneo (Opcional)', opcoes: _tiposSanguineos, valorInicial: _tipoSanguineoSelecionado, aoSelecionar: (v) => setState(() => _tipoSanguineoSelecionado = v)),
                          const SizedBox(height: 24),
                          SwitchListTile(title: const Text('O aluno possui algum problema de saúde?'), activeThumbColor: corPrimaria, value: _temProbSaude, onChanged: (v) => setState(() => _temProbSaude = v)),
                          if (_temProbSaude) Padding(padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16), child: TextFormField(controller: _probSaudeCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Qual problema?', border: OutlineInputBorder()))),
                          SwitchListTile(title: const Text('Faz uso de alguma medicação controlada/contínua?'), activeThumbColor: corPrimaria, value: _tomaRemedio, onChanged: (v) => setState(() => _tomaRemedio = v)),
                          if (_tomaRemedio) Padding(padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16), child: TextFormField(controller: _remedioCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Qual medicamento e horário?', border: OutlineInputBorder()))),
                          SwitchListTile(title: const Text('Possui alguma alergia (Alimentar, medicamento, insetos)?'), activeThumbColor: corPrimaria, value: _temAlergia, onChanged: (v) => setState(() => _temAlergia = v)),
                          if (_temAlergia) Padding(padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16), child: TextFormField(controller: _alergiaCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Especifique as alergias', border: OutlineInputBorder()))),
                          const SizedBox(height: 16),
                          TextFormField(controller: _obsMedicasCtrl, textInputAction: TextInputAction.newline, inputFormatters: [_upperCase], maxLines: 3, decoration: const InputDecoration(labelText: 'Observações Gerais (Opcional)', border: OutlineInputBorder())),
                          const SizedBox(height: 32),
                          const Text('Contatos de Emergência', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          _buildEmergenciaRow('1º Contato', _emerg1NomeCtrl, _emerg1TelCtrl), const SizedBox(height: 8),
                          _buildEmergenciaRow('2º Contato', _emerg2NomeCtrl, _emerg2TelCtrl), const SizedBox(height: 8),
                          _buildEmergenciaRow('3º Contato', _emerg3NomeCtrl, _emerg3TelCtrl),
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
                      label: Text(isEdicao ? 'ATUALIZAR MATRÍCULA DO ALUNO' : 'SALVAR MATRÍCULA DO ALUNO', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildEmergenciaRow(String label, TextEditingController nomeCtrl, TextEditingController telCtrl) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 3, child: TextFormField(controller: nomeCtrl, textInputAction: TextInputAction.next, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()))),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: TextFormField(controller: telCtrl, textInputAction: TextInputAction.next, inputFormatters: [_telMask, _upperCase], decoration: const InputDecoration(labelText: 'Telefone', hintText: '(xx) xxxxx-xxxx', border: OutlineInputBorder()))),
      ],
    );
  }
}