import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Adicionado para fazer a contagem no banco

// Importamos o provedor de Autenticação para saber quem está logado
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// Importamos os provedores do Admin
import '../../../admin/apresentacao/estado/professor_provider.dart';
import '../../../admin/apresentacao/estado/turma_provider.dart';

class ProfessorDashboardTela extends ConsumerStatefulWidget {
  const ProfessorDashboardTela({super.key});

  @override
  ConsumerState<ProfessorDashboardTela> createState() =>
      _ProfessorDashboardTelaState();
}

class _ProfessorDashboardTelaState
    extends ConsumerState<ProfessorDashboardTela> {
  // Filtro de ano letivo (por padrão, o ano atual)
  String _anoSelecionado = DateTime.now().year.toString();

  // ==========================================================
  // FUNÇÃO QUE CONTA OS ALUNOS DIRETAMENTE NO BANCO DE DADOS
  // ==========================================================
  Future<int> _buscarQuantidadeAlunos(String tenantId, String turmaId) async {
    try {
      // 1. Conta alunos que têm essa turma como PRINCIPAL
      final snapshotPrincipal = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('alunos')
          .where('turmaId', isEqualTo: turmaId)
          .where('status', isEqualTo: 'Ativo') // Conta apenas alunos ativos
          .count()
          .get();

      // 2. Conta alunos que têm essa turma como EXTRA (Ex: Natação, Inglês extra)
      final snapshotExtra = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('alunos')
          .where('turmasExtrasIds', arrayContains: turmaId)
          .where('status', isEqualTo: 'Ativo')
          .count()
          .get();

      // Soma os dois e retorna
      return (snapshotPrincipal.count ?? 0) + (snapshotExtra.count ?? 0);
    } catch (e) {
      return 0; // Em caso de erro (ex: sem internet), mostra 0 provisoriamente
    }
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final usuarioLogado = ref.watch(authProvider).value;

    if (usuarioLogado == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: corPrimaria)),
      );
    }

    final emailUsuario = usuarioLogado.email.trim().toLowerCase();
    final nomeEscola = usuarioLogado.nomeEscola ?? 'Escola Domex Edu';
    final tenantId = usuarioLogado
        .id; // O ID da sessão já carrega o código da escola (Ex: ESC-0003)

    final estadoProfessores = ref.watch(professoresStreamProvider);
    final estadoTurmas = ref.watch(turmasStreamProvider);

    return estadoTurmas.when(
      loading: () => Scaffold(
        body: Center(child: CircularProgressIndicator(color: corPrimaria)),
      ),
      error: (e, s) =>
          Scaffold(body: Center(child: Text('Erro ao carregar turmas: $e'))),
      data: (turmas) {
        final Set<String> anosSet = {DateTime.now().year.toString()};
        for (var t in turmas) {
          if (t['anoLetivo'] != null &&
              t['anoLetivo'].toString().isNotEmpty &&
              t['status'] != 'Inativa') {
            anosSet.add(t['anoLetivo'].toString());
          }
        }
        final listaAnos = anosSet.toList()..sort((a, b) => b.compareTo(a));
        if (!listaAnos.contains(_anoSelecionado))
          _anoSelecionado = listaAnos.first;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: estadoProfessores.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: corPrimaria)),
            error: (e, s) => Center(child: Text('Erro ao carregar dados: $e')),
            data: (professores) {
              final profMap = professores.where((p) {
                final emailProf = (p['email'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                return emailProf == emailUsuario;
              }).toList();

              if (profMap.isEmpty) {
                return _buildErrorState(
                  'Professor não encontrado.',
                  'O e-mail ($emailUsuario) não está vinculado.',
                );
              }

              final professorLogado = profMap.first;
              final isAtivo = professorLogado['status'] == 'Ativo';

              if (!isAtivo) {
                return _buildErrorState(
                  'Acesso Bloqueado',
                  'Seu cadastro consta como inativo.',
                  isBlock: true,
                );
              }

              final profId = professorLogado['id'];
              final profNome = professorLogado['nome'] ?? 'Professor';
              final profFoto = professorLogado['fotoUrl'];

              final minhasTurmasBrutas = turmas.where((t) {
                if (t['status'] == 'Inativa') return false;
                final vinculados = t['professoresVinculados'] as List? ?? [];
                return vinculados.any((v) => v['professorId'] == profId);
              }).toList();

              final minhasTurmas = minhasTurmasBrutas
                  .where((t) => t['anoLetivo'] == _anoSelecionado)
                  .toList();
              minhasTurmas.sort(
                (a, b) => (a['nome'] ?? '').toString().compareTo(
                  (b['nome'] ?? '').toString(),
                ),
              );

              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ========================================================
                    // LINHA 1: Nome da Escola e Dropdown de Ano
                    // ========================================================
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            nomeEscola,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _anoSelecionado,
                              icon: Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: corPrimaria,
                                  size: 18,
                                ),
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: corPrimaria,
                                fontSize: 14,
                              ),
                              onChanged: (novoAno) {
                                if (novoAno != null)
                                  setState(() => _anoSelecionado = novoAno);
                              },
                              items: listaAnos
                                  .map(
                                    (ano) => DropdownMenuItem(
                                      value: ano,
                                      child: Text('Ano: $ano'),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ========================================================
                    // LINHA 2: Nome do Professor e Foto Perfil
                    // ========================================================
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: corPrimaria.withAlpha(30),
                          backgroundImage:
                              profFoto != null && profFoto.toString().isNotEmpty
                              ? NetworkImage(profFoto)
                              : null,
                          child:
                              (profFoto == null || profFoto.toString().isEmpty)
                              ? Icon(Icons.person, color: corPrimaria, size: 24)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Olá, $profNome',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bem-vindo(a) ao seu painel acadêmico.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_rounded,
                          color: Colors.deepPurple,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Minhas Turmas em $_anoSelecionado (${minhasTurmas.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ========================================================
                    // GRID DE TURMAS
                    // ========================================================
                    Expanded(
                      child: minhasTurmas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_off_rounded,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Sem turmas em $_anoSelecionado.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                int colunas = 1;
                                if (constraints.maxWidth > 1200) {
                                  colunas = 4;
                                } else if (constraints.maxWidth > 800) {
                                  colunas = 3;
                                } else if (constraints.maxWidth > 600) {
                                  colunas = 2;
                                }

                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: colunas,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        mainAxisExtent: 260,
                                      ),
                                  itemCount: minhasTurmas.length,
                                  itemBuilder: (context, index) {
                                    final turma = minhasTurmas[index];

                                    // Leitura real da Grade de Horários
                                    final horariosGerais =
                                        turma['horarios'] as List? ?? [];
                                    final meusHorariosRaw = horariosGerais
                                        .where(
                                          (h) => h['professorId'] == profId,
                                        )
                                        .toList();

                                    List<String> meusHorarios = [];
                                    for (var h in meusHorariosRaw) {
                                      String diaAbrev = _abreviarDia(
                                        h['dia']?.toString() ?? '',
                                      );
                                      String inicio =
                                          h['inicio']?.toString() ?? '';
                                      String fim = h['fim']?.toString() ?? '';

                                      if (diaAbrev.isNotEmpty &&
                                          inicio.isNotEmpty) {
                                        meusHorarios.add(
                                          '$diaAbrev $inicio - $fim',
                                        );
                                      }
                                    }

                                    if (meusHorarios.isEmpty) {
                                      meusHorarios.add(
                                        'Nenhum horário definido',
                                      );
                                    }

                                    return Card(
                                      elevation: 1,
                                      shadowColor: corPrimaria.withAlpha(20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: corPrimaria
                                                        .withAlpha(20),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.meeting_room_rounded,
                                                    color: corPrimaria,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        turma['nome'] ??
                                                            'Turma',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),

                                                      // ==========================================================
                                                      // FUTURE BUILDER: BUSCANDO OS ALUNOS AO VIVO!
                                                      // ==========================================================
                                                      FutureBuilder<int>(
                                                        future:
                                                            _buscarQuantidadeAlunos(
                                                              tenantId,
                                                              turma['id'],
                                                            ),
                                                        initialData:
                                                            turma['qtdAlunos'] ??
                                                            0, // Fallback rápido se houver
                                                        builder: (context, snapshot) {
                                                          final qtdAlunos =
                                                              snapshot.data ??
                                                              0;

                                                          return Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .people_alt_rounded,
                                                                size: 12,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                snapshot.connectionState ==
                                                                        ConnectionState
                                                                            .waiting
                                                                    ? 'Carregando...'
                                                                    : '$qtdAlunos Alunos',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade700,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text(
                                                                '• ${turma['turno'] ?? 'N/A'}',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade500,
                                                                  fontSize: 11,
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),

                                            // Bloco: Grade de Aulas
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.grey.shade100,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Grade de Aulas:',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blueGrey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  ...meusHorarios.map(
                                                    (h) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 2,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .schedule_rounded,
                                                            size: 10,
                                                            color:
                                                                Colors.blueGrey,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            h,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey
                                                                  .shade800,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const Spacer(),

                                            // Botão Acessar Diário
                                            SizedBox(
                                              width: double.infinity,
                                              height: 36,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: corPrimaria,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                onPressed: () {
                                                  context.push(
                                                    '/diario/${turma['id']}',
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.edit_document,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Abrir Turma',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Helper para formatar o dia da semana do Firebase (Ex: SEGUNDA -> Seg.)
  String _abreviarDia(String dia) {
    switch (dia.trim().toUpperCase()) {
      case 'SEGUNDA':
        return 'Seg.';
      case 'TERÇA':
        return 'Ter.';
      case 'QUARTA':
        return 'Qua.';
      case 'QUINTA':
        return 'Qui.';
      case 'SEXTA':
        return 'Sex.';
      case 'SÁBADO':
        return 'Sáb.';
      case 'DOMINGO':
        return 'Dom.';
      default:
        return dia;
    }
  }

  Widget _buildErrorState(
    String title,
    String message, {
    bool isBlock = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isBlock ? Icons.block_rounded : Icons.person_off_rounded,
            size: 64,
            color: isBlock ? Colors.red : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isBlock ? Colors.red : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
