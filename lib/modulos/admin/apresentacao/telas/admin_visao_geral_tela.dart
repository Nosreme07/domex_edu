import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/turma_provider.dart';

class AdminVisaoGeralTela extends ConsumerStatefulWidget {
  const AdminVisaoGeralTela({super.key});

  @override
  ConsumerState<AdminVisaoGeralTela> createState() => _AdminVisaoGeralTelaState();
}

class _AdminVisaoGeralTelaState extends ConsumerState<AdminVisaoGeralTela> {
  // Começa sempre travado no ano atual para não ter erro
  String _anoSelecionado = DateTime.now().year.toString();

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;

    // Lendo os dados do Firebase em tempo real
    final estadoAlunos = ref.watch(alunosStreamProvider);
    final estadoProfs = ref.watch(professoresStreamProvider);
    final estadoTurmas = ref.watch(turmasStreamProvider);

    // 1. Gera a lista de anos disponíveis dinamicamente (Ano Atual + Anos cadastrados nas Turmas)
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

    // Proteção extra caso o ano selecionado suma misteriosamente do banco
    if (!listaAnos.contains(_anoSelecionado)) {
      _anoSelecionado = listaAnos.first;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= CABEÇALHO COM SELETOR DE ANO =================
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Visão Geral do Sistema', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text('Resumo dos dados da escola para o ano letivo de $_anoSelecionado', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  ],
                ),
                const Spacer(),
                
                // NOVO: SELETOR DE ANO LETIVO
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200, width: 1.5)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _anoSelecionado,
                          icon: const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blue)),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
                          onChanged: (novoAno) {
                            if (novoAno != null) setState(() => _anoSelecionado = novoAno);
                          },
                          items: listaAnos.map((ano) => DropdownMenuItem(
                            value: ano, 
                            child: Text('Ano Vigente: $ano')
                          )).toList(),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 32),

            // ================= CARDS DE RESUMO (KPIs) =================
            Row(
              children: [
                Expanded(
                  child: _ConstruirCardResumo(
                    titulo: 'Alunos Ativos',
                    icone: Icons.school_rounded,
                    cor: Colors.blue,
                    estado: estadoAlunos,
                    calculo: (dados) => dados.where((a) => a['status'] != 'Inativo' && a['status'] != 'Transferido').length.toString(),
                    onTap: () => context.go('/admin/cadastros', extra: 0),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _ConstruirCardResumo(
                    titulo: 'Professores Ativos',
                    icone: Icons.assignment_ind_rounded,
                    cor: Colors.green,
                    estado: estadoProfs,
                    calculo: (dados) => dados.where((p) => p['status'] == 'Ativo').length.toString(),
                    onTap: () => context.go('/admin/cadastros', extra: 1),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _ConstruirCardResumo(
                    titulo: 'Turmas ($_anoSelecionado)',
                    icone: Icons.meeting_room_rounded,
                    cor: Colors.orange,
                    estado: estadoTurmas,
                    // Filtra as turmas especificamente pelo ano selecionado no topo!
                    calculo: (dados) => dados.where((t) => t['anoLetivo'] == _anoSelecionado && t['status'] != 'Inativa').length.toString(),
                    onTap: () => context.go('/admin/cadastros', extra: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ================= ÁREA INFERIOR: ATALHOS E STATUS =================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.bolt_rounded, color: Colors.amber), SizedBox(width: 8), Text('Ações Rápidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _BotaoAtalho(titulo: 'Nova Matrícula', icone: Icons.person_add_alt_1_rounded, cor: Colors.blue, onTap: () => context.push('/admin/cadastros/aluno/novo')),
                              _BotaoAtalho(titulo: 'Novo Professor', icone: Icons.person_add_alt_rounded, cor: Colors.green, onTap: () => context.push('/admin/cadastros/professor/novo')),
                              _BotaoAtalho(titulo: 'Nova Turma', icone: Icons.meeting_room_rounded, cor: Colors.orange, onTap: () => context.push('/admin/cadastros/turma/novo')),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                
                Expanded(
                  flex: 1,
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.info_outline_rounded, color: Colors.grey), SizedBox(width: 8), Text('Status do Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                          const Divider(height: 32),
                          const _StatusLinha(icone: Icons.cloud_done_rounded, cor: Colors.green, texto: 'Banco de Dados Conectado'),
                          const SizedBox(height: 16),
                          const _StatusLinha(icone: Icons.security_rounded, cor: Colors.blue, texto: 'Backup Automático Ativo'),
                          const SizedBox(height: 16),
                          _StatusLinha(icone: Icons.sync_rounded, cor: corPrimaria, texto: 'Sincronização em Tempo Real'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ================= WIDGETS AUXILIARES =================

class _ConstruirCardResumo extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final Color cor;
  final AsyncValue<List<Map<String, dynamic>>> estado;
  final String Function(List<Map<String, dynamic>>) calculo;
  final VoidCallback? onTap;

  const _ConstruirCardResumo({required this.titulo, required this.icone, required this.cor, required this.estado, required this.calculo, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cor.withAlpha(50), width: 2)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cor.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: Icon(icone, color: cor)),
                  const Spacer(),
                  Icon(Icons.open_in_new_rounded, color: Colors.grey.shade400, size: 20)
                ],
              ),
              const SizedBox(height: 24),
              estado.when(
                loading: () => const SizedBox(height: 38, child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator())),
                error: (e, s) => Text('Erro', style: TextStyle(color: Colors.red.shade700, fontSize: 24, fontWeight: FontWeight.bold)),
                data: (dados) => Text(calculo(dados), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              const SizedBox(height: 4),
              Text(titulo, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotaoAtalho extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final Color cor;
  final VoidCallback onTap;

  const _BotaoAtalho({required this.titulo, required this.icone, required this.cor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(color: cor.withAlpha(15), border: Border.all(color: cor.withAlpha(50)), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 32),
            const SizedBox(height: 12),
            Text(titulo, textAlign: TextAlign.center, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _StatusLinha extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String texto;

  const _StatusLinha({required this.icone, required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, color: cor, size: 20),
        const SizedBox(width: 12),
        Text(texto, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
      ],
    );
  }
}