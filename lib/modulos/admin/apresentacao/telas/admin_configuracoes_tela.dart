import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class AdminConfiguracoesTela extends ConsumerStatefulWidget {
  const AdminConfiguracoesTela({super.key});

  @override
  ConsumerState<AdminConfiguracoesTela> createState() => _AdminConfiguracoesTelaState();
}

class _AdminConfiguracoesTelaState extends ConsumerState<AdminConfiguracoesTela> {
  final _formKey = GlobalKey<FormState>();
  bool _carregando = true;
  bool _salvando = false;

  // ==========================================================================
  // VARIÁVEIS E MÁSCARAS
  // ==========================================================================
  final _cnpjMask = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  final _telMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  
  final List<String> _estadosUF = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 
    'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
  ];
  String? _ufSelecionada;

  // Imagem e Cores
  String? _logoUrlExistente;
  XFile? _logoSelecionada;
  final ImagePicker _picker = ImagePicker();

  Color _corPrimariaSelecionada = Colors.blue.shade800;
  Color _corSecundariaSelecionada = Colors.blue.shade500;

  // Controladores de Texto
  final _nomeInstCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _responsavelCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  
  final _instaCtrl = TextEditingController();
  final _faceCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();

  final _ruaCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDadosDaEscola();
    });
  }

  @override
  void dispose() {
    _nomeInstCtrl.dispose(); _cnpjCtrl.dispose(); _sloganCtrl.dispose();
    _responsavelCtrl.dispose(); _emailCtrl.dispose(); _telefoneCtrl.dispose();
    _instaCtrl.dispose(); _faceCtrl.dispose(); _youtubeCtrl.dispose();
    _ruaCtrl.dispose(); _numeroCtrl.dispose(); _bairroCtrl.dispose(); _cidadeCtrl.dispose();
    super.dispose();
  }

  Color _converterHexParaColor(String? hex, Color corPadrao) {
    if (hex == null || hex.isEmpty) return corPadrao;
    try {
      String cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return corPadrao;
    }
  }

  Future<void> _carregarDadosDaEscola() async {
    final usuario = ref.read(authProvider).value;
    if (usuario == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('tenants').doc(usuario.id).get();
      
      if (doc.exists && doc.data() != null) {
        final dados = doc.data()!;
        
        setState(() {
          _nomeInstCtrl.text = dados['nomeEscola'] ?? dados['nome'] ?? '';
          _cnpjCtrl.text = dados['cnpj'] ?? '';
          _sloganCtrl.text = dados['slogan'] ?? '';
          _responsavelCtrl.text = dados['responsavel'] ?? '';
          _emailCtrl.text = dados['email'] ?? '';
          _telefoneCtrl.text = dados['telefone'] ?? '';
          
          _instaCtrl.text = dados['instagram'] ?? '';
          _faceCtrl.text = dados['facebook'] ?? '';
          _youtubeCtrl.text = dados['youtube'] ?? '';
          
          _corPrimariaSelecionada = _converterHexParaColor(dados['corPrimaria'] ?? dados['corHex'], Colors.blue.shade800);
          _corSecundariaSelecionada = _converterHexParaColor(dados['corSecundaria'], Colors.blue.shade500);
          
          _logoUrlExistente = dados['logoUrl'] ?? dados['fotoUrl'] ?? dados['logo'];

          final end = dados['endereco'] ?? {};
          _ruaCtrl.text = end['rua'] ?? '';
          _numeroCtrl.text = end['numero'] ?? '';
          _bairroCtrl.text = end['bairro'] ?? '';
          _cidadeCtrl.text = end['cidade'] ?? '';
          if (end['estado'] != null && _estadosUF.contains(end['estado'])) {
            _ufSelecionada = end['estado'];
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar configurações: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _salvarConfiguracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    final usuario = ref.read(authProvider).value;

    if (usuario != null) {
      try {
        String? linkLogoFinal = _logoUrlExistente;

        if (_logoSelecionada != null) {
          final caminhoStorage = FirebaseStorage.instance.ref().child('logos/${usuario.id}_logo.png');
          final bytes = await _logoSelecionada!.readAsBytes();
          await caminhoStorage.putData(bytes, SettableMetadata(contentType: 'image/png'));
          linkLogoFinal = await caminhoStorage.getDownloadURL();
        }

        final dadosParaSalvar = {
          'nomeEscola': _nomeInstCtrl.text.trim(),
          'cnpj': _cnpjCtrl.text.trim(),
          'slogan': _sloganCtrl.text.trim(),
          'responsavel': _responsavelCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'telefone': _telefoneCtrl.text.trim(),
          'instagram': _instaCtrl.text.trim(),
          'facebook': _faceCtrl.text.trim(),
          'youtube': _youtubeCtrl.text.trim(),
          'corPrimaria': '#${_corPrimariaSelecionada.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
          'corSecundaria': '#${_corSecundariaSelecionada.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
          if (linkLogoFinal != null) 'logoUrl': linkLogoFinal,
          'endereco': {
            'rua': _ruaCtrl.text.trim(),
            'numero': _numeroCtrl.text.trim(),
            'bairro': _bairroCtrl.text.trim(),
            'cidade': _cidadeCtrl.text.trim(),
            'estado': _ufSelecionada ?? '',
          },
          'ultimaAtualizacao': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance.collection('tenants').doc(usuario.id).set(dadosParaSalvar, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações salvas com sucesso!'), backgroundColor: Colors.green));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
      }
    }
    
    setState(() => _salvando = false);
  }

  Future<void> _escolherERecortarLogo() async {
    final XFile? imagem = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;

    if (imagem != null) {
      CroppedFile? imagemRecortada = await ImageCropper().cropImage(
        sourcePath: imagem.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Enquadrar Logo da Escola', toolbarColor: Theme.of(context).primaryColor, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.square, lockAspectRatio: true),
          IOSUiSettings(title: 'Enquadrar Logo', aspectRatioLockEnabled: true),
          WebUiSettings(context: context, presentStyle: WebPresentStyle.dialog),
        ],
      );

      if (imagemRecortada != null) {
        setState(() {
          _logoSelecionada = XFile(imagemRecortada.path);
          _logoUrlExistente = null; 
        });
      }
    }
  }

  void _abrirSeletorDeCores({required bool isPrimaria}) {
    Color corTemporaria = isPrimaria ? _corPrimariaSelecionada : _corSecundariaSelecionada;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isPrimaria ? 'Selecione a Cor Primária' : 'Selecione a Cor Secundária'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: corTemporaria,
              onColorChanged: (Color cor) => corTemporaria = cor,
              colorPickerWidth: 300,
              pickerAreaHeightPercent: 0.7,
              enableAlpha: false, 
              displayThumbColor: true,
              labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb], 
              paletteType: PaletteType.hsvWithHue, 
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF080E1C), foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  if (isPrimaria) _corPrimariaSelecionada = corTemporaria;
                  else _corSecundariaSelecionada = corTemporaria;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Confirmar Cor'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final corPrimariaTema = Theme.of(context).primaryColor;

    if (_carregando) return Scaffold(backgroundColor: Colors.grey.shade50, body: Center(child: CircularProgressIndicator(color: corPrimariaTema)));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1,
        title: const Text('Configurações da Escola', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Identidade Visual e Dados', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Personalize as cores, logo e informações cadastrais da sua instituição.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  const SizedBox(height: 32),

                  // ================= CARD 1: IDENTIDADE VISUAL =================
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.palette_rounded, color: corPrimariaTema), const SizedBox(width: 8), const Text('Identidade Visual', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  InkWell(
                                    onTap: _escolherERecortarLogo,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 150, height: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16),
                                        image: _logoUrlExistente != null && _logoSelecionada == null ? DecorationImage(image: NetworkImage(_logoUrlExistente!), fit: BoxFit.cover) : null
                                      ),
                                      child: _logoSelecionada == null && _logoUrlExistente == null
                                          ? const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey)) 
                                          : _logoSelecionada != null ? ClipRRect(borderRadius: BorderRadius.circular(16), child: kIsWeb ? Image.network(_logoSelecionada!.path, fit: BoxFit.cover) : Image.file(File(_logoSelecionada!.path), fit: BoxFit.cover)) : null,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(onPressed: _escolherERecortarLogo, icon: const Icon(Icons.crop), label: const Text('Alterar Logo')),
                                ],
                              ),
                              const SizedBox(width: 48),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Cores do Sistema (Tema)', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _abrirSeletorDeCores(isPrimaria: true),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                              child: Row(
                                                children: [
                                                  Container(width: 24, height: 24, decoration: BoxDecoration(color: _corPrimariaSelecionada, shape: BoxShape.circle, border: Border.all(color: Colors.black26))),
                                                  const SizedBox(width: 12),
                                                  const Expanded(child: Text('Cor Primária', style: TextStyle(fontWeight: FontWeight.w500))),
                                                  const Icon(Icons.colorize_rounded, size: 20, color: Colors.grey),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _abrirSeletorDeCores(isPrimaria: false),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                              child: Row(
                                                children: [
                                                  Container(width: 24, height: 24, decoration: BoxDecoration(color: _corSecundariaSelecionada, shape: BoxShape.circle, border: Border.all(color: Colors.black26))),
                                                  const SizedBox(width: 12),
                                                  const Expanded(child: Text('Cor Secundária', style: TextStyle(fontWeight: FontWeight.w500))),
                                                  const Icon(Icons.colorize_rounded, size: 20, color: Colors.grey),
                                                ],
                                              ),
                                            ),
                                          ),
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

                  // ================= CARD 2: INFORMAÇÕES CADASTRAIS =================
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.business_rounded, color: corPrimariaTema), const SizedBox(width: 8), const Text('Informações Cadastrais', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          Row(
                            children: [
                              Expanded(flex: 2, child: TextFormField(controller: _nomeInstCtrl, decoration: const InputDecoration(labelText: 'Nome da Instituição', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                              const SizedBox(width: 16),
                              Expanded(flex: 1, child: TextFormField(controller: _cnpjCtrl, inputFormatters: [_cnpjMask], decoration: const InputDecoration(labelText: 'CNPJ', hintText: '00.000.000/0000-00', border: OutlineInputBorder()))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(controller: _sloganCtrl, decoration: const InputDecoration(labelText: 'Slogan (Frase de Efeito)', border: OutlineInputBorder())),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _responsavelCtrl, decoration: const InputDecoration(labelText: 'Nome do Responsável', border: OutlineInputBorder()))),
                              const SizedBox(width: 16),
                              Expanded(child: TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'E-mail da Administração', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ================= CARD 3: CONTATOS E REDES SOCIAIS =================
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.contact_phone_rounded, color: corPrimariaTema), const SizedBox(width: 8), const Text('Contatos e Redes Sociais', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          SizedBox(
                            width: 300,
                            child: TextFormField(controller: _telefoneCtrl, inputFormatters: [_telMask], decoration: const InputDecoration(labelText: 'WhatsApp / Celular', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _instaCtrl, decoration: const InputDecoration(labelText: 'Link do Instagram', prefixIcon: Icon(Icons.camera_alt_outlined), border: OutlineInputBorder()))),
                              const SizedBox(width: 16),
                              Expanded(child: TextFormField(controller: _faceCtrl, decoration: const InputDecoration(labelText: 'Link do Facebook', prefixIcon: Icon(Icons.facebook), border: OutlineInputBorder()))),
                              const SizedBox(width: 16),
                              Expanded(child: TextFormField(controller: _youtubeCtrl, decoration: const InputDecoration(labelText: 'Link do YouTube', prefixIcon: Icon(Icons.play_circle_outline), border: OutlineInputBorder()))),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ================= CARD 4: ENDEREÇO =================
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.location_on_rounded, color: corPrimariaTema), const SizedBox(width: 8), const Text('Endereço', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          Row(
                            children: [
                              Expanded(flex: 3, child: TextFormField(controller: _ruaCtrl, decoration: const InputDecoration(labelText: 'Rua / Logradouro', border: OutlineInputBorder()))),
                              const SizedBox(width: 16),
                              Expanded(flex: 1, child: TextFormField(controller: _numeroCtrl, decoration: const InputDecoration(labelText: 'Número', border: OutlineInputBorder()))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(flex: 2, child: TextFormField(controller: _bairroCtrl, decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder()))),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: TextFormField(controller: _cidadeCtrl, decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()))),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1, 
                                child: DropdownButtonFormField<String>(
                                  value: _ufSelecionada,
                                  decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder()),
                                  items: _estadosUF.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
                                  onChanged: (v) => setState(() => _ufSelecionada = v),
                                )
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 55, width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: corPrimariaTema, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _salvando ? null : _salvarConfiguracoes,
                      icon: _salvando ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, color: Colors.white),
                      label: Text(_salvando ? 'SALVANDO...' : 'SALVAR CONFIGURAÇÕES', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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