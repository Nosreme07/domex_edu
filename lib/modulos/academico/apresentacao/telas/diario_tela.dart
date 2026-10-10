import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// FUNÇÕES GLOBAIS DE VISUALIZAÇÃO E DOWNLOAD
// ============================================================================
Future<void> _abrirLink(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// Visualizador Unificado com Botão de Download Embutido
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
            // Cabeçalho do Modal
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
            
            // Área de Visualização (Zoom)
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
                            const Text('Toque no botão abaixo para baixar ou visualizar o arquivo detalhadamente.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
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
            
            // Rodapé com o Botão de Download
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

class DiarioTela extends ConsumerStatefulWidget {
  final String turmaId;
  const DiarioTela({super.key, required this.turmaId});
  @override
  ConsumerState<DiarioTela> createState() => _DiarioTelaState();
}

class _DiarioTelaState extends ConsumerState<DiarioTela> {
  DateTime _dataSelecionada = DateTime.now();
  int _abaAtiva = 0;
  String _termoPesquisa = '';
  bool _carregandoDiario = false;
  String _conteudoAulaAtual = '';
  
  final List<String> _anexosAulaUrls = [];
  bool _fazendoUploadAnexo = false;
  
  bool _isDiaAvaliacao = false;
  double _mediaEscola = 6.0;
  final Map<String, Map<String, String>> _frequenciaPorData = {};
  final Map<String, String> _statusAulaPorData = {};

  // Controle de Avisos
  String _tipoAviso = 'TURMA';
  String? _alunoAvisoSelecionado;
  final TextEditingController _mensagemAvisoCtrl = TextEditingController();
  bool _enviandoAviso = false;
  late String _bimestreAtivo;
  
  int _limiteAvisosTurma = 5;
  
  final List<PlatformFile> _anexosAviso = [];

  bool _carregandoDisciplinas = true;
  List<String> _disciplinasDoProf = ['Geral'];
  String? _disciplinaSelecionada;

  String get _dataDisplay =>
      "${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}";
  String get _dataBanco =>
      "${_dataSelecionada.year}-${_dataSelecionada.month.toString().padLeft(2, '0')}-${_dataSelecionada.day.toString().padLeft(2, '0')}";
  bool get _isDiaPassado => DateTime(
        _dataSelecionada.year,
        _dataSelecionada.month,
        _dataSelecionada.day,
      ).isBefore(DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ));

  String get _idDiario {
    String discLimpa = (_disciplinaSelecionada ?? 'Geral').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return "${_dataBanco}_$discLimpa";
  }

  String get _statusAulaHoje => _statusAulaPorData[_idDiario] ?? 'NAO_INICIADA';

  String _calcularBimestre(DateTime data) {
    int mes = data.month;
    if (mes >= 2 && mes <= 4) return '1º Bimestre';
    if (mes >= 5 && mes <= 6) return '2º Bimestre';
    if (mes >= 7 && mes <= 9) return '3º Bimestre';
    return '4º Bimestre';
  }

  String _formatarDataDisplay(String dataBanco) {
    try {
      final partes = dataBanco.split('-');
      if (partes.length == 3) {
        return "${partes[2]}/${partes[1]}/${partes[0]}";
      }
    } catch (_) {}
    return dataBanco.isNotEmpty ? dataBanco : 'Sem data';
  }

  @override
  void initState() {
    super.initState();
    _bimestreAtivo = _calcularBimestre(_dataSelecionada);
    _carregarDisciplinasIniciais();
  }

  @override
  void dispose() {
    _mensagemAvisoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDisciplinasIniciais() async {
    final disciplinas = await _buscarDisciplinasDoProfessor();
    if (mounted) {
      setState(() {
        _disciplinasDoProf = disciplinas.isNotEmpty ? disciplinas : ['Geral'];
        _disciplinaSelecionada = _disciplinasDoProf.first;
        _carregandoDisciplinas = false;
      });
      _carregarDiarioDoBanco();
    }
  }

  Future<List<String>> _buscarDisciplinasDoProfessor() async {
    final user = ref.read(authProvider).value;
    if (user == null) return ['Geral'];
    try {
      var docProf = await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('professores').doc(user.id).get();
      if (docProf.exists && docProf.data() != null) {
        final lista = List<String>.from(docProf.data()!['disciplinas'] ?? []);
        if (lista.isNotEmpty) return lista;
      }
      final email = user.email.trim();
      if (email.isNotEmpty && email.contains('@')) {
        var snapEmail = await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('professores').where('email', isEqualTo: email).limit(1).get();
        if (snapEmail.docs.isNotEmpty) {
          final lista = List<String>.from(snapEmail.docs.first.data()['disciplinas'] ?? []);
          if (lista.isNotEmpty) return lista;
        }
      }
      var snapNome = await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('professores').where('nome', isEqualTo: user.nome).limit(1).get();
      if (snapNome.docs.isNotEmpty) {
        final lista = List<String>.from(snapNome.docs.first.data()['disciplinas'] ?? []);
        if (lista.isNotEmpty) return lista;
      }
    } catch (e) {
      debugPrint('Erro ao buscar disciplinas do professor: $e');
    }
    return ['Geral'];
  }

  Future<void> _carregarDiarioDoBanco() async {
    final user = ref.read(authProvider).value;
    if (user == null || _carregandoDisciplinas) return;
    setState(() => _carregandoDiario = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('turmas').doc(widget.turmaId).collection('diarios').doc(_idDiario).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _statusAulaPorData[_idDiario] = (data['status'] ?? 'NAO_INICIADA').toString();
          
          final frequenciaRaw = data['frequencia'];
          if (frequenciaRaw is Map) {
            _frequenciaPorData[_idDiario] = frequenciaRaw.map((key, value) => MapEntry(key.toString(), value.toString()));
          } else {
            _frequenciaPorData[_idDiario] = {};
          }
          
          _conteudoAulaAtual = (data['conteudo'] ?? '').toString();
          
          _anexosAulaUrls.clear();
          final lstAnexos = data['anexosUrl'] as List<dynamic>? ?? [];
          for (var item in lstAnexos) {
            _anexosAulaUrls.add(item.toString());
          }
          
          if (data['anexoUrl'] != null && data['anexoUrl'].toString().isNotEmpty && _anexosAulaUrls.isEmpty) {
             _anexosAulaUrls.add(data['anexoUrl'].toString());
          }

          _isDiaAvaliacao = data['isDiaAvaliacao'] == true;
        });
      } else {
        setState(() {
          _statusAulaPorData[_idDiario] = 'NAO_INICIADA';
          _frequenciaPorData[_idDiario] = {};
          _conteudoAulaAtual = '';
          _anexosAulaUrls.clear();
          _isDiaAvaliacao = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar diário: $e');
    }
    setState(() => _carregandoDiario = false);
  }

  Future<void> _salvarAlteracaoNoBanco(Map<String, dynamic> dados) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;
    dados['disciplina'] = _disciplinaSelecionada ?? 'Geral';
    dados['dataDiario'] = _dataBanco;
    await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('turmas').doc(widget.turmaId).collection('diarios').doc(_idDiario).set(dados, SetOptions(merge: true));
  }

  void _verificarEEncerrarAulaAtualAntesDeMudar() {
    if (_statusAulaHoje == 'EM_ANDAMENTO') {
      _statusAulaPorData[_idDiario] = 'FINALIZADA';
      _salvarAlteracaoNoBanco({'status': 'FINALIZADA'});
    }
  }

  void _mudarDia(int dias) {
    _verificarEEncerrarAulaAtualAntesDeMudar();
    setState(() {
      _dataSelecionada = _dataSelecionada.add(Duration(days: dias));
      _termoPesquisa = '';
      _bimestreAtivo = _calcularBimestre(_dataSelecionada);
    });
    _carregarDiarioDoBanco();
  }

  Future<void> _escolherDataCalendario() async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (dataEscolhida != null && dataEscolhida != _dataSelecionada) {
      _verificarEEncerrarAulaAtualAntesDeMudar();
      setState(() { _dataSelecionada = dataEscolhida; _termoPesquisa = ''; _bimestreAtivo = _calcularBimestre(_dataSelecionada); });
      _carregarDiarioDoBanco();
    }
  }

  void _iniciarAula() {
    setState(() => _statusAulaPorData[_idDiario] = 'EM_ANDAMENTO');
    _salvarAlteracaoNoBanco({'status': 'EM_ANDAMENTO', 'dataCriacao': FieldValue.serverTimestamp()});
  }

  void _encerrarAula() {
    setState(() => _statusAulaPorData[_idDiario] = 'FINALIZADA');
    _salvarAlteracaoNoBanco({'status': 'FINALIZADA'});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aula encerrada!'), backgroundColor: Colors.green));
  }

  void _reabrirAula() {
    setState(() => _statusAulaPorData[_idDiario] = 'EM_ANDAMENTO');
    _salvarAlteracaoNoBanco({'status': 'EM_ANDAMENTO'});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aula reaberta para edição.'), backgroundColor: Colors.amber));
  }

  void _alternarDiaAvaliacao() {
    setState(() => _isDiaAvaliacao = !_isDiaAvaliacao);
    _salvarAlteracaoNoBanco({'isDiaAvaliacao': _isDiaAvaliacao});
  }

  void _marcarStatusAluno(String matricula, String status) {
    if (_statusAulaHoje != 'EM_ANDAMENTO') return;
    setState(() {
      final map = _frequenciaPorData[_idDiario] ?? <String, String>{};
      map[matricula] = status;
      _frequenciaPorData[_idDiario] = map;
    });
    _salvarAlteracaoNoBanco({'frequencia': _frequenciaPorData[_idDiario]});
  }

  String _obterStatusAluno(String matricula) {
    final map = _frequenciaPorData[_idDiario] ?? <String, String>{};
    return map[matricula] ?? 'P';
  }

  Future<bool> _confirmarEnvioProfessor(BuildContext context, String nomeProfessor, Color corPrimaria) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [Icon(Icons.send_rounded, color: corPrimaria), const SizedBox(width: 8), const Text('Confirmar Envio', style: TextStyle(fontWeight: FontWeight.bold))]),
        content: Text('Olá, $nomeProfessor!\n\nTem certeza de que deseja enviar esta mensagem? Ela ficará registrada em seu nome para a turma e para a direção.', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.check_rounded), label: const Text('Sim, Enviar', style: TextStyle(fontWeight: FontWeight.bold)))
        ],
      ),
    ) ?? false;
  }

  Widget _buildBotaoStatus(String matricula, String sigla, String palavraCompleta, IconData icone, Color cor, String statusAtual) {
    final isSelecionado = statusAtual == sigla;
    final bloqueado = _statusAulaHoje == 'FINALIZADA';
    return Expanded(
      child: InkWell(
        onTap: bloqueado ? null : () => _marcarStatusAluno(matricula, sigla),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: isSelecionado ? cor.withAlpha(bloqueado ? 20 : 40) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 14, color: isSelecionado ? (bloqueado ? cor.withAlpha(150) : cor) : Colors.grey.shade400),
              if (isSelecionado) ...[const SizedBox(width: 4), Text(palavraCompleta, style: TextStyle(color: (bloqueado ? cor.withAlpha(150) : cor), fontWeight: FontWeight.bold, fontSize: 12))] 
              else ...[const SizedBox(width: 4), Text(sigla, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12))]
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _anexarArquivoDiario(StateSetter setModalState, bool usarCamera) async {
    if (_anexosAulaUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limite máximo de 3 anexos atingido.'), backgroundColor: Colors.red));
      return;
    }

    try {
      File? arquivoFisico;
      Uint8List? arquivoBytes;
      String extensao = 'jpg';

      if (usarCamera) {
        final picker = ImagePicker();
        final XFile? foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
        if (foto == null) return;
        if (!kIsWeb) arquivoFisico = File(foto.path);
        arquivoBytes = await foto.readAsBytes();
        extensao = 'jpg';
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.single;
        if (!kIsWeb && file.path != null) arquivoFisico = File(file.path!);
        arquivoBytes = file.bytes;
        extensao = file.extension?.toLowerCase() ?? 'jpg';
      }

      if (!mounted) return;
      
      setModalState(() => _fazendoUploadAnexo = true);
      setState(() => _fazendoUploadAnexo = true);
      
      final user = ref.read(authProvider).value;
      if (user == null) return;
      
      final nomeArquivo = 'anexo_aula_${_idDiario}_${DateTime.now().millisecondsSinceEpoch}.$extensao';
      final refStorage = FirebaseStorage.instance.ref('tenants/${user.tenantId}/turmas/${widget.turmaId}/diarios/$nomeArquivo');
      
      if (kIsWeb && arquivoBytes != null) {
        await refStorage.putData(arquivoBytes);
      } else if (arquivoFisico != null) {
        await refStorage.putFile(arquivoFisico);
      } else if (arquivoBytes != null) {
        await refStorage.putData(arquivoBytes);
      } else {
        throw Exception('Não foi possível ler o arquivo.');
      }
      
      final url = await refStorage.getDownloadURL();
      
      _anexosAulaUrls.add(url);
      
      setModalState(() { _fazendoUploadAnexo = false; });
      setState(() { _fazendoUploadAnexo = false; });
      
      await _salvarAlteracaoNoBanco({'anexosUrl': _anexosAulaUrls});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anexo adicionado!'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      setModalState(() => _fazendoUploadAnexo = false);
      setState(() => _fazendoUploadAnexo = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  void _removerFotoAnexada(int index, StateSetter setModalState) {
    _anexosAulaUrls.removeAt(index);
    setModalState(() {});
    setState(() {});
    _salvarAlteracaoNoBanco({'anexosUrl': _anexosAulaUrls});
  }

  void _abrirModalPreencherDiario() {
    final ctrl = TextEditingController(text: _conteudoAulaAtual);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('Diário de Sala', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: ctrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Conteúdo lecionado...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  if (_anexosAulaUrls.isNotEmpty)
                    Wrap(
                      spacing: 12, runSpacing: 12,
                      children: List.generate(_anexosAulaUrls.length, (i) {
                         final url = _anexosAulaUrls[i];
                         final isPdf = url.toLowerCase().contains('.pdf');

                         return Stack(
                          alignment: Alignment.topRight,
                          children: [
                            GestureDetector(
                              onTap: () => _mostrarAnexoAmpliadoGlobal(context, url, isPdf, Theme.of(context).primaryColor),
                              child: Container(
                                width: 140, height: 140,
                                decoration: BoxDecoration(
                                  color: isPdf ? Colors.red.shade50 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                  image: !isPdf ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
                                ),
                                child: isPdf ? const Center(child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 40)) : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.redAccent,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  onPressed: () => _removerFotoAnexada(i, setModalState),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),

                  const SizedBox(height: 16),

                  if (_fazendoUploadAnexo)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Theme.of(context).primaryColor),
                          const SizedBox(height: 12),
                          const Text('Aguarde, anexando...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else if (_anexosAulaUrls.length < 3)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Adicionar Anexo (${_anexosAulaUrls.length}/3)', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Theme.of(context).primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: () => _anexarArquivoDiario(setModalState, true),
                                icon: Icon(Icons.camera_alt_rounded, color: Theme.of(context).primaryColor, size: 18),
                                label: Text('Câmera', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: Theme.of(context).primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: () => _anexarArquivoDiario(setModalState, false),
                                icon: Icon(Icons.folder_rounded, color: Theme.of(context).primaryColor, size: 18),
                                label: Text('Galeria/PC', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                setState(() => _conteudoAulaAtual = ctrl.text.trim());
                await _salvarAlteracaoNoBanco({'conteudo': _conteudoAulaAtual});
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Salvar Diário', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  void _abrirConfigMediaEscola(Color corPrimaria) {
    final ctrl = TextEditingController(text: _mediaEscola.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.settings_rounded, color: corPrimaria),
            const SizedBox(width: 8),
            const Text('Média da Escola', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Defina a nota média para aprovação.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: corPrimaria,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                _mediaEscola = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 6.0;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          )
        ],
      ),
    );
  }

  void _excluirAvaliacao(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Excluir Avaliação')]),
        content: const Text('Tem certeza que deseja excluir esta avaliação e TODAS as notas lançadas nela?\n\nEssa ação não poderá ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final user = ref.read(authProvider).value;
              if (user != null) {
                if (!ctx.mounted) return;
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(ctx);
                await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('turmas').doc(widget.turmaId).collection('avaliacoes').doc(id).delete();
                if (!ctx.mounted) return;
                nav.pop();
                messenger.showSnackBar(const SnackBar(content: Text('Avaliação excluída com sucesso!'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Sim, Excluir'),
          )
        ],
      ),
    );
  }

  void _abrirModalEditarAvaliacao(Map<String, dynamic> avaliacao, String avaliacaoId, Color corPrimaria, dynamic user, List<Map<String, dynamic>> avaliacoesDoBimestre, List<Map<String, dynamic>> alunosTurma) {
    final ctrlNome = TextEditingController(text: (avaliacao['nome'] ?? '').toString());
    final ctrlPontos = TextEditingController(text: (avaliacao['pontuacaoMaxima'] ?? '').toString());
    String? disciplinaSelecionada = (avaliacao['disciplina'] ?? '').toString();
    String? tipoSelecionado = (avaliacao['tipo'] ?? 'Prova').toString();
    bool contaParaMedia = avaliacao['contaParaMedia'] == true;
    String dataBancoAval = (avaliacao['dataAvaliacao'] ?? _dataBanco).toString();
    String dataDisplayAval = '';
    try {
      final p = dataBancoAval.split('-');
      if (p.length == 3) { dataDisplayAval = "${p[2]}/${p[1]}/${p[0]}"; }
    } catch (_) {}
    bool salvando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [Icon(Icons.edit_rounded, color: corPrimaria), const SizedBox(width: 8), const Text('Editar Avaliação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrlNome,
                  decoration: InputDecoration(labelText: 'Nome ou Assunto da Avaliação', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: InputDecoration(labelText: 'Tipo de Avaliação', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: tipoSelecionado,
                      isExpanded: true,
                      items: ['Prova', 'Trabalho', 'Exercício', 'Projeto', 'Seminário', 'Simulado'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) => setModalState(() => tipoSelecionado = val),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<String>>(
                  future: _buscarDisciplinasDoProfessor(),
                  builder: (context, snapProf) {
                    if (snapProf.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    List<String> disciplinasDoProf = snapProf.data ?? ['Geral'];
                    disciplinaSelecionada ??= disciplinasDoProf.first;
                    if (!disciplinasDoProf.contains(disciplinaSelecionada)) { disciplinasDoProf.add(disciplinaSelecionada!); }
                    return InputDecorator(
                      decoration: InputDecoration(labelText: 'Disciplina Associada', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: disciplinaSelecionada, isExpanded: true,
                          items: disciplinasDoProf.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (val) { setModalState(() => disciplinaSelecionada = val); },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    DateTime inicial = DateTime.now();
                    try { final p = dataBancoAval.split('-'); inicial = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])); } catch (_) {}
                    final date = await showDatePicker(
                      context: context, initialDate: inicial, firstDate: DateTime(2020), lastDate: DateTime(2030),
                      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: corPrimaria, onPrimary: Colors.white)), child: child!),
                    );
                    if (date != null) {
                      setModalState(() {
                        dataBancoAval = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                        dataDisplayAval = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: 'Data da Avaliação', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dataDisplayAval.isEmpty ? 'Selecionar Data' : dataDisplayAval), const Icon(Icons.calendar_month_rounded, color: Colors.grey)]),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrlPontos, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Pontuação Máxima', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero, title: const Text('Contabiliza para a Média?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: const Text('Se desmarcado, a nota não soma no boletim.', style: TextStyle(fontSize: 11)),
                  value: contaParaMedia, activeTrackColor: corPrimaria.withAlpha(128), activeThumbColor: corPrimaria,
                  onChanged: (val) => setModalState(() => contaParaMedia = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: salvando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: salvando
                  ? null
                  : () async {
                      if (ctrlNome.text.trim().isEmpty) return;
                      if (contaParaMedia && avaliacao['isRecuperacao'] != true && avaliacao['isSegundaChamada'] != true) {
                        double somaAtual = 0.0;
                        for (var a in avaliacoesDoBimestre) {
                          if (a['id'] != avaliacaoId && a['disciplina'] == (disciplinaSelecionada ?? 'Geral') && a['isRecuperacao'] != true && a['isSegundaChamada'] != true && a['contaParaMedia'] != false) {
                            somaAtual += (a['pontuacaoMaxima'] as num? ?? 0.0).toDouble();
                          }
                        }
                        double novaP = double.tryParse(ctrlPontos.text.replaceAll(',', '.')) ?? 10.0;
                        if (somaAtual + novaP > 10.0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A soma das avaliações ultrapassa o limite de 10.0 pontos no bimestre!'), backgroundColor: Colors.red));
                          return;
                        }
                      }
                      setModalState(() => salvando = true);
                      if (user != null) {
                        if (!ctx.mounted) return;
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(ctx);
                        await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('turmas').doc(widget.turmaId).collection('avaliacoes').doc(avaliacaoId).update({
                          'nome': ctrlNome.text.trim(), 'disciplina': disciplinaSelecionada ?? 'Geral', 'tipo': tipoSelecionado ?? 'Prova', 'dataAvaliacao': dataBancoAval, 'pontuacaoMaxima': double.tryParse(ctrlPontos.text.replaceAll(',', '.')) ?? 10.0, 'contaParaMedia': contaParaMedia,
                        });
                        if (!ctx.mounted) return;
                        nav.pop();
                        messenger.showSnackBar(const SnackBar(content: Text('Avaliação atualizada!'), backgroundColor: Colors.green));
                      }
                    },
              child: salvando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salvar'),
            )
          ],
        ),
      ),
    );
  }

  void _abrirModalNovaAvaliacao(Color corPrimaria, List<Map<String, dynamic>> alunosTurma, dynamic user, List<Map<String, dynamic>> avaliacoesDoBimestre) {
    final ctrlNome = TextEditingController();
    final ctrlPontos = TextEditingController(text: '10.0');
    String? disciplinaSelecionada;
    String? tipoSelecionado = 'Prova';
    bool contaParaMedia = true;
    bool salvando = false;
    String dataBancoAval = _dataBanco;
    String dataDisplayAval = _dataDisplay;
    bool isSegundaChamada = false;
    bool isRecuperacao = false;
    List<String> alunosSelecionados = [];
    final bimestreAlvo = _abaAtiva == 1 ? _bimestreAtivo : _calcularBimestre(_dataSelecionada);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [Icon(Icons.add_task_rounded, color: corPrimaria), const SizedBox(width: 8), const Text('Nova Avaliação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vinculada ao: $bimestreAlvo', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
                  TextField(controller: ctrlNome, decoration: InputDecoration(labelText: 'Nome ou Assunto da Avaliação', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)), const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(labelText: 'Tipo de Avaliação', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tipoSelecionado, isExpanded: true,
                        items: ['Prova', 'Trabalho', 'Exercício', 'Projeto', 'Seminário', 'Simulado'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (val) => setModalState(() => tipoSelecionado = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<String>>(
                    future: _buscarDisciplinasDoProfessor(),
                    builder: (context, snapProf) {
                      if (snapProf.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      List<String> disciplinasDoProf = snapProf.data ?? ['Geral'];
                      disciplinaSelecionada ??= disciplinasDoProf.first;
                      return InputDecorator(
                        decoration: InputDecoration(labelText: 'Disciplina Associada', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: disciplinaSelecionada, isExpanded: true,
                            items: disciplinasDoProf.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (val) { setModalState(() => disciplinaSelecionada = val); },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      DateTime inicial = DateTime.now();
                      try { final p = dataBancoAval.split('-'); inicial = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])); } catch (_) {}
                      final date = await showDatePicker(
                        context: context, initialDate: inicial, firstDate: DateTime(2020), lastDate: DateTime(2030),
                        builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: corPrimaria, onPrimary: Colors.white)), child: child!),
                      );
                      if (date != null) {
                        setModalState(() {
                          dataBancoAval = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                          dataDisplayAval = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                        });
                      }
                    },
                    child: InputDecorator(decoration: InputDecoration(labelText: 'Data da Avaliação', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dataDisplayAval), const Icon(Icons.calendar_month_rounded, color: Colors.grey)])),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: ctrlPontos, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Pontuação Máxima', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)),
                  const Divider(height: 32),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Contabiliza para a Média?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: const Text('Se desmarcado, a nota não soma no boletim.', style: TextStyle(fontSize: 11)), value: contaParaMedia, activeTrackColor: corPrimaria.withAlpha(128), activeThumbColor: corPrimaria, onChanged: (val) => setModalState(() => contaParaMedia = val)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('É uma prova de Recuperação?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: const Text('Substitui automaticamente a menor nota do bimestre.', style: TextStyle(fontSize: 11)), value: isRecuperacao, activeTrackColor: Colors.purple.withAlpha(128), activeThumbColor: Colors.purple, onChanged: (val) { setModalState(() { isRecuperacao = val; }); }),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('É uma prova de 2ª Chamada?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: const Text('Apenas os alunos selecionados receberão nota.', style: TextStyle(fontSize: 11)), value: isSegundaChamada, activeTrackColor: corPrimaria.withAlpha(128), activeThumbColor: corPrimaria, onChanged: (val) { setModalState(() { isSegundaChamada = val; }); }),
                  if (isSegundaChamada)
                    Container(
                      margin: const EdgeInsets.only(top: 8), constraints: const BoxConstraints(maxHeight: 180), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: ListView(
                        shrinkWrap: true,
                        children: alunosTurma.map<Widget>((a) {
                          final mat = (a['matricula'] ?? '').toString();
                          return CheckboxListTile(
                            dense: true, activeColor: corPrimaria, title: Text((a['nome'] ?? '').toString()), value: alunosSelecionados.contains(mat),
                            onChanged: (bool? checked) {
                              setModalState(() {
                                if (checked == true) { alunosSelecionados.add(mat); } else { alunosSelecionados.remove(mat); }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: salvando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: salvando
                  ? null
                  : () async {
                      if (ctrlNome.text.trim().isEmpty) return;
                      if (contaParaMedia && !isRecuperacao && !isSegundaChamada) {
                        double somaAtual = 0.0;
                        for (var a in avaliacoesDoBimestre) {
                          if (a['disciplina'] == (disciplinaSelecionada ?? 'Geral') && a['isRecuperacao'] != true && a['isSegundaChamada'] != true && a['contaParaMedia'] != false) {
                            somaAtual += (a['pontuacaoMaxima'] as num? ?? 0.0).toDouble();
                          }
                        }
                        double novaP = double.tryParse(ctrlPontos.text.replaceAll(',', '.')) ?? 10.0;
                        if (somaAtual + novaP > 10.0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A soma ultrapassa o limite de 10.0 pontos no bimestre!'), backgroundColor: Colors.red));
                          return;
                        }
                      }

                      setModalState(() => salvando = true);
                      if (user != null) {
                        if (!ctx.mounted) return;
                        final nav = Navigator.of(ctx);
                        List<String> ausentes = alunosTurma.where((a) => _obterStatusAluno((a['matricula'] ?? '').toString()) == 'A').map((a) => (a['matricula'] ?? '').toString()).toList();
                        final novaAvaliacao = <String, dynamic>{
                          'nome': ctrlNome.text.trim(), 'disciplina': disciplinaSelecionada ?? 'Geral', 'tipo': tipoSelecionado ?? 'Prova', 'pontuacaoMaxima': double.tryParse(ctrlPontos.text.replaceAll(',', '.')) ?? 10.0, 'bimestre': bimestreAlvo, 'dataAvaliacao': dataBancoAval, 'dataCriacao': FieldValue.serverTimestamp(), 'matriculasAusentes': ausentes, 'notas': <String, dynamic>{}, 'observacoes': <String, dynamic>{}, 'anexos': <String, dynamic>{}, 'isSegundaChamada': isSegundaChamada, 'alunosPermitidos': isSegundaChamada ? alunosSelecionados : <String>[], 'isRecuperacao': isRecuperacao, 'contaParaMedia': contaParaMedia,
                        };
                        final docRef = await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('turmas').doc(widget.turmaId).collection('avaliacoes').add(novaAvaliacao);
                        if (!ctx.mounted) return;
                        nav.pop(); 
                        setState(() { _abaAtiva = 1; _bimestreAtivo = bimestreAlvo; });
                        _abrirModalLancarNotas(novaAvaliacao, docRef.id, alunosTurma, corPrimaria);
                      }
                    },
              child: salvando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Criar e Lançar', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  void _abrirModalLancarNotas(Map<String, dynamic> avaliacao, String avaliacaoId, List<Map<String, dynamic>> alunosTurmaOriginal, Color corPrimaria) {
    final Map<String, TextEditingController> controladores = {};
    final notasAtuais = Map<String, dynamic>.from(avaliacao['notas'] as Map<dynamic, dynamic>? ?? <String, dynamic>{});
    final pontuacaoMaxima = (avaliacao['pontuacaoMaxima'] ?? 10.0) as double;
    final List<dynamic> ausentes = avaliacao['matriculasAusentes'] as List<dynamic>? ?? [];
    final bool isSegundaChamada = avaliacao['isSegundaChamada'] == true;
    final List<dynamic> permitidos = avaliacao['alunosPermitidos'] as List<dynamic>? ?? [];

    List<Map<String, dynamic>> alunosParaAvaliar = alunosTurmaOriginal;
    if (isSegundaChamada) {
      alunosParaAvaliar = alunosTurmaOriginal.where((a) => permitidos.contains((a['matricula'] ?? '').toString())).toList();
    }

    for (var aluno in alunosParaAvaliar) {
      final matricula = (aluno['matricula'] ?? '').toString();
      controladores[matricula] = TextEditingController(text: notasAtuais[matricula] != null ? notasAtuais[matricula].toString() : '');
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double soma = 0.0; int qtdValidas = 0;
          controladores.forEach((mat, ctrl) {
            if (ctrl.text.trim().isNotEmpty) { soma += double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0; qtdValidas++; }
          });
          double mediaDaTurma = qtdValidas > 0 ? soma / qtdValidas : 0.0;
          double mediaEsperada = (pontuacaoMaxima / 10.0) * _mediaEscola;
          bool turmaBem = mediaDaTurma >= mediaEsperada;
          final dataAvaliacaoStr = _formatarDataDisplay((avaliacao['dataAvaliacao'] ?? '').toString());
          final tipoAvaliacao = (avaliacao['tipo'] ?? 'Prova').toString();

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: DraggableScrollableSheet(
              initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
              builder: (_, scrollController) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.edit_note_rounded, color: corPrimaria)), const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$tipoAvaliacao: ${avaliacao['nome'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), Text('Data: $dataAvaliacaoStr • Max: $pontuacaoMaxima pts | Média da Escola: ${_mediaEscola.toStringAsFixed(1)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: turmaBem ? Colors.green.shade50 : Colors.red.shade50,
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Média atual da Turma:', style: TextStyle(fontWeight: FontWeight.bold, color: turmaBem ? Colors.green.shade800 : Colors.red.shade800)), Text('${mediaDaTurma.toStringAsFixed(1)} / $pontuacaoMaxima', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: turmaBem ? Colors.green.shade800 : Colors.red.shade800))]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController, padding: const EdgeInsets.all(16), itemCount: alunosParaAvaliar.length, separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final aluno = alunosParaAvaliar[index];
                        final matricula = (aluno['matricula'] ?? '').toString();
                        final faltou = ausentes.contains(matricula);
                        final ctrlNota = controladores[matricula];

                        return Card(
                          elevation: 0, color: faltou ? Colors.red.shade50.withAlpha(100) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: faltou ? Colors.red.shade200 : Colors.grey.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 18, backgroundColor: corPrimaria.withAlpha(30), backgroundImage: aluno['fotoUrl'] != null ? NetworkImage(aluno['fotoUrl'].toString()) : null, child: aluno['fotoUrl'] == null ? Icon(Icons.person, color: corPrimaria, size: 20) : null), const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((aluno['nome'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), if (faltou) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text('Faltou neste dia', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))])),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: ctrlNota, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))],
                                    decoration: InputDecoration(hintText: '-', contentPadding: const EdgeInsets.symmetric(vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.white),
                                    onChanged: (val) {
                                      String valLimpo = val.replaceAll(',', '.');
                                      double? numValue = double.tryParse(valLimpo);
                                      if (ctrlNota != null && numValue != null && numValue > pontuacaoMaxima) {
                                        ctrlNota.text = pontuacaoMaxima.toStringAsFixed(1);
                                        ctrlNota.selection = TextSelection.fromPosition(TextPosition(offset: ctrlNota.text.length));
                                      }
                                      setModalState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -5))]),
                    child: SafeArea(
                      child: SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () async {
                            final user = ref.read(authProvider).value;
                            if (user == null) return;
                            if (!ctx.mounted) return;
                            final messenger = ScaffoldMessenger.of(ctx);
                            final nav = Navigator.of(ctx);
                            final Map<String, double> notasFinais = {};
                            controladores.forEach((mat, ctrl) {
                              if (ctrl.text.trim().isNotEmpty) { notasFinais[mat] = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0; }
                            });
                            final notasParaSalvar = Map<String, dynamic>.from(notasAtuais);
                            notasFinais.forEach((k, v) { notasParaSalvar[k] = v; });
                            await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('turmas').doc(widget.turmaId).collection('avaliacoes').doc(avaliacaoId).update({'notas': notasParaSalvar});
                            if (!ctx.mounted) return;
                            nav.pop();
                            messenger.showSnackBar(const SnackBar(content: Text('Notas salvas com sucesso!'), backgroundColor: Colors.green));
                          },
                          icon: const Icon(Icons.save_rounded), label: const Text('SALVAR NOTAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _abrirDialogMensagemDireta(Map<String, dynamic> aluno, Color corPrimaria) {
    final ctrlTexto = TextEditingController();
    bool enviando = false;
    final alunoIdSeguro = (aluno['id'] ?? aluno['matricula'] ?? aluno['nome']).toString();

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [Icon(Icons.send_rounded, color: corPrimaria), const SizedBox(width: 8), Expanded(child: Text('Aviso para ${(aluno['nome'] ?? 'Aluno').toString()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
          content: TextField(controller: ctrlTexto, maxLines: 4, decoration: InputDecoration(hintText: 'Digite a mensagem...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)),
          actions: [
            TextButton(onPressed: enviando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: enviando
                  ? null
                  : () async {
                      if (ctrlTexto.text.trim().isEmpty) return;
                      final user = ref.read(authProvider).value;
                      if (user == null) return;
                      final confirmado = await _confirmarEnvioProfessor(ctx, (user.nome ?? '').toString(), corPrimaria);
                      if (!confirmado) return;
                      if (!ctx.mounted) return;
                      final messenger = ScaffoldMessenger.of(ctx);
                      final nav = Navigator.of(ctx);
                      setDialogState(() => enviando = true);
                      try {
                        await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('turmas').doc(widget.turmaId).collection('avisos').add({
                          'tipoDestinatario': 'ALUNO', 'alunoId': alunoIdSeguro, 'mensagem': ctrlTexto.text.trim(), 'dataEnvio': FieldValue.serverTimestamp(), 'remetenteId': user.id, 'remetenteNome': 'Professor(a) - ${user.nome}', 'alunoNome': (aluno['nome'] ?? '').toString(),
                        });
                        if (!ctx.mounted) return;
                        nav.pop();
                        messenger.showSnackBar(const SnackBar(content: Text('Aviso enviado com sucesso!'), backgroundColor: Colors.green));
                      } catch (e) {
                        if (!ctx.mounted) return;
                        messenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                      } finally {
                        if (ctx.mounted) setDialogState(() => enviando = false);
                      }
                    },
              child: enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enviar'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _escolherAnexosAviso() async {
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

  Future<void> _enviarAvisoFirebase(Color corPrimaria, List<Map<String, dynamic>> alunosList) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (_tipoAviso != 'TURMA' && _alunoAvisoSelecionado == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Selecione um destinatário.'), backgroundColor: Colors.red));
      return;
    }
    if (_mensagemAvisoCtrl.text.trim().isEmpty && _anexosAviso.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('A mensagem ou anexo não pode estar vazio.'), backgroundColor: Colors.red));
      return;
    }

    final user = ref.read(authProvider).value;
    if (user == null) return;

    final confirmado = await _confirmarEnvioProfessor(context, (user.nome ?? '').toString(), corPrimaria);
    if (!confirmado) return;

    setState(() => _enviandoAviso = true);
    try {
      List<Map<String, String>> anexosFinais = [];

      for (var f in _anexosAviso) {
        Uint8List? arquivoBytes;
        File? arquivoFisico;

        if (!kIsWeb && f.path != null) arquivoFisico = File(f.path!);
        arquivoBytes = f.bytes;

        final nomeArquivo = 'anexo_aviso_${DateTime.now().millisecondsSinceEpoch}_${f.name.replaceAll(' ', '_')}';
        final storageRef = FirebaseStorage.instance.ref().child('tenants/${user.tenantId}/avisos_anexos/$nomeArquivo');
        
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

      String tipoDestFinal = _tipoAviso;
      String? alunoIdStr = _alunoAvisoSelecionado;
      String nomeAluno = '';
      String nomeResp = '';

      if (_tipoAviso == 'RESPONSAVEL' && _alunoAvisoSelecionado == 'TODOS') {
        tipoDestFinal = 'TURMA_RESPONSAVEIS';
        alunoIdStr = null;
      } else if (_tipoAviso == 'ALUNO' || _tipoAviso == 'RESPONSAVEL') {
        final alunoAlvo = alunosList.firstWhere((a) => (a['id'] ?? a['matricula'] ?? a['nome']).toString() == alunoIdStr, orElse: () => <String, dynamic>{});
        if (alunoAlvo.isNotEmpty) {
          nomeAluno = (alunoAlvo['nome'] ?? '').toString();
          if (_tipoAviso == 'RESPONSAVEL') {
            final resps = alunoAlvo['responsaveis'] as List? ?? [];
            if (resps.isNotEmpty) {
              var resp = resps.firstWhere((r) => r['principal'] == true, orElse: () => resps.first);
              nomeResp = (resp['nome'] ?? '').toString();
            }
          }
        }
      }

      final Map<String, dynamic> payload = {
        'tipoDestinatario': tipoDestFinal,
        'alunoId': alunoIdStr,
        'mensagem': _mensagemAvisoCtrl.text.trim(),
        'dataEnvio': FieldValue.serverTimestamp(),
        'remetenteId': user.id,
        'remetenteNome': 'Professor(a) - ${user.nome ?? ''}',
      };

      if (nomeAluno.isNotEmpty) payload['alunoNome'] = nomeAluno;
      if (nomeResp.isNotEmpty) payload['responsavelNome'] = nomeResp;
      if (anexosFinais.isNotEmpty) payload['anexos'] = anexosFinais;

      await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('turmas').doc(widget.turmaId).collection('avisos').add(payload);
      
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Aviso enviado!'), backgroundColor: Colors.green));
      _mensagemAvisoCtrl.clear();
      setState(() {
        _alunoAvisoSelecionado = null;
        _tipoAviso = 'TURMA';
        _anexosAviso.clear();
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _enviandoAviso = false);
    }
  }

  Widget _buildAbaControle(int indice, String titulo, IconData icone) {
    final isAtiva = _abaAtiva == indice;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _abaAtiva = indice),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isAtiva ? Colors.white : Colors.transparent, width: 3))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icone, color: isAtiva ? Colors.white : Colors.white60, size: 16), const SizedBox(width: 8), Text(titulo, style: TextStyle(color: isAtiva ? Colors.white : Colors.white60, fontWeight: isAtiva ? FontWeight.bold : FontWeight.normal, fontSize: 13))]),
        ),
      ),
    );
  }

  Widget _buildAbaFrequencia(List<Map<String, dynamic>> alunos, Color corPrimaria) {
    if (_statusAulaHoje == 'NAO_INICIADA') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending_actions_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Aula Não Iniciada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Data: $_dataDisplay', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              onPressed: _iniciarAula, icon: const Icon(Icons.play_arrow_rounded), label: const Text('INICIAR AULA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
      );
    }

    if (alunos.isEmpty) { return Center(child: Text('Nenhum aluno encontrado.', style: TextStyle(color: Colors.grey.shade600))); }

    return ListView.separated(
      padding: const EdgeInsets.all(16).copyWith(bottom: 100), itemCount: alunos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final aluno = alunos[index];
        final matricula = (aluno['matricula'] ?? '').toString();
        final statusAtual = _obterStatusAluno(matricula);

        return Card(
          elevation: 1, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _mostrarAnexoAmpliadoGlobal(context, aluno['fotoUrl']?.toString() ?? '', false, corPrimaria),
                  child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Container(width: 54, height: 72, color: corPrimaria.withAlpha(30), child: aluno['fotoUrl'] != null ? Image.network(aluno['fotoUrl'].toString(), fit: BoxFit.cover) : Icon(Icons.person, color: corPrimaria, size: 28))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () { _abrirDialogMensagemDireta(aluno, corPrimaria); },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: Text((aluno['nome'] ?? '').toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corPrimaria, decoration: TextDecoration.underline, decorationColor: corPrimaria.withAlpha(100)), maxLines: 2)),
                              Icon(Icons.send_rounded, size: 16, color: corPrimaria.withAlpha(150))
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(color: _statusAulaHoje == 'FINALIZADA' ? Colors.grey.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildBotaoStatus(matricula, 'P', 'Presente', Icons.check_circle_rounded, Colors.green, statusAtual), Container(width: 1, height: 26, color: Colors.grey.shade300),
                            _buildBotaoStatus(matricula, 'A', 'Ausente', Icons.cancel_rounded, Colors.red, statusAtual), Container(width: 1, height: 26, color: Colors.grey.shade300),
                            _buildBotaoStatus(matricula, 'J', 'Justificado', Icons.info_rounded, Colors.orange, statusAtual),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAbaAvaliacoes(List<Map<String, dynamic>> alunosTurma, Color corPrimaria) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '1º Bimestre', label: Text('1º Bim')), ButtonSegment(value: '2º Bimestre', label: Text('2º Bim')),
              ButtonSegment(value: '3º Bimestre', label: Text('3º Bim')), ButtonSegment(value: '4º Bimestre', label: Text('4º Bim')),
            ],
            selected: {_bimestreAtivo}, onSelectionChanged: (s) => setState(() => _bimestreAtivo = s.first),
            style: SegmentedButton.styleFrom(selectedBackgroundColor: corPrimaria.withAlpha(40), selectedForegroundColor: corPrimaria),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).collection('turmas').doc(widget.turmaId).collection('avaliacoes').where('bimestre', isEqualTo: _bimestreAtivo).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) { return Center(child: CircularProgressIndicator(color: corPrimaria)); }
              var docs = snapshot.data?.docs.toList() ?? [];
              var avaliacoesMap = docs.map((d) { var m = d.data() as Map<String, dynamic>; m['id'] = d.id; return m; }).toList();
              
              avaliacoesMap.sort((a, b) {
                final timeA = a['dataCriacao'] as Timestamp?; final timeB = b['dataCriacao'] as Timestamp?;
                if (timeA == null && timeB == null) { return 0; }
                if (timeA == null) { return 1; }
                if (timeB == null) { return -1; }
                return timeB.compareTo(timeA);
              });

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: corPrimaria, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () => _abrirModalNovaAvaliacao(corPrimaria, alunosTurma, user, avaliacoesMap), icon: Icon(Icons.add_rounded, color: corPrimaria), label: Text('Criar Nova Avaliação', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _abrirConfigMediaEscola(corPrimaria), borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: 2), borderRadius: BorderRadius.circular(12)),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Média', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)), Text(_mediaEscola.toStringAsFixed(1), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: corPrimaria))]),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (avaliacoesMap.isEmpty)
                    Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Nenhuma avaliação', style: TextStyle(fontSize: 16, color: Colors.grey.shade600))])) )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16).copyWith(bottom: 100), itemCount: avaliacoesMap.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final avaliacao = avaliacoesMap[index];
                          final id = avaliacao['id']?.toString() ?? '';
                          final notasMap = Map<String, dynamic>.from(avaliacao['notas'] as Map<dynamic, dynamic>? ?? <String, dynamic>{});
                          final dataAvaliacaoStr = _formatarDataDisplay(avaliacao['dataAvaliacao']?.toString() ?? '');
                          final tipoAvaliacao = (avaliacao['tipo'] ?? 'Prova').toString();
                          final bool contaParaMedia = avaliacao['contaParaMedia'] == true;
                          int totalEsperado = avaliacao['isSegundaChamada'] == true ? (avaliacao['alunosPermitidos'] as List? ?? []).length : alunosTurma.length;

                          return Card(
                            elevation: 1, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                            child: InkWell(
                              onTap: () => _abrirModalLancarNotas(avaliacao, id, alunosTurma, corPrimaria),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.edit_document, color: corPrimaria)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text((avaliacao['nome'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Wrap(
                                            spacing: 6,
                                            children: [
                                              if (avaliacao['isSegundaChamada'] == true) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: corPrimaria.withAlpha(30), borderRadius: BorderRadius.circular(4)), child: Text('2ª Chamada', style: TextStyle(fontSize: 10, color: corPrimaria))),
                                              if (avaliacao['isRecuperacao'] == true) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(4)), child: Text('Recuperação', style: TextStyle(fontSize: 10, color: Colors.purple.shade800))),
                                              if (!contaParaMedia) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)), child: Text('Não conta p/ Média', style: TextStyle(fontSize: 10, color: Colors.grey.shade800))),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text('$tipoAvaliacao • ${avaliacao['disciplina'] ?? 'Geral'} • $dataAvaliacaoStr • Max: ${avaliacao['pontuacaoMaxima']} pts', style: TextStyle(color: Colors.grey.shade600, fontSize: 11))
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: notasMap.length == totalEsperado ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: Text('${notasMap.length} / $totalEsperado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: notasMap.length == totalEsperado ? Colors.green.shade700 : Colors.orange.shade700))),
                                        const SizedBox(height: 4),
                                        const Text('Lançadas', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                                      onSelected: (val) {
                                        if (val == 'editar') { _abrirModalEditarAvaliacao(avaliacao, id, corPrimaria, user, avaliacoesMap, alunosTurma); }
                                        if (val == 'excluir') { _excluirAvaliacao(id); }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Editar')])),
                                        const PopupMenuItem(value: 'excluir', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('Excluir', style: TextStyle(color: Colors.red))])),
                                      ],
                                    )
                                  ],
                                ),
                              ),
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

  Widget _buildAbaAvisos(List<Map<String, dynamic>> alunos, Color corPrimaria) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();

    String idProf = user.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24).copyWith(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.campaign_rounded, color: corPrimaria)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Enviar Novo Aviso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('Comunique-se com a turma ou responsáveis.', style: TextStyle(color: Colors.grey.shade600))]))]),
                  const SizedBox(height: 24), const Text('Enviar para:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'TURMA', label: Text('Toda a Turma', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'ALUNO', label: Text('Aluno Específico', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'RESPONSAVEL', label: Text('Responsável', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_tipoAviso},
                    onSelectionChanged: (s) => setState(() { _tipoAviso = s.first; _alunoAvisoSelecionado = null; }),
                    style: SegmentedButton.styleFrom(selectedBackgroundColor: corPrimaria.withAlpha(40), selectedForegroundColor: corPrimaria),
                  ),
                  if (_tipoAviso != 'TURMA') ...[
                    const SizedBox(height: 16),
                    Builder(builder: (context) {
                      List<DropdownMenuItem<String>> dropItems = [];
                      if (_tipoAviso == 'RESPONSAVEL') {
                        dropItems.add(DropdownMenuItem(value: 'TODOS', child: Text('Todos os Responsáveis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corPrimaria))));
                        for (var a in alunos) {
                          final resps = a['responsaveis'] as List? ?? [];
                          if (resps.isNotEmpty) {
                            var resp = resps.firstWhere((r) => r['principal'] == true, orElse: () => resps.first);
                            String respNome = (resp['nome'] ?? 'Responsável').toString();
                            String alunoNome = (a['nome'] ?? '').toString();
                            String alunoId = (a['id'] ?? a['matricula'] ?? a['nome'] ?? '').toString();
                            dropItems.add(
                              DropdownMenuItem(
                                value: alunoId,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                  children: [Text(respNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis), Text('Resp. por: $alunoNome', style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)],
                                ),
                              ),
                            );
                          }
                        }
                      } else if (_tipoAviso == 'ALUNO') {
                        for (var a in alunos) {
                          String alunoNome = (a['nome'] ?? '').toString();
                          String alunoId = (a['id'] ?? a['matricula'] ?? a['nome'] ?? '').toString();
                          dropItems.add(DropdownMenuItem(value: alunoId, child: Text(alunoNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)));
                        }
                      }

                      return InputDecorator(
                        decoration: InputDecoration(labelText: _tipoAviso == 'ALUNO' ? 'Selecione o Aluno' : 'Selecione o Responsável', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), filled: true, fillColor: Colors.white),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _alunoAvisoSelecionado, isExpanded: true, itemHeight: _tipoAviso == 'RESPONSAVEL' ? 56.0 : 48.0, hint: const Text('Selecione...'), items: dropItems,
                            onChanged: (val) { setState(() { _alunoAvisoSelecionado = val; }); },
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                  TextField(controller: _mensagemAvisoCtrl, maxLines: 4, decoration: InputDecoration(labelText: 'Mensagem do Aviso', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)),
                  const SizedBox(height: 16),
                  
                  // MULTIPLOS ANEXOS NOS AVISOS
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _escolherAnexosAviso,
                        icon: Icon(Icons.attach_file_rounded, color: corPrimaria),
                        label: Text('Anexar Arquivos (${_anexosAviso.length}/3)', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: corPrimaria), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
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
                            decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: corPrimaria.withAlpha(50))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: isPdf ? Colors.red : corPrimaria, size: 20),
                                const SizedBox(width: 8),
                                Flexible(child: Text(anexo.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corPrimaria), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _enviandoAviso ? null : () => _enviarAvisoFirebase(corPrimaria, alunos),
                      icon: _enviandoAviso ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded),
                      label: Text(_enviandoAviso ? 'Aguarde...' : 'ENVIAR AVISO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Mural da Turma', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tenants')
                .doc(user.tenantId)
                .collection('turmas')
                .doc(widget.turmaId)
                .collection('avisos')
                .orderBy('dataEnvio', descending: true)
                .limit(_limiteAvisosTurma)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return Center(child: Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(color: corPrimaria)));
              }
              final docs = snapshot.data?.docs ?? [];
              
              var docsFiltrados = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final remetenteIdBanco = (data['remetenteId'] ?? '').toString();
                final remetenteNomeBanco = (data['remetenteNome'] ?? '').toString();
                final tipoDest = (data['tipoDestinatario'] ?? 'TURMA').toString();
                
                bool isAdmin = remetenteNomeBanco.contains('Administração') || remetenteNomeBanco.contains('Direção') || remetenteNomeBanco.contains('Admin');
                bool isMe = remetenteIdBanco == idProf;
                
                if (isMe) return true; 
                if (isAdmin && tipoDest == 'TURMA') return true; 
                if (isAdmin && tipoDest == 'PROFESSORES') return true; 
                return false; 
              }).toList();

              if (docsFiltrados.isEmpty) {
                return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Nenhum aviso no mural.', style: TextStyle(color: Colors.grey))));
              }
              
              docsFiltrados.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>; final dataB = b.data() as Map<String, dynamic>;
                final timeA = dataA['dataEnvio'] as Timestamp?; final timeB = dataB['dataEnvio'] as Timestamp?;
                if (timeA == null && timeB == null) { return 0; }
                if (timeA == null) { return 1; }
                if (timeB == null) { return -1; }
                return timeB.compareTo(timeA);
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListView.separated(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: docsFiltrados.length, 
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final data = docsFiltrados[index].data() as Map<String, dynamic>;
                      final idAviso = docsFiltrados[index].id;
                      
                      return AvisoCardWidgetDiario(
                        aviso: data,
                        avisoId: idAviso,
                        tenantId: user.tenantId,
                        turmaId: widget.turmaId,
                        meuId: idProf,
                        meuNome: user.nome ?? '',
                        corPrimaria: corPrimaria,
                        alunos: alunos,
                      );
                    },
                  ),
                  if (docs.length >= _limiteAvisosTurma) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: corPrimaria,
                        backgroundColor: corPrimaria.withAlpha(20),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () {
                        setState(() { _limiteAvisosTurma += 10; }); 
                      },
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Carregar mais antigos', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final user = ref.watch(authProvider).value;

    if (user == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: corPrimaria)));
    }
    
    final tenantId = user.tenantId;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(widget.turmaId).snapshots(),
      builder: (context, snapTurma) {
        if (snapTurma.connectionState == ConnectionState.waiting) return Scaffold(appBar: AppBar(backgroundColor: corPrimaria, foregroundColor: Colors.white, elevation: 0), body: Center(child: CircularProgressIndicator(color: corPrimaria)));
        
        if (!snapTurma.hasData || !snapTurma.data!.exists) {
          return Scaffold(appBar: AppBar(title: const Text('Diário de Classe'), backgroundColor: corPrimaria, foregroundColor: Colors.white, elevation: 0), body: const Center(child: Text('Turma não encontrada.')));
        }

        final turma = snapTurma.data!.data() as Map<String, dynamic>;
        final tituloAppBar = (turma['nome'] ?? 'Diário de Classe').toString();

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(backgroundColor: corPrimaria, foregroundColor: Colors.white, elevation: 0, title: Text(tituloAppBar, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          floatingActionButton: _abaAtiva == 0 && _statusAulaHoje != 'NAO_INICIADA' && !_carregandoDiario ? FloatingActionButton.extended(onPressed: _statusAulaHoje == 'FINALIZADA' ? (_isDiaPassado ? null : _reabrirAula) : _encerrarAula, backgroundColor: _statusAulaHoje == 'FINALIZADA' ? (_isDiaPassado ? Colors.grey : Colors.orange) : corPrimaria, foregroundColor: Colors.white, icon: Icon(_statusAulaHoje == 'FINALIZADA' ? (_isDiaPassado ? Icons.lock_rounded : Icons.lock_open_rounded) : Icons.check_circle_rounded), label: Text(_statusAulaHoje == 'FINALIZADA' ? (_isDiaPassado ? 'Bloqueada' : 'Reabrir Aula') : 'Encerrar Aula', style: const TextStyle(fontWeight: FontWeight.bold))) : null,
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('alunos').where('status', isEqualTo: 'Ativo').snapshots(),
            builder: (context, snapAlunos) {
              if (snapAlunos.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: corPrimaria));
              
              final alunosRaw = snapAlunos.data?.docs.map((d) => d.data() as Map<String, dynamic>).toList() ?? [];
              var alunosDaTurma = alunosRaw.where((a) => ((a['turmaId'] ?? '') == widget.turmaId || (a['turma'] ?? '') == turma['nome'] || (a['turmasExtrasIds'] as List? ?? []).contains(widget.turmaId))).toList();
              alunosDaTurma.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

              int presentes = 0, faltas = 0;
              for (var a in alunosDaTurma) {
                final st = _obterStatusAluno((a['matricula'] ?? '').toString());
                if (st == 'P') { presentes++; } else if (st == 'A' || st == 'J') { faltas++; }
              }
              final total = alunosDaTurma.length;
              final percP = total == 0 ? 0 : (presentes / total) * 100;
              final percA = total == 0 ? 0 : (faltas / total) * 100;

              List<Map<String, dynamic>> alunosListagem = List.from(alunosDaTurma);
              if (_termoPesquisa.isNotEmpty) {
                alunosListagem = alunosListagem.where((a) => (a['nome'] ?? '').toString().toUpperCase().contains(_termoPesquisa.toUpperCase())).toList();
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity, decoration: BoxDecoration(color: corPrimaria, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Row(children: [const Icon(Icons.wb_sunny_rounded, color: Colors.white70, size: 14), const SizedBox(width: 4), Text('${turma['turno'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(width: 12), const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 14), const SizedBox(width: 4), Text('$total Alunos', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))])),
                              if (_abaAtiva == 0) Container(decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(padding: const EdgeInsets.all(4), constraints: const BoxConstraints(), icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20), onPressed: () => _mudarDia(-1)), InkWell(onTap: _escolherDataCalendario, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Row(children: [const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14), const SizedBox(width: 6), Text(_dataDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]))), IconButton(padding: const EdgeInsets.all(4), constraints: const BoxConstraints(), icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20), onPressed: () => _mudarDia(1))]))
                            ],
                          ),
                        ),
                        if (_abaAtiva == 0 && !_carregandoDisciplinas)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.class_rounded, color: Colors.white70, size: 14),
                                const SizedBox(width: 8),
                                const Text('Disciplina: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    dropdownColor: corPrimaria,
                                    value: _disciplinaSelecionada,
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    items: _disciplinasDoProf.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                    onChanged: (val) {
                                      if (val != null && val != _disciplinaSelecionada) {
                                        _verificarEEncerrarAulaAtualAntesDeMudar();
                                        setState(() { _disciplinaSelecionada = val; });
                                        _carregarDiarioDoBanco();
                                      }
                                    }
                                  )
                                )
                              ]
                            )
                          ),
                        Container(color: Colors.black.withAlpha(20), child: Row(children: [_buildAbaControle(0, 'Frequência', Icons.fact_check_outlined), _buildAbaControle(1, 'Avaliações', Icons.edit_note_rounded), _buildAbaControle(2, 'Avisos', Icons.campaign_rounded)])),
                      ],
                    ),
                  ),

                  if (_abaAtiva == 0 && _statusAulaHoje != 'NAO_INICIADA' && !_carregandoDiario && total > 0) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Expanded(child: SizedBox(height: 48, child: InkWell(onTap: _statusAulaHoje == 'FINALIZADA' ? null : _abrirModalPreencherDiario, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), border: Border.all(color: corPrimaria.withAlpha(50)), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu_book_rounded, color: corPrimaria, size: 18), const SizedBox(width: 8), Flexible(child: Text('Diário de Sala', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria, fontSize: 13), overflow: TextOverflow.ellipsis)), if (_conteudoAulaAtual.isNotEmpty || _anexosAulaUrls.isNotEmpty) ...[const SizedBox(width: 6), Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 16)]]))))),
                          const SizedBox(width: 12),
                          Expanded(child: SizedBox(height: 48, child: TextField(decoration: InputDecoration(hintText: 'Pesquisar...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300))), onChanged: (v) => setState(() => _termoPesquisa = v)))),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        decoration: BoxDecoration(color: _isDiaAvaliacao ? Colors.orange.shade50 : Colors.white, border: Border.all(color: _isDiaAvaliacao ? Colors.orange.shade300 : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: _statusAulaHoje == 'FINALIZADA' ? null : _alternarDiaAvaliacao, borderRadius: BorderRadius.circular(12),
                              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [Icon(Icons.assignment_late_rounded, color: _isDiaAvaliacao ? Colors.orange.shade700 : Colors.grey.shade400, size: 20), const SizedBox(width: 12), Expanded(child: Text('Marcar hoje como Dia de Avaliação', style: TextStyle(fontWeight: FontWeight.bold, color: _isDiaAvaliacao ? Colors.orange.shade900 : Colors.grey.shade700, fontSize: 13))), Switch(value: _isDiaAvaliacao, onChanged: _statusAulaHoje == 'FINALIZADA' ? null : (val) => _alternarDiaAvaliacao(), activeTrackColor: Colors.orange.withAlpha(128), activeThumbColor: Colors.orange, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)])),
                            ),
                            if (_isDiaAvaliacao && _statusAulaHoje != 'FINALIZADA') Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: SizedBox(width: double.infinity, height: 40, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0), onPressed: () => _abrirModalNovaAvaliacao(corPrimaria, alunosDaTurma, user, []), icon: const Icon(Icons.add_task_rounded, size: 16), label: const Text('Criar Prova/Atividade Agora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text('Presentes: ${percP.toStringAsFixed(1)}%', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))), const SizedBox(width: 8),
                          Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text('Faltas: ${percA.toStringAsFixed(1)}%', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                        ],
                      ),
                    ),
                  ],

                  Expanded(
                    child: _carregandoDiario ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: corPrimaria), const SizedBox(height: 16), const Text('Sincronizando com o Firebase...', style: TextStyle(color: Colors.grey))]))
                      : _abaAtiva == 0 ? _buildAbaFrequencia(alunosListagem, corPrimaria) 
                      : _abaAtiva == 1 ? _buildAbaAvaliacoes(alunosDaTurma, corPrimaria) 
                      : _buildAbaAvisos(alunosDaTurma, corPrimaria),   
                  ),
                ],
              );
            }
          ),
        );
      }
    );
  }
}

// ============================================================================
// CARTÃO DE AVISO COM SUPORTE A MINIATURAS E RESPOSTAS
// ============================================================================
class AvisoCardWidgetDiario extends StatelessWidget {
  final Map<String, dynamic> aviso;
  final String avisoId;
  final String tenantId;
  final String turmaId;
  final String meuId;
  final String meuNome;
  final Color corPrimaria;
  final List<Map<String, dynamic>> alunos;

  const AvisoCardWidgetDiario({
    super.key,
    required this.aviso,
    required this.avisoId,
    required this.tenantId,
    required this.turmaId,
    required this.meuId,
    required this.meuNome,
    required this.corPrimaria,
    required this.alunos,
  });

  void _abrirChat(BuildContext context, DocumentReference avisoRef) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatAvisoModalDiario(
        avisoRef: avisoRef,
        avisoData: aviso,
        meuId: meuId,
        meuNome: meuNome,
        corPrimaria: corPrimaria,
        tenantId: tenantId,
        alunos: alunos,
      ),
    );

    avisoRef.collection('respostas').get().then((snap) {
      final batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if ((data['remetenteId'] ?? '').toString() != meuId && data['lidaPorProfessor'] != true) {
          batch.update(doc.reference, {'lidaPorProfessor': true});
          hasUpdates = true;
        }
      }
      if (hasUpdates) batch.commit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataEnvio = aviso['dataEnvio'] as Timestamp?;
    final textoData = dataEnvio != null ? DateFormat('dd/MM HH:mm').format(dataEnvio.toDate()) : 'Enviando...';
    
    final alvoId = (aviso['alunoId'] ?? '').toString(); 
    String prefixoDestino = ''; 
    String nomeDestino = ''; 
    bool isAvisoParaEquipe = false;
    
    if (aviso['tipoDestinatario'] == 'TURMA' || aviso['tipoDestinatario'] == 'TURMA_RESPONSAVEIS') { 
      prefixoDestino = 'Para: '; 
      nomeDestino = aviso['tipoDestinatario'] == 'TURMA' ? 'Toda a Turma' : 'Todos os Responsáveis';
    } else if (aviso['tipoDestinatario'] == 'PROFESSORES') { 
      prefixoDestino = 'Aviso Interno: '; 
      nomeDestino = 'Para Professores'; 
      isAvisoParaEquipe = true;
    } else {
      final alunoAlvo = alunos.firstWhere((a) { 
        final idPossivel = (a['id'] ?? a['matricula'] ?? a['nome']).toString(); 
        return idPossivel == alvoId; 
      }, orElse: () => <String, dynamic>{});
      
      nomeDestino = (alunoAlvo['nome'] ?? 'Desconhecido').toString(); 
      prefixoDestino = aviso['tipoDestinatario'] == 'ALUNO' ? 'Para Aluno: ' : 'Para Resp: ';
    }

    final String nomeRemetente = (aviso['remetenteNome'] ?? '').toString().trim();
    final String exibirRemetente = nomeRemetente.isEmpty ? 'Professor(a)' : nomeRemetente;

    final avisoRef = FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId).collection('avisos').doc(avisoId);

    // Compatibilidade de Múltiplos Anexos (ou o Anexo Antigo Singular)
    List<dynamic> anexosList = aviso['anexos'] as List<dynamic>? ?? [];
    if (aviso['anexoUrl'] != null && aviso['anexoUrl'].toString().isNotEmpty && anexosList.isEmpty) {
       anexosList.add({
         'nome': (aviso['anexoNome'] ?? 'Anexo').toString(),
         'url': aviso['anexoUrl'].toString(),
       });
    }

    return Card(
      elevation: 0, 
      color: isAvisoParaEquipe ? Colors.orange.shade50 : Colors.white, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isAvisoParaEquipe ? Colors.orange.shade300 : Colors.grey.shade300)), 
      child: Padding(
        padding: const EdgeInsets.all(16), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(
              children: [
                Icon(isAvisoParaEquipe ? Icons.admin_panel_settings_rounded : (aviso['tipoDestinatario'] == 'TURMA' ? Icons.groups : Icons.person), size: 16, color: isAvisoParaEquipe ? Colors.orange.shade800 : corPrimaria), const SizedBox(width: 8), 
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'De: $exibirRemetente ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const WidgetSpan(child: Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_right_alt_rounded, size: 16, color: Colors.grey)), alignment: PlaceholderAlignment.middle),
                        TextSpan(text: prefixoDestino, style: TextStyle(fontWeight: FontWeight.bold, color: isAvisoParaEquipe ? Colors.orange.shade900 : corPrimaria, fontSize: 12)),
                        TextSpan(text: nomeDestino, style: TextStyle(fontWeight: FontWeight.bold, color: isAvisoParaEquipe ? Colors.orange.shade900 : Colors.red, fontSize: 12)),
                      ]
                    )
                  )
                ), 
                Text(textoData, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
              ]
            ), 
            const Divider(height: 16), 

            if (anexosList.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Wrap(
                  spacing: 12, runSpacing: 12,
                  children: anexosList.map((anexo) {
                    final String url = (anexo['url'] ?? '').toString();
                    final String nome = (anexo['nome'] ?? 'Anexo').toString();
                    final bool isPdf = nome.toLowerCase().endsWith('.pdf');

                    return Tooltip(
                      message: 'Clique para visualizar/baixar',
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

            Text((aviso['mensagem'] ?? '').toString(), style: TextStyle(fontSize: 14, color: isAvisoParaEquipe ? Colors.black87 : Colors.black)),

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: StreamBuilder<QuerySnapshot>(
                stream: avisoRef.collection('respostas').snapshots(),
                builder: (context, snapRespostas) {
                  int naoLidos = 0;
                  if (snapRespostas.hasData) {
                    for (var doc in snapRespostas.data!.docs) {
                      final rData = doc.data() as Map<String, dynamic>;
                      if ((rData['remetenteId'] ?? '').toString() != meuId && rData['lidaPorProfessor'] != true) {
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        onPressed: () => _abrirChat(context, avisoRef),
                        icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: corPrimaria),
                        label: Text('Ver Respostas / Interagir', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria, fontSize: 12)),
                      ),
                      if (naoLidos > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            decoration: BoxDecoration(
                              color: Colors.red, 
                              borderRadius: BorderRadius.circular(10), 
                              border: Border.all(color: Colors.white, width: 1.5)
                            ),
                            child: Text(
                              naoLidos > 9 ? '9+' : naoLidos.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                    ],
                  );
                }
              )
            )
          ]
        )
      )
    );
  }
}

// ============================================================================
// CHAT DO AVISO (Para o Professor COM ANEXOS E NOMES FORMATADOS)
// ============================================================================
class _ChatAvisoModalDiario extends StatefulWidget {
  final DocumentReference avisoRef;
  final Map<String, dynamic> avisoData;
  final String meuId;
  final String meuNome;
  final Color corPrimaria;
  final String tenantId;
  final List<Map<String, dynamic>> alunos;

  const _ChatAvisoModalDiario({
    required this.avisoRef,
    required this.avisoData,
    required this.meuId,
    required this.meuNome,
    required this.corPrimaria,
    required this.tenantId,
    required this.alunos,
  });

  @override
  State<_ChatAvisoModalDiario> createState() => _ChatAvisoModalDiarioState();
}

class _ChatAvisoModalDiarioState extends State<_ChatAvisoModalDiario> {
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
        'remetenteNome': 'Prof(a) ${widget.meuNome}',
        'lidaPorProfessor': true, 
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
    
    // Anexos do aviso original para exibir no topo
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
            // CABEÇALHO DO CHAT
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), shape: BoxShape.circle), child: Icon(Icons.forum_rounded, color: widget.corPrimaria, size: 20)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Interagir com o Aviso', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),

            // AVISO ORIGINAL NO TOPO
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
                            message: 'Clique para visualizar/baixar',
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

            // MENSAGENS / RESPOSTAS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.avisoRef.collection('respostas').orderBy('dataEnvio', descending: false).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
                  }
                  
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
                      
                      // Formatação Inteligente do Remetente Baseada no Destino do Aviso
                      if (!isMeu) {
                        final tipoDest = (widget.avisoData['tipoDestinatario'] ?? '').toString();
                        String alunoN = (widget.avisoData['alunoNome'] ?? '').toString();

                        // Tenta buscar o nome da base de dados local se não estiver no doc do aviso
                        if (alunoN.isEmpty && widget.avisoData['alunoId'] != null) {
                            final alu = widget.alunos.firstWhere(
                              (a) => (a['id'] ?? '').toString() == widget.avisoData['alunoId'].toString() || (a['matricula'] ?? '').toString() == widget.avisoData['alunoId'].toString(), 
                              orElse: () => <String, dynamic>{}
                            );
                            alunoN = (alu['nome'] ?? '').toString();
                        }
                        
                        final turmaN = (widget.avisoData['turmaNome'] ?? '').toString();
                        final respN = (widget.avisoData['responsavelNome'] ?? '').toString();
                        
                        if ((tipoDest == 'RESPONSAVEL' || tipoDest == 'TURMA_RESPONSAVEIS') && alunoN.isNotEmpty) {
                          String nomeLimpo = remetenteExibicao.split(' (Resp. por')[0].trim();
                          if (respN.isNotEmpty && nomeLimpo == respN) {
                            remetenteExibicao = '$respN - $alunoN ($turmaN)';
                          } else {
                            remetenteExibicao = '$nomeLimpo - $alunoN ($turmaN)';
                          }
                        } else if (tipoDest == 'ALUNO' && turmaN.isNotEmpty) {
                          remetenteExibicao = '$remetenteExibicao ($turmaN)';
                        }
                      }

                      // Extrair anexos das respostas
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
                                        message: 'Clique para visualizar/baixar',
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