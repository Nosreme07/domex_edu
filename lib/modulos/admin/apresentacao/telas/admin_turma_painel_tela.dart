import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../estado/aluno_provider.dart';
import '../estado/turma_provider.dart';
import '../estado/professor_provider.dart';

// ============================================================================
// FORMATADOR PARA TUDO MAIÚSCULO
// ============================================================================
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// ============================================================================
// FUNÇÃO GLOBAL: ABRIR FOTO EM TELA CHEIA (Para qualquer avatar da página)
// ============================================================================
void _mostrarFotoAmpliada(BuildContext context, String url) {
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

class AdminTurmaPainelTela extends ConsumerStatefulWidget {
  final Map<String, dynamic> turma;
  const AdminTurmaPainelTela({super.key, required this.turma});

  @override
  ConsumerState<AdminTurmaPainelTela> createState() =>
      _AdminTurmaPainelTelaState();
}

class _AdminTurmaPainelTelaState extends ConsumerState<AdminTurmaPainelTela> {
  late Map<String, dynamic> _turmaAtual;
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _turmaAtual = Map<String, dynamic>.from(widget.turma);
  }

  // ==========================================================================
  // VERIFICA SE A TURMA É EXTRACURRICULAR
  // ==========================================================================
  bool _isTurmaExtra(String nome) {
    final n = nome.toUpperCase();
    if (n.contains('MÉDIO') ||
        n.contains('MEDIO') ||
        n.contains('SÉRIE') ||
        n.contains('SERIE') ||
        n.contains('TERCEIRÃO')) {
      return false;
    }
    if (n.contains('ANO') || n.contains('FUNDAMENTAL')) {
      return false;
    }
    if (n.contains('BERÇÁRIO') ||
        n.contains('BERCARIO') ||
        n.contains('MATERNAL') ||
        n.contains('INFANTIL') ||
        n.contains('JARDIM') ||
        n.contains('PRÉ')) {
      return false;
    }
    return true;
  }

  // ==========================================================================
  // FICHA RÁPIDA DO ALUNO
  // ==========================================================================
  void _abrirFichaAlunoRapida(
    BuildContext context,
    Map<String, dynamic> aluno,
  ) {
    final telefoneAluno = (aluno['telefone'] ?? '').toString();
    final numAlunoLimpo = telefoneAluno.replaceAll(RegExp(r'[^0-9]'), '');

    List responsaveis = aluno['responsaveis'] ?? [];
    Map<String, dynamic>? respPrincipal;
    if (responsaveis.isNotEmpty) {
      respPrincipal = responsaveis.firstWhere(
        (r) => r['principal'] == true,
        orElse: () => responsaveis.first,
      );
    }
    final nomeResp = respPrincipal?['nome'] ?? 'Não informado';
    final telResp = (respPrincipal?['telefone'] ?? '').toString();
    final numRespLimpo = telResp.replaceAll(RegExp(r'[^0-9]'), '');

    Widget buildLinhaContatoModal(String telefone, String numeroLimpo) {
      if (telefone.isEmpty) {
        return const Text(
          'Não informado',
          style: TextStyle(color: Colors.grey),
        );
      }
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              telefone,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (numeroLimpo.length >= 10) ...[
            const Spacer(),
            Tooltip(
              message: 'Abrir WhatsApp',
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://wa.me/55$numeroLimpo'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Image.asset(
                  'assets/whatsapp.png',
                  width: 28,
                  height: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Tooltip(
              message: 'Ligar',
              child: InkWell(
                onTap: () => launchUrl(Uri.parse('tel:$numeroLimpo')),
                child: const Icon(Icons.phone, color: Colors.blue, size: 28),
              ),
            ),
          ],
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Ficha Rápida do Aluno',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(35),
                    onTap: aluno['fotoUrl'] != null
                        ? () => _mostrarFotoAmpliada(context, aluno['fotoUrl'])
                        : null,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: aluno['fotoUrl'] != null
                          ? NetworkImage(aluno['fotoUrl'])
                          : null,
                      child: aluno['fotoUrl'] == null
                          ? const Icon(
                              Icons.person,
                              size: 35,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          aluno['nome'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Matrícula: ${aluno['matricula']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Status: ${aluno['status'] ?? 'Ativo'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: aluno['status'] == 'Inadimplente'
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              const Text(
                'Vínculo Acadêmico',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Turma Principal: ${aluno['turma'] ?? 'Não informada'}',
                style: const TextStyle(fontSize: 13),
              ),
              const Divider(height: 32),
              const Text(
                'Contato do Aluno',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              buildLinhaContatoModal(telefoneAluno, numAlunoLimpo),
              const Divider(height: 32),
              const Text(
                'Responsável Principal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nomeResp,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              buildLinhaContatoModal(telResp, numRespLimpo),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MODAL DE AVISOS
  // ==========================================================================
  void _abrirModalAvisos() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.campaign, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text(
              'Avisos da Turma',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const SizedBox(
          width: 400,
          child: Text(
            'O painel de envio de avisos específicos para os alunos e responsáveis desta turma será implementado em breve!',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CARDS SUPERIORES
  // ==========================================================================
  Widget _buildCardAcao(
    String titulo,
    String subtitulo,
    IconData icone,
    Color cor,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icone, color: cor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // MODAL DE PUXAR ALUNOS
  // ==========================================================================
  void _abrirModalVincularAlunos(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> todosAlunos,
  ) {
    final idTurma = _turmaAtual['id'].toString();
    final turnoFormatado = _turmaAtual['turno'] ?? '';
    final turmaNomeOficial =
        '${_turmaAtual['nome']} (${_turmaAtual['anoLetivo']}) - $turnoFormatado'
            .toUpperCase();
    final isExtra = _isTurmaExtra(_turmaAtual['nome'] ?? '');

    final alunosDisponiveis = todosAlunos.where((a) {
      if (a['status'] == 'Transferido' || a['status'] == 'Inativo') {
        return false;
      }

      final turmaIdAluno = (a['turmaId'] ?? '').toString().trim();
      final turmasExtrasIds = List<String>.from(a['turmasExtrasIds'] ?? []);

      if (isExtra) {
        return !turmasExtrasIds.contains(idTurma);
      } else {
        return turmaIdAluno != idTurma;
      }
    }).toList();

    alunosDisponiveis.sort(
      (a, b) =>
          (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()),
    );
    List<String> matriculasSelecionadas = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          final corPrimaria = Theme.of(context).primaryColor;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.group_add_rounded, color: corPrimaria),
                const SizedBox(width: 8),
                const Text(
                  'Puxar Alunos para a Turma',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: alunosDisponiveis.isEmpty
                  ? const Center(
                      child: Text(
                        'Todos os alunos ativos já estão nesta turma.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isExtra
                                ? Colors.purple.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: isExtra ? Colors.purple : Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isExtra
                                      ? 'Esta é uma turma EXTRACURRICULAR. Os alunos adicionados NÃO serão removidos de suas turmas regulares.'
                                      : 'Selecione os alunos. Se eles estiverem em outra turma regular, serão transferidos para cá.',
                                  style: TextStyle(
                                    color: isExtra
                                        ? Colors.purple
                                        : Colors.blue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              itemCount: alunosDisponiveis.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final a = alunosDisponiveis[index];
                                final isChecked = matriculasSelecionadas
                                    .contains(a['matricula'].toString());
                                return CheckboxListTile(
                                  activeColor: corPrimaria,
                                  title: Text(
                                    a['nome'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Matrícula: ${a['matricula']} | Turma Atual: ${a['turma'] == null || a['turma'].toString().isEmpty ? 'Nenhuma' : a['turma']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  value: isChecked,
                                  onChanged: (val) {
                                    setStateModal(() {
                                      if (val == true) {
                                        matriculasSelecionadas.add(
                                          a['matricula'].toString(),
                                        );
                                      } else {
                                        matriculasSelecionadas.remove(
                                          a['matricula'].toString(),
                                        );
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            actionsPadding: const EdgeInsets.all(24),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: corPrimaria,
                  foregroundColor: Colors.white,
                ),
                onPressed: matriculasSelecionadas.isEmpty
                    ? null
                    : () async {
                        showDialog(
                          context: ctx,
                          barrierDismissible: false,
                          builder: (_) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );

                        for (String matricula in matriculasSelecionadas) {
                          final alunoOriginal = todosAlunos.firstWhere(
                            (a) => a['matricula'].toString() == matricula,
                          );
                          final alunoAtualizado = Map<String, dynamic>.from(
                            alunoOriginal,
                          );

                          if (isExtra) {
                            final extrasIds = List<String>.from(
                              alunoAtualizado['turmasExtrasIds'] ?? [],
                            );
                            final extrasNomes = List<String>.from(
                              alunoAtualizado['turmasExtrasNomes'] ?? [],
                            );

                            if (!extrasIds.contains(idTurma)) {
                              extrasIds.add(idTurma);
                              extrasNomes.add(turmaNomeOficial);
                            }

                            alunoAtualizado['turmasExtrasIds'] = extrasIds;
                            alunoAtualizado['turmasExtrasNomes'] = extrasNomes;
                          } else {
                            alunoAtualizado['turma'] = turmaNomeOficial;
                            alunoAtualizado['turmaId'] = idTurma;
                          }

                          await ref
                              .read(alunoServiceProvider)
                              .salvarAluno(alunoAtualizado);
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${matriculasSelecionadas.length} aluno(s) vinculados!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.check),
                label: const Text('Salvar na Turma'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final estadoAlunos = ref.watch(alunosStreamProvider);

    final profs = _turmaAtual['professoresVinculados'] as List? ?? [];
    final horarios = _turmaAtual['horarios'] as List? ?? [];
    final isExtra = _isTurmaExtra(_turmaAtual['nome'] ?? '');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Painel da Turma: ${_turmaAtual['nome']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (isExtra) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EXTRACURRICULAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              'Ano Letivo: ${_turmaAtual['anoLetivo']} | Turno: ${_turmaAtual['turno']} | Sala: ${_turmaAtual['sala'] ?? 'N/A'}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCardAcao(
                  'Corpo Docente',
                  '${profs.length} professores vinculados',
                  Icons.assignment_ind_rounded,
                  Colors.blue,
                  () => showDialog(
                    context: context,
                    builder: (ctx) => _ModalGerenciadorCorpoDocente(
                      turma: _turmaAtual,
                      aoAtualizar: (novaTurma) =>
                          setState(() => _turmaAtual = novaTurma),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildCardAcao(
                  'Quadro de Horários',
                  '${horarios.length} aulas cadastradas',
                  Icons.calendar_month_rounded,
                  Colors.orange,
                  () => showDialog(
                    context: context,
                    builder: (ctx) => _ModalGerenciadorHorarios(
                      turma: _turmaAtual,
                      aoAtualizar: (novaTurma) =>
                          setState(() => _turmaAtual = novaTurma),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildCardAcao(
                  'Mural de Avisos',
                  'Notificar pais e alunos',
                  Icons.campaign_rounded,
                  Colors.deepPurple,
                  _abrirModalAvisos,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ================================================================
            // LISTAGEM DE ALUNOS
            // ================================================================
            estadoAlunos.when(
              loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, s) => Expanded(child: Center(child: Text('Erro: $e'))),
              data: (alunos) {
                final idTurma = _turmaAtual['id'].toString();
                final turnoFormatado = _turmaAtual['turno'] ?? '';
                final turmaNomeOficial =
                    '${_turmaAtual['nome']} (${_turmaAtual['anoLetivo']}) - $turnoFormatado'
                        .toUpperCase();
                final turmaNomeAntigo =
                    '${_turmaAtual['nome']} (${_turmaAtual['anoLetivo']})'
                        .toUpperCase();

                final matriculadosRaw = alunos.where((a) {
                  if (a['status'] == 'Transferido' ||
                      a['status'] == 'Inativo') {
                    return false;
                  }
                  final turmaAluno = (a['turma'] ?? '')
                      .toString()
                      .trim()
                      .toUpperCase();
                  final turmaIdAluno = (a['turmaId'] ?? '').toString().trim();
                  final turmasExtrasIds = List<String>.from(
                    a['turmasExtrasIds'] ?? [],
                  );

                  return turmaAluno == turmaNomeOficial ||
                      turmaAluno == turmaNomeAntigo ||
                      turmaIdAluno == idTurma ||
                      turmasExtrasIds.contains(idTurma);
                }).toList();

                final matriculadosFiltrados = matriculadosRaw.where((a) {
                  final busca = _termoBusca.toLowerCase();
                  final nome = (a['nome'] ?? '').toString().toLowerCase();
                  final matricula = (a['matricula'] ?? '')
                      .toString()
                      .toLowerCase();
                  return nome.contains(busca) || matricula.contains(busca);
                }).toList();

                matriculadosFiltrados.sort(
                  (a, b) => (a['nome'] ?? '').toString().compareTo(
                    b['nome']?.toString() ?? '',
                  ),
                );

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Alunos Matriculados (${matriculadosRaw.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              SizedBox(
                                width: 250,
                                height: 40,
                                child: TextField(
                                  onChanged: (value) =>
                                      setState(() => _termoBusca = value),
                                  decoration: InputDecoration(
                                    hintText: 'Pesquisar aluno...',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: corPrimaria,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _abrirModalVincularAlunos(
                                  context,
                                  ref,
                                  alunos,
                                ),
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                ),
                                label: const Text('Puxar Alunos'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (matriculadosFiltrados.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_alt_outlined,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _termoBusca.isEmpty
                                      ? 'Nenhum aluno matriculado nesta turma.'
                                      : 'Nenhum aluno encontrado na pesquisa.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_termoBusca.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => _abrirModalVincularAlunos(
                                      context,
                                      ref,
                                      alunos,
                                    ),
                                    child: const Text(
                                      'Clique aqui para puxar alunos',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: ListView.separated(
                              itemCount: matriculadosFiltrados.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final aluno = matriculadosFiltrados[index];
                                return ListTile(
                                  leading: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: aluno['fotoUrl'] != null
                                        ? () => _mostrarFotoAmpliada(
                                            context,
                                            aluno['fotoUrl'],
                                          )
                                        : null,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.blue.shade50,
                                      backgroundImage: aluno['fotoUrl'] != null
                                          ? NetworkImage(aluno['fotoUrl'])
                                          : null,
                                      child: aluno['fotoUrl'] == null
                                          ? const Icon(
                                              Icons.person,
                                              color: Colors.blue,
                                            )
                                          : null,
                                    ),
                                  ),
                                  title: Text(
                                    aluno['nome'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Matrícula: ${aluno['matricula']} | Status: ${aluno['status'] ?? 'Ativo'}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Visualizar Ficha Rápida',
                                        icon: const Icon(
                                          Icons.visibility_rounded,
                                          color: Colors.blueGrey,
                                        ),
                                        onPressed: () => _abrirFichaAlunoRapida(
                                          context,
                                          aluno,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: isExtra
                                            ? 'Remover da Turma Extra'
                                            : 'Remover da Turma',
                                        icon: const Icon(
                                          Icons.person_remove_rounded,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Row(
                                                children: [
                                                  Icon(
                                                    Icons.warning_rounded,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Remover da Turma'),
                                                ],
                                              ),
                                              content: Text(
                                                'Deseja retirar o(a) aluno(a) ${aluno['nome']} desta turma?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text(
                                                    'Cancelar',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.red,
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  onPressed: () async {
                                                    final alunoRemover =
                                                        Map<
                                                          String,
                                                          dynamic
                                                        >.from(aluno);

                                                    if (isExtra) {
                                                      final extrasIds =
                                                          List<String>.from(
                                                        alunoRemover['turmasExtrasIds'] ??
                                                            [],
                                                      );
                                                      final extrasNomes =
                                                          List<String>.from(
                                                        alunoRemover['turmasExtrasNomes'] ??
                                                            [],
                                                      );
                                                      extrasIds.remove(idTurma);
                                                      extrasNomes.remove(
                                                        turmaNomeOficial,
                                                      );
                                                      alunoRemover['turmasExtrasIds'] =
                                                          extrasIds;
                                                      alunoRemover['turmasExtrasNomes'] =
                                                          extrasNomes;
                                                    } else {
                                                      alunoRemover['turma'] =
                                                          '';
                                                      alunoRemover['turmaId'] =
                                                          '';
                                                    }

                                                    await ref
                                                        .read(
                                                          alunoServiceProvider,
                                                        )
                                                        .salvarAluno(
                                                          alunoRemover,
                                                        );
                                                    if (ctx.mounted) {
                                                      Navigator.pop(ctx);
                                                    }
                                                  },
                                                  child: const Text(
                                                    'Sim, Remover',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET EXTRA 1: GERENCIADOR DO CORPO DOCENTE
// ============================================================================
class _ModalGerenciadorCorpoDocente extends ConsumerStatefulWidget {
  final Map<String, dynamic> turma;
  final Function(Map<String, dynamic>) aoAtualizar;

  const _ModalGerenciadorCorpoDocente({
    required this.turma,
    required this.aoAtualizar,
  });

  @override
  ConsumerState<_ModalGerenciadorCorpoDocente> createState() =>
      _ModalGerenciadorCorpoDocenteState();
}

class _ModalGerenciadorCorpoDocenteState
    extends ConsumerState<_ModalGerenciadorCorpoDocente> {
  String? _disciplinaSelecionada;
  Map<String, dynamic>? _professorSelecionado;
  late List<Map<String, dynamic>> _profsVinculadosLocal;

  int _limpadorIndex = 0;

  @override
  void initState() {
    super.initState();
    _profsVinculadosLocal = List<Map<String, dynamic>>.from(
      widget.turma['professoresVinculados'] ?? [],
    );
  }

  Future<void> _salvarNoBanco() async {
    final turmaCompleta = Map<String, dynamic>.from(widget.turma);
    turmaCompleta['professoresVinculados'] = _profsVinculadosLocal;
    await ref.read(turmaServiceProvider).salvarTurma(turmaCompleta);
    widget.aoAtualizar(turmaCompleta);
  }

  void _vincularProfessor() async {
    if (_disciplinaSelecionada == null ||
        _disciplinaSelecionada!.trim().isEmpty ||
        _professorSelecionado == null) return;

    final novoVinculo = {
      '_keyId': DateTime.now().microsecondsSinceEpoch.toString(),
      'disciplina': _disciplinaSelecionada!.trim().toUpperCase(),
      'professorId': _professorSelecionado!['id'],
      'professorNome': _professorSelecionado!['nome'],
    };

    setState(() {
      _profsVinculadosLocal.add(novoVinculo);
      _disciplinaSelecionada = null;
      _professorSelecionado = null;
      _limpadorIndex++;
    });

    await _salvarNoBanco();
  }

  void _removerVinculo(String keyId) async {
    setState(
      () => _profsVinculadosLocal.removeWhere((p) => p['_keyId'] == keyId),
    );
    await _salvarNoBanco();
  }

  // Ficha rápida com foto ampliada
  void _abrirFichaProfessorRapida(
    BuildContext context,
    Map<String, dynamic> prof,
    List<Map<String, dynamic>> turmasDoSistema,
  ) {
    final telefone = (prof['telefone'] ?? '').toString();
    final numeroLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');

    List<String> turmasVinculadas = [];
    for (var t in turmasDoSistema) {
      final profsDaTurma = t['professoresVinculados'] as List? ?? [];
      if (profsDaTurma.any((pv) => pv['professorId'] == prof['id'])) {
        turmasVinculadas.add('${t['nome']} (${t['anoLetivo']})');
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Ficha Rápida do Professor',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(35),
                    onTap: prof['fotoUrl'] != null
                        ? () => _mostrarFotoAmpliada(context, prof['fotoUrl'])
                        : null,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: prof['fotoUrl'] != null
                          ? NetworkImage(prof['fotoUrl'])
                          : null,
                      child: prof['fotoUrl'] == null
                          ? const Icon(
                              Icons.person,
                              size: 35,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prof['nome'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Disciplinas: ${(prof['disciplinas'] as List? ?? []).join(', ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (telefone.isNotEmpty) ...[
                const Text(
                  'Contato Rápido:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        telefone,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (numeroLimpo.length >= 10) ...[
                      const Spacer(),
                      Tooltip(
                        message: 'Abrir WhatsApp',
                        child: InkWell(
                          onTap: () => launchUrl(
                            Uri.parse('https://wa.me/55$numeroLimpo'),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Image.asset(
                            'assets/whatsapp.png',
                            width: 28,
                            height: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Tooltip(
                        message: 'Ligar',
                        child: InkWell(
                          onTap: () => launchUrl(Uri.parse('tel:$numeroLimpo')),
                          child: const Icon(
                            Icons.phone,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 32),
              ],
              const Text(
                'Leciona nas Turmas:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 12),
              if (turmasVinculadas.isEmpty)
                const Text(
                  'Não está vinculado a nenhuma turma.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: turmasVinculadas
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estadoProfessores = ref.watch(professoresStreamProvider);
    final estadoTurmas = ref.watch(turmasStreamProvider);
    final corPrimaria = Theme.of(context).primaryColor;

    List<Map<String, dynamic>> profsAtivos = [];
    Set<String> disciplinasDoSistema = {};

    final profs = estadoProfessores.value ?? [];
    final turmas = estadoTurmas.value ?? [];

    profsAtivos = profs.where((p) => p['status'] == 'Ativo').toList();
    profsAtivos.sort(
      (a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo(
        (b['nome'] ?? '').toString().toUpperCase(),
      ),
    );

    for (var p in profsAtivos) {
      if (p['disciplinas'] != null) {
        for (var d in p['disciplinas']) {
          disciplinasDoSistema.add(d.toString().toUpperCase().trim());
        }
      }
    }

    if (disciplinasDoSistema.isEmpty) {
      disciplinasDoSistema.add('GERAL / PADRÃO');
    }
    final listaDisciplinas = disciplinasDoSistema.toList()..sort();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_ind, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Corpo Docente',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              context.push('/admin/cadastros/professor/novo');
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Cadastrar Novo Professor'),
          ),
        ],
      ),
      content: SizedBox(
        width: 750,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                key: ValueKey(_limpadorIndex),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textoDigitado) {
                            if (textoDigitado.text.isEmpty) {
                              return listaDisciplinas;
                            }
                            return listaDisciplinas.where(
                              (d) =>
                                  d.contains(textoDigitado.text.toUpperCase()),
                            );
                          },
                          onSelected: (selecao) {
                            setState(() {
                              _disciplinaSelecionada = selecao;
                              _professorSelecionado = null;
                            });
                          },
                          fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                            return TextFormField(
                              controller: ctrl,
                              focusNode: focus,
                              inputFormatters: [UpperCaseTextFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Selecione a Disciplina',
                                border: OutlineInputBorder(),
                                fillColor: Colors.white,
                                filled: true,
                                prefixIcon: Icon(Icons.search, size: 20),
                              ),
                              onChanged: (v) {
                                setState(() {
                                  _disciplinaSelecionada = v.toUpperCase();
                                });
                              },
                            );
                          },
                          optionsViewBuilder: (ctx, onSel, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  height: 200,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (ctx, idx) => ListTile(
                                      title: Text(options.elementAt(idx)),
                                      onTap: () =>
                                          onSel(options.elementAt(idx)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<Map<String, dynamic>>(
                          displayStringForOption: (prof) => '${prof['nome']}',
                          optionsBuilder: (TextEditingValue texto) {
                            Iterable<Map<String, dynamic>> profsFiltrados =
                                profsAtivos;

                            if (_disciplinaSelecionada != null &&
                                _disciplinaSelecionada!.trim().isNotEmpty) {
                              final discBusca = _disciplinaSelecionada!
                                  .trim()
                                  .toUpperCase();
                              profsFiltrados = profsFiltrados.where((p) {
                                final disciplinasDoProf =
                                    (p['disciplinas'] as List? ?? [])
                                        .map(
                                          (d) =>
                                              d.toString().toUpperCase().trim(),
                                        )
                                        .toList();
                                return disciplinasDoProf.any(
                                  (d) => d.contains(discBusca),
                                );
                              });
                            }

                            if (texto.text.isNotEmpty) {
                              final busca = texto.text.toUpperCase();
                              profsFiltrados = profsFiltrados.where(
                                (p) =>
                                    p['nome'].toString().toUpperCase().contains(
                                      busca,
                                    ) ||
                                    p['id'].toString().contains(busca),
                              );
                            }

                            return profsFiltrados;
                          },
                          onSelected: (prof) =>
                              setState(() => _professorSelecionado = prof),
                          fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                            return TextFormField(
                              controller: ctrl,
                              focusNode: focus,
                              inputFormatters: [UpperCaseTextFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Selecione o Professor Ativo',
                                border: OutlineInputBorder(),
                                fillColor: Colors.white,
                                filled: true,
                                prefixIcon: Icon(Icons.search, size: 20),
                              ),
                            );
                          },
                          optionsViewBuilder: (ctx, onSel, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  height: 250,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (ctx, idx) {
                                      final prof = options.elementAt(idx);
                                      final discStr =
                                          (prof['disciplinas'] as List? ?? [])
                                              .join(', ')
                                              .toUpperCase();
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage:
                                              prof['fotoUrl'] != null
                                              ? NetworkImage(prof['fotoUrl'])
                                              : null,
                                          child: prof['fotoUrl'] == null
                                              ? const Icon(
                                                  Icons.person,
                                                  size: 20,
                                                )
                                              : null,
                                        ),
                                        title: Text(
                                          prof['nome'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Leciona: $discStr',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onTap: () {
                                          onSel(prof);
                                          FocusScope.of(ctx).unfocus();
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade100,
                      foregroundColor: Colors.blueGrey.shade800,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      elevation: 0,
                    ),
                    onPressed:
                        (_disciplinaSelecionada != null &&
                            _disciplinaSelecionada!.isNotEmpty &&
                            _professorSelecionado != null)
                        ? _vincularProfessor
                        : null,
                    child: const Text(
                      'Vincular',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Professores Vinculados a Esta Turma',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const Divider(),
            Expanded(
              child: _profsVinculadosLocal.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum professor vinculado a esta turma ainda.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _profsVinculadosLocal.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final vinculo = _profsVinculadosLocal[i];
                        final profId = vinculo['professorId'];

                        final profCompleto = profsAtivos.firstWhere(
                          (p) => p['id'] == profId,
                          orElse: () => {},
                        );
                        final fotoUrl = profCompleto.isNotEmpty
                            ? profCompleto['fotoUrl']
                            : null;

                        return ListTile(
                          leading: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: fotoUrl != null
                                ? () => _mostrarFotoAmpliada(context, fotoUrl)
                                : null,
                            child: CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              backgroundImage: fotoUrl != null
                                  ? NetworkImage(fotoUrl)
                                  : null,
                              child: fotoUrl == null
                                  ? const Icon(Icons.person, color: Colors.blue)
                                  : null,
                            ),
                          ),
                          title: Text(
                            vinculo['disciplina']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Prof: ${vinculo['professorNome']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (profCompleto.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.visibility_rounded,
                                    color: Colors.blueGrey,
                                  ),
                                  tooltip: 'Ver Contato e Turmas',
                                  onPressed: () => _abrirFichaProfessorRapida(
                                    context,
                                    profCompleto,
                                    turmas,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Remover Professor da Turma',
                                onPressed: () =>
                                    _removerVinculo(vinculo['_keyId']),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Fechar Painel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// WIDGET EXTRA 2: QUADRO DE HORÁRIOS (Com Visualização Semanal e PDF)
// ============================================================================
class _ModalGerenciadorHorarios extends ConsumerStatefulWidget {
  final Map<String, dynamic> turma;
  final Function(Map<String, dynamic>) aoAtualizar;

  const _ModalGerenciadorHorarios({
    required this.turma,
    required this.aoAtualizar,
  });

  @override
  ConsumerState<_ModalGerenciadorHorarios> createState() =>
      _ModalGerenciadorHorariosState();
}

class _ModalGerenciadorHorariosState
    extends ConsumerState<_ModalGerenciadorHorarios> {
  final List<String> _diasDaSemana = [
    'SEGUNDA',
    'TERÇA',
    'QUARTA',
    'QUINTA',
    'SEXTA',
    'SÁBADO',
    'DOMINGO',
  ];
  late List<Map<String, dynamic>> _horariosLocal;

  final Map<String, int> _disciplinaCores = {};

  final List<Color> _bgColors = [
    Colors.blue.shade50,
    Colors.green.shade50,
    Colors.purple.shade50,
    Colors.orange.shade50,
    Colors.teal.shade50,
    Colors.pink.shade50,
    Colors.cyan.shade50,
    Colors.amber.shade50,
    Colors.indigo.shade50,
    Colors.red.shade50,
  ];
  final List<Color> _tagColors = [
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.purple.shade100,
    Colors.orange.shade100,
    Colors.teal.shade100,
    Colors.pink.shade100,
    Colors.cyan.shade100,
    Colors.amber.shade100,
    Colors.indigo.shade100,
    Colors.red.shade100,
  ];
  final List<Color> _textColors = [
    Colors.blue.shade900,
    Colors.green.shade900,
    Colors.purple.shade900,
    Colors.orange.shade900,
    Colors.teal.shade900,
    Colors.pink.shade900,
    Colors.cyan.shade900,
    Colors.amber.shade900,
    Colors.indigo.shade900,
    Colors.red.shade900,
  ];

  @override
  void initState() {
    super.initState();
    _horariosLocal = List<Map<String, dynamic>>.from(
      widget.turma['horarios'] ?? [],
    );
    _atualizarMapaDeCores();
  }

  void _atualizarMapaDeCores() {
    _disciplinaCores.clear();
    final disciplinasUnicas =
        _horariosLocal
            .map((h) => h['disciplina'].toString())
            .where((d) => d != 'INTERVALO')
            .toSet()
            .toList()
          ..sort();

    for (int i = 0; i < disciplinasUnicas.length; i++) {
      _disciplinaCores[disciplinasUnicas[i]] = i;
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Color _getBgTileColor(String disciplina) {
    if (disciplina == 'INTERVALO') {
      return Colors.grey.shade100;
    }
    int index = _disciplinaCores[disciplina] ?? 0;
    return _bgColors[index % _bgColors.length];
  }

  Color _getBgTagColor(String disciplina) {
    if (disciplina == 'INTERVALO') {
      return Colors.grey.shade400;
    }
    int index = _disciplinaCores[disciplina] ?? 0;
    return _tagColors[index % _tagColors.length];
  }

  Color _getTextColor(String disciplina) {
    if (disciplina == 'INTERVALO') {
      return Colors.black87;
    }
    int index = _disciplinaCores[disciplina] ?? 0;
    return _textColors[index % _textColors.length];
  }

  Future<void> _salvarNoBanco() async {
    final turmaCompleta = Map<String, dynamic>.from(widget.turma);
    turmaCompleta['horarios'] = _horariosLocal;
    await ref.read(turmaServiceProvider).salvarTurma(turmaCompleta);
    widget.aoAtualizar(turmaCompleta);
  }

  // ==========================================================================
  // ATUALIZAÇÃO NO MODAL DE EDIÇÃO PARA PREENCHER OS DADOS AUTOMATICAMENTE
  // ==========================================================================
  void _abrirModalEdicaoAula({
    Map<String, dynamic>? horarioEdicao,
    String? diaPreSelecionado,
    String? horarioPreSelecionado,
    VoidCallback? onSaved,
  }) {
    final profsVinculados =
        widget.turma['professoresVinculados'] as List? ?? [];

    List<Map<String, dynamic>> opcoesSelect = List.from(profsVinculados);
    opcoesSelect.add({'disciplina': 'INTERVALO', 'professorNome': 'LIVRE'});
    opcoesSelect.sort(
      (a, b) =>
          a['disciplina'].toString().compareTo(b['disciplina'].toString()),
    );

    String diaSelecionado = horarioEdicao?['dia'] ?? diaPreSelecionado ?? 'SEGUNDA';
    String disciplinaSelecionada =
        horarioEdicao?['disciplina'] ?? opcoesSelect.first['disciplina'];

    String inicialI = '';
    String inicialF = '';
    
    if (horarioEdicao != null) {
      inicialI = horarioEdicao['inicio'] ?? '';
      inicialF = horarioEdicao['fim'] ?? '';
    } else if (horarioPreSelecionado != null) {
      final p = horarioPreSelecionado.split(' - ');
      if (p.length == 2) {
        inicialI = p[0];
        inicialF = p[1];
      }
    }

    final inicioCtrl = TextEditingController(text: inicialI);
    final fimCtrl = TextEditingController(text: inicialF);

    final maskInicio = MaskTextInputFormatter(
      mask: '##:##',
      filter: {"#": RegExp(r'[0-9]')},
      initialText: inicioCtrl.text,
    );
    final maskFim = MaskTextInputFormatter(
      mask: '##:##',
      filter: {"#": RegExp(r'[0-9]')},
      initialText: fimCtrl.text,
    );

    final formAulaKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctxAula) => AlertDialog(
        title: Text(
          horarioEdicao == null ? 'Cadastrar Aula ou Intervalo' : 'Editar Aula ou Intervalo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formAulaKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: diaSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Dia da Semana',
                    border: OutlineInputBorder(),
                  ),
                  items: _diasDaSemana
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => diaSelecionado = v!,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: inicioCtrl,
                        inputFormatters: [maskInicio],
                        decoration: const InputDecoration(
                          labelText: 'Início (Ex: 07:00)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Obrigatório';
                          }
                          if (!RegExp(
                            r'^([01][0-9]|2[0-3]):[0-5][0-9]$',
                          ).hasMatch(v)) {
                            return 'Inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: fimCtrl,
                        inputFormatters: [maskFim],
                        decoration: const InputDecoration(
                          labelText: 'Fim (Ex: 07:50)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Obrigatório';
                          }
                          if (!RegExp(
                            r'^([01][0-9]|2[0-3]):[0-5][0-9]$',
                          ).hasMatch(v)) {
                            return 'Inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: disciplinaSelecionada,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Disciplina / Professor',
                    border: OutlineInputBorder(),
                  ),
                  items: opcoesSelect
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['disciplina'].toString(),
                          child: Text(
                            '${p['disciplina']} - ${p['professorNome']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => disciplinaSelecionada = v!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctxAula),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formAulaKey.currentState!.validate()) {
                return;
              }

              int novoInicio = _timeToMinutes(inicioCtrl.text);
              int novoFim = _timeToMinutes(fimCtrl.text);

              if (novoInicio >= novoFim) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Atenção: O horário de início não pode ser maior ou igual ao horário final!',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              bool isConflito = _horariosLocal.any((h) {
                if (h['dia'] != diaSelecionado) {
                  return false;
                }
                if (h['id'] == horarioEdicao?['id']) {
                  return false;
                }

                int hInicio = _timeToMinutes(h['inicio']);
                int hFim = _timeToMinutes(h['fim']);

                return (novoInicio < hFim) && (novoFim > hInicio);
              });

              if (isConflito) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Conflito! Já existe uma aula ou intervalo ocupando este horário.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final profOficial = opcoesSelect.firstWhere(
                (p) => p['disciplina'] == disciplinaSelecionada,
              );
              final novoHorario = {
                'id':
                    horarioEdicao?['id'] ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                'dia': diaSelecionado,
                'inicio': inicioCtrl.text,
                'fim': fimCtrl.text,
                'disciplina': disciplinaSelecionada,
                'professorNome': profOficial['professorNome'],
                'professorId': profOficial['professorId'],
              };

              setState(() {
                if (horarioEdicao != null) {
                  final index = _horariosLocal.indexWhere(
                    (h) => h['id'] == horarioEdicao['id'],
                  );
                  if (index != -1) {
                    _horariosLocal[index] = novoHorario;
                  }
                } else {
                  _horariosLocal.add(novoHorario);
                }
                _atualizarMapaDeCores();
              });

              await _salvarNoBanco();
              if (!ctxAula.mounted) {
                return;
              }
              Navigator.pop(ctxAula);
              if (onSaved != null) {
                onSaved();
              }
            },
            child: const Text(
              'Salvar na Grade',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _removerHorario(String idHorario) async {
    setState(() {
      _horariosLocal.removeWhere((h) => h['id'] == idHorario);
      _atualizarMapaDeCores();
    });
    await _salvarNoBanco();
  }

  // ==========================================================================
  // FUNÇÃO DE VISUALIZAR GRADE SEMANAL INTERATIVA (TABELA)
  // ==========================================================================
  void _abrirVisualizacaoSemanal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setGridState) {
          
          Set<String> hUnicos = {};
          for (var h in _horariosLocal) {
            hUnicos.add('${h['inicio']} - ${h['fim']}');
          }
          List<String> linhasTempo = hUnicos.toList()..sort();

          List<String> diasUteis = [
            'SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA', 'SÁBADO', 'DOMINGO'
          ];

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.all(16), 
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95, 
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.grid_view_rounded, color: Colors.deepPurple),
                          const SizedBox(width: 8),
                          Text(
                            'Grade Semanal - ${widget.turma['nome']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade800,
                              elevation: 0,
                            ),
                            onPressed: () {
                              _abrirModalEdicaoAula(
                                onSaved: () => setGridState(() {}),
                              );
                            }, 
                            icon: const Icon(Icons.add, size: 18), 
                            label: const Text('Nova Aula')
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true, 
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            dataRowMinHeight: 50,
                            dataRowMaxHeight: 85, 
                            headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                            border: TableBorder.all(
                              color: Colors.grey.shade300,
                              width: 0.5,
                            ),
                            columns: [
                              const DataColumn(
                                label: Text(
                                  'HORÁRIO',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...diasUteis.map(
                                (d) => DataColumn(
                                  label: Text(
                                    d,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                            rows: linhasTempo.map((tempo) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      tempo,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  ...diasUteis.map((dia) {
                                    
                                    Map<String, dynamic>? aulaEncontrada;
                                    try {
                                      aulaEncontrada = _horariosLocal.firstWhere(
                                        (h) => h['dia'] == dia && '${h['inicio']} - ${h['fim']}' == tempo,
                                      );
                                    } catch (_) {
                                      aulaEncontrada = null;
                                    }

                                    if (aulaEncontrada != null) {
                                      final isIntervalo = aulaEncontrada['disciplina'] == 'INTERVALO';
                                      
                                      return DataCell(
                                        Ink(
                                          width: 140, 
                                          decoration: BoxDecoration(
                                            color: isIntervalo
                                                ? Colors.grey.shade200
                                                : _getBgTileColor(aulaEncontrada['disciplina']),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(4),
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctxAcao) => AlertDialog(
                                                  title: Text(aulaEncontrada!['disciplina']),
                                                  content: const Text('O que deseja fazer com este horário?'),
                                                  actions: [
                                                    TextButton.icon(
                                                      icon: const Icon(Icons.delete, color: Colors.red),
                                                      label: const Text('Excluir', style: TextStyle(color: Colors.red)),
                                                      onPressed: () {
                                                        Navigator.pop(ctxAcao);
                                                        _removerHorario(aulaEncontrada!['id']);
                                                        setGridState(() {});
                                                      }
                                                    ),
                                                    TextButton.icon(
                                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                                      label: const Text('Editar', style: TextStyle(color: Colors.blue)),
                                                      onPressed: () {
                                                        Navigator.pop(ctxAcao);
                                                        _abrirModalEdicaoAula(
                                                          horarioEdicao: aulaEncontrada,
                                                          onSaved: () => setGridState(() {}),
                                                        );
                                                      }
                                                    )
                                                  ]
                                                )
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    aulaEncontrada['disciplina'],
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: isIntervalo
                                                          ? Colors.black54
                                                          : _getTextColor(aulaEncontrada['disciplina']),
                                                    ),
                                                  ),
                                                  if (!isIntervalo)
                                                    Text(
                                                      aulaEncontrada['professorNome'],
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis, 
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: _getTextColor(
                                                          aulaEncontrada['disciplina'],
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      // Célula Vazia (Botão Adicionar)
                                      return DataCell(
                                        Ink(
                                          width: 140, 
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue.shade100, style: BorderStyle.solid)
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(4),
                                            onTap: () {
                                              _abrirModalEdicaoAula(
                                                diaPreSelecionado: dia,
                                                horarioPreSelecionado: tempo,
                                                onSaved: () => setGridState(() {}),
                                              );
                                            },
                                            child: const Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.add, size: 14, color: Colors.blue),
                                                  SizedBox(width: 4),
                                                  Text('Adicionar', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold))
                                                ]
                                              )
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Fechar Visão',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  // ==========================================================================
  // FUNÇÃO DE GERAR PDF DA GRADE SEMANAL
  // ==========================================================================
  Future<void> _gerarEImprimirHorarioPdf(Color corPrimaria) async {
    final doc = pw.Document();

    Set<String> hUnicos = {};
    for (var h in _horariosLocal) {
      hUnicos.add('${h['inicio']} - ${h['fim']}');
    }
    List<String> linhasTempo = hUnicos.toList()..sort();

    // Filtra apenas os dias que possuem alguma aula cadastrada (para dar ainda mais espaço)
    final diasDaSemanaCompletos = [
      'SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA', 'SÁBADO', 'DOMINGO'
    ];
    List<String> diasAtivos = diasDaSemanaCompletos.where((dia) {
      return _horariosLocal.any((h) => h['dia'] == dia);
    }).toList();

    final pdfCorPrimaria = PdfColor.fromInt(corPrimaria.value);
    final turno = widget.turma['turno'] ?? '';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, 
        margin: const pw.EdgeInsets.all(20), // Diminui a margem para caber mais tabela
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'QUADRO DE HORÁRIOS - ${widget.turma['nome']} (${widget.turma['anoLetivo']})' + (turno.isNotEmpty ? ' - $turno' : ''),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfCorPrimaria,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                context: context,
                headerDecoration: pw.BoxDecoration(
                  color: pdfCorPrimaria,
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8, // Cabeçalho menor para não ter quebra de linha
                ),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 2), // Padding menor
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8), // Coluna de horário mais fina
                  for (int i = 1; i <= diasAtivos.length; i++)
                    i: const pw.FlexColumnWidth(2),
                },
                headers: ['HORÁRIO', ...diasAtivos],
                data: linhasTempo.map((tempo) {
                  // Quebra de linha no horário: 07:00 \n 07:50
                  final partesTempo = tempo.split(' - ');
                  final tempoFormatado = partesTempo.join('\n');

                  List<dynamic> row = [
                    pw.Text(
                      tempoFormatado, 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), 
                      textAlign: pw.TextAlign.center
                    )
                  ];
                  
                  for (String dia in diasAtivos) {
                    try {
                      final aula = _horariosLocal.firstWhere(
                        (h) => h['dia'] == dia && '${h['inicio']} - ${h['fim']}' == tempo,
                      );
                      if (aula['disciplina'] == 'INTERVALO') {
                        row.add(
                          pw.Text(
                            'INTERVALO', 
                            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)
                          )
                        );
                      } else {
                        row.add(
                          pw.Column(
                            mainAxisSize: pw.MainAxisSize.min,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                aula['disciplina'], 
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), // Maior e Negrito
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                aula['professorNome'], 
                                style: const pw.TextStyle(fontSize: 6), // Menor, como pediu
                                textAlign: pw.TextAlign.center,
                              ),
                            ]
                          )
                        );
                      }
                    } catch (e) {
                      row.add(pw.Text('---', style: const pw.TextStyle(color: PdfColors.grey)));
                    }
                  }
                  return row;
                }).toList(),
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Gerado por Domex Edu - Gestão Escolar Inteligente',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Horario_${widget.turma['nome']}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final estadoProfessores = ref.watch(professoresStreamProvider);
    final listaProfessores = estadoProfessores.value ?? [];
    final corPrimaria = Theme.of(context).primaryColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Quadro de Horários',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _abrirModalEdicaoAula(),
            icon: const Icon(Icons.add),
            label: const Text('Nova Aula / Intervalo'),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 500,
        child: ListView.builder(
          itemCount: _diasDaSemana.length,
          itemBuilder: (context, index) {
            final dia = _diasDaSemana[index];
            final aulasDoDia = _horariosLocal
                .where((h) => h['dia'] == dia)
                .toList();
            
            aulasDoDia.sort(
              (a, b) => (a['inicio'] ?? '').compareTo(b['inicio'] ?? ''),
            );

            if (aulasDoDia.isEmpty) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                elevation: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        dia,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Livre / Nenhuma aula cadastrada',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  ],
                ),
              );
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              elevation: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      dia,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  ...aulasDoDia.map((aula) {
                    bool isIntervalo = aula['disciplina'] == 'INTERVALO';

                    String? fotoProfessor;
                    if (!isIntervalo) {
                      final profEncontrado = listaProfessores.firstWhere(
                        (p) =>
                            (aula['professorId'] != null &&
                                p['id'] == aula['professorId']) ||
                            (p['nome'] ?? '')
                                    .toString()
                                    .trim()
                                    .toUpperCase() ==
                                (aula['professorNome'] ?? '')
                                    .toString()
                                    .trim()
                                    .toUpperCase(),
                        orElse: () => {},
                      );
                      if (profEncontrado.isNotEmpty) {
                        fotoProfessor = profEncontrado['fotoUrl'];
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: _getBgTileColor(aula['disciplina']),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getBgTagColor(aula['disciplina']),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${aula['inicio']} - ${aula['fim']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getTextColor(aula['disciplina']),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              aula['disciplina'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getTextColor(aula['disciplina']),
                              ),
                            ),
                            if (!isIntervalo) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: fotoProfessor != null
                                    ? () => _mostrarFotoAmpliada(
                                        context,
                                        fotoProfessor!,
                                      )
                                    : null,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white,
                                  backgroundImage: fotoProfessor != null
                                      ? NetworkImage(fotoProfessor)
                                      : null,
                                  child: fotoProfessor == null
                                      ? Icon(
                                          Icons.person,
                                          size: 14,
                                          color: _getTextColor(
                                            aula['disciplina'],
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: isIntervalo
                            ? null
                            : Text(
                                'Prof. ${aula['professorNome']}',
                                style: TextStyle(
                                  color: _getTextColor(
                                    aula['disciplina'],
                                  ).withOpacity(0.7),
                                ),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                                size: 20,
                              ),
                              onPressed: () => _abrirModalEdicaoAula(
                                horarioEdicao: aula,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _removerHorario(aula['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        if (_horariosLocal.isNotEmpty) ...[
          TextButton.icon(
            onPressed: _abrirVisualizacaoSemanal,
            icon: const Icon(Icons.grid_view_rounded, color: Colors.deepPurple),
            label: const Text(
              'Visualizar Grade',
              style: TextStyle(color: Colors.deepPurple),
            ),
          ),
          TextButton.icon(
            onPressed: () => _gerarEImprimirHorarioPdf(corPrimaria),
            icon: const Icon(Icons.print_rounded, color: Colors.blue),
            label: const Text(
              'Exportar PDF',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Fechar Painel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}