import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/turma_provider.dart';
import '../estado/secretaria_provider.dart'; 
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class AdminVisaoGeralTela extends ConsumerStatefulWidget {
  const AdminVisaoGeralTela({super.key});

  @override
  ConsumerState<AdminVisaoGeralTela> createState() => _AdminVisaoGeralTelaState();
}

class _AdminVisaoGeralTelaState extends ConsumerState<AdminVisaoGeralTela> {
  String _anoSelecionado = DateTime.now().year.toString();

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final usuarioLogado = ref.watch(authProvider).value;
    final nomeAdmin = usuarioLogado?.nome ?? 'Administração';
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    final estadoAlunos = ref.watch(alunosStreamProvider);
    final estadoProfs = ref.watch(professoresStreamProvider);
    final estadoTurmas = ref.watch(turmasStreamProvider);
    final estadoSecretaria = ref.watch(secretariaStreamProvider);

    final Set<String> anosSet = {DateTime.now().year.toString()};
    estadoTurmas.whenData((turmas) {
      for (var t in turmas) {
        if (t['anoLetivo'] != null && t['anoLetivo'].toString().isNotEmpty) {
          anosSet.add(t['anoLetivo'].toString());
        }
      }
    });

    final listaAnos = anosSet.toList()..sort((a, b) => b.compareTo(a));

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
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================================
            // CABEÇALHO (HEADER)
            // =================================================================
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(isMobile ? 24 : 40, 40, isMobile ? 24 : 40, 80),
              decoration: BoxDecoration(
                color: corPrimaria,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                boxShadow: [BoxShadow(color: corPrimaria.withAlpha(60), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: SafeArea(
                bottom: false,
                child: Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Visão Geral do Sistema',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Olá, $nomeAdmin 👋\nAqui está o resumo da escola para o ano letivo de $_anoSelecionado.',
                          style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ),
                    if (isMobile) const SizedBox(height: 24),
                    
                    // Seletor de Ano Letivo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(50), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 12),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _anoSelecionado,
                              dropdownColor: corPrimaria,
                              icon: const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white)),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                              onChanged: (novoAno) {
                                if (novoAno != null) {
                                  setState(() => _anoSelecionado = novoAno);
                                }
                              },
                              items: listaAnos.map((ano) => DropdownMenuItem(value: ano, child: Text('Ano Letivo: $ano'))).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // =================================================================
            // CARDS DE MÉTRICAS (SOBREPOSTOS AO CABEÇALHO)
            // =================================================================
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40),
                child: isMobile
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _CardMetrica(titulo: 'Alunos', valor: qtdAlunos.toString(), icone: Icons.school_rounded, cor: Colors.blue, onTap: () => context.go('/admin/cadastros', extra: 0))),
                              const SizedBox(width: 16),
                              Expanded(child: _CardMetrica(titulo: 'Professores', valor: qtdProfs.toString(), icone: Icons.assignment_ind_rounded, cor: Colors.green, onTap: () => context.go('/admin/cadastros', extra: 1))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _CardMetrica(titulo: 'Funcionários', valor: qtdSec.toString(), icone: Icons.support_agent_rounded, cor: Colors.teal, onTap: () => context.go('/admin/cadastros', extra: 2))),
                              const SizedBox(width: 16),
                              Expanded(child: _CardMetrica(titulo: 'Turmas ($_anoSelecionado)', valor: qtdTurmas.toString(), icone: Icons.meeting_room_rounded, cor: Colors.orange, onTap: () => context.go('/admin/cadastros', extra: 3))),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _CardMetrica(titulo: 'Alunos', valor: qtdAlunos.toString(), icone: Icons.school_rounded, cor: Colors.blue, onTap: () => context.go('/admin/cadastros', extra: 0))),
                          const SizedBox(width: 16),
                          Expanded(child: _CardMetrica(titulo: 'Professores', valor: qtdProfs.toString(), icone: Icons.assignment_ind_rounded, cor: Colors.green, onTap: () => context.go('/admin/cadastros', extra: 1))),
                          const SizedBox(width: 16),
                          Expanded(child: _CardMetrica(titulo: 'Funcionários', valor: qtdSec.toString(), icone: Icons.support_agent_rounded, cor: Colors.teal, onTap: () => context.go('/admin/cadastros', extra: 2))),
                          const SizedBox(width: 16),
                          Expanded(child: _CardMetrica(titulo: 'Turmas ($_anoSelecionado)', valor: qtdTurmas.toString(), icone: Icons.meeting_room_rounded, cor: Colors.orange, onTap: () => context.go('/admin/cadastros', extra: 3))),
                        ],
                      ),
              ),
            ),

            // =================================================================
            // CORPO INFERIOR (AÇÕES RÁPIDAS E STATUS)
            // =================================================================
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40),
              child: Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                // O segredo do alinhamento: CrossAxisAlignment.end alinha tudo pela base!
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Lado Esquerdo: Ações Rápidas
                  Expanded(
                    flex: isMobile ? 0 : 7,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: corPrimaria.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.bolt_rounded, color: corPrimaria)),
                              const SizedBox(width: 12),
                              const Text('Ações Rápidas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: isMobile ? 2 : 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            // Deixa o botão retangular mais "achatado" para desktop
                            childAspectRatio: isMobile ? 2.5 : 2.8,
                            children: [
                              _BotaoAtalho(titulo: 'Novo Aluno', icone: Icons.person_add_alt_1_rounded, cor: Colors.blue, onTap: () => context.push('/admin/cadastros/aluno/novo')),
                              _BotaoAtalho(titulo: 'Novo Professor', icone: Icons.person_add_alt_rounded, cor: Colors.green, onTap: () => context.push('/admin/cadastros/professor/novo')),
                              _BotaoAtalho(titulo: 'Nova Turma', icone: Icons.meeting_room_rounded, cor: Colors.orange, onTap: () => context.push('/admin/cadastros/turma/novo')),
                              _BotaoAtalho(titulo: 'Novo Funcionário', icone: Icons.support_agent_rounded, cor: Colors.teal, onTap: () => context.push('/admin/cadastros/secretaria/novo')),
                              _BotaoAtalho(titulo: 'Gerir Usuários', icone: Icons.manage_accounts_rounded, cor: Colors.deepPurple, onTap: () => context.go('/admin/cadastros', extra: 4)),
                              _BotaoAtalho(titulo: 'Avisos', icone: Icons.campaign_rounded, cor: Colors.pink, onTap: () => context.push('/admin/mensagens')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (isMobile) const SizedBox(height: 32) else const SizedBox(width: 32),

                  // Lado Direito: Status do Sistema (Menor e no Canto)
                  Expanded(
                    flex: isMobile ? 0 : 3,
                    child: Card(
                      elevation: 0,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0), // Padding menor para compactar
                        child: Column(
                          mainAxisSize: MainAxisSize.min, // Ocupa apenas o espaço necessário
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.monitor_heart_rounded, color: Colors.grey, size: 18),
                                SizedBox(width: 8),
                                Text('Status do Sistema', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ]
                            ),
                            const Divider(height: 24),
                            const _StatusLinha(icone: Icons.cloud_done_rounded, cor: Colors.green, texto: 'Banco Conectado'),
                            const SizedBox(height: 12),
                            const _StatusLinha(icone: Icons.security_rounded, cor: Colors.blue, texto: 'Backup Automático Ativo'),
                            const SizedBox(height: 12),
                            _StatusLinha(icone: Icons.sync_rounded, cor: corPrimaria, texto: 'Sincronização Online'),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.green.withAlpha(100), blurRadius: 4, spreadRadius: 1)]),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('Todos os sistemas operacionais e estáveis.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11))),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENTES AUXILIARES DE UI
// ============================================================================

class _CardMetrica extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final MaterialColor cor;
  final VoidCallback onTap;

  const _CardMetrica({required this.titulo, required this.valor, required this.icone, required this.cor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 160, // Aumentado para 160 para evitar overflow no texto inferior
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: cor.shade100, width: 1.5), 
          boxShadow: [BoxShadow(color: cor.withAlpha(15), blurRadius: 12, offset: const Offset(0, 6))]
        ),
        child: Stack(
          children: [
            // Ícone de fundo gigante no canto inferior direito
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(icone, size: 100, color: cor.withAlpha(15)),
            ),
            // Conteúdo principal
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10), 
                        decoration: BoxDecoration(color: cor.shade50, borderRadius: BorderRadius.circular(12)), 
                        child: Icon(icone, color: cor.shade700, size: 22)
                      ),
                      Icon(Icons.arrow_outward_rounded, color: Colors.grey.shade300, size: 20),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(valor, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1)),
                      const SizedBox(height: 4),
                      Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoAtalho extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final MaterialColor cor;
  final VoidCallback onTap;

  const _BotaoAtalho({required this.titulo, required this.icone, required this.cor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, 
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white, 
          border: Border.all(color: cor.shade100), 
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cor.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: cor.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo, 
                style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          ]
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
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: cor.withAlpha(20), borderRadius: BorderRadius.circular(8)),
          child: Icon(icone, color: cor, size: 14)
        ), 
        const SizedBox(width: 12), 
        Expanded(child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)))
      ]
    );
  }
}