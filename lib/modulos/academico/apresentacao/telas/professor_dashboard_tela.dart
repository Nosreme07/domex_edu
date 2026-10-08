import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';
import 'turma_calendario_tela.dart'; 

// Função auxiliar global para abrir PDFs
Future<void> _abrirLink(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

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
// TELA PRINCIPAL DO DASHBOARD DO PROFESSOR
// ============================================================================
class ProfessorDashboardTela extends ConsumerStatefulWidget {
  const ProfessorDashboardTela({super.key});

  @override
  ConsumerState<ProfessorDashboardTela> createState() => _ProfessorDashboardTelaState();
}

class _ProfessorDashboardTelaState extends ConsumerState<ProfessorDashboardTela> {
  String _anoSelecionado = DateTime.now().year.toString();
  bool _turmasExpandidas = true;

  final List<String> _diasSemanaAbrev = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  final List<String> _diasSemanaCompleto = ['SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA', 'SÁBADO', 'DOMINGO'];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
  }

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
      {'id': 'feriado_1_$ano', 'titulo': 'Confraternização Universal', 'data': '01/01/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_2_$ano', 'titulo': 'Tiradentes', 'data': '21/04/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_3_$ano', 'titulo': 'Dia do Trabalhador', 'data': '01/05/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_4_$ano', 'titulo': 'Independência do Brasil', 'data': '07/09/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_5_$ano', 'titulo': 'N. S. Aparecida', 'data': '12/10/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_6_$ano', 'titulo': 'Finados', 'data': '02/11/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
      {'id': 'feriado_7_$ano', 'titulo': 'Proclamação da República', 'data': '15/11/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true},
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

  String _formatarData(DateTime data) {
    return "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
  }

  Color _getCorPorTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('feriado') || t.contains('recesso')) return Colors.red;
    if (t.contains('avaliação') || t.contains('prova')) return Colors.red.shade700;
    if (t.contains('aula')) return Colors.blue.shade700;
    if (t.contains('reunião')) return Colors.deepPurple;
    if (t.contains('escolar')) return Colors.green;
    return Colors.orange; 
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

  Future<List<Map<String, dynamic>>> _carregarEventosDaSemana(String tenantId, String professorId, List<Map<String, dynamic>> turmas, List<dynamic> eventosGerais) async {
    DateTime hoje = DateTime.now();
    DateTime inicioSemana = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: hoje.weekday - 1));
    DateTime fimSemana = inicioSemana.add(const Duration(days: 6, hours: 23, minutes: 59));

    List<Map<String, dynamic>> listaSemana = [];

    // 1. Adiciona Feriados
    var feriados = _obterFeriadosNacionais(hoje.year);
    for(var f in feriados) {
      DateTime? d = _converterDataString(f['data']);
      if (d != null && d.isAfter(inicioSemana.subtract(const Duration(days: 1))) && d.isBefore(fimSemana.add(const Duration(days: 1)))) {
        listaSemana.add(f);
      }
    }

    // 2. Adiciona Eventos Gerais da Escola
    for (var e in eventosGerais) {
      DateTime? d = _converterDataString(e['data'] ?? e['dataEvento'] ?? '');
      if (d != null && d.isAfter(inicioSemana.subtract(const Duration(days: 1))) && d.isBefore(fimSemana.add(const Duration(days: 1)))) {
        listaSemana.add({...e, 'isGeral': true});
      }
    }

    // 3. Aulas na Grade e Eventos das Turmas
    for (var t in turmas) {
      // A) Aulas do Professor baseadas no Quadro de Horários da Turma
      List horarios = t['horarios'] ?? [];
      for (var h in horarios) {
        if (h['professorId'] == professorId) {
          int indexDia = _diasSemanaCompleto.indexOf(h['dia'].toString().toUpperCase());
          if (indexDia != -1) {
            DateTime dataAula = inicioSemana.add(Duration(days: indexDia));
            listaSemana.add({
              'id': 'aula_${t['id']}_${h['inicio']}_$indexDia',
              'titulo': 'Aula de ${h['disciplina']}',
              'data': _formatarData(dataAula),
              'tipo': 'Aula',
              'horario': '${h['inicio']} - ${h['fim']}',
              'turmaOrigem': t['nome']
            });
          }
        }
      }

      // B) Eventos Específicos da Turma (Ex: Semanas de Prova, Trabalhos)
      final evSnap = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(t['id']).collection('eventos').get();
      for (var doc in evSnap.docs) {
        var ev = doc.data();
        if (ev['tipo'] == 'Semana de Prova') {
          Map<String, dynamic> crono = ev['cronograma'] ?? {};
          crono.forEach((dataStr, blocosRaw) {
            DateTime? d = _converterDataString(dataStr);
            if (d != null && d.isAfter(inicioSemana.subtract(const Duration(days: 1))) && d.isBefore(fimSemana.add(const Duration(days: 1)))) {
              if (blocosRaw is Map && blocosRaw.isNotEmpty) {
                blocosRaw.forEach((tempo, disc) {
                  listaSemana.add({
                    'titulo': ev['titulo'] ?? 'Prova', 'data': dataStr, 'tipo': 'Prova',
                    'disciplina': disc, 'horario': tempo, 'turmaOrigem': t['nome']
                  });
                });
              } else if (blocosRaw is List && blocosRaw.isNotEmpty) {
                for (var disc in List<String>.from(blocosRaw)) {
                  listaSemana.add({
                    'titulo': ev['titulo'] ?? 'Prova', 'data': dataStr, 'tipo': 'Prova',
                    'disciplina': disc, 'turmaOrigem': t['nome']
                  });
                }
              }
            }
          });
        } else {
          String dataStr = ev['dataEvento'] ?? ev['data'] ?? '';
          if (dataStr.contains('-')) { final p = dataStr.split('-'); if (p.length == 3) dataStr = '${p[2]}/${p[1]}/${p[0]}'; }
          DateTime? d = _converterDataString(dataStr);
          if (d != null && d.isAfter(inicioSemana.subtract(const Duration(days: 1))) && d.isBefore(fimSemana.add(const Duration(days: 1)))) {
            listaSemana.add({...ev, 'data': dataStr, 'turmaOrigem': t['nome']});
          }
        }
      }
    }

    // Ordenação Final (Primeiro a data, depois o horário)
    listaSemana.sort((a, b) {
      int c = (_converterDataString(a['data']) ?? hoje).compareTo(_converterDataString(b['data']) ?? hoje);
      if (c == 0) {
        return (a['horario'] ?? '23:59').toString().compareTo((b['horario'] ?? '23:59').toString());
      }
      return c;
    });

    return listaSemana;
  }

  void _abrirModalMensagensProfessor(String tenantId, String profId, String profNome, List<Map<String, dynamic>> turmasProf, Color corPrimaria) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) {
            return _ModalMuralProfessor(
              tenantId: tenantId,
              profId: profId,
              profNome: profNome,
              turmas: turmasProf,
              corPrimaria: corPrimaria,
            );
          }
        );
      }
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
    final tenantId = usuarioLogado.tenantId; 
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
              final idOriginalProf = professorLogado['id']; 

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
                  
                  // NOVO BOTÃO DE MURAL DE AVISOS E COMUNICAÇÕES
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: () => _abrirModalMensagensProfessor(tenantId, idOriginalProf, profNome, minhasTurmas, corPrimaria),
                      icon: const Icon(Icons.campaign_rounded),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Comunicações e Avisos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          _BalaoNotificacaoAvisosProfessor(tenantId: tenantId, profId: idOriginalProf, turmas: minhasTurmas),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_note_rounded, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Minha Agenda da Semana',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // ==================================================================
                          // GRADE DA SEMANA (AULAS + EVENTOS GERAIS + EVENTOS DA TURMA)
                          // ==================================================================
                          StreamBuilder<QuerySnapshot>(
                            stream: calStream,
                            builder: (context, snapCal) {
                              if (!snapCal.hasData) return const SizedBox(height: 75, child: Center(child: CircularProgressIndicator()));
                              
                              final eventosRaw = snapCal.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();

                              return FutureBuilder<List<Map<String, dynamic>>>(
                                future: _carregarEventosDaSemana(tenantId, idOriginalProf, minhasTurmas, eventosRaw),
                                builder: (context, snapSemana) {
                                  if (snapSemana.connectionState == ConnectionState.waiting) return const SizedBox(height: 75, child: Center(child: CircularProgressIndicator()));
                                  
                                  final eventosSemana = snapSemana.data ?? [];
                                  
                                  if (eventosSemana.isEmpty) {
                                    return Container(
                                      width: double.infinity, height: 70,
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.event_available_rounded, color: Colors.grey.shade400, size: 24),
                                          const SizedBox(height: 4),
                                          Text('Sua agenda está livre nesta semana.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
                                        final isHoje = dataEvento != null && dataEvento.day == DateTime.now().day && dataEvento.month == DateTime.now().month;
                                        
                                        String tituloExtendido = evento['titulo'] ?? '';
                                        if (evento['disciplina'] != null && evento['disciplina'].toString().isNotEmpty && evento['tipo'] != 'Aula') {
                                          tituloExtendido += ' (${evento['disciplina']})';
                                        }

                                        return Container(
                                          width: 250, 
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
                                                            if (evento['turmaOrigem'] != null)
                                                              Container(margin: const EdgeInsets.only(bottom: 2), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(4)), child: Text(evento['turmaOrigem'], style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                            Text(tituloExtendido, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                            const SizedBox(height: 2),
                                                            Row(
                                                              children: [
                                                                Text(evento['tipo'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                                if (evento['horario'] != null) ...[
                                                                  const SizedBox(width: 4),
                                                                  Expanded(child: Text('• ${evento['horario']}', style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))
                                                                ]
                                                              ],
                                                            ),
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
                              );
                            }
                          ),

                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // ==================================================================
                          // BOTÃO EM CASCATA: MINHAS TURMAS (EXPANSION TILE ANIMADO)
                          // ==================================================================
                          InkWell(
                            onTap: () => setState(() => _turmasExpandidas = !_turmasExpandidas),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.meeting_room_rounded, color: corPrimaria, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Minhas Turmas em $anoExibicao (${minhasTurmas.length})',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: corPrimaria),
                                  ),
                                  const Spacer(),
                                  AnimatedRotation(
                                    turns: _turmasExpandidas ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(Icons.keyboard_arrow_down_rounded, color: corPrimaria),
                                  )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          AnimatedCrossFade(
                            firstChild: const SizedBox(width: double.infinity),
                            secondChild: minhasTurmas.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 20, bottom: 20),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.folder_off_rounded, size: 48, color: Colors.grey.shade300),
                                          const SizedBox(height: 16),
                                          Text('Sem turmas em $anoExibicao.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true, 
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: minhasTurmas.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                          child: ExpansionTile(
                                            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                            childrenPadding: const EdgeInsets.all(20),
                                            leading: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                              child: Icon(Icons.meeting_room_rounded, color: corPrimaria, size: 20),
                                            ),
                                            title: Text(
                                              turma['nome'] ?? 'Turma',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              maxLines: 2, overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: FutureBuilder<int>(
                                              future: _buscarQuantidadeAlunos(tenantId, turma['id']),
                                              initialData: turma['qtdAlunos'] ?? 0,
                                              builder: (context, snapshot) {
                                                final qtdAlunos = snapshot.data ?? 0;
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Row(
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
                                                  ),
                                                );
                                              },
                                            ),
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Sua Grade de Aulas:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                                    const SizedBox(height: 8),
                                                    ...meusHorarios.map((h) => Padding(
                                                      padding: const EdgeInsets.only(bottom: 4),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.schedule_rounded, size: 12, color: Colors.blueGrey),
                                                          const SizedBox(width: 6),
                                                          Text(h, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                                                        ],
                                                      ),
                                                    )),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton.icon(
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: corPrimaria,
                                                        side: BorderSide(color: corPrimaria),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        padding: const EdgeInsets.symmetric(vertical: 14)
                                                      ),
                                                      onPressed: () {
                                                        Navigator.push(context, MaterialPageRoute(builder: (context) => TurmaCalendarioTela(turma: turma)));
                                                      },
                                                      icon: const Icon(Icons.calendar_month, size: 18),
                                                      label: const Text('Calendário da Turma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                    )
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: corPrimaria, foregroundColor: Colors.white, 
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
                                                        padding: const EdgeInsets.symmetric(vertical: 14)
                                                      ),
                                                      onPressed: () {
                                                        final diaHojeStr = _obterDiaSemanaAtualFirebase();
                                                        bool temAulaHoje = meusHorariosRaw.any((h) => (h['dia']?.toString().trim().toUpperCase() ?? '') == diaHojeStr);

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
                                                      icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                                                      label: const Text('Iniciar Aula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                    )
                                                  )
                                                ],
                                              )
                                            ],
                                          ),
                                        )
                                      );
                                    },
                                  ),
                            crossFadeState: _turmasExpandidas ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
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

// ============================================================================
// WIDGET DO BALÃO DE NOTIFICAÇÃO (BOLINHA VERMELHA) PARA O PROFESSOR
// ============================================================================
class _BalaoNotificacaoAvisosProfessor extends StatefulWidget {
  final String tenantId;
  final String profId;
  final List<Map<String, dynamic>> turmas;

  const _BalaoNotificacaoAvisosProfessor({
    required this.tenantId, 
    required this.profId, 
    required this.turmas
  });

  @override
  State<_BalaoNotificacaoAvisosProfessor> createState() => _BalaoNotificacaoAvisosProfessorState();
}

class _BalaoNotificacaoAvisosProfessorState extends State<_BalaoNotificacaoAvisosProfessor> {
  int _naoLidos = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarCount();
    // Atualiza os dados a cada 5 segundos de forma invisível
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _carregarCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarCount() async {
    if (!mounted || widget.tenantId.isEmpty) return;
    int total = 0;
    final db = FirebaseFirestore.instance;

    try {
        // Varre Globais
        final globaisSnap = await db.collection('tenants').doc(widget.tenantId).collection('avisos_professores').get();
        for (var a in globaisSnap.docs) {
          final d = a.data();
          bool isParaMim = false;
          if (d['tipoDestinatario'] == 'TODOS' || d['tipoDestinatario'] == 'PROFESSORES' || d['professorAlvoId'] == widget.profId) {
             isParaMim = true;
             final lidos = List<String>.from(d['lidosPor'] ?? []);
             if (!lidos.contains(widget.profId) && d['remetenteId'] != widget.profId) {
               total++;
             }
          }

          if (d['remetenteId'] == widget.profId || isParaMim) {
            final respostasSnap = await a.reference.collection('respostas').where('lidaPorProfessor', isEqualTo: false).get();
            total += respostasSnap.docs.where((r) => r['remetenteId'] != widget.profId).length;
          }
        }

        // Varre Turmas
        for (var t in widget.turmas) {
          final avisosSnap = await db.collection('tenants').doc(widget.tenantId).collection('turmas').doc(t['id']).collection('avisos').get();
          for (var a in avisosSnap.docs) {
            final d = a.data();
            
            bool isParaMim = false;
            if (d['tipoDestinatario'] == 'TODOS' || d['tipoDestinatario'] == 'PROFESSORES') {
               isParaMim = true;
               final lidos = List<String>.from(d['lidosPor'] ?? []);
               if (!lidos.contains(widget.profId) && d['remetenteId'] != widget.profId) {
                 total++;
               }
            }

            if (d['remetenteId'] == widget.profId || isParaMim) {
              final respostasSnap = await a.reference.collection('respostas').where('lidaPorProfessor', isEqualTo: false).get();
              total += respostasSnap.docs.where((r) => r['remetenteId'] != widget.profId).length;
            }
          }
        }

        if (mounted) {
          setState(() {
            _naoLidos = total;
          });
        }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_naoLidos == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
      ),
      child: Text(
        _naoLidos > 9 ? '9+' : _naoLidos.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.1),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ============================================================================
// WIDGET EXTRA: MURAL DE AVISOS DO PROFESSOR (Feed + Envio)
// ============================================================================
class _ModalMuralProfessor extends StatefulWidget {
  final String tenantId;
  final String profId;
  final String profNome;
  final List<Map<String, dynamic>> turmas;
  final Color corPrimaria;

  const _ModalMuralProfessor({
    required this.tenantId,
    required this.profId,
    required this.profNome,
    required this.turmas,
    required this.corPrimaria,
  });

  @override
  State<_ModalMuralProfessor> createState() => _ModalMuralProfessorState();
}

class _ModalMuralProfessorState extends State<_ModalMuralProfessor> {
  // Controle de Abas
  int _abaAtual = 0;

  // Variáveis para o formulário de Envio
  final _formKey = GlobalKey<FormState>();
  String _destinatario = 'TURMA'; 
  String? _turmaSelecionadaId;
  String? _alunoSelecionadoId;
  final _tituloCtrl = TextEditingController();
  final _mensagemCtrl = TextEditingController();
  bool _enviando = false;
  List<Map<String, dynamic>> _alunosDaTurmaCache = [];
  bool _carregandoAlunos = false;

  // Refresh Feed
  int _recarregarTrigger = 0;
  int _limiteAvisos = 5;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensagemCtrl.dispose();
    super.dispose();
  }

  // BUSCA OS AVISOS RELEVANTES PARA O PROFESSOR
  Future<List<Map<String, dynamic>>> _carregarAvisos() async {
    final db = FirebaseFirestore.instance;
    List<Map<String, dynamic>> lista = [];

    // 1. Avisos Globais do Colégio (destinados a Professores ou a Toda a Escola)
    final globais = await db.collection('tenants').doc(widget.tenantId).collection('avisos_professores')
        .where('tipoDestinatario', whereIn: ['PROFESSORES', 'TODOS', 'PROFESSOR_ESPECIFICO'])
        .get();
    
    for (var d in globais.docs) {
      final data = d.data();
      if (data['tipoDestinatario'] == 'PROFESSOR_ESPECIFICO' && data['professorAlvoId'] != widget.profId) {
        continue;
      }
      lista.add({...data, 'id': d.id, 'turmaNome': 'Direção Escolar', 'isGlobal': true, 'turmaId': null});
    }

    // 2. Avisos nas Turmas onde ele leciona
    for (var t in widget.turmas) {
       final turmasSnap = await db.collection('tenants').doc(widget.tenantId).collection('turmas').doc(t['id']).collection('avisos').get();
       for (var a in turmasSnap.docs) {
          final data = a.data();
          final tipo = data['tipoDestinatario'];
          
          bool souDestinatario = (tipo == 'TODOS' || tipo == 'PROFESSORES');
          bool fuiEuQueEnviei = (data['remetenteId'] == widget.profId);
          
          if (souDestinatario || fuiEuQueEnviei) {
              lista.add({...data, 'id': a.id, 'turmaNome': t['nome'], 'isGlobal': false, 'turmaId': t['id']});
          }
       }
    }

    // 3. Desduplicação Inteligente
    List<Map<String, dynamic>> listaUnica = [];
    Set<String> assinaturas = {};
    for (var aviso in lista) {
        final assinatura = "${aviso['tipoDestinatario']}_${aviso['mensagem']}_${aviso['remetenteId']}";
        if (!assinaturas.contains(assinatura)) {
            assinaturas.add(assinatura);
            listaUnica.add(aviso);
        }
    }
    
    listaUnica.sort((a, b) {
      final tA = a['dataEnvio'] as Timestamp?;
      final tB = b['dataEnvio'] as Timestamp?;
      if (tA == null && tB == null) return 0;
      if (tA == null) return 1;
      if (tB == null) return -1;
      return tB.compareTo(tA);
    });

    return listaUnica;
  }

  // BUSCA OS ALUNOS QUANDO ELE SELECIONA UMA TURMA
  Future<void> _buscarAlunosDaTurma(String tId) async {
    setState(() => _carregandoAlunos = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('tenants').doc(widget.tenantId).collection('alunos')
          .where('status', isEqualTo: 'Ativo')
          .get();
      
      final filtrados = snap.docs.map((d) => {'id': d.id, ...d.data()}).where((a) {
         final trmId = a['turmaId']?.toString() ?? '';
         final extras = List<String>.from(a['turmasExtrasIds'] ?? []);
         return trmId == tId || extras.contains(tId);
      }).toList();

      filtrados.sort((a,b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

      setState(() {
        _alunosDaTurmaCache = filtrados;
      });
    } catch (_) {
      setState(() => _alunosDaTurmaCache = []);
    } finally {
      setState(() => _carregandoAlunos = false);
    }
  }

  // ENVIA O AVISO
  Future<void> _enviarAviso() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_destinatario != 'ADMINISTRACAO' && _turmaSelecionadaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione a turma destino.'), backgroundColor: Colors.red));
      return;
    }

    if ((_destinatario == 'ALUNO' || _destinatario == 'RESPONSAVEL') && _alunoSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o aluno destino.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _enviando = true);

    try {
      final db = FirebaseFirestore.instance;
      final titulo = _tituloCtrl.text.trim();
      final msgBase = _mensagemCtrl.text.trim();
      final msgComTitulo = titulo.isNotEmpty ? "📍 *$titulo*\n\n$msgBase" : msgBase;

      String? nomeAlunoStr;
      String? nomeRespStr;

      if (_destinatario == 'ALUNO' || _destinatario == 'RESPONSAVEL') {
        try {
          final alunoTarget = _alunosDaTurmaCache.firstWhere((a) => a['id'].toString() == _alunoSelecionadoId);
          nomeAlunoStr = alunoTarget['nome'];
          
          if (_destinatario == 'RESPONSAVEL') {
            List resps = alunoTarget['responsaveis'] as List? ?? [];
            if (resps.isNotEmpty) {
              var resp = resps.firstWhere((r) => r['principal'] == true, orElse: () => resps.first);
              nomeRespStr = resp['nome'];
            } else {
              nomeRespStr = 'Responsável';
            }
          }
        } catch (_) {}
      }

      final Map<String, dynamic> payload = {
         'titulo': titulo,
         'mensagem': msgComTitulo,
         'dataEnvio': FieldValue.serverTimestamp(),
         'remetenteNome': 'Professor(a) ${widget.profNome}',
         'remetenteId': widget.profId,
         'tipoDestinatario': _destinatario,
      };
      
      if (nomeAlunoStr != null) payload['alunoNome'] = nomeAlunoStr;
      if (nomeRespStr != null) payload['responsavelNome'] = nomeRespStr;

      if (_destinatario == 'ADMINISTRACAO') {
        // Envia para o admin central
        await db.collection('tenants').doc(widget.tenantId).collection('avisos_admin').add(payload);
      } else {
        // Envia para a turma
        if (_destinatario == 'ALUNO' || _destinatario == 'RESPONSAVEL') {
          payload['alunoId'] = _alunoSelecionadoId ?? '';
        }
        await db.collection('tenants').doc(widget.tenantId).collection('turmas').doc(_turmaSelecionadaId).collection('avisos').add(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aviso enviado com sucesso!'), backgroundColor: Colors.green));
        _tituloCtrl.clear();
        _mensagemCtrl.clear();
        setState(() {
           _alunoSelecionadoId = null;
           _recarregarTrigger++;
           _abaAtual = 0; // Volta para o feed
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ==========================================
  // CONSTRUÇÃO DAS ABAS
  // ==========================================

  Widget _buildFeedTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(_recarregarTrigger),
      future: _carregarAvisos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
        }
        final avisos = snapshot.data ?? [];
        if (avisos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speaker_notes_off_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Nenhum aviso encontrado.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ],
            ),
          );
        }

        final exibidos = avisos.take(_limiteAvisos).toList();
        final bool temMais = avisos.length > _limiteAvisos;

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: exibidos.length + (temMais ? 1 : 0),
          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == exibidos.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: widget.corPrimaria,
                    backgroundColor: widget.corPrimaria.withAlpha(20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  onPressed: () => setState(() => _limiteAvisos = avisos.length),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Ver Histórico Completo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              );
            }

            return AvisoCardWidgetProfessor(
              aviso: exibidos[index],
              tenantId: widget.tenantId,
              meuId: widget.profId,
              meuNome: widget.profNome,
              corPrimaria: widget.corPrimaria,
            );
          },
        );
      },
    );
  }

  Widget _buildFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enviar Novo Aviso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Selecione para quem deseja enviar o comunicado.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),

            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Público Alvo', 
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.people_alt_rounded),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _destinatario,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'TURMA', child: Text('Toda a Turma')),
                    DropdownMenuItem(value: 'ALUNO', child: Text('Um Aluno Específico')),
                    DropdownMenuItem(value: 'RESPONSAVEL', child: Text('Pais / Responsáveis de um Aluno')),
                    DropdownMenuItem(value: 'ADMINISTRACAO', child: Text('Para a Secretaria / Direção')),
                  ],
                  onChanged: (val) { 
                    setState(() { 
                      _destinatario = val!; 
                      _alunoSelecionadoId = null;
                    }); 
                  },
                ),
              ),
            ),

            if (_destinatario != 'ADMINISTRACAO') ...[
              const SizedBox(height: 20),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Selecione a Turma', 
                  border: OutlineInputBorder(), 
                  prefixIcon: Icon(Icons.meeting_room_rounded),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _turmaSelecionadaId,
                    isExpanded: true,
                    hint: const Text('Selecione...'),
                    items: widget.turmas.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['nome']))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _turmaSelecionadaId = val;
                        _alunoSelecionadoId = null;
                      });
                      _buscarAlunosDaTurma(val!);
                    },
                  ),
                ),
              ),
            ],

            if (_destinatario == 'ALUNO' || _destinatario == 'RESPONSAVEL') ...[
              const SizedBox(height: 20),
              if (_carregandoAlunos)
                const Center(child: CircularProgressIndicator())
              else if (_turmaSelecionadaId != null)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Selecione o Aluno', 
                    border: OutlineInputBorder(), 
                    prefixIcon: Icon(Icons.person_search_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _alunoSelecionadoId,
                      isExpanded: true,
                      itemHeight: _destinatario == 'RESPONSAVEL' ? 64.0 : 48.0, 
                      hint: const Text('Selecione...'),
                      items: _alunosDaTurmaCache.map((a) {
                        String nomeAluno = a['nome'] ?? 'Sem nome';
                        String textoResp = '';
                        
                        if (_destinatario == 'RESPONSAVEL') {
                          List resps = a['responsaveis'] as List? ?? [];
                          if (resps.isNotEmpty) {
                            var resp = resps.firstWhere((r) => r['principal'] == true, orElse: () => resps.first);
                            textoResp = 'Responsável: ${resp['nome'] ?? 'Sem nome'}';
                          } else {
                            textoResp = 'Sem responsável cadastrado';
                          }
                        }

                        return DropdownMenuItem(
                          value: a['id'].toString(), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(nomeAluno, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (textoResp.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    textoResp, 
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          )
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _alunoSelecionadoId = val),
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 24),
            TextFormField(
              controller: _tituloCtrl, 
              decoration: const InputDecoration(labelText: 'Título do Aviso (Opcional)', border: OutlineInputBorder()), 
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _mensagemCtrl, 
              maxLines: 5, 
              decoration: const InputDecoration(labelText: 'Escreva a sua mensagem...', alignLabelWithHint: true, border: OutlineInputBorder()), 
              validator: (v) => v!.isEmpty ? 'A mensagem não pode estar vazia.' : null
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: widget.corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _enviando ? null : _enviarAviso, 
                icon: _enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded), 
                label: Text(_enviando ? 'ENVIANDO...' : 'ENVIAR COMUNICADO', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: _abaAtual,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.campaign_rounded, color: widget.corPrimaria)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mural de Comunicações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Avisos e mensagens do corpo docente', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ])),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          TabBar(
            labelColor: widget.corPrimaria,
            unselectedLabelColor: Colors.grey,
            indicatorColor: widget.corPrimaria,
            indicatorWeight: 3,
            onTap: (index) => setState(() => _abaAtual = index),
            tabs: const [
              Tab(icon: Icon(Icons.notifications_active_rounded), text: 'Avisos Recentes'),
              Tab(icon: Icon(Icons.send_rounded), text: 'Enviar Nova Mensagem'),
            ]
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(), // Evita deslizar por engano quando digita
              children: [
                _buildFeedTab(),
                _buildFormTab(),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ============================================================================
// CARTÃO DE AVISO COM BOTÃO PARA CHAT E MENSAGENS FORMATADAS
// ============================================================================
class AvisoCardWidgetProfessor extends StatelessWidget {
  final Map<String, dynamic> aviso;
  final String tenantId;
  final String meuId;
  final String meuNome;
  final Color corPrimaria;

  const AvisoCardWidgetProfessor({
    super.key,
    required this.aviso,
    required this.tenantId,
    required this.meuId,
    required this.meuNome,
    required this.corPrimaria,
  });

  void _abrirChat(BuildContext context, DocumentReference avisoRef) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatAvisoModal(
        avisoRef: avisoRef,
        avisoData: aviso,
        meuId: meuId,
        meuNome: meuNome,
        corPrimaria: corPrimaria,
        tenantId: tenantId,
      ),
    );

    // Marca as respostas não lidas pelo professor como visualizadas em background
    avisoRef.collection('respostas').get().then((snap) {
      final batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['remetenteId'] != meuId && data['lidaPorProfessor'] != true) {
          batch.update(doc.reference, {'lidaPorProfessor': true});
          hasUpdates = true;
        }
      }
      if (hasUpdates) batch.commit();
    });
  }

  void _mostrarImagemFullscreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(url, fit: BoxFit.contain))),
            Positioned(top: 16, right: 16, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 32), onPressed: () => Navigator.pop(ctx))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataEnvio = aviso['dataEnvio'];
    final textoData = dataEnvio != null ? DateFormat('dd/MM HH:mm').format((dataEnvio as Timestamp).toDate()) : 'Enviando...';
    
    final isMeu = aviso['remetenteId'] == meuId;
    final tipoDest = aviso['tipoDestinatario'];

    final String nomeA = aviso['alunoNome'] ?? 'Aluno Específico';
    final String nomeR = aviso['responsavelNome'] ?? 'Responsável';

    String tagDestino = 'Aviso Global';
    Color corTag = Colors.blue;
    
    if (tipoDest == 'TODOS') {
      tagDestino = 'Escola Inteira'; corTag = Colors.green;
    } else if (tipoDest == 'PROFESSORES' || tipoDest == 'PROFESSOR_ESPECIFICO') {
      tagDestino = 'Diretoria / Coord.'; corTag = Colors.orange;
    } else if (tipoDest == 'ALUNO') {
      tagDestino = '$nomeA - ${aviso['turmaNome']}'; 
      corTag = Colors.purple;
    } else if (tipoDest == 'RESPONSAVEL') {
      tagDestino = 'Para o responsável - $nomeR - Resp. por $nomeA (${aviso['turmaNome']})'; 
      corTag = Colors.red;
    } else if (tipoDest == 'ADMINISTRACAO') {
      tagDestino = 'Para a Coordenação'; corTag = Colors.indigo;
    } else {
      tagDestino = 'Turma: ${aviso['turmaNome']}';
    }

    DocumentReference avisoRef;
    if (aviso['isGlobal'] == true) {
      avisoRef = FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('avisos_professores').doc(aviso['id']);
    } else {
      avisoRef = FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(aviso['turmaId']).collection('avisos').doc(aviso['id']);
    }

    final lidosPor = List<String>.from(aviso['lidosPor'] ?? []);
    final isLidoMsgOriginal = isMeu || lidosPor.contains(meuId);
    
    final String anexoUrl = aviso['anexoUrl'] ?? '';
    final String anexoNome = aviso['anexoNome'] ?? 'Anexo';
    final bool isAnexoPdf = anexoNome.toLowerCase().endsWith('.pdf');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isMeu ? 'Enviado por você' : 'De: ${aviso['remetenteNome']}', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(textoData, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (!isLidoMsgOriginal) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: const Text('NOVA MENSAGEM', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: corTag.withAlpha(20), borderRadius: BorderRadius.circular(6)),
            child: Text(tagDestino, style: TextStyle(color: corTag, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          
          if (anexoUrl.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: isAnexoPdf 
                ? InkWell(
                    onTap: () => _abrirLink(anexoUrl),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 24),
                          const SizedBox(width: 8),
                          Flexible(child: Text(anexoNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  )
                : InkWell(
                    onTap: () => _mostrarImagemFullscreen(context, anexoUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        anexoUrl, height: 150, width: double.infinity, fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(height: 150, width: double.infinity, color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator()));
                        },
                      ),
                    ),
                  ),
            ),
          ],

          if ((aviso['mensagem'] ?? '').toString().isNotEmpty)
            Text(aviso['mensagem'] ?? '', style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
          
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              if (!isLidoMsgOriginal)
                InkWell(
                  onTap: () {
                    avisoRef.update({'lidosPor': FieldValue.arrayUnion([meuId])});
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_rounded, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('Marcar lida', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),

              StreamBuilder<QuerySnapshot>(
                stream: avisoRef.collection('respostas').snapshots(),
                builder: (context, snapRespostas) {
                  int naoLidos = 0;
                  if (snapRespostas.hasData) {
                    for (var doc in snapRespostas.data!.docs) {
                      final rData = doc.data() as Map<String, dynamic>;
                      if (rData['remetenteId'] != meuId && rData['lidaPorProfessor'] != true) {
                        naoLidos++;
                      }
                    }
                  }
                  
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: corPrimaria,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        onPressed: () {
                          if (!isLidoMsgOriginal) {
                             avisoRef.update({
                               'lidosPor': FieldValue.arrayUnion([meuId])
                             });
                          }
                          _abrirChat(context, avisoRef);
                        },
                        icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: corPrimaria),
                        label: Text('Ver Respostas / Responder', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria, fontSize: 12)),
                      ),
                      if (naoLidos > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            decoration: BoxDecoration(
                              color: Colors.red, 
                              borderRadius: BorderRadius.circular(10), 
                              border: Border.all(color: Colors.white, width: 1.5)
                            ),
                            child: Text(
                              naoLidos > 9 ? '9+' : naoLidos.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                    ],
                  );
                }
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ============================================================================
// CHAT DO AVISO (Para o Professor COM ANEXOS E NOMES FORMATADOS)
// ============================================================================
class _ChatAvisoModal extends StatefulWidget {
  final DocumentReference avisoRef;
  final Map<String, dynamic> avisoData;
  final String meuId;
  final String meuNome;
  final Color corPrimaria;
  final String tenantId;

  const _ChatAvisoModal({
    required this.avisoRef,
    required this.avisoData,
    required this.meuId,
    required this.meuNome,
    required this.corPrimaria,
    required this.tenantId,
  });

  @override
  State<_ChatAvisoModal> createState() => _ChatAvisoModalState();
}

class _ChatAvisoModalState extends State<_ChatAvisoModal> {
  final TextEditingController _msgCtrl = TextEditingController();
  bool _enviando = false;
  File? _anexoFile;
  String? _anexoNomeChat;
  bool _isPdfChat = false;

  Future<void> _escolherAnexoChat() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _anexoFile = File(result.files.single.path!);
          _anexoNomeChat = result.files.single.name;
          _isPdfChat = _anexoNomeChat!.toLowerCase().endsWith('.pdf');
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao selecionar anexo: $e')));
    }
  }

  Future<void> _enviarResposta() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty && _anexoFile == null) return;

    setState(() => _enviando = true);
    try {
      String? anexoUrl;

      if (_anexoFile != null) {
        final ext = _anexoNomeChat!.split('.').last;
        final nomeArquivo = 'anexo_resp_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final storageRef = FirebaseStorage.instance.ref().child('tenants/${widget.tenantId}/avisos_anexos/$nomeArquivo');
        await storageRef.putFile(_anexoFile!);
        anexoUrl = await storageRef.getDownloadURL();
      }

      await widget.avisoRef.collection('respostas').add({
        'texto': texto,
        'dataEnvio': FieldValue.serverTimestamp(),
        'remetenteId': widget.meuId,
        'remetenteNome': 'Prof(a) ${widget.meuNome}',
        'lidaPorProfessor': true, 
        if (anexoUrl != null) 'anexoUrl': anexoUrl,
        if (anexoUrl != null) 'anexoNome': _anexoNomeChat,
      });
      
      _msgCtrl.clear();
      setState(() {
        _anexoFile = null;
        _anexoNomeChat = null;
        _isPdfChat = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarImagemFullscreen(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(url, fit: BoxFit.contain))),
            Positioned(top: 16, right: 16, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 32), onPressed: () => Navigator.pop(ctx))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // CABEÇALHO DO CHAT
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), shape: BoxShape.circle), child: Icon(Icons.forum_rounded, color: widget.corPrimaria, size: 20)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Respostas ao Aviso', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),

            // AVISO ORIGINAL NO TOPO
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aviso Original de ${widget.avisoData['remetenteNome']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(widget.avisoData['mensagem'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.black12),

            // MENSAGENS / RESPOSTAS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.avisoRef.collection('respostas').orderBy('dataEnvio', descending: false).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
                  }
                  
                  final respostas = snapshot.data?.docs ?? [];
                  
                  if (respostas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Nenhuma resposta ainda.', style: TextStyle(color: Colors.grey.shade500)),
                          Text('Seja o primeiro a enviar uma mensagem!', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      )
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: respostas.length,
                    itemBuilder: (context, index) {
                      final resp = respostas[index].data() as Map<String, dynamic>;
                      final isMeu = resp['remetenteId'] == widget.meuId;
                      
                      final dataTime = resp['dataEnvio'];
                      final hora = dataTime != null ? DateFormat('HH:mm').format((dataTime as Timestamp).toDate()) : '...';

                      String remetenteExibicao = resp['remetenteNome'] ?? 'Usuário';
                      
                      // Lógica de Formatação Inteligente do Remetente Baseada no Destino do Aviso
                      if (!isMeu) {
                        final tipoDest = widget.avisoData['tipoDestinatario'];
                        final alunoN = widget.avisoData['alunoNome'] ?? '';
                        final turmaN = widget.avisoData['turmaNome'] ?? '';
                        final respN = widget.avisoData['responsavelNome'] ?? '';
                        
                        if (tipoDest == 'RESPONSAVEL' && alunoN.isNotEmpty) {
                          String nomeLimpo = remetenteExibicao.split(' (Resp. por')[0].trim();
                          if (respN.isNotEmpty && nomeLimpo == respN) {
                            remetenteExibicao = '$respN - $alunoN ($turmaN)';
                          } else {
                            remetenteExibicao = '$nomeLimpo - $alunoN ($turmaN)';
                          }
                        } else if (tipoDest == 'ALUNO' && turmaN.isNotEmpty) {
                          remetenteExibicao = '$remetenteExibicao ($turmaN)';
                        }
                      }

                      final String anexoUrl = resp['anexoUrl'] ?? '';
                      final String anexoNome = resp['anexoNome'] ?? 'Anexo';
                      final bool isAnexoPdf = anexoNome.toLowerCase().endsWith('.pdf');

                      return Align(
                        alignment: isMeu ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMeu ? widget.corPrimaria.withAlpha(20) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMeu ? const Radius.circular(0) : null,
                              bottomLeft: !isMeu ? const Radius.circular(0) : null,
                            )
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMeu ? 'Você' : remetenteExibicao, 
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMeu ? widget.corPrimaria : Colors.grey.shade700)
                              ),
                              const SizedBox(height: 4),

                              if (anexoUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: isAnexoPdf 
                                    ? InkWell(
                                        onTap: () => _abrirLink(anexoUrl),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 24),
                                              const SizedBox(width: 8),
                                              Flexible(child: Text(anexoNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                      )
                                    : InkWell(
                                        onTap: () => _mostrarImagemFullscreen(anexoUrl),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            anexoUrl, height: 150, width: double.infinity, fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(height: 150, width: double.infinity, color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator()));
                                            },
                                          ),
                                        ),
                                      ),
                                ),

                              if ((resp['texto'] ?? '').toString().isNotEmpty)
                                Text(resp['texto'] ?? '', style: const TextStyle(fontSize: 14)),
                              
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(hora, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            if (_anexoFile != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.blue.shade50,
                child: Row(
                  children: [
                    _isPdfChat 
                      ? const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 32)
                      : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_anexoFile!, width: 40, height: 40, fit: BoxFit.cover)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_anexoNomeChat ?? 'Arquivo selecionado', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.red), onPressed: () => setState(() { _anexoFile = null; _anexoNomeChat = null; _isPdfChat = false; }))
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]),
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.attach_file_rounded, color: Colors.grey.shade600), onPressed: _escolherAnexoChat, tooltip: 'Anexar Foto ou PDF'),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Escreva uma resposta...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: widget.corPrimaria, shape: BoxShape.circle),
                    child: IconButton(
                      icon: _enviando 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _enviando ? null : _enviarResposta,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}