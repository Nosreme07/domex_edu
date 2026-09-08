import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ============================================================================
// IMPORTAÇÃO DOS PROVEDORES (Buscadores de dados em tempo real)
// ============================================================================
import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/turma_provider.dart';
import '../estado/secretaria_provider.dart'; // <-- NOVO: Import do provedor de funcionários

// Provedor de autenticação (usado internamente pelos outros provedores para achar a escola)
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class AdminVisaoGeralTela extends ConsumerStatefulWidget {
  const AdminVisaoGeralTela({super.key});

  @override
  ConsumerState<AdminVisaoGeralTela> createState() =>
      _AdminVisaoGeralTelaState();
}

class _AdminVisaoGeralTelaState extends ConsumerState<AdminVisaoGeralTela> {
  // Começa sempre travado no ano atual para não ter erro ao abrir a tela
  String _anoSelecionado = DateTime.now().year.toString();

  @override
  Widget build(BuildContext context) {
    // Captura a cor principal configurada pela escola (Azul, Vermelho, etc.)
    final corPrimaria = Theme.of(context).primaryColor;

    // ========================================================================
    // ESCUTANDO OS BANCOS DE DADOS EM TEMPO REAL
    // ========================================================================
    final estadoAlunos = ref.watch(alunosStreamProvider);
    final estadoProfs = ref.watch(professoresStreamProvider);
    final estadoTurmas = ref.watch(turmasStreamProvider);
    final estadoSecretaria = ref.watch(
      secretariaStreamProvider,
    ); // <-- NOVO: Escutando os funcionários

    // ========================================================================
    // LÓGICA DO SELETOR DE ANO LETIVO
    // Descobre todos os anos cadastrados nas turmas para montar o filtro
    // ========================================================================
    final Set<String> anosSet = {DateTime.now().year.toString()};
    estadoTurmas.whenData((turmas) {
      for (var t in turmas) {
        if (t['anoLetivo'] != null && t['anoLetivo'].toString().isNotEmpty) {
          anosSet.add(t['anoLetivo'].toString());
        }
      }
    });

    // Organiza do maior para o menor (Ex: 2027, 2026, 2025)
    final listaAnos = anosSet.toList()..sort((a, b) => b.compareTo(a));

    // Proteção extra: se o ano selecionado sumir do banco, volta para o mais recente
    if (!listaAnos.contains(_anoSelecionado)) {
      _anoSelecionado = listaAnos.first;
    }

    return Scaffold(
      backgroundColor:
          Colors.grey.shade50, // Fundo cinza bem clarinho (moderno)
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================================================================
            // CABEÇALHO DA TELA COM TÍTULO E SELETOR DE ANO
            // ================================================================
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visão Geral do Sistema',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Resumo dos dados da escola para o ano letivo de $_anoSelecionado',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),

                // Seletor de Ano Estilizado com a Cor Primária da Escola
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: corPrimaria.withAlpha(80),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: corPrimaria.withAlpha(20),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: corPrimaria,
                      ),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _anoSelecionado,
                          icon: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: corPrimaria,
                            ),
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: corPrimaria,
                            fontSize: 16,
                          ),
                          onChanged: (novoAno) {
                            if (novoAno != null)
                              setState(() => _anoSelecionado = novoAno);
                          },
                          items: listaAnos
                              .map(
                                (ano) => DropdownMenuItem(
                                  value: ano,
                                  child: Text('Ano Vigente: $ano'),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ================================================================
            // INDICADORES DE DESEMPENHO (KPIs - OS 4 CARDS SUPERIORES)
            // ================================================================
            Row(
              children: [
                Expanded(
                  child: _ConstruirCardResumo(
                    titulo: 'Alunos Ativos',
                    icone: Icons.school_rounded,
                    cor: Colors
                        .blue, // Cores mantidas fixas para padrão visual de Dashboards (cada métrica uma cor)
                    estado: estadoAlunos,
                    calculo: (dados) => dados
                        .where(
                          (a) =>
                              a['status'] != 'Inativo' &&
                              a['status'] != 'Transferido',
                        )
                        .length
                        .toString(),
                    onTap: () => context.go('/admin/cadastros', extra: 0),
                  ),
                ),
                const SizedBox(
                  width: 16,
                ), // Espaçamento levemente reduzido para caber 4 cards bem
                Expanded(
                  child: _ConstruirCardResumo(
                    titulo: 'Professores Ativos',
                    icone: Icons.assignment_ind_rounded,
                    cor: Colors.green,
                    estado: estadoProfs,
                    calculo: (dados) => dados
                        .where((p) => p['status'] == 'Ativo')
                        .length
                        .toString(),
                    onTap: () => context.go('/admin/cadastros', extra: 2),
                  ),
                ),
                const SizedBox(width: 16),
                // --- NOVO CARD DE FUNCIONÁRIOS DA SECRETARIA ---
                Expanded(
                  child: _ConstruirCardResumo(
                    titulo: 'Funcionários Ativos',
                    icone: Icons.support_agent_rounded,
                    cor: Colors
                        .teal, // Cor verde-água para diferenciar dos professores
                    estado: estadoSecretaria,
                    calculo: (dados) => dados
                        .where((s) => s['status'] == 'Ativo')
                        .length
                        .toString(),
                    onTap: () => context.go(
                      '/admin/cadastros',
                      extra: 3,
                    ), // Aba 3 é a de Secretaria
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ConstruirCardResumo(
                    titulo: 'Turmas ($_anoSelecionado)',
                    icone: Icons.meeting_room_rounded,
                    cor: Colors.orange,
                    estado: estadoTurmas,
                    calculo: (dados) => dados
                        .where(
                          (t) =>
                              t['anoLetivo'] == _anoSelecionado &&
                              t['status'] != 'Inativa',
                        )
                        .length
                        .toString(),
                    onTap: () => context.go('/admin/cadastros', extra: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ================================================================
            // ÁREA INFERIOR: AÇÕES RÁPIDAS (ATALHOS) E STATUS DO SISTEMA
            // ================================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CARD GIGANTE DA ESQUERDA: Ações Rápidas
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 1,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bolt_rounded, color: corPrimaria),
                              const SizedBox(width: 8),
                              const Text(
                                'Ações Rápidas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _BotaoAtalho(
                                titulo: 'Novo Aluno',
                                icone: Icons.person_add_alt_1_rounded,
                                cor: Colors.blue,
                                onTap: () =>
                                    context.push('/admin/cadastros/aluno/novo'),
                              ),
                              _BotaoAtalho(
                                titulo: 'Novo Professor',
                                icone: Icons.person_add_alt_rounded,
                                cor: Colors.green,
                                onTap: () => context.push(
                                  '/admin/cadastros/professor/novo',
                                ),
                              ),
                              _BotaoAtalho(
                                titulo: 'Novo Funcionário',
                                icone: Icons.support_agent_rounded,
                                cor: Colors.teal,
                                onTap: () => context.push(
                                  '/admin/cadastros/secretaria/novo',
                                ),
                              ),
                              _BotaoAtalho(
                                titulo: 'Nova Turma',
                                icone: Icons.meeting_room_rounded,
                                cor: Colors.orange,
                                onTap: () =>
                                    context.push('/admin/cadastros/turma/novo'),
                              ),
                              _BotaoAtalho(
                                titulo: 'Novo Acesso',
                                icone: Icons.manage_accounts_rounded,
                                cor: Colors.deepPurple,
                                onTap: () =>
                                    context.go('/admin/cadastros', extra: 5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // CARD MENOR DA DIREITA: Status do Banco de Dados
                Expanded(
                  flex: 1,
                  child: Card(
                    elevation: 1,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Status do Sistema',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          const _StatusLinha(
                            icone: Icons.cloud_done_rounded,
                            cor: Colors.green,
                            texto: 'Banco de Dados Conectado',
                          ),
                          const SizedBox(height: 16),
                          const _StatusLinha(
                            icone: Icons.security_rounded,
                            cor: Colors.blue,
                            texto: 'Backup Automático Ativo',
                          ),
                          const SizedBox(height: 16),
                          _StatusLinha(
                            icone: Icons.sync_rounded,
                            cor: corPrimaria,
                            texto: 'Sincronização em Tempo Real',
                          ),
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
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES (Designers dos Componentes da Tela)
// ============================================================================

// --- Molde dos 4 Cards Coloridos Superiores ---
class _ConstruirCardResumo extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final Color cor;
  final AsyncValue<List<Map<String, dynamic>>> estado;
  final String Function(List<Map<String, dynamic>>) calculo;
  final VoidCallback? onTap;

  const _ConstruirCardResumo({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.estado,
    required this.calculo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: cor.withAlpha(40),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cor.withAlpha(50), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icone, color: cor),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ), // Ícone de "Ir para" moderno
                ],
              ),
              const SizedBox(height: 24),
              // Trata a leitura dos dados do Firebase (Carregando, Erro ou os Dados Prontos)
              estado.when(
                loading: () => const SizedBox(
                  height: 38,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, s) => Text(
                  'Erro',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                data: (dados) => Text(
                  calculo(dados),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Molde dos Botões Quadrados de "Ações Rápidas" ---
class _BotaoAtalho extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final Color cor;
  final VoidCallback onTap;

  const _BotaoAtalho({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140, // Largura fixa para ficarem todos alinhadinhos
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: cor.withAlpha(15),
          border: Border.all(color: cor.withAlpha(50)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 32),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Molde das linhas de "Status do Sistema" ---
class _StatusLinha extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String texto;

  const _StatusLinha({
    required this.icone,
    required this.cor,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, color: cor, size: 20),
        const SizedBox(width: 12),
        Text(
          texto,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
