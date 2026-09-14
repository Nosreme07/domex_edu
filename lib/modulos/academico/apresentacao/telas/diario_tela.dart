import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  // CONTROLE DE ABAS E ESTADO GERAL
  // ==========================================================================
  int _abaAtiva = 0; 
  String _termoPesquisa = ''; 
  
  bool _carregandoDiario = false;
  String _conteudoAulaAtual = ''; 
  String? _anexoAulaUrl; 
  bool _fazendoUploadAnexo = false; 
  bool _isDiaAvaliacao = false; 
  
  final Map<String, Map<String, String>> _frequenciaPorData = {};
  final Map<String, String> _statusAulaPorData = {};

  // ==========================================================================
  // ESTADOS DA ABA DE AVISOS E NOTAS
  // ==========================================================================
  String _tipoAviso = 'TURMA'; 
  String? _alunoAvisoSelecionado;
  final TextEditingController _mensagemAvisoCtrl = TextEditingController();
  bool _enviandoAviso = false;

  late String _bimestreAtivo;

  String get _dataDisplay => "${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}";
  String get _dataBanco => "${_dataSelecionada.year}-${_dataSelecionada.month.toString().padLeft(2, '0')}-${_dataSelecionada.day.toString().padLeft(2, '0')}";

  bool get _isDiaPassado {
    final hoje = DateTime.now();
    final dataSemHora = DateTime(_dataSelecionada.year, _dataSelecionada.month, _dataSelecionada.day);
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    return dataSemHora.isBefore(hojeSemHora);
  }

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
    _bimestreAtivo = _calcularBimestre(_dataSelecionada);
    Future.microtask(() => _carregarDiarioDoBanco());
  }

  @override
  void dispose() {
    _mensagemAvisoCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  // FUNÇÕES DE BANCO DE DADOS
  // ==========================================================================
  Future<void> _carregarDiarioDoBanco() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    setState(() => _carregandoDiario = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('tenants').doc(user.id)
          .collection('turmas').doc(widget.turmaId)
          .collection('diarios').doc(_dataBanco)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _statusAulaPorData[_dataBanco] = data['status'] ?? 'NAO_INICIADA';
          _frequenciaPorData[_dataBanco] = Map<String, String>.from(data['frequencia'] ?? {});
          _conteudoAulaAtual = data['conteudo'] ?? '';
          _anexoAulaUrl = data['anexoUrl'];
          _isDiaAvaliacao = data['isDiaAvaliacao'] ?? false;
        });
      } else {
        setState(() {
          _statusAulaPorData[_dataBanco] = 'NAO_INICIADA';
          _frequenciaPorData[_dataBanco] = {};
          _conteudoAulaAtual = '';
          _anexoAulaUrl = null;
          _isDiaAvaliacao = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar diário: $e');
    }

    setState(() => _carregandoDiario = false);
  }

  Future<void> _salvarAlteracaoNoBancoEspecifico(String dataDB, Map<String, dynamic> dados) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('tenants').doc(user.id)
        .collection('turmas').doc(widget.turmaId)
        .collection('diarios').doc(dataDB)
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

  void _alternarDiaAvaliacao() {
    setState(() {
      _isDiaAvaliacao = !_isDiaAvaliacao;
    });
    _salvarAlteracaoNoBanco({'isDiaAvaliacao': _isDiaAvaliacao});
  }

  // ==========================================================================
  // FUNÇÕES DA ABA FREQUÊNCIA E DIÁRIO
  // ==========================================================================
  Future<void> _capturarEEnviarFoto(StateSetter setModalState) async {
    try {
      final picker = ImagePicker();
      final XFile? foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      
      if (foto == null) return; 

      setModalState(() => _fazendoUploadAnexo = true);
      setState(() => _fazendoUploadAnexo = true);

      final user = ref.read(authProvider).value;
      final nomeArquivo = 'anexo_aula_$_dataBanco-${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final refStorage = FirebaseStorage.instance
          .ref('tenants/${user!.id}/turmas/${widget.turmaId}/diarios/$nomeArquivo');

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
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto anexada com sucesso!'), backgroundColor: Colors.green));
    } catch (e) {
      setModalState(() => _fazendoUploadAnexo = false);
      setState(() => _fazendoUploadAnexo = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar foto: $e'), backgroundColor: Colors.red));
    }
  }

  void _removerFotoAnexada(StateSetter setModalState) {
    setModalState(() => _anexoAulaUrl = null);
    setState(() => _anexoAulaUrl = null);
    _salvarAlteracaoNoBanco({'anexoUrl': FieldValue.delete()});
  }

  String get _statusAulaHoje => _statusAulaPorData[_dataBanco] ?? 'NAO_INICIADA';

  String _obterStatusAluno(String matricula) {
    if (!_frequenciaPorData.containsKey(_dataBanco)) _frequenciaPorData[_dataBanco] = {};
    return _frequenciaPorData[_dataBanco]![matricula] ?? 'P'; 
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor, onPrimary: Colors.white)),
          child: child!,
        );
      },
    );

    if (dataEscolhida != null && dataEscolhida != _dataSelecionada) {
      _verificarEEncerrarAulaAtualAntesDeMudar();
      setState(() {
        _dataSelecionada = dataEscolhida;
        _termoPesquisa = '';
        _bimestreAtivo = _calcularBimestre(_dataSelecionada); 
      });
      _carregarDiarioDoBanco();
    }
  }

  void _iniciarAula() {
    setState(() => _statusAulaPorData[_dataBanco] = 'EM_ANDAMENTO');
    _salvarAlteracaoNoBanco({'status': 'EM_ANDAMENTO', 'dataCriacao': FieldValue.serverTimestamp()});
  }

  void _encerrarAula() {
    setState(() => _statusAulaPorData[_dataBanco] = 'FINALIZADA');
    _salvarAlteracaoNoBanco({'status': 'FINALIZADA'});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aula do dia $_dataDisplay encerrada e salva!'), backgroundColor: Colors.green));
  }

  void _reabrirAula() {
    setState(() => _statusAulaPorData[_dataBanco] = 'EM_ANDAMENTO');
    _salvarAlteracaoNoBanco({'status': 'EM_ANDAMENTO'});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aula reaberta para edição.'), backgroundColor: Colors.amber, behavior: SnackBarBehavior.floating));
  }

  void _marcarStatusAluno(String matricula, String status) {
    if (_statusAulaHoje != 'EM_ANDAMENTO') return;

    setState(() {
      if (!_frequenciaPorData.containsKey(_dataBanco)) _frequenciaPorData[_dataBanco] = {};
      _frequenciaPorData[_dataBanco]![matricula] = status;
    });

    _salvarAlteracaoNoBanco({'frequencia': _frequenciaPorData[_dataBanco]});
  }

  // ==========================================================================
  // FUNÇÕES DE ESTATÍSTICAS E POPUPS (RAIO-X DO ALUNO)
  // ==========================================================================
  Future<Map<String, dynamic>> _buscarEstatisticasAluno(String matricula) async {
    final user = ref.read(authProvider).value;
    if (user == null) return {};

    int presencas = 0;
    int faltas = 0;
    List<Map<String, dynamic>> notasList = [];

    try {
      final diariosSnap = await FirebaseFirestore.instance
          .collection('tenants').doc(user.id)
          .collection('turmas').doc(widget.turmaId)
          .collection('diarios').get();

      for (var doc in diariosSnap.docs) {
        final data = doc.data();
        if (data['status'] != 'NAO_INICIADA') {
           final freq = Map<String, String>.from(data['frequencia'] ?? {});
           final st = freq[matricula] ?? 'P'; 
           if (st == 'P') {
             presencas++;
           } else if (st == 'A' || st == 'J') {
             faltas++;
           }
        }
      }

      final avaliacoesSnap = await FirebaseFirestore.instance
          .collection('tenants').doc(user.id)
          .collection('turmas').doc(widget.turmaId)
          .collection('avaliacoes')
          .get();

      final avaliacoes = avaliacoesSnap.docs;
      // Ordenação local segura (Data Criação)
      avaliacoes.sort((a, b) {
        final dataA = a.data()['dataCriacao'] as Timestamp?;
        final dataB = b.data()['dataCriacao'] as Timestamp?;
        if (dataA == null && dataB == null) return 0;
        if (dataA == null) return 1;
        if (dataB == null) return -1;
        return dataB.compareTo(dataA); 
      });

      for (var doc in avaliacoes) {
        final data = doc.data();
        final notas = Map<String, dynamic>.from(data['notas'] ?? {});
        if (notas.containsKey(matricula)) {
          notasList.add({
            'nome': data['nome'] ?? 'Avaliação',
            'bimestre': data['bimestre'] ?? '',
            'nota': notas[matricula],
            'maxima': data['pontuacaoMaxima'] ?? 10.0,
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar estatísticas do aluno: $e');
    }

    return {
      'presencas': presencas,
      'faltas': faltas,
      'notas': notasList,
    };
  }

  void _abrirPopupResumoAluno(Map<String, dynamic> aluno, Color corPrimaria) {
    final matricula = (aluno['matricula'] ?? '').toString();
    final fotoUrl = aluno['fotoUrl'];
    final nome = aluno['nome'] ?? 'Sem nome';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
          builder: (_, scrollController) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _buscarEstatisticasAluno(matricula),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stats = snapshot.data ?? {};
                final int presencas = stats['presencas'] ?? 0;
                final int faltas = stats['faltas'] ?? 0;
                final int totalAulas = presencas + faltas;
                final double percFrequencia = totalAulas == 0 ? 100.0 : (presencas / totalAulas) * 100;
                
                final List<Map<String, dynamic>> notas = stats['notas'] ?? [];

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30, backgroundColor: corPrimaria.withAlpha(30),
                            backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                            child: fotoUrl == null ? Icon(Icons.person, color: corPrimaria, size: 30) : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text('Matrícula: $matricula', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: percFrequencia >= 75 ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: percFrequencia >= 75 ? Colors.green.shade200 : Colors.red.shade200)
                              ),
                              child: Column(
                                children: [
                                  Icon(percFrequencia >= 75 ? Icons.thumb_up_alt_rounded : Icons.warning_rounded, color: percFrequencia >= 75 ? Colors.green.shade700 : Colors.red.shade700),
                                  const SizedBox(height: 8),
                                  Text('${percFrequencia.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: percFrequencia >= 75 ? Colors.green.shade800 : Colors.red.shade800)),
                                  Text('Frequência', style: TextStyle(color: percFrequencia >= 75 ? Colors.green.shade800 : Colors.red.shade800, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                              child: Column(
                                children: [
                                  Icon(Icons.event_busy_rounded, color: Colors.blue.shade700),
                                  const SizedBox(height: 8),
                                  Text('$faltas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue.shade800)),
                                  Text('Faltas Acumuladas', style: TextStyle(color: Colors.blue.shade800, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      color: Colors.grey.shade50,
                      child: const Text('Histórico de Notas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                    ),
                    Expanded(
                      child: notas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text('Nenhuma nota lançada.', style: TextStyle(color: Colors.grey.shade500)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: notas.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final n = notas[index];
                                final valorNota = (n['nota'] as num).toDouble();
                                final valorMax = (n['maxima'] as num).toDouble();
                                final double percentualAproveitamento = valorMax > 0 ? (valorNota / valorMax) * 100 : 0;
                                final bool notaBoa = percentualAproveitamento >= 60;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: notaBoa ? Colors.green.shade50 : Colors.red.shade50,
                                    child: Icon(notaBoa ? Icons.check_rounded : Icons.close_rounded, color: notaBoa ? Colors.green : Colors.red),
                                  ),
                                  title: Text(n['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(n['bimestre'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: notaBoa ? Colors.green.shade600 : Colors.red.shade600,
                                      borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: Text(
                                      '${valorNota.toStringAsFixed(1)} / ${valorMax.toStringAsFixed(1)}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
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

  // ==========================================================================
  // FUNÇÕES DE NOTAS E AVALIAÇÕES GERAIS
  // ==========================================================================
  void _abrirModalNovaAvaliacao(Color corPrimaria, List<Map<String, dynamic>> alunosTurma) {
    final ctrlNome = TextEditingController();
    final ctrlPontos = TextEditingController(text: '10.0');
    bool salvando = false;

    final bimestreAlvo = _abaAtiva == 1 ? _bimestreAtivo : _calcularBimestre(_dataSelecionada);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.add_task_rounded, color: corPrimaria),
                const SizedBox(width: 8),
                const Text('Nova Avaliação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vinculada ao: $bimestreAlvo', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrlNome,
                  decoration: InputDecoration(
                    labelText: 'Nome da Avaliação (ex: Prova Parcial)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrlPontos,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Pontuação Máxima',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: salvando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: salvando ? null : () async {
                  if (ctrlNome.text.trim().isEmpty) return;
                  
                  setModalState(() => salvando = true);
                  final user = ref.read(authProvider).value;
                  
                  if (user != null) {
                    List<String> matriculasAusentes = [];
                    for (var aluno in alunosTurma) {
                      final mat = (aluno['matricula'] ?? '').toString();
                      if (_obterStatusAluno(mat) == 'A') {
                        matriculasAusentes.add(mat);
                      }
                    }

                    final novaAvaliacao = {
                      'nome': ctrlNome.text.trim(),
                      'pontuacaoMaxima': double.tryParse(ctrlPontos.text.replaceAll(',', '.')) ?? 10.0,
                      'bimestre': bimestreAlvo, 
                      'dataAvaliacao': _dataBanco, 
                      'dataCriacao': FieldValue.serverTimestamp(),
                      'matriculasAusentes': matriculasAusentes, 
                      'notas': {} 
                    };

                    final docRef = await FirebaseFirestore.instance
                        .collection('tenants').doc(user.id)
                        .collection('turmas').doc(widget.turmaId)
                        .collection('avaliacoes')
                        .add(novaAvaliacao);
                    
                    if (mounted) {
                      Navigator.pop(ctx); 
                      setState(() {
                        _abaAtiva = 1;
                        _bimestreAtivo = bimestreAlvo;
                      });
                      
                      _abrirModalLancarNotas(novaAvaliacao, docRef.id, alunosTurma, corPrimaria);
                    }
                  }
                },
                child: salvando 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('Criar e Lançar Notas', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

  void _abrirModalLancarNotas(Map<String, dynamic> avaliacao, String avaliacaoId, List<Map<String, dynamic>> alunosTurma, Color corPrimaria) {
    final Map<String, TextEditingController> controladores = {};
    final notasAtuais = Map<String, dynamic>.from(avaliacao['notas'] ?? {});
    final pontuacaoMaxima = (avaliacao['pontuacaoMaxima'] ?? 10.0) as double;
    final List<dynamic> ausentes = avaliacao['matriculasAusentes'] ?? [];

    for (var aluno in alunosTurma) {
      final matricula = (aluno['matricula'] ?? '').toString();
      final notaExistente = notasAtuais[matricula];
      controladores[matricula] = TextEditingController(text: notaExistente != null ? notaExistente.toString() : '');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.edit_note_rounded, color: corPrimaria)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(avaliacao['nome'] ?? 'Avaliação', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Valor Máximo: $pontuacaoMaxima pontos', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: alunosTurma.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final aluno = alunosTurma[index];
                    final matricula = (aluno['matricula'] ?? '').toString();
                    final ctrl = controladores[matricula]!;
                    final faltouNaProva = ausentes.contains(matricula); 

                    return Card(
                      elevation: 0,
                      color: faltouNaProva ? Colors.red.shade50.withAlpha(100) : Colors.white, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: faltouNaProva ? Colors.red.shade200 : Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18, backgroundColor: corPrimaria.withAlpha(30),
                              backgroundImage: aluno['fotoUrl'] != null ? NetworkImage(aluno['fotoUrl']) : null,
                              child: aluno['fotoUrl'] == null ? Icon(Icons.person, color: corPrimaria, size: 20) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(aluno['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (faltouNaProva)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Faltou neste dia', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    )
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: ctrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: '-',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true, fillColor: Colors.white,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -5))]),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        final user = ref.read(authProvider).value;
                        if (user == null) return;

                        final Map<String, double> notasFinais = {};
                        controladores.forEach((mat, ctrl) {
                          if (ctrl.text.trim().isNotEmpty) {
                            notasFinais[mat] = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
                          }
                        });

                        await FirebaseFirestore.instance
                            .collection('tenants').doc(user.id)
                            .collection('turmas').doc(widget.turmaId)
                            .collection('avaliacoes').doc(avaliacaoId)
                            .update({'notas': notasFinais});

                        // Novo formato seguro de fechamento assíncrono:
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notas salvas com sucesso!'), backgroundColor: Colors.green));
                        }
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('SALVAR NOTAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FUNÇÃO DE DIÁRIO DE AULA (POPUP)
  // ==========================================================================
  void _abrirModalPreencherDiario() {
    final ctrl = TextEditingController(text: _conteudoAulaAtual);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder( 
        builder: (context, setModalState) {
          return AlertDialog(
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
                      controller: ctrl, maxLines: 4,
                      decoration: InputDecoration(hintText: 'Digite o conteúdo lecionado (opcional)...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    if (_fazendoUploadAnexo)
                      Container(
                        padding: const EdgeInsets.all(24), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [CircularProgressIndicator(color: Theme.of(context).primaryColor), const SizedBox(height: 12), const Text('Enviando foto...', style: TextStyle(color: Colors.grey))]),
                      )
                    else if (_anexoAulaUrl != null)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_anexoAulaUrl!, fit: BoxFit.cover, width: double.infinity, height: 200)),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircleAvatar(
                              backgroundColor: Colors.redAccent,
                              child: IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 20), onPressed: () => _removerFotoAnexada(setModalState), tooltip: 'Remover foto'),
                            ),
                          )
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Theme.of(context).primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => _capturarEEnviarFoto(setModalState),
                        icon: Icon(Icons.camera_alt_rounded, color: Theme.of(context).primaryColor),
                        label: Text('Tirar Foto do Quadro', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () {
                  setState(() => _conteudoAulaAtual = ctrl.text.trim());
                  _salvarAlteracaoNoBanco({'conteudo': _conteudoAulaAtual});
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.save_rounded, size: 18), label: const Text('Salvar Diário', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
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
            ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(fotoUrl, fit: BoxFit.contain)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context), style: IconButton.styleFrom(backgroundColor: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // FUNÇÃO DE AVISOS 
  // ==========================================================================
  Future<void> _enviarAvisoFirebase() async {
    if (_tipoAviso != 'TURMA' && _alunoAvisoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione um aluno.'), backgroundColor: Colors.red));
      return;
    }
    if (_mensagemAvisoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A mensagem não pode estar vazia.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _enviandoAviso = true);

    try {
      final user = ref.read(authProvider).value;
      if (user == null) return;

      final avisoData = {
        'tipoDestinatario': _tipoAviso, 
        'alunoId': _tipoAviso == 'TURMA' ? null : _alunoAvisoSelecionado,
        'mensagem': _mensagemAvisoCtrl.text.trim(),
        'dataEnvio': FieldValue.serverTimestamp(),
        'remetenteId': user.id,
      };

      await FirebaseFirestore.instance
          .collection('tenants').doc(user.id)
          .collection('turmas').doc(widget.turmaId)
          .collection('avisos')
          .add(avisoData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aviso enviado e salvo com sucesso!'), backgroundColor: Colors.green));
        _mensagemAvisoCtrl.clear();
        setState(() {
          _alunoAvisoSelecionado = null;
          _tipoAviso = 'TURMA';
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar aviso: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _enviandoAviso = false);
    }
  }

  // ==========================================================================
  // CONSTRUÇÃO DA TELA (BUILD)
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    
    final estadoTurmas = ref.watch(turmasStreamProvider);
    final estadoAlunos = ref.watch(alunosStreamProvider);

    String tituloAppBar = 'Diário de Classe';
    if (estadoTurmas.hasValue) {
      final tMap = estadoTurmas.value!.where((t) => t['id'] == widget.turmaId).toList();
      if (tMap.isNotEmpty) tituloAppBar = tMap.first['nome'] ?? 'Diário de Classe';
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: Text(tituloAppBar, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      
      floatingActionButton: _abaAtiva == 0 && _statusAulaHoje != 'NAO_INICIADA' && !_carregandoDiario
        ? FloatingActionButton.extended(
            onPressed: _statusAulaHoje == 'FINALIZADA' 
                ? (_isDiaPassado ? null : _reabrirAula) 
                : _encerrarAula,
            backgroundColor: _statusAulaHoje == 'FINALIZADA' 
                ? (_isDiaPassado ? Colors.grey : Colors.orange) 
                : corPrimaria,
            foregroundColor: Colors.white,
            icon: Icon(_statusAulaHoje == 'FINALIZADA' 
                ? (_isDiaPassado ? Icons.lock_rounded : Icons.lock_open_rounded) 
                : Icons.check_circle_rounded),
            label: Text(
              _statusAulaHoje == 'FINALIZADA' ? (_isDiaPassado ? 'Bloqueada (Dia Anterior)' : 'Reabrir Aula') : 'Encerrar Aula', 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
          )
        : null,

      body: estadoTurmas.when(
        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
        error: (e, s) => Center(child: Text('Erro ao carregar a turma: $e')),
        data: (turmas) {
          final turmaMap = turmas.where((t) => t['id'] == widget.turmaId).toList();
          if (turmaMap.isEmpty) return const Center(child: Text('Turma não encontrada.'));
          final turma = turmaMap.first;

          return estadoAlunos.when(
            loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
            error: (e, s) => Center(child: Text('Erro ao carregar os alunos: $e')),
            data: (alunosRaw) {
              
              var alunosDaTurma = alunosRaw.where((a) {
                final isPrincipal = a['turmaId'] == widget.turmaId || a['turma'] == turma['nome'];
                bool isExtra = false;
                if (a['turmasExtrasIds'] != null && a['turmasExtrasIds'] is List) {
                  isExtra = (a['turmasExtrasIds'] as List).contains(widget.turmaId);
                }
                return (isPrincipal || isExtra) && a['status'] == 'Ativo';
              }).toList();

              alunosDaTurma.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

              int presentes = 0;
              int faltas = 0;
              for (var a in alunosDaTurma) {
                final st = _obterStatusAluno((a['matricula'] ?? '').toString());
                if (st == 'P') {
                  presentes++;
                } else if (st == 'A' || st == 'J') {
                  faltas++; 
                }
              }
              final int total = alunosDaTurma.length;
              final double percP = total == 0 ? 0 : (presentes / total) * 100;
              final double percA = total == 0 ? 0 : (faltas / total) * 100;

              List<Map<String, dynamic>> alunosListagem = List.from(alunosDaTurma);
              if (_termoPesquisa.isNotEmpty) {
                alunosListagem = alunosListagem.where((a) => (a['nome'] ?? '').toString().toUpperCase().contains(_termoPesquisa.toUpperCase())).toList();
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: corPrimaria, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.wb_sunny_rounded, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text('${turma['turno'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text('${alunosDaTurma.length} Alunos', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              
                              if (_abaAtiva == 0)
                                Container(
                                  decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                                        onPressed: () => _mudarDia(-1),
                                      ),
                                      InkWell(
                                        onTap: _escolherDataCalendario,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
                                              const SizedBox(width: 6),
                                              Text(_dataDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                                        onPressed: () => _mudarDia(1),
                                      ),
                                    ],
                                  ),
                                )
                            ],
                          ),
                        ),
                        
                        Container(
                          color: Colors.black.withAlpha(20),
                          child: Row(
                            children: [
                              _buildAbaControle(0, 'Frequência', Icons.fact_check_outlined),
                              _buildAbaControle(1, 'Notas', Icons.edit_note_rounded),
                              _buildAbaControle(2, 'Avisos', Icons.campaign_rounded),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  if (_abaAtiva == 0 && _statusAulaHoje != 'NAO_INICIADA' && !_carregandoDiario && total > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48, 
                              child: InkWell(
                                onTap: _statusAulaHoje == 'FINALIZADA' ? null : _abrirModalPreencherDiario, 
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.menu_book_rounded, color: Colors.blue.shade700, size: 18),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Diário de Sala', 
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13), 
                                          overflow: TextOverflow.ellipsis
                                        )
                                      ),
                                      if (_conteudoAulaAtual.isNotEmpty || _anexoAulaUrl != null) ...[
                                        const SizedBox(width: 6),
                                        Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 16),
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          Expanded(
                            child: SizedBox(
                              height: 48, 
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Pesquisar...',
                                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                  filled: true, fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                ),
                                onChanged: (v) => setState(() => _termoPesquisa = v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_abaAtiva == 0 && _statusAulaHoje != 'NAO_INICIADA' && !_carregandoDiario && total > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isDiaAvaliacao ? Colors.orange.shade50 : Colors.white,
                          border: Border.all(color: _isDiaAvaliacao ? Colors.orange.shade300 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: _statusAulaHoje == 'FINALIZADA' ? null : _alternarDiaAvaliacao,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.assignment_late_rounded, color: _isDiaAvaliacao ? Colors.orange.shade700 : Colors.grey.shade400, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Marcar hoje como Dia de Avaliação', 
                                        style: TextStyle(fontWeight: FontWeight.bold, color: _isDiaAvaliacao ? Colors.orange.shade900 : Colors.grey.shade700, fontSize: 13)
                                      )
                                    ),
                                    Switch(
                                      value: _isDiaAvaliacao,
                                      onChanged: _statusAulaHoje == 'FINALIZADA' ? null : (val) => _alternarDiaAvaliacao(),
                                      activeTrackColor: Colors.orange.shade300,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    )
                                  ],
                                ),
                              ),
                            ),
                            if (_isDiaAvaliacao && _statusAulaHoje != 'FINALIZADA')
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: corPrimaria,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _abrirModalNovaAvaliacao(corPrimaria, alunosDaTurma),
                                    icon: const Icon(Icons.add_task_rounded, size: 16),
                                    label: const Text('Criar Prova/Atividade Agora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                  
                  if (_abaAtiva == 0 && _statusAulaHoje != 'NAO_INICIADA' && !_carregandoDiario && total > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text('Presentes: ${percP.toStringAsFixed(1)}%', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                            )
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text('Faltas: ${percA.toStringAsFixed(1)}%', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                            )
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: _carregandoDiario 
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: corPrimaria),
                            const SizedBox(height: 16),
                            const Text('Sincronizando com o Firebase...', style: TextStyle(color: Colors.grey))
                          ],
                        ))
                      : _abaAtiva == 0 
                        ? _buildAbaFrequencia(alunosListagem, corPrimaria) 
                        : _abaAtiva == 1
                          ? _buildAbaNotas(alunosDaTurma, corPrimaria) 
                          : _buildAbaAvisos(alunosDaTurma, corPrimaria),   
                  ),
                ],
              );
            }
          );
        }
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
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isAtiva ? Colors.white : Colors.transparent, width: 3))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: isAtiva ? Colors.white : Colors.white60, size: 16),
              const SizedBox(width: 8),
              Text(titulo, style: TextStyle(color: isAtiva ? Colors.white : Colors.white60, fontWeight: isAtiva ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // CONSTRUÇÃO DA ABA FREQUÊNCIA
  // ==========================================================================
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
              onPressed: _iniciarAula,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('INICIAR AULA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
      );
    }

    if (alunos.isEmpty) {
      return Center(child: Text('Nenhum aluno encontrado.', style: TextStyle(color: Colors.grey.shade600)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16).copyWith(bottom: 100), 
      itemCount: alunos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6), 
      itemBuilder: (context, index) {
        final aluno = alunos[index];
        final fotoUrl = aluno['fotoUrl'];
        final nome = aluno['nome'] ?? 'Aluno sem nome';
        final matricula = (aluno['matricula'] ?? '').toString();
        final statusAtual = _obterStatusAluno(matricula);

        return Card(
          elevation: 1,
          margin: EdgeInsets.zero, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _mostrarFotoAmpliada(fotoUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6), 
                    child: Container(
                      width: 54,
                      height: 72, 
                      color: corPrimaria.withAlpha(30),
                      child: fotoUrl != null
                          ? Image.network(fotoUrl, fit: BoxFit.cover)
                          : Icon(Icons.person, color: corPrimaria, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _abrirPopupResumoAluno(aluno, corPrimaria),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  nome, 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 14, 
                                    color: corPrimaria, 
                                    decoration: TextDecoration.underline,
                                    decorationColor: corPrimaria.withAlpha(100)
                                  ), 
                                  maxLines: 2, 
                                  overflow: TextOverflow.visible, 
                                  softWrap: true
                                ),
                              ),
                              Icon(Icons.analytics_outlined, size: 16, color: corPrimaria.withAlpha(150)),
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
                            _buildBotaoStatus(matricula, 'P', 'Presente', Icons.check_circle_rounded, Colors.green, statusAtual),
                            Container(width: 1, height: 26, color: Colors.grey.shade300),
                            _buildBotaoStatus(matricula, 'A', 'Ausente', Icons.cancel_rounded, Colors.red, statusAtual),
                            Container(width: 1, height: 26, color: Colors.grey.shade300),
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
              if (isSelecionado) ...[
                const SizedBox(width: 4),
                Text(palavraCompleta, style: TextStyle(color: (bloqueado ? cor.withAlpha(150) : cor), fontWeight: FontWeight.bold, fontSize: 12)),
              ] else ... [
                const SizedBox(width: 4),
                Text(sigla, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // CONSTRUÇÃO DA ABA NOTAS E AVALIAÇÕES
  // ==========================================================================
  Widget _buildAbaNotas(List<Map<String, dynamic>> alunosTurma, Color corPrimaria) {
    final user = ref.watch(authProvider).value;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '1º Bimestre', label: Text('1º Bim', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: '2º Bimestre', label: Text('2º Bim', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: '3º Bimestre', label: Text('3º Bim', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: '4º Bimestre', label: Text('4º Bim', style: TextStyle(fontSize: 12))),
            ],
            selected: {_bimestreAtivo},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _bimestreAtivo = newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: corPrimaria.withAlpha(40),
              selectedForegroundColor: corPrimaria,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: corPrimaria, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () => _abrirModalNovaAvaliacao(corPrimaria, alunosTurma),
              icon: Icon(Icons.add_rounded, color: corPrimaria),
              label: Text('Criar Nova Avaliação', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: user == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tenants').doc(user.id)
                      .collection('turmas').doc(widget.turmaId)
                      .collection('avaliacoes')
                      .where('bimestre', isEqualTo: _bimestreAtivo)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Erro interno ao carregar avaliações.', style: TextStyle(color: Colors.red.shade700)));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    var docs = snapshot.data?.docs.toList() ?? [];
                    
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('Nenhuma avaliação no $_bimestreAtivo', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    }

                    docs.sort((a, b) {
                      final mapA = a.data() as Map<String, dynamic>;
                      final mapB = b.data() as Map<String, dynamic>;
                      final dataA = mapA['dataCriacao'] as Timestamp?;
                      final dataB = mapB['dataCriacao'] as Timestamp?;
                      if (dataA == null && dataB == null) return 0;
                      if (dataA == null) return 1;
                      if (dataB == null) return -1;
                      return dataB.compareTo(dataA); 
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final avaliacao = docs[index].data() as Map<String, dynamic>;
                        final id = docs[index].id;
                        final notasMap = Map<String, dynamic>.from(avaliacao['notas'] ?? {});
                        
                        final totalAlunos = alunosTurma.length;
                        final alunosComNota = notasMap.length;
                        
                        return InkWell(
                          onTap: () => _abrirModalLancarNotas(avaliacao, id, alunosTurma, corPrimaria),
                          borderRadius: BorderRadius.circular(12),
                          child: Card(
                            elevation: 1,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(Icons.edit_document, color: corPrimaria),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(avaliacao['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text('Valor Máximo: ${avaliacao['pontuacaoMaxima']} pontos', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: alunosComNota == totalAlunos ? Colors.green.shade50 : Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(8)
                                        ),
                                        child: Text(
                                          '$alunosComNota / $totalAlunos', 
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: alunosComNota == totalAlunos ? Colors.green.shade700 : Colors.orange.shade700)
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Lançadas', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================================================
  // CONSTRUÇÃO DA ABA AVISOS
  // ==========================================================================
  Widget _buildAbaAvisos(List<Map<String, dynamic>> alunos, Color corPrimaria) {
    final user = ref.watch(authProvider).value;

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.campaign_rounded, color: corPrimaria),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enviar Novo Aviso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('Comunique-se com a turma ou responsáveis.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  const Text('Enviar para:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'TURMA', label: Text('Toda a Turma', style: TextStyle(fontSize: 12)), icon: Icon(Icons.groups_rounded)),
                      ButtonSegment(value: 'ALUNO', label: Text('Aluno Específico', style: TextStyle(fontSize: 12)), icon: Icon(Icons.person_rounded)),
                      ButtonSegment(value: 'RESPONSAVEL', label: Text('Responsável', style: TextStyle(fontSize: 12)), icon: Icon(Icons.family_restroom_rounded)),
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
                    Builder(
                      builder: (context) {
                        final Map<String, String> alunosUnicos = {};
                        for (var a in alunos) {
                          final id = (a['id'] ?? a['matricula'] ?? a['nome']).toString();
                          alunosUnicos[id] = (a['nome'] ?? 'Sem nome').toString();
                        }

                        final valorSeguro = alunosUnicos.containsKey(_alunoAvisoSelecionado) 
                            ? _alunoAvisoSelecionado 
                            : null;

                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: _tipoAviso == 'ALUNO' ? 'Selecione o Aluno' : 'Selecione o Aluno (Enviaremos ao Responsável)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          initialValue: valorSeguro, 
                          items: alunosUnicos.entries.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: Text(e.value),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _alunoAvisoSelecionado = val),
                        );
                      }
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _mensagemAvisoCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Mensagem do Aviso',
                      alignLabelWithHint: true,
                      hintText: 'Digite aqui os detalhes do aviso, lembretes de prova, material, etc...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: _enviandoAviso ? null : _enviarAvisoFirebase,
                      icon: _enviandoAviso 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label: Text(_enviandoAviso ? 'Enviando...' : 'ENVIAR AVISO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Avisos Enviados Recentemente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          const SizedBox(height: 12),
          
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tenants').doc(user.id)
                  .collection('turmas').doc(widget.turmaId)
                  .collection('avisos')
                  .orderBy('dataEnvio', descending: true)
                  .limit(10) 
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                }
                
                if (snapshot.hasError) {
                  return const Center(child: Text('Erro ao carregar os avisos.'));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('Nenhum aviso enviado para esta turma ainda.', style: TextStyle(color: Colors.grey))),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true, 
                  physics: const NeverScrollableScrollPhysics(), 
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    
                    final dataEnvioRaw = data['dataEnvio'];
                    String dataFormatada = 'Data desconhecida';
                    if (dataEnvioRaw is Timestamp) {
                      dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(dataEnvioRaw.toDate());
                    }
                    
                    final tipo = data['tipoDestinatario'] ?? 'TURMA';
                    String nomeDestinatario = 'Toda a Turma';
                    IconData iconeDest = Icons.groups_rounded;
                    
                    if (tipo != 'TURMA') {
                      iconeDest = tipo == 'ALUNO' ? Icons.person_rounded : Icons.family_restroom_rounded;
                      final alunoAlvo = alunos.firstWhere((a) => a['id'] == data['alunoId'], orElse: () => {'nome': 'Aluno não encontrado'});
                      nomeDestinatario = (tipo == 'ALUNO' ? 'Aluno: ' : 'Resp. por: ') + (alunoAlvo['nome'] ?? '');
                    }

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(iconeDest, size: 16, color: corPrimaria),
                                const SizedBox(width: 8),
                                Expanded(child: Text(nomeDestinatario, style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria))),
                                Text(dataFormatada, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                            const Divider(height: 16),
                            Text(data['mensagem'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}