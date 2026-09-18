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
import '../../../admin/apresentacao/estado/professor_provider.dart';

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

class DiarioTela extends ConsumerStatefulWidget {
  final String turmaId;

  const DiarioTela({super.key, required this.turmaId});

  @override
  ConsumerState<DiarioTela> createState() => _DiarioTelaState();
}

class _DiarioTelaState extends ConsumerState<DiarioTela> {
  DateTime _dataSelecionada = DateTime.now();
  
  // ==========================================================================
  // ESTADOS GERAIS
  // ==========================================================================
  int _abaAtiva = 0; 
  String _termoPesquisa = ''; 
  bool _carregandoDiario = false;
  String _conteudoAulaAtual = ''; 
  String? _anexoAulaUrl; 
  bool _fazendoUploadAnexo = false; 
  bool _isDiaAvaliacao = false; 
  
  // Média da Escola (Padrão 6.0)
  double _mediaEscola = 6.0;
  
  final Map<String, Map<String, String>> _frequenciaPorData = {};
  final Map<String, String> _statusAulaPorData = {};

  // ==========================================================================
  // ESTADOS AVISOS E NOTAS
  // ==========================================================================
  String _tipoAviso = 'TURMA'; 
  String? _alunoAvisoSelecionado;
  final TextEditingController _mensagemAvisoCtrl = TextEditingController();
  bool _enviandoAviso = false;
  late String _bimestreAtivo;
  
  int _limiteAvisosTurma = 5;

  String get _dataDisplay => "${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}";
  String get _dataBanco => "${_dataSelecionada.year}-${_dataSelecionada.month.toString().padLeft(2, '0')}-${_dataSelecionada.day.toString().padLeft(2, '0')}";
  bool get _isDiaPassado => DateTime(_dataSelecionada.year, _dataSelecionada.month, _dataSelecionada.day).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
  String get _statusAulaHoje => _statusAulaPorData[_dataBanco] ?? 'NAO_INICIADA';

  String _calcularBimestre(DateTime data) {
    int mes = data.month;
    if (mes >= 2 && mes <= 4) {
      return '1º Bimestre';
    }
    if (mes >= 5 && mes <= 6) {
      return '2º Bimestre';
    }
    if (mes >= 7 && mes <= 9) {
      return '3º Bimestre';
    }
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
  // FUNÇÕES DE BANCO DE DADOS E AULA
  // ==========================================================================
  Future<void> _carregarDiarioDoBanco() async {
    final user = ref.read(authProvider).value;
    if (user == null) {
      return;
    }
    setState(() => _carregandoDiario = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('diarios').doc(_dataBanco).get();
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

  Future<void> _salvarAlteracaoNoBanco(Map<String, dynamic> dados) async {
    final user = ref.read(authProvider).value;
    if (user == null) {
      return;
    }
    await FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('diarios').doc(_dataBanco).set(dados, SetOptions(merge: true));
  }

  void _verificarEEncerrarAulaAtualAntesDeMudar() {
    if (_statusAulaHoje == 'EM_ANDAMENTO') {
      _statusAulaPorData[_dataBanco] = 'FINALIZADA';
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
      context: context, initialDate: _dataSelecionada, firstDate: DateTime(2020), lastDate: DateTime(2030),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor, onPrimary: Colors.white)), child: child!),
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aula encerrada!'), backgroundColor: Colors.green));
  }

  void _reabrirAula() {
    setState(() => _statusAulaPorData[_dataBanco] = 'EM_ANDAMENTO');
    _salvarAlteracaoNoBanco({'status': 'EM_ANDAMENTO'});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aula reaberta para edição.'), backgroundColor: Colors.amber));
  }

  void _alternarDiaAvaliacao() {
    setState(() => _isDiaAvaliacao = !_isDiaAvaliacao);
    _salvarAlteracaoNoBanco({'isDiaAvaliacao': _isDiaAvaliacao});
  }

  void _marcarStatusAluno(String matricula, String status) {
    if (_statusAulaHoje != 'EM_ANDAMENTO') {
      return;
    }
    setState(() {
      if (!_frequenciaPorData.containsKey(_dataBanco)) {
        _frequenciaPorData[_dataBanco] = {};
      }
      _frequenciaPorData[_dataBanco]![matricula] = status;
    });
    _salvarAlteracaoNoBanco({'frequencia': _frequenciaPorData[_dataBanco]});
  }

  String _obterStatusAluno(String matricula) {
    if (!_frequenciaPorData.containsKey(_dataBanco)) {
      _frequenciaPorData[_dataBanco] = {};
    }
    return _frequenciaPorData[_dataBanco]![matricula] ?? 'P'; 
  }

  // ==========================================================================
  // COMPONENTES REUTILIZÁVEIS
  // ==========================================================================
  Widget _buildBotaoStatus(String matricula, String sigla, String palavraCompleta, IconData icone, Color cor, String statusAtual) {
    final isSelecionado = statusAtual == sigla;
    final bloqueado = _statusAulaHoje == 'FINALIZADA';
    
    return Expanded(
      child: InkWell(
        onTap: bloqueado ? null : () => _marcarStatusAluno(matricula, sigla),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelecionado ? cor.withAlpha(bloqueado ? 20 : 40) : Colors.transparent, 
            borderRadius: BorderRadius.circular(8)
          ),
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
  // CÂMERA E DIÁRIO DE SALA
  // ==========================================================================
  Future<void> _capturarEEnviarFoto(StateSetter setModalState) async {
    try {
      final picker = ImagePicker();
      final XFile? foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (foto == null) {
        return; 
      }

      setModalState(() => _fazendoUploadAnexo = true);
      setState(() => _fazendoUploadAnexo = true);

      final user = ref.read(authProvider).value;
      if (user == null) {
        return;
      }
      final nomeArquivo = 'anexo_aula_$_dataBanco-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final refStorage = FirebaseStorage.instance.ref('tenants/${user.id}/turmas/${widget.turmaId}/diarios/$nomeArquivo');

      await refStorage.putFile(File(foto.path));
      final url = await refStorage.getDownloadURL();

      setModalState(() { _anexoAulaUrl = url; _fazendoUploadAnexo = false; });
      setState(() { _anexoAulaUrl = url; _fazendoUploadAnexo = false; });
      await _salvarAlteracaoNoBanco({'anexoUrl': url});
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto anexada!'), backgroundColor: Colors.green));
    } catch (e) {
      setModalState(() => _fazendoUploadAnexo = false);
      setState(() => _fazendoUploadAnexo = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  void _removerFotoAnexada(StateSetter setModalState) {
    setModalState(() => _anexoAulaUrl = null);
    setState(() => _anexoAulaUrl = null);
    _salvarAlteracaoNoBanco({'anexoUrl': FieldValue.delete()});
  }

  // ==========================================================================
  // CONFIGURAÇÃO DA MÉDIA ESCOLAR
  // ==========================================================================
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
            const Text('Defina a nota média para aprovação. O sistema fará os cálculos baseados neste valor.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              setState(() {
                _mediaEscola = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 6.0;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          )
        ],
      )
    );
  }

  // ==========================================================================
  // ESTATÍSTICAS, SUBSTITUIÇÃO DE NOTAS E POPUP ALUNO (RAIO-X)
  // ==========================================================================
  void _mostrarDetalhesFrequencia(String nomeAluno, List<Map<String, String>> frequenciaMes, Color corPrimaria) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Frequência do Mês', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold)),
            Text(nomeAluno, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
        content: frequenciaMes.isEmpty
            ? const Text('Nenhuma aula registrada neste mês.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: frequenciaMes.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final f = frequenciaMes[index];
                    final status = f['status'];
                    
                    Color corStatus = Colors.green;
                    String textoStatus = 'Presente';
                    IconData iconeStatus = Icons.check_circle_rounded;

                    if (status == 'A') {
                      corStatus = Colors.red;
                      textoStatus = 'Falta';
                      iconeStatus = Icons.cancel_rounded;
                    } else if (status == 'J') {
                      corStatus = Colors.orange;
                      textoStatus = 'Justificada';
                      iconeStatus = Icons.info_rounded;
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event_available_rounded, color: Colors.grey.shade400),
                      title: Text(f['data'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                        decoration: BoxDecoration(color: corStatus.withAlpha(30), borderRadius: BorderRadius.circular(8)), 
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(iconeStatus, color: corStatus, size: 14),
                            const SizedBox(width: 4),
                            Text(textoStatus, style: TextStyle(color: corStatus, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ),
                    );
                  },
                ),
              ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ),
    );
  }

  void _mostrarHistoricoNotas(String nomeAluno, List notas, Color corPrimaria) {
    double totalPontos = 0.0;
    double notasAlcancadas = 0.0;
    
    for (var n in notas) {
      if (n['validaParaMedia'] == true) {
        totalPontos += (n['maxima'] as num).toDouble();
        notasAlcancadas += (n['nota'] as num).toDouble();
      }
    }
    double aproveitamento = totalPontos > 0 ? (notasAlcancadas / totalPontos) * 10 : 0.0;
    bool alunoAprovado = aproveitamento >= _mediaEscola;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histórico de Notas', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold)),
            Text(nomeAluno, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
        content: notas.isEmpty
            ? const Text('Nenhuma nota lançada para este aluno.')
            : SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: alunoAprovado ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: alunoAprovado ? Colors.green.shade200 : Colors.red.shade200)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('Média Alcançada', style: TextStyle(fontSize: 10, color: alunoAprovado ? Colors.green.shade800 : Colors.red.shade800)),
                              Text(aproveitamento.toStringAsFixed(1), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: alunoAprovado ? Colors.green.shade800 : Colors.red.shade800)),
                            ],
                          ),
                          Container(width: 1, height: 30, color: alunoAprovado ? Colors.green.shade200 : Colors.red.shade200),
                          Column(
                            children: [
                              Text('Soma dos Pontos', style: TextStyle(fontSize: 10, color: alunoAprovado ? Colors.green.shade800 : Colors.red.shade800)),
                              Text('${notasAlcancadas.toStringAsFixed(1)} / ${totalPontos.toStringAsFixed(1)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: alunoAprovado ? Colors.green.shade800 : Colors.red.shade800)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: notas.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final n = notas[index];
                          final double valorNota = (n['nota'] as num).toDouble();
                          final double valorMax = (n['maxima'] as num).toDouble();
                          
                          bool isValida = n['validaParaMedia'] == true;
                          bool isRecuperacao = n['isRecuperacao'] == true;

                          String subTexto = n['bimestre'];
                          if (!isValida && !isRecuperacao) {
                            subTexto += ' • (Substituída)';
                          }
                          if (!isValida && isRecuperacao) {
                            subTexto += ' • (Descartada)';
                          }
                          if (isValida && isRecuperacao) {
                            subTexto += ' • (Nota Substituta)';
                          }

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isValida ? Colors.green.shade50 : Colors.grey.shade200, 
                              child: Icon(isValida ? Icons.check_rounded : Icons.block_rounded, color: isValida ? Colors.green : Colors.grey)
                            ),
                            title: Text(n['nome'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, decoration: isValida ? TextDecoration.none : TextDecoration.lineThrough, color: isValida ? Colors.black : Colors.grey)),
                            subtitle: Text(subTexto, style: TextStyle(color: isValida && isRecuperacao ? Colors.purple.shade700 : Colors.grey.shade600, fontSize: 12, fontWeight: isValida && isRecuperacao ? FontWeight.bold : FontWeight.normal)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                              decoration: BoxDecoration(color: isValida ? Colors.green.shade600 : Colors.grey.shade400, borderRadius: BorderRadius.circular(8)), 
                              child: Text('${valorNota.toStringAsFixed(1)} / ${valorMax.toStringAsFixed(1)}', style: TextStyle(color: isValida ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, decoration: isValida ? TextDecoration.none : TextDecoration.lineThrough))
                            ),
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ),
    );
  }

  void _abrirDialogMensagemDireta(Map<String, dynamic> aluno, Color corPrimaria) {
    final ctrlTexto = TextEditingController();
    bool enviando = false;
    final nomeAluno = aluno['nome'] ?? 'Aluno';
    final alunoIdSeguro = (aluno['id'] ?? aluno['matricula'] ?? aluno['nome']).toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.send_rounded, color: corPrimaria),
              const SizedBox(width: 8),
              Expanded(child: Text('Aviso para $nomeAluno', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: TextField(
            controller: ctrlTexto, maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Digite a mensagem direta aqui...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.grey.shade50,
            ),
          ),
          actions: [
            TextButton(onPressed: enviando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: enviando ? null : () async {
                if (ctrlTexto.text.trim().isEmpty) {
                  return;
                }
                setDialogState(() => enviando = true);
                try {
                  final user = ref.read(authProvider).value;
                  final professores = ref.read(professoresStreamProvider).value ?? [];
                  
                  if (user != null) {
                    
                    // INTELIGÊNCIA DE NOMES
                    String remetenteNome = 'Usuário Desconhecido';
                    String remetenteId = user.id;

                    final p = professores.firstWhere((prof) {
                      final pid = prof['id']?.toString().trim();
                      final uid = prof['uid']?.toString().trim();
                      final authUid = prof['authUid']?.toString().trim();
                      return (pid == user.id && pid != null) || 
                             (uid == user.id && uid != null) || 
                             (authUid == user.id && authUid != null);
                    }, orElse: () => {});

                    if (p.isNotEmpty) {
                      remetenteNome = 'Professor(a) - ${p['nome']}';
                      if (p['id'] != null) remetenteId = p['id'].toString();
                    }

                    await FirebaseFirestore.instance
                        .collection('tenants').doc(user.id)
                        .collection('turmas').doc(widget.turmaId)
                        .collection('avisos')
                        .add({
                          'tipoDestinatario': 'ALUNO',
                          'alunoId': alunoIdSeguro,
                          'mensagem': ctrlTexto.text.trim(),
                          'dataEnvio': FieldValue.serverTimestamp(),
                          'remetenteId': remetenteId,
                          'remetenteNome': remetenteNome,
                        });
                    
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aviso enviado com sucesso!'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => enviando = false);
                  }
                }
              },
              child: enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enviar'),
            )
          ],
        ),
      ),
    );
  }

  void _abrirHistoricoCompletoAvisos(String alunoIdSeguro, String nomeAluno, Color corPrimaria) {
    final user = ref.read(authProvider).value;
    if (user == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.history_edu_rounded, color: corPrimaria)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Histórico Completo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Mensagens para $nomeAluno', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('avisos')
                        .where('alunoId', isEqualTo: alunoIdSeguro)
                        .snapshots(),
                builder: (context, snapAvisos) {
                  if (snapAvisos.connectionState == ConnectionState.waiting && !snapAvisos.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var docs = snapAvisos.data?.docs.toList() ?? [];
                  if (docs.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.speaker_notes_off_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Nenhum aviso no histórico.', style: TextStyle(color: Colors.grey.shade500))]));
                  }
                  
                  docs.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final timeA = dataA['dataEnvio'];
                    final timeB = dataB['dataEnvio'];
                    if (timeA == null && timeB == null) {
                      return 0;
                    }
                    if (timeA == null) {
                      return 1;
                    }
                    if (timeB == null) {
                      return -1;
                    }
                    return (timeB as dynamic).compareTo(timeA as dynamic);
                  });

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16), itemCount: docs.length, 
                    separatorBuilder: (context, index) => const SizedBox(height: 12), 
                    itemBuilder: (context, index) {
                      final a = docs[index].data() as Map<String, dynamic>;
                      final dataEnvio = a['dataEnvio'];
                      final textoData = dataEnvio != null ? DateFormat('dd/MM/yyyy HH:mm').format((dataEnvio as dynamic).toDate()) : '';
                      
                      return Card(
                        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Row(
                                  children: [
                                    Icon(Icons.send_rounded, size: 16, color: corPrimaria),
                                    const SizedBox(width: 8),
                                    Text('Mensagem Direta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corPrimaria)),
                                  ],
                                ), 
                                Text(textoData, style: const TextStyle(fontSize: 11, color: Colors.grey))
                              ]),
                              const Divider(height: 16), 
                              Text(a['mensagem'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                            ],
                          ),
                        ),
                      );
                    }
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _buscarEstatisticasAluno(Map<String, dynamic> aluno) async {
    final user = ref.read(authProvider).value;
    if (user == null) {
      return {};
    }

    final matricula = (aluno['matricula'] ?? '').toString();
    final alunoIdSeguro = (aluno['id'] ?? aluno['matricula'] ?? aluno['nome']).toString();
    
    List<Map<String, String>> frequenciaMes = [];
    List<Map<String, dynamic>> notasList = [];
    String prefixoMes = "${_dataSelecionada.year}-${_dataSelecionada.month.toString().padLeft(2, '0')}";

    try {
      List<Map<String, dynamic>> freqRaw = [];
      final diariosSnap = await FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('diarios').get();
      for (var doc in diariosSnap.docs) {
        final data = doc.data();
        if (data['status'] != 'NAO_INICIADA' && doc.id.startsWith(prefixoMes)) {
           final freq = Map<String, String>.from(data['frequencia'] ?? {});
           final st = freq[matricula] ?? 'P';
           freqRaw.add({'docId': doc.id, 'status': st});
        }
      }
      
      freqRaw.sort((a,b) => b['docId'].compareTo(a['docId'])); 
      
      frequenciaMes = freqRaw.map((e) {
          final p = e['docId'].split('-');
          return { 'data': "${p[2]}/${p[1]}/${p[0]}", 'status': e['status'] as String };
      }).toList();

      final avaliacoesSnap = await FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('avaliacoes').get();
      final avaliacoes = avaliacoesSnap.docs;
      
      avaliacoes.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();
        final timeA = dataA['dataCriacao'];
        final timeB = dataB['dataCriacao'];
        if (timeA == null && timeB == null) {
          return 0;
        }
        if (timeA == null) {
          return 1;
        }
        if (timeB == null) {
          return -1;
        }
        return (timeB as dynamic).compareTo(timeA as dynamic);
      });

      Map<String, List<Map<String, dynamic>>> agrupadoPorBimestre = {};

      for (var doc in avaliacoes) {
        final data = doc.data();
        final notas = Map<String, dynamic>.from(data['notas'] ?? {});
        if (notas.containsKey(matricula)) {
          final item = {
            'nome': data['nome'] ?? 'Avaliação', 
            'bimestre': data['bimestre'] ?? '', 
            'nota': notas[matricula], 
            'maxima': data['pontuacaoMaxima'] ?? 10.0,
            'isRecuperacao': data['isRecuperacao'] ?? false,
            'validaParaMedia': true,
          };
          agrupadoPorBimestre.putIfAbsent(item['bimestre'], () => []).add(item);
        }
      }

      for (var bim in agrupadoPorBimestre.keys) {
        var notasBimestre = agrupadoPorBimestre[bim]!;
        var recuperacoes = notasBimestre.where((n) => n['isRecuperacao'] == true).toList();
        var normais = notasBimestre.where((n) => n['isRecuperacao'] != true).toList();

        for (var rec in recuperacoes) {
          if (normais.isEmpty) {
            continue;
          }
          
          normais.sort((a, b) => ((a['nota'] / a['maxima']).compareTo(b['nota'] / b['maxima'])));
          var piorNormal = normais.first;

          double aproveitamentoRec = rec['nota'] / rec['maxima'];
          double aproveitamentoPiorNormal = piorNormal['nota'] / piorNormal['maxima'];

          if (aproveitamentoRec > aproveitamentoPiorNormal) {
            piorNormal['validaParaMedia'] = false; 
          } else {
            rec['validaParaMedia'] = false; 
          }
        }
        notasList.addAll(notasBimestre);
      }

      notasList.sort((a, b) => a['bimestre'].compareTo(b['bimestre']));

    } catch (e) {
      debugPrint('Erro stat: $e');
    }

    return { 'frequenciaMes': frequenciaMes, 'notas': notasList, 'alunoIdSeguro': alunoIdSeguro };
  }

  void _abrirPopupResumoAluno(Map<String, dynamic> aluno, Color corPrimaria) {
    final matricula = (aluno['matricula'] ?? '').toString();
    final nomeAluno = aluno['nome'] ?? 'Sem nome';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (sheetContext, scrollController) => FutureBuilder<Map<String, dynamic>>(
          future: _buscarEstatisticasAluno(aluno),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final stats = snapshot.data ?? {};
            
            final List<Map<String, String>> frequenciaMes = stats['frequenciaMes'] ?? [];
            final int aulasMes = frequenciaMes.length;
            final int faltasInjustificadas = frequenciaMes.where((f) => f['status'] == 'A').length;
            final int faltasJustificadas = frequenciaMes.where((f) => f['status'] == 'J').length;
            final int totalFaltas = faltasInjustificadas + faltasJustificadas;
            
            String textoResumoFaltas = totalFaltas == 0 
                ? 'Nenhuma falta registrada' 
                : '$totalFaltas falta(s) (sendo $faltasJustificadas justificada(s))';

            final List notas = stats['notas'] ?? [];
            final String alunoIdSeguro = stats['alunoIdSeguro'] ?? '';
            final user = ref.read(authProvider).value;

            return ListView(
              controller: scrollController, padding: EdgeInsets.zero,
              children: [
                Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 30, backgroundColor: corPrimaria.withAlpha(30), backgroundImage: aluno['fotoUrl'] != null ? NetworkImage(aluno['fotoUrl']) : null, child: aluno['fotoUrl'] == null ? Icon(Icons.person, color: corPrimaria, size: 30) : null),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nomeAluno, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 2),
                        Text('Matrícula: $matricula', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ])),
                      Container(
                        decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(Icons.chat_rounded, color: Colors.blue.shade700),
                          tooltip: 'Enviar Mensagem',
                          onPressed: () => _abrirDialogMensagemDireta(aluno, corPrimaria),
                        ),
                      )
                    ],
                  ),
                ),
                
                const Divider(),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: InkWell(
                    onTap: () => _mostrarDetalhesFrequencia(nomeAluno, frequenciaMes, corPrimaria),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200)
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: Colors.blue.shade700, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$aulasMes aulas registradas no mês', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue.shade900)),
                                const SizedBox(height: 4),
                                Text(textoResumoFaltas, style: TextStyle(color: Colors.blue.shade800, fontSize: 13)),
                              ]
                            )
                          ),
                          Icon(Icons.chevron_right_rounded, color: Colors.blue.shade300)
                        ]
                      )
                    )
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300)
                    ),
                    onPressed: () => _mostrarHistoricoNotas(nomeAluno, notas, corPrimaria),
                    icon: Icon(Icons.grading_rounded, color: corPrimaria),
                    label: Text('Ver Histórico de Notas', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 16),
                
                Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), color: Colors.grey.shade50, child: const Text('Últimos Avisos Enviados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54))),
                if (user != null && alunoIdSeguro.isNotEmpty)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('avisos')
                            .where('alunoId', isEqualTo: alunoIdSeguro)
                            .snapshots(),
                    builder: (context, snapAvisos) {
                      if (snapAvisos.connectionState == ConnectionState.waiting && !snapAvisos.hasData) {
                        return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                      }
                      var docs = snapAvisos.data?.docs.toList() ?? [];
                      if (docs.isEmpty) {
                        return Padding(padding: const EdgeInsets.all(24), child: Center(child: Column(children: [Icon(Icons.speaker_notes_off_outlined, size: 40, color: Colors.grey.shade300), const SizedBox(height: 8), Text('Nenhuma mensagem direta.', style: TextStyle(color: Colors.grey.shade500))])));
                      }
                      
                      docs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        final timeA = dataA['dataEnvio'];
                        final timeB = dataB['dataEnvio'];
                        if (timeA == null && timeB == null) {
                          return 0;
                        }
                        if (timeA == null) {
                          return 1;
                        }
                        if (timeB == null) {
                          return -1;
                        }
                        return (timeB as dynamic).compareTo(timeA as dynamic);
                      });
                      var avisosRecentes = docs.take(3).toList(); 

                      return Column(
                        children: [
                          ListView.separated(
                            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.all(16), itemCount: avisosRecentes.length, 
                            separatorBuilder: (context, index) => const SizedBox(height: 8), 
                            itemBuilder: (context, index) {
                              final a = avisosRecentes[index].data() as Map<String, dynamic>;
                              final dataEnvio = a['dataEnvio'];
                              final textoData = dataEnvio != null ? DateFormat('dd/MM HH:mm').format((dataEnvio as dynamic).toDate()) : '';
                              return Card(
                                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Mensagem Direta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corPrimaria)), Text(textoData, style: const TextStyle(fontSize: 10, color: Colors.grey))]),
                                      const SizedBox(height: 6), Text(a['mensagem'] ?? '', style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                              );
                            }
                          ),
                          if (docs.length > 3)
                            TextButton.icon(
                              onPressed: () => _abrirHistoricoCompletoAvisos(alunoIdSeguro, nomeAluno, corPrimaria), 
                              icon: const Icon(Icons.history_rounded, size: 18), 
                              label: const Text('Ver todo o histórico de mensagens', style: TextStyle(fontWeight: FontWeight.bold))
                            ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                  ),
                const SizedBox(height: 40),
              ],
            );
          }
        ),
      ),
    );
  }

  // ==========================================================================
  // MODAIS E LÓGICA DE AVALIAÇÕES GERAIS DA TURMA
  // ==========================================================================
  
  void _excluirAvaliacao(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Excluir Avaliação'),
          ],
        ),
        content: const Text('Tem certeza que deseja excluir esta avaliação e TODAS as notas lançadas nela?\n\nEssa ação não poderá ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final user = ref.read(authProvider).value;
              if (user != null) {
                await FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('avaliacoes').doc(id).delete();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avaliação excluída com sucesso!'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Sim, Excluir'),
          )
        ]
      )
    );
  }

  void _abrirModalEditarAvaliacao(Map<String, dynamic> avaliacao, String avaliacaoId, Color corPrimaria) {
    final ctrlNome = TextEditingController(text: avaliacao['nome']);
    final ctrlPontos = TextEditingController(text: avaliacao['pontuacaoMaxima'].toString());
    bool salvando = false;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [Icon(Icons.edit_rounded, color: corPrimaria), const SizedBox(width: 8), const Text('Editar Avaliação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
          content: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: ctrlNome, decoration: InputDecoration(labelText: 'Nome da Avaliação', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)), const SizedBox(height: 16),
              TextField(controller: ctrlPontos, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Pontuação Máxima', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)),
            ],
          ),
          actions: [
            TextButton(onPressed: salvando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: salvando ? null : () async {
                if (ctrlNome.text.trim().isEmpty) {
                  return;
                }
                setModalState(() => salvando = true);
                final user = ref.read(authProvider).value;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('avaliacoes').doc(avaliacaoId).update({
                    'nome': ctrlNome.text.trim(),
                    'pontuacaoMaxima': double.tryParse(ctrlPontos.text.replaceAll(',', '.')) ?? 10.0,
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avaliação atualizada!'), backgroundColor: Colors.green));
                }
              },
              child: salvando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salvar'),
            )
          ],
        )
      ),
    );
  }

  void _abrirModalNovaAvaliacao(Color corPrimaria, List<Map<String, dynamic>> alunosTurma) {
    final ctrlNome = TextEditingController();
    final ctrlPontos = TextEditingController(text: '10.0');
    bool salvando = false;
    
    bool isSegundaChamada = false;
    bool isRecuperacao = false;
    List<String> alunosSelecionados = [];

    final bimestreAlvo = _abaAtiva == 1 ? _bimestreAtivo : _calcularBimestre(_dataSelecionada);

    showDialog(
      context: context, barrierDismissible: false,
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
                  TextField(controller: ctrlNome, decoration: InputDecoration(labelText: 'Nome da Avaliação', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)), const SizedBox(height: 16),
                  TextField(controller: ctrlPontos, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Pontuação Máxima', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)),
                  
                  const Divider(height: 32),
                  
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('É uma prova de Recuperação?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Substitui automaticamente a menor nota do bimestre.', style: TextStyle(fontSize: 11)),
                    value: isRecuperacao,
                    activeThumbColor: Colors.purple,
                    onChanged: (val) {
                      setModalState(() {
                        isRecuperacao = val;
                      });
                    },
                  ),
                  
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('É uma prova de 2ª Chamada?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Apenas os alunos selecionados receberão nota.', style: TextStyle(fontSize: 11)),
                    value: isSegundaChamada,
                    activeThumbColor: Colors.blue,
                    onChanged: (val) {
                      setModalState(() {
                        isSegundaChamada = val;
                      });
                    },
                  ),

                  if (isSegundaChamada)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: ListView(
                        shrinkWrap: true,
                        children: alunosTurma.map((a) {
                          final mat = (a['matricula'] ?? '').toString();
                          return CheckboxListTile(
                            dense: true,
                            title: Text(a['nome'] ?? ''),
                            value: alunosSelecionados.contains(mat),
                            onChanged: (bool? checked) {
                              setModalState(() {
                                if (checked == true) {
                                  alunosSelecionados.add(mat);
                                } else {
                                  alunosSelecionados.remove(mat);
                                }
                              });
                            }
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
              onPressed: salvando ? null : () async {
                if (ctrlNome.text.trim().isEmpty) {
                  return;
                }
                setModalState(() => salvando = true);
                final user = ref.read(authProvider).value;
                if (user != null) {
                  List<String> ausentes = alunosTurma.where((a) => _obterStatusAluno((a['matricula'] ?? '').toString()) == 'A').map((a) => (a['matricula'] ?? '').toString()).toList();
                  
                  final novaAvaliacao = {
                    'nome': ctrlNome.text.trim(), 
                    'pontuacaoMaxima': double.tryParse(ctrlPontos.text.replaceAll(',', '.')) ?? 10.0, 
                    'bimestre': bimestreAlvo, 
                    'dataAvaliacao': _dataBanco, 
                    'dataCriacao': FieldValue.serverTimestamp(), 
                    'matriculasAusentes': ausentes, 
                    'notas': {},
                    'isSegundaChamada': isSegundaChamada,
                    'alunosPermitidos': isSegundaChamada ? alunosSelecionados : [],
                    'isRecuperacao': isRecuperacao,
                  };

                  final docRef = await FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('avaliacoes').add(novaAvaliacao);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx); 
                  if (!mounted) return;
                  setState(() { _abaAtiva = 1; _bimestreAtivo = bimestreAlvo; });
                  _abrirModalLancarNotas(novaAvaliacao, docRef.id, alunosTurma, corPrimaria);
                }
              },
              child: salvando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Criar e Lançar', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        )
      ),
    );
  }

  void _abrirModalLancarNotas(Map<String, dynamic> avaliacao, String avaliacaoId, List<Map<String, dynamic>> alunosTurmaOriginal, Color corPrimaria) {
    final Map<String, TextEditingController> controladores = {};
    final notasAtuais = Map<String, dynamic>.from(avaliacao['notas'] ?? {});
    final pontuacaoMaxima = (avaliacao['pontuacaoMaxima'] ?? 10.0) as double;
    final List ausentes = avaliacao['matriculasAusentes'] ?? [];
    
    final bool isSegundaChamada = avaliacao['isSegundaChamada'] ?? false;
    final List permitidos = avaliacao['alunosPermitidos'] ?? [];

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
          double soma = 0.0;
          int qtdValidas = 0;
          controladores.forEach((mat, ctrl) {
            if (ctrl.text.trim().isNotEmpty) {
              soma += double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
              qtdValidas++;
            }
          });
          double mediaDaTurma = qtdValidas > 0 ? soma / qtdValidas : 0.0;
          double mediaEsperada = (pontuacaoMaxima / 10.0) * _mediaEscola;
          bool turmaBem = mediaDaTurma >= mediaEsperada;

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
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.edit_note_rounded, color: corPrimaria)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(avaliacao['nome'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('Max: $pontuacaoMaxima pts | Média Escolar: ${_mediaEscola.toStringAsFixed(1)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    color: turmaBem ? Colors.green.shade50 : Colors.red.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Média atual da Turma:', style: TextStyle(fontWeight: FontWeight.bold, color: turmaBem ? Colors.green.shade800 : Colors.red.shade800)),
                        Text('${mediaDaTurma.toStringAsFixed(1)} / $pontuacaoMaxima', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: turmaBem ? Colors.green.shade800 : Colors.red.shade800)),
                      ],
                    ),
                  ),

                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController, padding: const EdgeInsets.all(16), itemCount: alunosParaAvaliar.length, 
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final aluno = alunosParaAvaliar[index];
                        final matricula = (aluno['matricula'] ?? '').toString();
                        final faltou = ausentes.contains(matricula); 
                        return Card(
                          elevation: 0, color: faltou ? Colors.red.shade50.withAlpha(100) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: faltou ? Colors.red.shade200 : Colors.grey.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 18, backgroundColor: corPrimaria.withAlpha(30), backgroundImage: aluno['fotoUrl'] != null ? NetworkImage(aluno['fotoUrl']) : null, child: aluno['fotoUrl'] == null ? Icon(Icons.person, color: corPrimaria, size: 20) : null), const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(aluno['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), if (faltou) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text('Faltou neste dia', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))])),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 80, 
                                  child: TextField(
                                    controller: controladores[matricula], 
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                                    textAlign: TextAlign.center, 
                                    decoration: InputDecoration(hintText: '-', contentPadding: const EdgeInsets.symmetric(vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.white),
                                    onChanged: (val) {
                                      setModalState(() {});
                                    },
                                  )
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
                            if (user == null) {
                              return;
                            }
                            final Map<String, double> notasFinais = {};
                            controladores.forEach((mat, ctrl) { if (ctrl.text.trim().isNotEmpty) notasFinais[mat] = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0; });
                            
                            final notasParaSalvar = Map<String, dynamic>.from(notasAtuais);
                            notasFinais.forEach((k, v) { notasParaSalvar[k] = v; });

                            await FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('avaliacoes').doc(avaliacaoId).update({'notas': notasParaSalvar});
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notas salvas com sucesso!'), backgroundColor: Colors.green));
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
        }
      ),
    );
  }

  void _abrirModalPreencherDiario() {
    final ctrl = TextEditingController(text: _conteudoAulaAtual);
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder( 
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [Icon(Icons.edit_note_rounded, color: Theme.of(context).primaryColor), const SizedBox(width: 8), const Text('Diário de Sala', style: TextStyle(fontWeight: FontWeight.bold))]),
          content: SizedBox(
            width: 500, 
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: ctrl, maxLines: 4, decoration: InputDecoration(hintText: 'Conteúdo lecionado...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)), const SizedBox(height: 16), const Divider(), const SizedBox(height: 8),
                  if (_fazendoUploadAnexo) Container(padding: const EdgeInsets.all(24), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Column(children: [CircularProgressIndicator(color: Theme.of(context).primaryColor), const SizedBox(height: 12), const Text('Enviando foto...', style: TextStyle(color: Colors.grey))]))
                  else if (_anexoAulaUrl != null) Stack(alignment: Alignment.topRight, children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_anexoAulaUrl!, fit: BoxFit.cover, width: double.infinity, height: 200)), Padding(padding: const EdgeInsets.all(8.0), child: CircleAvatar(backgroundColor: Colors.redAccent, child: IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 20), onPressed: () => _removerFotoAnexada(setModalState))))])
                  else OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Theme.of(context).primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => _capturarEEnviarFoto(setModalState), icon: Icon(Icons.camera_alt_rounded, color: Theme.of(context).primaryColor), label: Text('Tirar Foto do Quadro', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async { 
                setState(() => _conteudoAulaAtual = ctrl.text.trim()); 
                await _salvarAlteracaoNoBanco({'conteudo': _conteudoAulaAtual}); 
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.save_rounded, size: 18), label: const Text('Salvar Diário', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        )
      ),
    );
  }

  // INTELIGÊNCIA REFATORADA AQUI: ENVIAR AVISO DO PROFESSOR CORRETAMENTE
  Future<void> _enviarAvisoFirebase() async {
    if (_tipoAviso != 'TURMA' && _alunoAvisoSelecionado == null) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um aluno.'), backgroundColor: Colors.red)); 
      return; 
    }
    if (_mensagemAvisoCtrl.text.trim().isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A mensagem não pode estar vazia.'), backgroundColor: Colors.red)); 
      return; 
    }
    
    setState(() => _enviandoAviso = true);
    try {
      final user = ref.read(authProvider).value;
      if (user != null) {
        
        // NOVO: Puxando o nome e o ID VERDADEIRO do professor que está logado
        String remetenteNome = 'Usuário Desconhecido';
        String remetenteId = user.id;

        final listaProfs = ref.read(professoresStreamProvider).value ?? [];
        final profData = listaProfs.firstWhere((p) {
          final pid = p['id']?.toString().trim();
          final uid = p['uid']?.toString().trim();
          final authUid = p['authUid']?.toString().trim();
          // O Cérebro verifica quem está logado comparando todas as chaves possíveis
          return (pid == user.id && pid != null) || 
                 (uid == user.id && uid != null) || 
                 (authUid == user.id && authUid != null);
        }, orElse: () => {});

        if (profData.isNotEmpty) {
          remetenteNome = 'Professor(a) - ${profData['nome']}';
          // Garante que enviamos o ID de Professor (Ex: PROF-05) e não da conta base!
          remetenteId = (profData['id'] ?? user.id).toString(); 
        }

        await FirebaseFirestore.instance
            .collection('tenants').doc(user.id)
            .collection('turmas').doc(widget.turmaId)
            .collection('avisos')
            .add({
              'tipoDestinatario': _tipoAviso, 
              'alunoId': _tipoAviso == 'TURMA' ? null : _alunoAvisoSelecionado, 
              'mensagem': _mensagemAvisoCtrl.text.trim(), 
              'dataEnvio': FieldValue.serverTimestamp(), 
              'remetenteId': remetenteId, // Agora salva o ID certo do prof
              'remetenteNome': remetenteNome, // E já deixa o nome pronto!
            });
            
        if (context.mounted) { 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aviso enviado!'), backgroundColor: Colors.green)); 
          _mensagemAvisoCtrl.clear(); 
          setState(() { 
            _alunoAvisoSelecionado = null; 
            _tipoAviso = 'TURMA'; 
          }); 
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red)); 
      }
    } finally {
      if (mounted) {
        setState(() => _enviandoAviso = false);
      }
    }
  }

  // ==========================================================================
  // WIDGETS E ABAS SECUNDÁRIAS
  // ==========================================================================
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
    if (_statusAulaHoje == 'NAO_INICIADA') return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.pending_actions_rounded, size: 64, color: Colors.grey.shade400), const SizedBox(height: 16), const Text('Aula Não Iniciada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Data: $_dataDisplay', style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: 24), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)), onPressed: _iniciarAula, icon: const Icon(Icons.play_arrow_rounded), label: const Text('INICIAR AULA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]));
    if (alunos.isEmpty) return Center(child: Text('Nenhum aluno encontrado.', style: TextStyle(color: Colors.grey.shade600)));

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
                GestureDetector(onTap: () => _mostrarFotoAmpliadaGlobal(context, aluno['fotoUrl']), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Container(width: 54, height: 72, color: corPrimaria.withAlpha(30), child: aluno['fotoUrl'] != null ? Image.network(aluno['fotoUrl'], fit: BoxFit.cover) : Icon(Icons.person, color: corPrimaria, size: 28)))),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(onTap: () => _abrirPopupResumoAluno(aluno, corPrimaria), borderRadius: BorderRadius.circular(4), child: Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: Text(aluno['nome'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corPrimaria, decoration: TextDecoration.underline, decorationColor: corPrimaria.withAlpha(100)), maxLines: 2)), Icon(Icons.analytics_outlined, size: 16, color: corPrimaria.withAlpha(150))]))),
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
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAbaNotas(List<Map<String, dynamic>> alunosTurma, Color corPrimaria) {
    final user = ref.watch(authProvider).value;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<String>(
            segments: const [ButtonSegment(value: '1º Bimestre', label: Text('1º Bim')), ButtonSegment(value: '2º Bimestre', label: Text('2º Bim')), ButtonSegment(value: '3º Bimestre', label: Text('3º Bim')), ButtonSegment(value: '4º Bimestre', label: Text('4º Bim'))],
            selected: {_bimestreAtivo}, onSelectionChanged: (s) => setState(() => _bimestreAtivo = s.first),
            style: SegmentedButton.styleFrom(selectedBackgroundColor: corPrimaria.withAlpha(40), selectedForegroundColor: corPrimaria),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), 
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: corPrimaria, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                  onPressed: () => _abrirModalNovaAvaliacao(corPrimaria, alunosTurma), 
                  icon: Icon(Icons.add_rounded, color: corPrimaria), 
                  label: Text('Criar Nova Avaliação', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold))
                )
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _abrirConfigMediaEscola(corPrimaria),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Média', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      Text(_mediaEscola.toStringAsFixed(1), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: corPrimaria)),
                    ],
                  ),
                ),
              )
            ]
          )
        ),

        const SizedBox(height: 16),
        Expanded(
          child: user == null ? const Center(child: CircularProgressIndicator()) : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('avaliacoes').where('bimestre', isEqualTo: _bimestreAtivo).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data?.docs.toList() ?? [];
              if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Nenhuma avaliação', style: TextStyle(fontSize: 16, color: Colors.grey.shade600))]));
              
              docs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;
                final timeA = dataA['dataCriacao'];
                final timeB = dataB['dataCriacao'];
                if (timeA == null && timeB == null) {
                  return 0;
                }
                if (timeA == null) {
                  return 1;
                }
                if (timeB == null) {
                  return -1;
                }
                return (timeB as dynamic).compareTo(timeA as dynamic);
              });

              return ListView.separated(
                padding: const EdgeInsets.all(16).copyWith(bottom: 100), itemCount: docs.length, 
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final avaliacao = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  final notasMap = Map<String, dynamic>.from(avaliacao['notas'] ?? {});
                  
                  int totalEsperado = avaliacao['isSegundaChamada'] == true 
                       ? (avaliacao['alunosPermitidos'] as List).length 
                       : alunosTurma.length;

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
                                  Text(avaliacao['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                                  if (avaliacao['isSegundaChamada'] == true) 
                                    Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)), child: Text('2ª Chamada', style: TextStyle(fontSize: 10, color: Colors.blue.shade800))),
                                  if (avaliacao['isRecuperacao'] == true) 
                                    Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(4)), child: Text('Recuperação', style: TextStyle(fontSize: 10, color: Colors.purple.shade800))),
                                  const SizedBox(height: 4), 
                                  Text('Max: ${avaliacao['pontuacaoMaxima']} pts', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
                                ]
                              )
                            ), 
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end, 
                              children: [
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: notasMap.length == totalEsperado ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: Text('${notasMap.length} / $totalEsperado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: notasMap.length == totalEsperado ? Colors.green.shade700 : Colors.orange.shade700))), 
                                const SizedBox(height: 4), 
                                const Text('Lançadas', style: TextStyle(fontSize: 10, color: Colors.grey))
                              ]
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              onSelected: (val) {
                                if (val == 'editar') {
                                  _abrirModalEditarAvaliacao(avaliacao, id, corPrimaria);
                                }
                                if (val == 'excluir') {
                                  _excluirAvaliacao(id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Editar')])),
                                const PopupMenuItem(value: 'excluir', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('Excluir', style: TextStyle(color: Colors.red))])),
                              ],
                            )
                          ]
                        )
                      )
                    )
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAbaAvisos(List<Map<String, dynamic>> alunos, Color corPrimaria) {
    final user = ref.watch(authProvider).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24).copyWith(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.campaign_rounded, color: corPrimaria)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Enviar Novo Aviso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('Comunique-se com a turma ou responsáveis.', style: TextStyle(color: Colors.grey))]))]),
                  const SizedBox(height: 24), const Text('Enviar para:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                  SegmentedButton<String>(segments: const [ButtonSegment(value: 'TURMA', label: Text('Toda a Turma', style: TextStyle(fontSize: 12))), ButtonSegment(value: 'ALUNO', label: Text('Aluno Específico', style: TextStyle(fontSize: 12))), ButtonSegment(value: 'RESPONSAVEL', label: Text('Responsável', style: TextStyle(fontSize: 12)))], selected: {_tipoAviso}, onSelectionChanged: (s) => setState(() { _tipoAviso = s.first; _alunoAvisoSelecionado = null; })),
                  if (_tipoAviso != 'TURMA') ...[
                    const SizedBox(height: 16),
                    Builder(builder: (context) {
                      final Map<String, String> alunosUnicos = {};
                      for (var a in alunos) { alunosUnicos[(a['id'] ?? a['matricula'] ?? a['nome']).toString()] = (a['nome'] ?? '').toString(); }
                      final valSeguro = alunosUnicos.containsKey(_alunoAvisoSelecionado) ? _alunoAvisoSelecionado : null;
                      
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Selecione o Aluno', 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: valSeguro, 
                            isExpanded: true,
                            items: alunosUnicos.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), 
                            onChanged: (val) {
                              setState(() {
                                _alunoAvisoSelecionado = val;
                              });
                            }
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 16), TextField(controller: _mensagemAvisoCtrl, maxLines: 4, decoration: InputDecoration(labelText: 'Mensagem do Aviso', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)), const SizedBox(height: 24),
                  SizedBox(height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _enviandoAviso ? null : _enviarAvisoFirebase, icon: _enviandoAviso ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded), label: Text(_enviandoAviso ? 'Enviando...' : 'ENVIAR AVISO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24), 
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Avisos Enviados Recentemente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))), 
          const SizedBox(height: 12),
          
          if (user != null) StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tenants').doc(user.id).collection('turmas').doc(widget.turmaId).collection('avisos').orderBy('dataEnvio', descending: true).limit(_limiteAvisosTurma).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Nenhum aviso enviado.', style: TextStyle(color: Colors.grey))));
              
              docs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;
                final timeA = dataA['dataEnvio'];
                final timeB = dataB['dataEnvio'];
                if (timeA == null && timeB == null) {
                  return 0;
                }
                if (timeA == null) {
                  return 1;
                }
                if (timeB == null) {
                  return -1;
                }
                return (timeB as dynamic).compareTo(timeA as dynamic);
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListView.separated(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: docs.length, 
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      
                      final alvoId = data['alunoId'];
                      String prefixoDestino = '';
                      String nomeDestino = '';
                      
                      if (data['tipoDestinatario'] == 'TURMA') {
                        prefixoDestino = 'Para: ';
                        nomeDestino = 'Toda a Turma';
                      } else {
                        final alunoAlvo = alunos.firstWhere((a) {
                          final idPossivel = (a['id'] ?? a['matricula'] ?? a['nome']).toString();
                          return idPossivel == alvoId;
                        }, orElse: () => {'nome': 'Aluno Desconhecido'});
                        
                        final nome = alunoAlvo['nome'] ?? 'Desconhecido';
                        prefixoDestino = data['tipoDestinatario'] == 'ALUNO' ? 'Para Aluno: ' : 'Para Resp: ';
                        nomeDestino = nome;
                      }

                      final dataEnvio = data['dataEnvio'];
                      final textoData = dataEnvio != null ? DateFormat('dd/MM HH:mm').format((dataEnvio as dynamic).toDate()) : '';

                      return Card(
                        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)), 
                        child: Padding(
                          padding: const EdgeInsets.all(16), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              Row(
                                children: [
                                  Icon(data['tipoDestinatario'] == 'TURMA' ? Icons.groups : Icons.person, size: 16, color: corPrimaria), 
                                  const SizedBox(width: 8), 
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: prefixoDestino,
                                            style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria),
                                          ),
                                          TextSpan(
                                            text: nomeDestino,
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ), 
                                  Text(textoData, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
                                ]
                              ), 
                              const Divider(height: 16), 
                              Text(data['mensagem'] ?? '', style: const TextStyle(fontSize: 14))
                            ]
                          )
                        )
                      );
                    },
                  ),
                  if (docs.length >= _limiteAvisosTurma) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _limiteAvisosTurma += 10;
                        });
                      },
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Carregar histórico de avisos', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // ==========================================================================
  // BUILD PRINCIPAL DA TELA
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final estadoTurmas = ref.watch(turmasStreamProvider);
    final estadoAlunos = ref.watch(alunosStreamProvider);

    String tituloAppBar = 'Diário de Classe';
    if (estadoTurmas.hasValue) {
      final tMap = estadoTurmas.value!.where((t) => t['id'] == widget.turmaId).toList();
      if (tMap.isNotEmpty) {
        tituloAppBar = tMap.first['nome'] ?? 'Diário de Classe';
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1, title: Text(tituloAppBar, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      floatingActionButton: _abaAtiva == 0 && _statusAulaHoje != 'NAO_INICIADA' && !_carregandoDiario ? FloatingActionButton.extended(onPressed: _statusAulaHoje == 'FINALIZADA' ? (_isDiaPassado ? null : _reabrirAula) : _encerrarAula, backgroundColor: _statusAulaHoje == 'FINALIZADA' ? (_isDiaPassado ? Colors.grey : Colors.orange) : corPrimaria, foregroundColor: Colors.white, icon: Icon(_statusAulaHoje == 'FINALIZADA' ? (_isDiaPassado ? Icons.lock_rounded : Icons.lock_open_rounded) : Icons.check_circle_rounded), label: Text(_statusAulaHoje == 'FINALIZADA' ? (_isDiaPassado ? 'Bloqueada' : 'Reabrir Aula') : 'Encerrar Aula', style: const TextStyle(fontWeight: FontWeight.bold))) : null,
      body: estadoTurmas.when(
        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)), error: (e, s) => Center(child: Text('Erro: $e')),
        data: (turmas) {
          final turmaMap = turmas.where((t) => t['id'] == widget.turmaId).toList();
          if (turmaMap.isEmpty) {
            return const Center(child: Text('Turma não encontrada.'));
          }
          final turma = turmaMap.first;

          return estadoAlunos.when(
            loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)), error: (e, s) => Center(child: Text('Erro: $e')),
            data: (alunosRaw) {
              var alunosDaTurma = alunosRaw.where((a) => (a['turmaId'] == widget.turmaId || a['turma'] == turma['nome'] || (a['turmasExtrasIds'] != null && (a['turmasExtrasIds'] as List).contains(widget.turmaId))) && a['status'] == 'Ativo').toList();
              alunosDaTurma.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

              int presentes = 0, faltas = 0;
              for (var a in alunosDaTurma) {
                final st = _obterStatusAluno((a['matricula'] ?? '').toString());
                if (st == 'P') {
                  presentes++;
                } else if (st == 'A' || st == 'J') {
                  faltas++;
                }
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
                        Container(color: Colors.black.withAlpha(20), child: Row(children: [_buildAbaControle(0, 'Frequência', Icons.fact_check_outlined), _buildAbaControle(1, 'Notas', Icons.edit_note_rounded), _buildAbaControle(2, 'Avisos', Icons.campaign_rounded)])),
                      ],
                    ),
                  ),

                  if (_abaAtiva == 0 && _statusAulaHoje != 'NAO_INICIADA' && !_carregandoDiario && total > 0) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Expanded(child: SizedBox(height: 48, child: InkWell(onTap: _statusAulaHoje == 'FINALIZADA' ? null : _abrirModalPreencherDiario, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.blue.shade50, border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.menu_book_rounded, color: Colors.blue.shade700, size: 18), const SizedBox(width: 8), Flexible(child: Text('Diário de Sala', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13), overflow: TextOverflow.ellipsis)), if (_conteudoAulaAtual.isNotEmpty || _anexoAulaUrl != null) ...[const SizedBox(width: 6), Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 16)]]))))),
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
                              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [Icon(Icons.assignment_late_rounded, color: _isDiaAvaliacao ? Colors.orange.shade700 : Colors.grey.shade400, size: 20), const SizedBox(width: 12), Expanded(child: Text('Marcar hoje como Dia de Avaliação', style: TextStyle(fontWeight: FontWeight.bold, color: _isDiaAvaliacao ? Colors.orange.shade900 : Colors.grey.shade700, fontSize: 13))), Switch(value: _isDiaAvaliacao, onChanged: _statusAulaHoje == 'FINALIZADA' ? null : (val) => _alternarDiaAvaliacao(), activeThumbColor: Colors.orange.shade300, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)])),
                            ),
                            if (_isDiaAvaliacao && _statusAulaHoje != 'FINALIZADA') Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: SizedBox(width: double.infinity, height: 40, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0), onPressed: () => _abrirModalNovaAvaliacao(corPrimaria, alunosDaTurma), icon: const Icon(Icons.add_task_rounded, size: 16), label: const Text('Criar Prova/Atividade Agora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))),
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
                      : _abaAtiva == 1 ? _buildAbaNotas(alunosDaTurma, corPrimaria) 
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
}