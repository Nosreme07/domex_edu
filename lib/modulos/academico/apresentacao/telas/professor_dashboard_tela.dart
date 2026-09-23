import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// WIDGET DO LETREIRO ANIMADO (ROLAGEM INFINITA)
// ============================================================================
class LetreiroAvisos extends StatefulWidget {
  final String texto;
  const LetreiroAvisos({super.key, required this.texto});

  @override
  State<LetreiroAvisos> createState() => _LetreiroAvisosState();
}

class _LetreiroAvisosState extends State<LetreiroAvisos> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iniciarAnimacao();
    });
  }

  void _iniciarAnimacao() {
    _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        
        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(currentScroll + 1.5); 
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        border: Border(bottom: BorderSide(color: Colors.orange.shade200))
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(), 
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Align(
              alignment: Alignment.center,
              child: Row(
                children: [
                  Icon(Icons.campaign_rounded, color: Colors.orange.shade800, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.texto,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// TELA PRINCIPAL DO DASHBOARD
// ============================================================================
class ProfessorDashboardTela extends ConsumerStatefulWidget {
  const ProfessorDashboardTela({super.key});

  @override
  ConsumerState<ProfessorDashboardTela> createState() => _ProfessorDashboardTelaState();
}

class _ProfessorDashboardTelaState extends ConsumerState<ProfessorDashboardTela> {
  String _anoSelecionado = DateTime.now().year.toString();
  final List<String> _diasSemanaAbrev = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

  String _obterDiaSemanaAtualFirebase() {
    switch (DateTime.now().weekday) {
      case 1: return 'SEGUNDA';
      case 2: return 'TERÇA';
      case 3: return 'QUARTA';
      case 4: return 'QUINTA';
      case 5: return 'SEXTA';
      case 6: return 'SÁBADO';
      case 7: return 'DOMINGO';
      default: return '';
    }
  }

  String _nomeDiaCompleto(String dia) {
    switch (dia) {
      case 'SEGUNDA': return 'Segunda-feira';
      case 'TERÇA': return 'Terça-feira';
      case 'QUARTA': return 'Quarta-feira';
      case 'QUINTA': return 'Quinta-feira';
      case 'SEXTA': return 'Sexta-feira';
      case 'SÁBADO': return 'Sábado';
      case 'DOMINGO': return 'Domingo';
      default: return dia;
    }
  }

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

  void _mostrarDetalhesRapidos(BuildContext context, Map<String, dynamic> prof) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Ficha Rápida', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nome Completo', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            Text(prof['nome'] ?? 'Não informado', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            Text('CPF', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            Text(prof['cpf'] ?? 'Não informado', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            
            Text('Contato', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            Text(prof['telefone'] ?? 'Não informado', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            
            Text('Disciplinas Habilitadas', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            Text((prof['disciplinas'] as List? ?? []).join(', ').isEmpty ? 'Geral' : (prof['disciplinas'] as List).join(', '), style: const TextStyle(fontSize: 14, color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _obterFeriadosNacionais(int ano) {
    return [
      {'id': 'feriado_1_$ano', 'titulo': 'Confrat. Universal', 'data': '01/01/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_2_$ano', 'titulo': 'Tiradentes', 'data': '21/04/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_3_$ano', 'titulo': 'Dia do Trabalhador', 'data': '01/05/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_4_$ano', 'titulo': 'Indep. do Brasil', 'data': '07/09/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_5_$ano', 'titulo': 'N. S. Aparecida', 'data': '12/10/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_6_$ano', 'titulo': 'Finados', 'data': '02/11/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_7_$ano', 'titulo': 'Proc. da República', 'data': '15/11/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_8_$ano', 'titulo': 'Natal', 'data': '25/12/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
    ];
  }

  DateTime? _converterDataString(String dataStr) {
    try {
      final partes = dataStr.split('/');
      if (partes.length == 3) {
        return DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
      }
    } catch (_) {}
    return null;
  }

  Color _getCorPorTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('feriado') || t.contains('recesso')) return Colors.red;
    if (t.contains('avaliação')) return Colors.orange;
    if (t.contains('reunião')) return Colors.blue;
    if (t.contains('escolar')) return Colors.green;
    return Colors.purple; 
  }

  Future<int> _buscarQuantidadeAlunos(String tenantId, String turmaId) async {
    try {
      final snapshotPrincipal = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('alunos')
          .where('turmaId', isEqualTo: turmaId).where('status', isEqualTo: 'Ativo').count().get();

      final snapshotExtra = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('alunos')
          .where('turmasExtrasIds', arrayContains: turmaId).where('status', isEqualTo: 'Ativo').count().get();

      return (snapshotPrincipal.count ?? 0) + (snapshotExtra.count ?? 0);
    } catch (e) {
      return 0;
    }
  }

  String _abreviarDia(String dia) {
    switch (dia.trim().toUpperCase()) {
      case 'SEGUNDA': return 'Seg.';
      case 'TERÇA': return 'Ter.';
      case 'QUARTA': return 'Qua.';
      case 'QUINTA': return 'Qui.';
      case 'SEXTA': return 'Sex.';
      case 'SÁBADO': return 'Sáb.';
      case 'DOMINGO': return 'Dom.';
      default: return dia;
    }
  }

  Widget _buildErrorState(String title, String message, {bool isBlock = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isBlock ? Icons.block_rounded : Icons.person_off_rounded, size: 64, color: isBlock ? Colors.red : Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isBlock ? Colors.red : Colors.black87)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final usuarioLogado = ref.watch(authProvider).value;

    if (usuarioLogado == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: corPrimaria)));
    }

    final emailUsuario = usuarioLogado.email.trim().toLowerCase();
    final profId = usuarioLogado.id.trim().toLowerCase(); 
    final tenantId = usuarioLogado.tenantId; // AGORA TEMOS O ID DA ESCOLA
    final nomeEscola = usuarioLogado.nomeEscola ?? 'Escola Domex Edu';

    // Cria as ligações diretas ao banco de dados isolando a escola correta
    final turmasStream = FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').snapshots();
    final profsStream = FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('professores').snapshots();
    final calStream = FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('calendario').snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: turmasStream,
      builder: (context, snapTurmas) {
        if (!snapTurmas.hasData) return Scaffold(body: Center(child: CircularProgressIndicator(color: corPrimaria)));
        
        final turmas = snapTurmas.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
        
        final Set<String> anosSet = {DateTime.now().year.toString()};
        for (var t in turmas) {
          if (t['anoLetivo'] != null && t['anoLetivo'].toString().isNotEmpty && t['status'] != 'Inativa') {
            anosSet.add(t['anoLetivo'].toString());
          }
        }
        
        final listaAnos = anosSet.toList()..sort((a, b) => b.compareTo(a));
        final String anoExibicao = listaAnos.contains(_anoSelecionado) ? _anoSelecionado : listaAnos.first;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: StreamBuilder<QuerySnapshot>(
            stream: profsStream,
            builder: (context, snapProfs) {
              if (!snapProfs.hasData) return Center(child: CircularProgressIndicator(color: corPrimaria));
              
              final professores = snapProfs.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();

              final profMap = professores.where((p) {
                final emailProf = (p['email'] ?? '').toString().trim().toLowerCase();
                final idProf = (p['id'] ?? '').toString().trim().toLowerCase();
                
                return idProf == profId || (emailProf.isNotEmpty && emailProf == emailUsuario);
              }).toList();

              if (profMap.isEmpty) {
                return _buildErrorState('Professor não encontrado.', 'A sua ficha de professor não foi localizada no cadastro desta escola.');
              }

              final professorLogado = profMap.first;
              final isAtivo = professorLogado['status'] == 'Ativo';

              if (!isAtivo) {
                return _buildErrorState('Acesso Bloqueado', 'Seu cadastro consta como inativo na escola.', isBlock: true);
              }

              final profNome = professorLogado['nome'] ?? 'Professor(a)';
              final profFoto = professorLogado['fotoUrl'];
              final idOriginalProf = professorLogado['id']; // Pega o ID original com maiúsculas para cruzar com as turmas

              final minhasTurmasBrutas = turmas.where((t) {
                if (t['status'] == 'Inativa') return false;
                final vinculados = t['professoresVinculados'] as List? ?? [];
                return vinculados.any((v) => v['professorId'] == idOriginalProf);
              }).toList();

              final minhasTurmas = minhasTurmasBrutas.where((t) => t['anoLetivo'] == anoExibicao).toList();
              minhasTurmas.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: corPrimaria, 
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => _mostrarFotoAmpliadaGlobal(context, profFoto),
                          borderRadius: BorderRadius.circular(40),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white24,
                            backgroundImage: profFoto != null && profFoto.toString().isNotEmpty ? NetworkImage(profFoto) : null,
                            child: (profFoto == null || profFoto.toString().isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 24) : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _mostrarDetalhesRapidos(context, professorLogado),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Olá, $profNome',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  nomeEscola,
                                  style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: anoExibicao,
                              dropdownColor: corPrimaria,
                              icon: const Padding(padding: EdgeInsets.only(left: 4.0), child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16)),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                              onChanged: (novoAno) {
                                if (novoAno != null) setState(() => _anoSelecionado = novoAno);
                              },
                              items: listaAnos.map((ano) => DropdownMenuItem(value: ano, child: Text(ano))).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('avisos').where('tipoDestinatario', isEqualTo: 'PROFESSORES').snapshots(),
                    builder: (context, snapAvisos) {
                      if (!snapAvisos.hasData || snapAvisos.data!.docs.isEmpty) return const SizedBox.shrink();
                      
                      var docs = snapAvisos.data!.docs;
                      String avisosJuntos = docs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return "   •   ${data['remetenteNome']}: ${data['mensagem']}";
                      }).join("       ");

                      return LetreiroAvisos(texto: avisosJuntos);
                    }
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.event_note_rounded, color: Colors.orange, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Agenda da Semana',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => context.go('/professor/calendario'),
                                child: const Text('Ver Calendário', style: TextStyle(fontSize: 12)),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),

                          StreamBuilder<QuerySnapshot>(
                            stream: calStream,
                            builder: (context, snapCal) {
                              if (!snapCal.hasData) return const SizedBox(height: 70, child: Center(child: CircularProgressIndicator()));
                              
                              final eventosRaw = snapCal.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();

                              DateTime hoje = DateTime.now();
                              DateTime inicioSemana = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: hoje.weekday - 1));
                              DateTime fimSemana = inicioSemana.add(const Duration(days: 6, hours: 23, minutes: 59));

                              List<Map<String, dynamic>> todosEventos = List.from(eventosRaw);
                              todosEventos.addAll(_obterFeriadosNacionais(hoje.year));

                              List<Map<String, dynamic>> eventosSemana = [];
                              for(var e in todosEventos) {
                                DateTime? d = _converterDataString(e['data'] ?? '');
                                if (d != null && d.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) && d.isBefore(fimSemana.add(const Duration(seconds: 1)))) {
                                  eventosSemana.add(e);
                                }
                              }

                              eventosSemana.sort((a, b) => (_converterDataString(a['data']) ?? hoje).compareTo(_converterDataString(b['data']) ?? hoje));

                              if (eventosSemana.isEmpty) {
                                return Container(
                                  width: double.infinity,
                                  height: 70,
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.event_available_rounded, color: Colors.grey.shade400, size: 24),
                                      const SizedBox(height: 4),
                                      Text('Nenhum evento agendado para esta semana.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                );
                              }

                              return SizedBox(
                                height: 75,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: eventosSemana.length,
                                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final evento = eventosSemana[index];
                                    final dataEvento = _converterDataString(evento['data']);
                                    final cor = _getCorPorTipo(evento['tipo']);
                                    final isHoje = dataEvento != null && dataEvento.day == hoje.day && dataEvento.month == hoje.month;

                                    return Container(
                                      width: 240, 
                                      decoration: BoxDecoration(
                                        color: isHoje ? cor.withAlpha(20) : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isHoje ? cor.withAlpha(100) : Colors.grey.shade300)
                                      ),
                                      child: Row(
                                        children: [
                                          Container(width: 4, decoration: BoxDecoration(color: cor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(color: cor.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(dataEvento != null ? _diasSemanaAbrev[dataEvento.weekday - 1] : '---', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cor)),
                                                        Text(dataEvento?.day.toString().padLeft(2, '0') ?? '--', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(evento['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                        const SizedBox(height: 2),
                                                        Text(evento['tipo'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          ),

                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Icon(Icons.meeting_room_rounded, color: corPrimaria, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Minhas Turmas em $anoExibicao (${minhasTurmas.length})',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: corPrimaria),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          minhasTurmas.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 40),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.folder_off_rounded, size: 64, color: Colors.grey.shade300),
                                        const SizedBox(height: 16),
                                        Text('Sem turmas em $anoExibicao.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    int colunas = 1;
                                    if (constraints.maxWidth > 1200) colunas = 4;
                                    else if (constraints.maxWidth > 800) colunas = 3;
                                    else if (constraints.maxWidth > 600) colunas = 2;

                                    return GridView.builder(
                                      shrinkWrap: true, 
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: colunas,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        mainAxisExtent: 260,
                                      ),
                                      itemCount: minhasTurmas.length,
                                      itemBuilder: (context, index) {
                                        final turma = minhasTurmas[index];

                                        final horariosGerais = turma['horarios'] as List? ?? [];
                                        final meusHorariosRaw = horariosGerais.where((h) => h['professorId'] == idOriginalProf).toList();

                                        List<String> meusHorarios = [];
                                        for (var h in meusHorariosRaw) {
                                          String diaAbrev = _abreviarDia(h['dia']?.toString() ?? '');
                                          String inicio = h['inicio']?.toString() ?? '';
                                          String fim = h['fim']?.toString() ?? '';
                                          if (diaAbrev.isNotEmpty && inicio.isNotEmpty) meusHorarios.add('$diaAbrev $inicio - $fim');
                                        }

                                        if (meusHorarios.isEmpty) meusHorarios.add('Nenhum horário definido');

                                        return Card(
                                          elevation: 1,
                                          shadowColor: corPrimaria.withAlpha(20),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                                      child: Icon(Icons.meeting_room_rounded, color: corPrimaria, size: 20),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            turma['nome'] ?? 'Turma',
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                            maxLines: 2, overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          FutureBuilder<int>(
                                                            future: _buscarQuantidadeAlunos(tenantId, turma['id']),
                                                            initialData: turma['qtdAlunos'] ?? 0,
                                                            builder: (context, snapshot) {
                                                              final qtdAlunos = snapshot.data ?? 0;
                                                              return Row(
                                                                children: [
                                                                  Icon(Icons.people_alt_rounded, size: 12, color: Colors.grey.shade600),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    snapshot.connectionState == ConnectionState.waiting ? 'Carregando...' : '$qtdAlunos Alunos',
                                                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                                                                  ),
                                                                  const SizedBox(width: 8),
                                                                  Text('• ${turma['turno'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
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

                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade100)),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('Grade de Aulas:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                                      const SizedBox(height: 4),
                                                      ...meusHorarios.map((h) => Padding(
                                                        padding: const EdgeInsets.only(bottom: 2),
                                                        child: Row(
                                                          children: [
                                                            const Icon(Icons.schedule_rounded, size: 10, color: Colors.blueGrey),
                                                            const SizedBox(width: 4),
                                                            Text(h, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                                                          ],
                                                        ),
                                                      )),
                                                    ],
                                                  ),
                                                ),
                                                const Spacer(),
                                                
                                                SizedBox(
                                                  width: double.infinity,
                                                  height: 36,
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.symmetric(horizontal: 16)),
                                                    onPressed: () {
                                                      final diaHojeStr = _obterDiaSemanaAtualFirebase();
                                                      
                                                      bool temAulaHoje = meusHorariosRaw.any((h) => 
                                                        (h['dia']?.toString().trim().toUpperCase() ?? '') == diaHojeStr
                                                      );

                                                      if (temAulaHoje || meusHorariosRaw.isEmpty) {
                                                        context.push('/diario/${turma['id']}');
                                                      } else {
                                                        showDialog(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                            title: const Row(
                                                              children: [
                                                                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                                                                SizedBox(width: 8),
                                                                Text('Atenção', style: TextStyle(fontWeight: FontWeight.bold)),
                                                              ],
                                                            ),
                                                            content: Text(
                                                              'Hoje é ${_nomeDiaCompleto(diaHojeStr)}, e você não possui horário cadastrado nesta turma para hoje.\n\nTem certeza que deseja iniciar a aula mesmo assim?',
                                                              style: const TextStyle(fontSize: 15),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.pop(ctx), 
                                                                child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
                                                              ),
                                                              ElevatedButton(
                                                                style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white),
                                                                onPressed: () {
                                                                  Navigator.pop(ctx);
                                                                  context.push('/diario/${turma['id']}');
                                                                },
                                                                child: const Text('Sim, Iniciar Aula', style: TextStyle(fontWeight: FontWeight.bold)),
                                                              )
                                                            ],
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                                                    label: const Text('Iniciar Aula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}