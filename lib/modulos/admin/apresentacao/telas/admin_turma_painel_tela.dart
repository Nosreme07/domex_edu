import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/aluno_provider.dart';

class AdminTurmaPainelTela extends ConsumerStatefulWidget {
  final Map<String, dynamic> turma;
  const AdminTurmaPainelTela({super.key, required this.turma});

  @override
  ConsumerState<AdminTurmaPainelTela> createState() => _AdminTurmaPainelTelaState();
}

class _AdminTurmaPainelTelaState extends ConsumerState<AdminTurmaPainelTela> {
  late Map<String, dynamic> _turmaAtual;

  @override
  void initState() {
    super.initState();
    _turmaAtual = Map<String, dynamic>.from(widget.turma);
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Painel da Turma: ${_turmaAtual['nome']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Ano Letivo: ${_turmaAtual['anoLetivo']} | Turno: ${_turmaAtual['turno']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.normal)),
            ],
          ),
          bottom: TabBar(
            labelColor: corPrimaria,
            unselectedLabelColor: Colors.grey,
            indicatorColor: corPrimaria,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_rounded), text: 'Resumo Geral'),
              Tab(icon: Icon(Icons.calendar_month_rounded), text: 'Quadro de Horários'),
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'Alunos Matriculados'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AbaResumoTurma(turma: _turmaAtual),
            _AbaHorariosTurma(
              turma: _turmaAtual,
              aoAtualizar: (novaTurma) => setState(() => _turmaAtual = novaTurma),
            ),
            _AbaAlunosTurma(turmaNome: _turmaAtual['nome']),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 1: RESUMO (Dados e Professores)
// ============================================================================
class _AbaResumoTurma extends StatelessWidget {
  final Map<String, dynamic> turma;
  const _AbaResumoTurma({required this.turma});

  Widget _buildCardInfo(String titulo, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cor.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: Icon(icone, color: cor)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profs = turma['professoresVinculados'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCardInfo('Sala / Local', turma['sala'] ?? 'Não definido', Icons.room, Colors.blue),
              const SizedBox(width: 16),
              _buildCardInfo('Status', turma['status'] ?? 'Ativo', Icons.info_outline, Colors.orange),
              const SizedBox(width: 16),
              _buildCardInfo('Total de Disciplinas', profs.length.toString(), Icons.menu_book, Colors.deepPurple),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Corpo Docente Vinculado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (profs.isEmpty)
            const Text('Nenhum professor vinculado a esta turma.', style: TextStyle(color: Colors.grey))
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: profs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.deepPurple.shade50, child: const Icon(Icons.person, color: Colors.deepPurple)),
                    title: Text(profs[i]['disciplina']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Prof: ${profs[i]['professorNome']}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ABA 2: QUADRO DE HORÁRIOS
// ============================================================================
class _AbaHorariosTurma extends StatefulWidget {
  final Map<String, dynamic> turma;
  final Function(Map<String, dynamic>) aoAtualizar;

  const _AbaHorariosTurma({required this.turma, required this.aoAtualizar});

  @override
  State<_AbaHorariosTurma> createState() => _AbaHorariosTurmaState();
}

class _AbaHorariosTurmaState extends State<_AbaHorariosTurma> {
  final List<String> _diasDaSemana = ['SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA'];

  void _abrirModalHorario({Map<String, dynamic>? horarioEdicao}) {
    final profsVinculados = widget.turma['professoresVinculados'] as List? ?? [];
    if (profsVinculados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vincule professores/disciplinas na tela de edição da turma primeiro.'), backgroundColor: Colors.orange));
      return;
    }

    String diaSelecionado = horarioEdicao?['dia'] ?? 'SEGUNDA';
    String disciplinaSelecionada = horarioEdicao?['disciplina'] ?? profsVinculados.first['disciplina'];
    final inicioCtrl = TextEditingController(text: horarioEdicao?['inicio'] ?? '07:00');
    final fimCtrl = TextEditingController(text: horarioEdicao?['fim'] ?? '07:50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cadastrar Aula', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: diaSelecionado,
                decoration: const InputDecoration(labelText: 'Dia da Semana', border: OutlineInputBorder()),
                items: _diasDaSemana.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => diaSelecionado = v!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: inicioCtrl, decoration: const InputDecoration(labelText: 'Início (Ex: 07:00)', border: OutlineInputBorder()))),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: fimCtrl, decoration: const InputDecoration(labelText: 'Fim (Ex: 07:50)', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: disciplinaSelecionada,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Disciplina / Professor', border: OutlineInputBorder()),
                items: profsVinculados.map((p) => DropdownMenuItem(value: p['disciplina'].toString(), child: Text('${p['disciplina']} - ${p['professorNome']}', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => disciplinaSelecionada = v!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final profOficial = profsVinculados.firstWhere((p) => p['disciplina'] == disciplinaSelecionada);
              final novoHorario = {
                'id': horarioEdicao?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                'dia': diaSelecionado,
                'inicio': inicioCtrl.text,
                'fim': fimCtrl.text,
                'disciplina': disciplinaSelecionada,
                'professorNome': profOficial['professorNome'],
              };

              List horarios = widget.turma['horarios'] != null ? List.from(widget.turma['horarios']) : [];
              if (horarioEdicao != null) {
                final index = horarios.indexWhere((h) => h['id'] == horarioEdicao['id']);
                if (index != -1) horarios[index] = novoHorario;
              } else {
                horarios.add(novoHorario);
              }

              // Salva no Firestore
              await FirebaseFirestore.instance.collection('turmas').doc(widget.turma['id']).update({'horarios': horarios});
              
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              
              final turmaAtualizada = Map<String, dynamic>.from(widget.turma);
              turmaAtualizada['horarios'] = horarios;
              widget.aoAtualizar(turmaAtualizada);
            },
            child: const Text('Salvar Aula'),
          )
        ],
      ),
    );
  }

  void _removerHorario(String idHorario) async {
    List horarios = List.from(widget.turma['horarios'] ?? []);
    horarios.removeWhere((h) => h['id'] == idHorario);
    await FirebaseFirestore.instance.collection('turmas').doc(widget.turma['id']).update({'horarios': horarios});
    
    final turmaAtualizada = Map<String, dynamic>.from(widget.turma);
    turmaAtualizada['horarios'] = horarios;
    widget.aoAtualizar(turmaAtualizada);
  }

  @override
  Widget build(BuildContext context) {
    final horarios = widget.turma['horarios'] as List? ?? [];
    final corPrimaria = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grade Semanal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white),
                onPressed: () => _abrirModalHorario(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Aula'),
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: horarios.isEmpty
              ? const Center(child: Text('Nenhum horário cadastrado. Clique em "Adicionar Aula".', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _diasDaSemana.length,
                  itemBuilder: (context, index) {
                    final dia = _diasDaSemana[index];
                    final aulasDoDia = horarios.where((h) => h['dia'] == dia).toList();
                    aulasDoDia.sort((a, b) => (a['inicio'] ?? '').compareTo(b['inicio'] ?? '')); // Ordena por hora

                    if (aulasDoDia.isEmpty) return const SizedBox.shrink();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                      elevation: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                            child: Text(dia, style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria)),
                          ),
                          ...aulasDoDia.map((aula) => ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text('${aula['inicio']} - ${aula['fim']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 12)),
                            ),
                            title: Text(aula['disciplina'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Prof. ${aula['professorNome']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _abrirModalHorario(horarioEdicao: aula)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _removerHorario(aula['id'])),
                              ],
                            ),
                          )),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ABA 3: ALUNOS MATRICULADOS
// ============================================================================
class _AbaAlunosTurma extends ConsumerWidget {
  final String turmaNome;
  const _AbaAlunosTurma({required this.turmaNome});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoAlunos = ref.watch(alunosStreamProvider);

    return estadoAlunos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Erro: $e')),
      data: (alunos) {
        // Filtra alunos que estão com o nome exato desta turma cadastrado na ficha deles
        final matriculados = alunos.where((a) => a['turma'] == turmaNome && a['status'] != 'Transferido').toList();
        matriculados.sort((a, b) => (a['nome'] ?? '').toString().compareTo(b['nome']?.toString() ?? ''));

        if (matriculados.isEmpty) {
          return const Center(child: Text('Nenhum aluno matriculado nesta turma ainda. Vá na ficha do aluno e altere a turma dele.', style: TextStyle(color: Colors.grey)));
        }

        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lista de Chamada (${matriculados.length} Alunos)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  child: ListView.separated(
                    itemCount: matriculados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final aluno = matriculados[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: aluno['fotoUrl'] != null ? NetworkImage(aluno['fotoUrl']) : null,
                          child: aluno['fotoUrl'] == null ? const Icon(Icons.person, color: Colors.blue) : null,
                        ),
                        title: Text(aluno['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Matrícula: ${aluno['matricula']} | Status: ${aluno['status'] ?? 'Ativo'}'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}