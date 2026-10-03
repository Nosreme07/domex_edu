import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ============================================================================
// IMPORTAÇÃO DOS PROVEDORES (Buscadores de dados em tempo real)
// ============================================================================
import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/turma_provider.dart';
import '../estado/secretaria_provider.dart'; 

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
    final estadoSecretaria = ref.watch(secretariaStreamProvider);

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

    int qtdAlunos = 0;
    if (estadoAlunos.hasValue) {
      qtdAlunos = estadoAlunos.value!.where((a) => a['status'] != 'Inativo' && a['status'] != 'Transferido').length;
    }

    int qtdProfs = 0;
    if (estadoProfs.hasValue) {
      qtdProfs = estadoProfs.value!.where((p) => p['status'] == 'Ativo').length;
    }

    int qtdSec = 0;
    if (estadoSecretaria.hasValue) {
      qtdSec = estadoSecretaria.value!.where((s) => s['status'] == 'Ativo').length;
    }

    int qtdTurmas = 0;
    if (estadoTurmas.hasValue) {
      qtdTurmas = estadoTurmas.value!.where((t) => t['anoLetivo']?.toString() == _anoSelecionado && t['status'] != 'Inativa').length;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Fundo cinza bem clarinho (moderno)
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
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                            if (novoAno != null) {
                              setState(() => _anoSelecionado = novoAno);
                            }
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
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = (constraints.maxWidth - (16 * 3)) / 4;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCard(context, 'Alunos', qtdAlunos.toString(), Icons.school_rounded, Colors.blue, 0, cardWidth), // ABA 0 (Alunos)
                    _buildMetricCard(context, 'Professores', qtdProfs.toString(), Icons.assignment_ind_rounded, Colors.green, 1, cardWidth), // ABA 1 (Professores)
                    _buildMetricCard(context, 'Funcionários', qtdSec.toString(), Icons.support_agent_rounded, Colors.teal, 2, cardWidth), // ABA 2 (Secretaria)
                    _buildMetricCard(context, 'Turmas ($_anoSelecionado)', qtdTurmas.toString(), Icons.meeting_room_rounded, Colors.orange, 3, cardWidth), // ABA 3 (Turmas)
                  ],
                );
              },
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
                                onTap: () => context.push('/admin/cadastros/aluno/novo'),
                              ),
                              _BotaoAtalho(
                                titulo: 'Novo Professor',
                                icone: Icons.person_add_alt_rounded,
                                cor: Colors.green,
                                onTap: () => context.push('/admin/cadastros/professor/novo'),
                              ),
                              _BotaoAtalho(
                                titulo: 'Novo Funcionário',
                                icone: Icons.support_agent_rounded,
                                cor: Colors.teal,
                                onTap: () => context.push('/admin/cadastros/secretaria/novo'),
                              ),
                              _BotaoAtalho(
                                titulo: 'Nova Turma',
                                icone: Icons.meeting_room_rounded,
                                cor: Colors.orange,
                                onTap: () => context.push('/admin/cadastros/turma/novo'),
                              ),
                              _BotaoAtalho(
                                titulo: 'Usuários',
                                icone: Icons.manage_accounts_rounded,
                                cor: Colors.deepPurple,
                                onTap: () => context.go('/admin/cadastros', extra: 4), // ABA 4 (Usuários)
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

  Widget _buildMetricCard(BuildContext context, String titulo, String valor, IconData icone, MaterialColor cor, int indexAba, double width) {
    return InkWell(
      onTap: () {
        context.go('/admin/cadastros', extra: indexAba);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.shade200),
          boxShadow: [
            BoxShadow(
              color: cor.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cor.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icone, color: cor.shade700),
                ),
                Icon(Icons.arrow_outward_rounded, color: Colors.grey.shade400, size: 20),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES (Designers dos Componentes da Tela)
// ============================================================================

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