import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';
import '../../../admin/apresentacao/estado/turma_provider.dart';
import '../../../admin/apresentacao/estado/aluno_provider.dart';

class DiarioTela extends ConsumerStatefulWidget {
  final String turmaId;

  const DiarioTela({super.key, required this.turmaId});

  @override
  ConsumerState<DiarioTela> createState() => _DiarioTelaState();
}

class _DiarioTelaState extends ConsumerState<DiarioTela> {
  DateTime _dataSelecionada = DateTime.now();

  // ==========================================================================
  // CONTROLE DE ABAS (0 = Frequência, 1 = Notas, 2 = Avisos)
  // ==========================================================================
  int _abaAtiva = 0;
  String _termoPesquisa = '';

  bool _carregandoDiario = false;
  String _conteudoAulaAtual = '';
  String? _anexoAulaUrl;
  bool _fazendoUploadAnexo = false;

  final Map<String, Map<String, String>> _frequenciaPorData = {};
  final Map<String, String> _statusAulaPorData = {};

  // ==========================================================================
  // ESTADOS DA ABA DE AVISOS
  // ==========================================================================
  String _tipoAviso = 'TURMA'; // 'TURMA', 'ALUNO', 'RESPONSAVEL'
  String? _alunoAvisoSelecionado;
  final TextEditingController _mensagemAvisoCtrl = TextEditingController();

  String get _dataDisplay =>
      "${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}";
  String get _dataBanco =>
      "${_dataSelecionada.year}-${_dataSelecionada.month.toString().padLeft(2, '0')}-${_dataSelecionada.day.toString().padLeft(2, '0')}";

  bool get _isDiaPassado {
    final hoje = DateTime.now();
    final dataSemHora = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      _dataSelecionada.day,
    );
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    return dataSemHora.isBefore(hojeSemHora);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _carregarDiarioDoBanco());
  }

  @override
  void dispose() {
    _mensagemAvisoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDiarioDoBanco() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    setState(() => _carregandoDiario = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(user.id)
          .collection('turmas')
          .doc(widget.turmaId)
          .collection('diarios')
          .doc(_dataBanco)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _statusAulaPorData[_dataBanco] = data['status'] ?? 'NAO_INICIADA';
          _frequenciaPorData[_dataBanco] = Map<String, String>.from(
            data['frequencia'] ?? {},
          );
          _conteudoAulaAtual = data['conteudo'] ?? '';
          _anexoAulaUrl = data['anexoUrl'];
        });
      } else {
        setState(() {
          _statusAulaPorData[_dataBanco] = 'NAO_INICIADA';
          _frequenciaPorData[_dataBanco] = {};
          _conteudoAulaAtual = '';
          _anexoAulaUrl = null;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar diário: $e');
    }

    setState(() => _carregandoDiario = false);
  }

  Future<void> _salvarAlteracaoNoBancoEspecifico(
    String dataDB,
    Map<String, dynamic> dados,
  ) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('tenants')
        .doc(user.id)
        .collection('turmas')
        .doc(widget.turmaId)
        .collection('diarios')
        .doc(dataDB)
        .set(dados, SetOptions(merge: true));
  }

  Future<void> _salvarAlteracaoNoBanco(Map<String, dynamic> dados) async {
    await _salvarAlteracaoNoBancoEspecifico(_dataBanco, dados);
  }

  void _verificarEEncerrarAulaAtualAntesDeMudar() {
    if (_statusAulaHoje == 'EM_ANDAMENTO') {
      _statusAulaPorData[_dataBanco] = 'FINALIZADA';
      _salvarAlteracaoNoBancoEspecifico(_dataBanco, {'status': 'FINALIZADA'});
    }
  }

  Future<void> _capturarEEnviarFoto(StateSetter setModalState) async {
    try {
      final picker = ImagePicker();
      final XFile? foto = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (foto == null) return;

      setModalState(() => _fazendoUploadAnexo = true);
      setState(() => _fazendoUploadAnexo = true);

      final user = ref.read(authProvider).value;
      final nomeArquivo =
          'anexo_aula_$_dataBanco-${DateTime.now().millisecondsSinceEpoch}.jpg';

      final refStorage = FirebaseStorage.instance.ref(
        'tenants/${user!.id}/turmas/${widget.turmaId}/diarios/$nomeArquivo',
      );

      await refStorage.putFile(File(foto.path));
      final url = await refStorage.getDownloadURL();

      setModalState(() {
        _anexoAulaUrl = url;
        _fazendoUploadAnexo = false;
      });
      setState(() {
        _anexoAulaUrl = url;
        _fazendoUploadAnexo = false;
      });

      await _salvarAlteracaoNoBanco({'anexoUrl': url});

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto anexada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      setModalState(() => _fazendoUploadAnexo = false);
      setState(() => _fazendoUploadAnexo = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  void _removerFotoAnexada(StateSetter setModalState) {
    setModalState(() => _anexoAulaUrl = null);
    setState(() => _anexoAulaUrl = null);
    _salvarAlteracaoNoBanco({'anexoUrl': FieldValue.delete()});
  }

  String get _statusAulaHoje =>
      _statusAulaPorData[_dataBanco] ?? 'NAO_INICIADA';

  String _obterStatusAluno(String matricula) {
    if (!_frequenciaPorData.containsKey(_dataBanco))
      _frequenciaPorData[_dataBanco] = {};
    return _frequenciaPorData[_dataBanco]![matricula] ?? 'P';
  }

  void _mudarDia(int dias) {
    _verificarEEncerrarAulaAtualAntesDeMudar();
    setState(() {
      _dataSelecionada = _dataSelecionada.add(Duration(days: dias));
      _termoPesquisa = '';
    });
    _carregarDiarioDoBanco();
  }

  Future<void> _escolherDataCalendario() async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (dataEscolhida != null && dataEscolhida != _dataSelecionada) {
      _verificarEEncerrarAulaAtualAntesDeMudar();
      setState(() {
        _dataSelecionada = dataEscolhida;
        _termoPesquisa = '';
      });
      _carregarDiarioDoBanco();
    }
  }

  void _iniciarAula() {
    setState(() => _statusAulaPorData[_dataBanco] = 'EM_ANDAMENTO');
    _salvarAlteracaoNoBanco({
      'status': 'EM_ANDAMENTO',
      'dataCriacao': FieldValue.serverTimestamp(),
    });
  }

  void _encerrarAula() {
    setState(() => _statusAulaPorData[_dataBanco] = 'FINALIZADA');
    _salvarAlteracaoNoBanco({'status': 'FINALIZADA'});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aula do dia $_dataDisplay encerrada e salva!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _reabrirAula() {
    setState(() => _statusAulaPorData[_dataBanco] = 'EM_ANDAMENTO');
    _salvarAlteracaoNoBanco({'status': 'EM_ANDAMENTO'});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aula reaberta para edição.'),
        backgroundColor: Colors.amber,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _marcarStatusAluno(String matricula, String status) {
    if (_statusAulaHoje != 'EM_ANDAMENTO') return;

    setState(() {
      if (!_frequenciaPorData.containsKey(_dataBanco))
        _frequenciaPorData[_dataBanco] = {};
      _frequenciaPorData[_dataBanco]![matricula] = status;
    });

    _salvarAlteracaoNoBanco({'frequencia': _frequenciaPorData[_dataBanco]});
  }

  void _abrirModalPreencherDiario() {
    final ctrl = TextEditingController(text: _conteudoAulaAtual);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Diário de Sala',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
                        hintText: 'Digite o conteúdo lecionado (opcional)...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    if (_fazendoUploadAnexo)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Enviando foto...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else if (_anexoAulaUrl != null)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _anexoAulaUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircleAvatar(
                              backgroundColor: Colors.redAccent,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _removerFotoAnexada(setModalState),
                                tooltip: 'Remover foto',
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _capturarEEnviarFoto(setModalState),
                        icon: Icon(
                          Icons.camera_alt_rounded,
                          color: Theme.of(context).primaryColor,
                        ),
                        label: Text(
                          'Tirar Foto do Quadro',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  setState(() => _conteudoAulaAtual = ctrl.text.trim());
                  _salvarAlteracaoNoBanco({'conteudo': _conteudoAulaAtual});
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text(
                  'Salvar Diário',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarFotoAmpliada(String? fotoUrl) {
    if (fotoUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(fotoUrl, fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;

    final estadoTurmas = ref.watch(turmasStreamProvider);
    final estadoAlunos = ref.watch(alunosStreamProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: const Text(
          'Diário de Classe',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),

      floatingActionButton:
          _abaAtiva == 0 &&
              _statusAulaHoje != 'NAO_INICIADA' &&
              !_carregandoDiario
          ? FloatingActionButton.extended(
              onPressed: _statusAulaHoje == 'FINALIZADA'
                  ? (_isDiaPassado ? null : _reabrirAula)
                  : _encerrarAula,
              backgroundColor: _statusAulaHoje == 'FINALIZADA'
                  ? (_isDiaPassado ? Colors.grey : Colors.orange)
                  : corPrimaria,
              foregroundColor: Colors.white,
              icon: Icon(
                _statusAulaHoje == 'FINALIZADA'
                    ? (_isDiaPassado
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded)
                    : Icons.check_circle_rounded,
              ),
              label: Text(
                _statusAulaHoje == 'FINALIZADA'
                    ? (_isDiaPassado
                          ? 'Bloqueada (Dia Anterior)'
                          : 'Reabrir Aula')
                    : 'Encerrar Aula',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,

      body: estadoTurmas.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: corPrimaria)),
        error: (e, s) => Center(child: Text('Erro ao carregar a turma: $e')),
        data: (turmas) {
          final turmaMap = turmas
              .where((t) => t['id'] == widget.turmaId)
              .toList();
          if (turmaMap.isEmpty)
            return const Center(child: Text('Turma não encontrada.'));
          final turma = turmaMap.first;

          return estadoAlunos.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: corPrimaria)),
            error: (e, s) =>
                Center(child: Text('Erro ao carregar os alunos: $e')),
            data: (alunosRaw) {
              var alunosDaTurma = alunosRaw.where((a) {
                final isPrincipal =
                    a['turmaId'] == widget.turmaId ||
                    a['turma'] == turma['nome'];
                bool isExtra = false;
                if (a['turmasExtrasIds'] != null &&
                    a['turmasExtrasIds'] is List) {
                  isExtra = (a['turmasExtrasIds'] as List).contains(
                    widget.turmaId,
                  );
                }
                return (isPrincipal || isExtra) && a['status'] == 'Ativo';
              }).toList();

              alunosDaTurma.sort(
                (a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo(
                  (b['nome'] ?? '').toString().toUpperCase(),
                ),
              );

              int presentes = 0;
              int faltas = 0;
              for (var a in alunosDaTurma) {
                final st = _obterStatusAluno((a['matricula'] ?? '').toString());
                if (st == 'P') presentes++;
                if (st == 'A') faltas++;
              }
              final int total = alunosDaTurma.length;
              final double percP = total == 0 ? 0 : (presentes / total) * 100;
              final double percA = total == 0 ? 0 : (faltas / total) * 100;

              List<Map<String, dynamic>> alunosListagem = List.from(
                alunosDaTurma,
              );
              if (_termoPesquisa.isNotEmpty) {
                alunosListagem = alunosListagem
                    .where(
                      (a) => (a['nome'] ?? '')
                          .toString()
                          .toUpperCase()
                          .contains(_termoPesquisa.toUpperCase()),
                    )
                    .toList();
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: corPrimaria,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                turma['nome'] ?? 'Turma',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.wb_sunny_rounded,
                                          color: Colors.white70,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${turma['turno'] ?? 'N/A'}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.people_alt_rounded,
                                          color: Colors.white70,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${alunosDaTurma.length} Alunos',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (_abaAtiva == 0)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(25),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(
                                              Icons.chevron_left_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: () => _mudarDia(-1),
                                          ),
                                          InkWell(
                                            onTap: _escolherDataCalendario,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 6,
                                                  ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .calendar_month_rounded,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _dataDisplay,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: () => _mudarDia(1),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ==========================================================================
                        // RENDERIZAÇÃO DOS BOTÕES DAS ABAS
                        // ==========================================================================
                        Container(
                          color: Colors.black.withAlpha(20),
                          child: Row(
                            children: [
                              _buildAbaControle(
                                0,
                                'Frequência',
                                Icons.fact_check_outlined,
                              ),
                              _buildAbaControle(
                                1,
                                'Notas',
                                Icons.edit_note_rounded,
                              ),
                              _buildAbaControle(
                                2,
                                'Avisos',
                                Icons.campaign_rounded,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==========================================================
                  // SPLIT 50/50 E BARRA DE PESQUISA (SÓ APARECE NA ABA 0)
                  // ==========================================================
                  if (_abaAtiva == 0 &&
                      _statusAulaHoje != 'NAO_INICIADA' &&
                      !_carregandoDiario &&
                      total > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _statusAulaHoje == 'FINALIZADA'
                                    ? null
                                    : _abrirModalPreencherDiario,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.menu_book_rounded,
                                            color: Colors.blue.shade700,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Diário de Sala',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (_anexoAulaUrl != null)
                                            Icon(
                                              Icons.photo_camera_back_rounded,
                                              color: Colors.blue.shade800,
                                              size: 14,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _conteudoAulaAtual.isEmpty &&
                                                _anexoAulaUrl == null
                                            ? 'Registrar conteúdo...'
                                            : (_conteudoAulaAtual.isNotEmpty
                                                  ? _conteudoAulaAtual
                                                  : 'Foto anexada'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue.shade800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Pesquisar...',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                onChanged: (v) =>
                                    setState(() => _termoPesquisa = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_abaAtiva == 0 &&
                      _statusAulaHoje != 'NAO_INICIADA' &&
                      !_carregandoDiario &&
                      total > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Presentes: ${percP.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Faltas: ${percA.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ==========================================================
                  // NAVEGAÇÃO E RENDERIZAÇÃO DAS TELAS CENTRAIS
                  // ==========================================================
                  Expanded(
                    child: _carregandoDiario
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: corPrimaria),
                                const SizedBox(height: 16),
                                const Text(
                                  'Sincronizando com o Firebase...',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : _abaAtiva == 0
                        ? _buildAbaFrequencia(
                            alunosListagem,
                            corPrimaria,
                          ) // === ABA 0: FREQUÊNCIA ===
                        : _abaAtiva == 1
                        ? _buildAbaNotas() // === ABA 1: NOTAS ===
                        : _buildAbaAvisos(
                            alunosDaTurma,
                            corPrimaria,
                          ), // === ABA 2: AVISOS ===
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAbaControle(int indice, String titulo, IconData icone) {
    final isAtiva = _abaAtiva == indice;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _abaAtiva = indice),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isAtiva ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icone,
                color: isAtiva ? Colors.white : Colors.white60,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: TextStyle(
                  color: isAtiva ? Colors.white : Colors.white60,
                  fontWeight: isAtiva ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ABA 0: FREQUÊNCIA
  // ==========================================================================
  Widget _buildAbaFrequencia(
    List<Map<String, dynamic>> alunos,
    Color corPrimaria,
  ) {
    if (_statusAulaHoje == 'NAO_INICIADA') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pending_actions_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aula Não Iniciada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Data: $_dataDisplay',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: corPrimaria,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              onPressed: _iniciarAula,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'INICIAR AULA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    if (alunos.isEmpty) {
      return Center(
        child: Text(
          'Nenhum aluno encontrado.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16).copyWith(bottom: 100),
      itemCount: alunos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final aluno = alunos[index];
        final fotoUrl = aluno['fotoUrl'];
        final nome = aluno['nome'] ?? 'Aluno sem nome';
        final matricula = (aluno['matricula'] ?? '').toString();
        final statusAtual = _obterStatusAluno(matricula);

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _mostrarFotoAmpliada(fotoUrl),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: corPrimaria.withAlpha(30),
                        backgroundImage: fotoUrl != null
                            ? NetworkImage(fotoUrl)
                            : null,
                        child: fotoUrl == null
                            ? Icon(Icons.person, color: corPrimaria)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: corPrimaria,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                            softWrap: true,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Matrícula: $matricula',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _statusAulaHoje == 'FINALIZADA'
                        ? Colors.grey.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBotaoStatus(
                        matricula,
                        'P',
                        'Presente',
                        Icons.check_circle_rounded,
                        Colors.green,
                        statusAtual,
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade300,
                      ),
                      _buildBotaoStatus(
                        matricula,
                        'A',
                        'Ausente',
                        Icons.cancel_rounded,
                        Colors.red,
                        statusAtual,
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade300,
                      ),
                      _buildBotaoStatus(
                        matricula,
                        'J',
                        'Justificado',
                        Icons.info_rounded,
                        Colors.orange,
                        statusAtual,
                      ),
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

  Widget _buildBotaoStatus(
    String matricula,
    String sigla,
    String palavraCompleta,
    IconData icone,
    Color cor,
    String statusAtual,
  ) {
    final isSelecionado = statusAtual == sigla;
    final bloqueado = _statusAulaHoje == 'FINALIZADA';

    return Expanded(
      child: InkWell(
        onTap: bloqueado ? null : () => _marcarStatusAluno(matricula, sigla),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelecionado
                ? cor.withAlpha(bloqueado ? 20 : 40)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icone,
                size: 16,
                color: isSelecionado
                    ? (bloqueado ? cor.withAlpha(150) : cor)
                    : Colors.grey.shade400,
              ),
              if (isSelecionado) ...[
                const SizedBox(width: 4),
                Text(
                  palavraCompleta,
                  style: TextStyle(
                    color: (bloqueado ? cor.withAlpha(150) : cor),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 4),
                Text(
                  sigla,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ABA 1: NOTAS
  // ==========================================================================
  Widget _buildAbaNotas() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Notas e Avaliações',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A planilha de notas será construída em breve.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ABA 2: AVISOS
  // ==========================================================================
  Widget _buildAbaAvisos(List<Map<String, dynamic>> alunos, Color corPrimaria) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: corPrimaria.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.campaign_rounded, color: corPrimaria),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enviar Novo Aviso',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Comunique-se com a turma ou responsáveis.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Enviar para:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'TURMA',
                    label: Text('Toda a Turma', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.groups_rounded),
                  ),
                  ButtonSegment(
                    value: 'ALUNO',
                    label: Text(
                      'Aluno Específico',
                      style: TextStyle(fontSize: 12),
                    ),
                    icon: Icon(Icons.person_rounded),
                  ),
                  ButtonSegment(
                    value: 'RESPONSAVEL',
                    label: Text('Responsável', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.family_restroom_rounded),
                  ),
                ],
                selected: {_tipoAviso},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _tipoAviso = newSelection.first;
                    _alunoAvisoSelecionado = null;
                  });
                },
              ),

              if (_tipoAviso != 'TURMA') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: _tipoAviso == 'ALUNO'
                        ? 'Selecione o Aluno'
                        : 'Selecione o Aluno (Enviaremos ao Responsável)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  initialValue: _alunoAvisoSelecionado,
                  items: alunos.map<DropdownMenuItem<String>>((a) {
                    final nome = a['nome'] ?? 'Sem nome';
                    final id = a['id'] ?? '';
                    return DropdownMenuItem<String>(
                      value: id.toString(),
                      child: Text(nome.toString()),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _alunoAvisoSelecionado = val),
                ),
              ],

              const SizedBox(height: 16),

              TextField(
                controller: _mensagemAvisoCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Mensagem do Aviso',
                  alignLabelWithHint: true,
                  hintText:
                      'Digite aqui os detalhes do aviso, lembretes de prova, material, etc...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corPrimaria,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (_tipoAviso != 'TURMA' &&
                        _alunoAvisoSelecionado == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, selecione um aluno.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (_mensagemAvisoCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('A mensagem não pode estar vazia.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Aviso enviado com sucesso! (Funcionalidade visual)',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _mensagemAvisoCtrl.clear();
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    'ENVIAR AVISO',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
