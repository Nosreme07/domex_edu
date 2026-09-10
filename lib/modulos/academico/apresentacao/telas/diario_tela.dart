import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importando os provedores para buscar as turmas e os alunos da escola
import '../../../admin/apresentacao/estado/turma_provider.dart';
import '../../../admin/apresentacao/estado/aluno_provider.dart';

class DiarioTela extends ConsumerStatefulWidget {
  final String turmaId;

  const DiarioTela({super.key, required this.turmaId});

  @override
  ConsumerState<DiarioTela> createState() => _DiarioTelaState();
}

class _DiarioTelaState extends ConsumerState<DiarioTela> {
  // ==========================================================================
  // ESTADO DA TELA
  // ==========================================================================
  DateTime _dataSelecionada = DateTime.now();
  int _abaAtiva = 0; // 0 = Frequência, 1 = Notas
  
  // Memória local para guardar a chamada de CADA DIA separadamente
  // Chave 1: Data (ex: 10/09/2026) | Chave 2: Matrícula | Valor: 'P', 'A' ou 'J'
  final Map<String, Map<String, String>> _frequenciaPorData = {};
  
  // Conjunto (Set) que guarda as datas que já foram SALVAS (e estão bloqueadas)
  final Set<String> _datasSalvas = {};

  // ==========================================================================
  // UTILITÁRIOS
  // ==========================================================================
  String _formatarData(DateTime data) {
    return "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
  }

  // Pega o status do aluno no dia selecionado. Se não houver, assume 'P' (Presente)
  String _obterStatusAluno(String matricula) {
    final dataKey = _formatarData(_dataSelecionada);
    if (!_frequenciaPorData.containsKey(dataKey)) {
      _frequenciaPorData[dataKey] = {};
    }
    return _frequenciaPorData[dataKey]![matricula] ?? 'P';
  }

  bool get _isChamadaSalva => _datasSalvas.contains(_formatarData(_dataSelecionada));

  // ==========================================================================
  // AÇÕES E EVENTOS
  // ==========================================================================
  void _mudarDia(int dias) {
    setState(() {
      _dataSelecionada = _dataSelecionada.add(Duration(days: dias));
    });
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
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (dataEscolhida != null && dataEscolhida != _dataSelecionada) {
      setState(() {
        _dataSelecionada = dataEscolhida;
      });
    }
  }

  void _marcarStatusAluno(String matricula, String status) {
    // Se a chamada já foi salva, impede a edição!
    if (_isChamadaSalva) return;

    final dataKey = _formatarData(_dataSelecionada);
    setState(() {
      if (!_frequenciaPorData.containsKey(dataKey)) {
        _frequenciaPorData[dataKey] = {};
      }
      _frequenciaPorData[dataKey]![matricula] = status;
    });
  }

  void _salvarChamada() {
    setState(() {
      _datasSalvas.add(_formatarData(_dataSelecionada));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chamada do dia ${_formatarData(_dataSelecionada)} salva e travada com sucesso!', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  void _editarChamada() {
    setState(() {
      _datasSalvas.remove(_formatarData(_dataSelecionada));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Modo de edição liberado. Você já pode alterar as faltas.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.amber,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  void _mostrarFotoAmpliada(String? fotoUrl, String nomeAluno) {
    if (fotoUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
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
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                tooltip: 'Fechar',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navegarParaPerfilAluno(Map<String, dynamic> aluno) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Acessando ficha de ${aluno['nome']}...\n(Página em construção)', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      )
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
        title: const Text('Diário de Classe', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      // BOTÃO FLUTUANTE DE SALVAR / EDITAR
      floatingActionButton: _abaAtiva == 0 
        ? FloatingActionButton.extended(
            onPressed: _isChamadaSalva ? _editarChamada : _salvarChamada,
            backgroundColor: _isChamadaSalva ? Colors.orange : corPrimaria,
            foregroundColor: Colors.white,
            icon: Icon(_isChamadaSalva ? Icons.edit_rounded : Icons.save_rounded),
            label: Text(
              _isChamadaSalva ? 'Editar Chamada' : 'Salvar Chamada', 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
          )
        : null,
      body: estadoTurmas.when(
        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
        error: (e, s) => Center(child: Text('Erro ao carregar a turma: $e')),
        data: (turmas) {
          final turmaMap = turmas.where((t) => t['id'] == widget.turmaId).toList();
          
          if (turmaMap.isEmpty) {
            return const Center(child: Text('Turma não encontrada.', style: TextStyle(fontSize: 16)));
          }
          
          final turma = turmaMap.first;

          return estadoAlunos.when(
            loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
            error: (e, s) => Center(child: Text('Erro ao carregar os alunos: $e')),
            data: (alunosRaw) {
              
              final alunosDaTurma = alunosRaw.where((a) {
                return a['turmaId'] == widget.turmaId || a['turma'] == turma['nome'];
              }).toList();

              alunosDaTurma.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

              return Column(
                children: [
                  // ==========================================================
                  // 1. CABEÇALHO DA TURMA E DATA
                  // ==========================================================
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: corPrimaria,
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                turma['nome'] ?? 'Turma Indefinida', 
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)
                              ),
                              const SizedBox(height: 16),
                              
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.wb_sunny_rounded, color: Colors.white70, size: 16),
                                      const SizedBox(width: 6),
                                      Text('Turno: ${turma['turno'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 16),
                                      const SizedBox(width: 6),
                                      Text('${alunosDaTurma.length} Alunos', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  
                                  if (_abaAtiva == 0)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: _isChamadaSalva ? Colors.green.withAlpha(50) : Colors.white.withAlpha(25), 
                                        borderRadius: BorderRadius.circular(12),
                                        border: _isChamadaSalva ? Border.all(color: Colors.greenAccent.withAlpha(100)) : null
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Dia Anterior',
                                            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                                            onPressed: () => _mudarDia(-1),
                                          ),
                                          InkWell(
                                            onTap: _escolherDataCalendario,
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(_isChamadaSalva ? Icons.lock_outline_rounded : Icons.calendar_month_rounded, color: Colors.white, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _formatarData(_dataSelecionada), 
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Próximo Dia',
                                            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                                            onPressed: () => _mudarDia(1),
                                          ),
                                        ],
                                      ),
                                    )
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ==========================================================
                        // 2. ABAS DE NAVEGAÇÃO
                        // ==========================================================
                        Container(
                          color: Colors.black.withAlpha(20),
                          child: Row(
                            children: [
                              _buildAbaControle(0, 'Controle de Frequência', Icons.fact_check_outlined),
                              _buildAbaControle(1, 'Lançamento de Notas', Icons.edit_note_rounded),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  
                  // ==========================================================
                  // 3. CONTEÚDO (Lista de Alunos)
                  // ==========================================================
                  Expanded(
                    child: alunosDaTurma.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_rounded, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('Nenhum aluno matriculado nesta turma.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                            ],
                          ),
                        )
                      : _abaAtiva == 0 
                          ? _buildAbaFrequencia(alunosDaTurma, corPrimaria)
                          : _buildAbaNotas(alunosDaTurma, corPrimaria),
                  ),
                ],
              );
            }
          );
        }
      ),
    );
  }

  // ==========================================================================
  // WIDGETS AUXILIARES
  // ==========================================================================

  Widget _buildAbaControle(int indice, String titulo, IconData icone) {
    final isAtiva = _abaAtiva == indice;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _abaAtiva = indice),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isAtiva ? Colors.white : Colors.transparent, width: 3))
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Icon(icone, color: isAtiva ? Colors.white : Colors.white60, size: 18),
              Text(
                titulo, 
                style: TextStyle(
                  color: isAtiva ? Colors.white : Colors.white60, 
                  fontWeight: isAtiva ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbaFrequencia(List<Map<String, dynamic>> alunos, Color corPrimaria) {
    return ListView.separated(
      padding: const EdgeInsets.all(24).copyWith(bottom: 100), 
      itemCount: alunos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final aluno = alunos[index];
        final fotoUrl = aluno['fotoUrl'];
        final nome = aluno['nome'] ?? 'Aluno sem nome';
        final matricula = (aluno['matricula'] ?? '').toString();

        final statusAtual = _obterStatusAluno(matricula);

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // PERFIL DO ALUNO (Com Zoom e Navegação)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _mostrarFotoAmpliada(fotoUrl, nome),
                      child: Tooltip(
                        message: 'Ampliar foto',
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: corPrimaria.withAlpha(30),
                          backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                          child: fotoUrl == null ? Icon(Icons.person, color: corPrimaria) : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => _navegarParaPerfilAluno(aluno),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome, 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16, 
                                color: corPrimaria,
                                decoration: TextDecoration.underline,
                                decorationColor: corPrimaria.withAlpha(100)
                              )
                            ),
                            const SizedBox(height: 4),
                            Text('Matrícula: $matricula', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // CONTROLE DE FREQUÊNCIA
                Container(
                  decoration: BoxDecoration(
                    color: _isChamadaSalva ? Colors.grey.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBotaoStatus(matricula, 'P', 'Presente', Icons.check_circle_rounded, Colors.green, statusAtual),
                      Container(width: 1, height: 30, color: Colors.grey.shade300),
                      _buildBotaoStatus(matricula, 'A', 'Ausente', Icons.cancel_rounded, Colors.red, statusAtual),
                      Container(width: 1, height: 30, color: Colors.grey.shade300),
                      _buildBotaoStatus(matricula, 'J', 'Justificada', Icons.info_rounded, Colors.orange, statusAtual),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBotaoStatus(String matricula, String statusValor, String tooltip, IconData icone, Color cor, String statusAtual) {
    final isSelecionado = statusAtual == statusValor;
    final bloqueado = _isChamadaSalva;
    
    return Tooltip(
      message: bloqueado ? 'Clique em Editar Chamada para alterar' : tooltip,
      child: InkWell(
        onTap: bloqueado ? null : () => _marcarStatusAluno(matricula, statusValor),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelecionado ? cor.withAlpha(bloqueado ? 15 : 30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8)
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 18, color: isSelecionado ? (bloqueado ? cor.withAlpha(150) : cor) : Colors.grey.shade300),
              if (isSelecionado) ...[
                const SizedBox(width: 6),
                Text(statusValor, style: TextStyle(color: (bloqueado ? cor.withAlpha(150) : cor), fontWeight: FontWeight.bold, fontSize: 14)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbaNotas(List<Map<String, dynamic>> alunos, Color corPrimaria) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Lançamento de Notas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Text('A planilha acadêmica de avaliações será construída em breve.', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}