import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart'; 
import '../../../admin/apresentacao/estado/calendario_provider.dart';
import 'aluno_dashboard_tela.dart'; // Importa o controller do aluno

class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class AlunoCalendarioTela extends ConsumerStatefulWidget {
  const AlunoCalendarioTela({super.key});
  @override
  ConsumerState<AlunoCalendarioTela> createState() => _AlunoCalendarioTelaState();
}

class _AlunoCalendarioTelaState extends ConsumerState<AlunoCalendarioTela> {
  DateTime _dataFoco = DateTime.now();
  String _modoVisualizacao = 'MÊS'; 
  String _termoBusca = '';
  final _debouncer = Debouncer(milliseconds: 400);

  final List<String> _mesesNomes = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
  final List<String> _diasSemanaAbrev = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  final List<String> _diasSemanaCompleto = ['SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA', 'SÁBADO', 'DOMINGO'];

  final List<Color> _bgColors = [Colors.blue.shade50, Colors.green.shade50, Colors.purple.shade50, Colors.orange.shade50, Colors.teal.shade50, Colors.pink.shade50];
  final List<Color> _textColors = [Colors.blue.shade900, Colors.green.shade900, Colors.purple.shade900, Colors.orange.shade900, Colors.teal.shade900, Colors.pink.shade900];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
  }

  Color _getCorMateria(String nome, bool isTexto) {
    if (nome.isEmpty) return Colors.grey;
    int hash = 0;
    for (int i = 0; i < nome.length; i++) hash = nome.codeUnitAt(i) + ((hash << 5) - hash);
    int index = hash.abs() % _bgColors.length;
    return isTexto ? _textColors[index] : _bgColors[index];
  }

  List<Map<String, dynamic>> _obterFeriadosNacionais(int ano) {
    return [
      {'id': 'feriado_1_$ano', 'titulo': 'Confraternização Universal', 'data': '01/01/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true, 'isGeral': true},
      {'id': 'feriado_2_$ano', 'titulo': 'Tiradentes', 'data': '21/04/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true, 'isGeral': true},
      {'id': 'feriado_3_$ano', 'titulo': 'Dia do Trabalhador', 'data': '01/05/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true, 'isGeral': true},
      {'id': 'feriado_4_$ano', 'titulo': 'Independência do Brasil', 'data': '07/09/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true, 'isGeral': true},
      {'id': 'feriado_5_$ano', 'titulo': 'N. S. Aparecida', 'data': '12/10/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true, 'isGeral': true},
      {'id': 'feriado_6_$ano', 'titulo': 'Finados', 'data': '02/11/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true, 'isGeral': true},
      {'id': 'feriado_7_$ano', 'titulo': 'Proclamação da República', 'data': '15/11/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true, 'isGeral': true},
      {'id': 'feriado_8_$ano', 'titulo': 'Natal', 'data': '25/12/$ano', 'tipo': 'Feriado / Recesso', 'fixo': true, 'isGeral': true},
    ];
  }

  DateTime? _converterDataString(String dataStr) {
    try {
      final partes = dataStr.split('/');
      if (partes.length == 3) return DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
    } catch (_) {}
    return null;
  }

  String _formatarData(DateTime data) => "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
  bool _isMesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Color _getCorPorTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('feriado') || t.contains('recesso')) return Colors.red;
    if (t.contains('prova') || t.contains('avaliação')) return Colors.red.shade700;
    if (t.contains('semana de prova')) return Colors.red.shade900;
    if (t.contains('trabalho') || t.contains('projeto')) return Colors.orange;
    if (t.contains('simulado')) return Colors.purple;
    if (t.contains('reunião')) return Colors.blue;
    if (t.contains('escolar')) return Colors.green;
    return Colors.teal; 
  }

  IconData _getIconePorTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('feriado') || t.contains('recesso')) return Icons.beach_access_rounded;
    if (t.contains('prova') || t.contains('avaliação')) return Icons.edit_document;
    if (t.contains('semana de prova')) return Icons.fact_check_rounded;
    if (t.contains('trabalho')) return Icons.assignment_rounded;
    if (t.contains('simulado')) return Icons.quiz_rounded;
    if (t.contains('reunião')) return Icons.groups_rounded;
    if (t.contains('escolar')) return Icons.event_rounded;
    return Icons.star_rounded; 
  }

  PdfColor _getPdfColor(Color cor) => PdfColor((cor.r * 255).round().clamp(0, 255) / 255.0, (cor.g * 255).round().clamp(0, 255) / 255.0, (cor.b * 255).round().clamp(0, 255) / 255.0);

  void _navegar(int direcao) {
    setState(() {
      if (_modoVisualizacao == 'MÊS') _dataFoco = DateTime(_dataFoco.year, _dataFoco.month + direcao, 1);
      else if (_modoVisualizacao == 'SEMANA') _dataFoco = _dataFoco.add(Duration(days: 7 * direcao));
      else if (_modoVisualizacao == 'ANO') _dataFoco = DateTime(_dataFoco.year + direcao, _dataFoco.month, 1);
    });
  }

  void _irParaHoje() => setState(() => _dataFoco = DateTime.now());

  List<Map<String, dynamic>> _montarListaEventosGlobais(int anoFoco, List<QueryDocumentSnapshot> eventosTurmaRaw, List<dynamic>? eventosGerais) {
    List<Map<String, dynamic>> list = [];
    list.addAll(_obterFeriadosNacionais(anoFoco - 1));
    list.addAll(_obterFeriadosNacionais(anoFoco));
    list.addAll(_obterFeriadosNacionais(anoFoco + 1));

    if (eventosGerais != null) {
      for (var e in eventosGerais) {
        var eventoGeral = Map<String, dynamic>.from(e);
        eventoGeral['isGeral'] = true; eventoGeral['fixo'] = true; 
        list.add(eventoGeral);
      }
    }

    for (var doc in eventosTurmaRaw) {
      var ev = doc.data() as Map<String, dynamic>;
      if (ev['tipo'] == 'Semana de Prova') {
        try {
          DateTime dIni = DateTime.parse(ev['dataInicio']);
          DateTime dFim = DateTime.parse(ev['dataFim']);
          Map<String, dynamic> crono = ev['cronograma'] ?? {};
          
          int diff = dFim.difference(dIni).inDays;
          for (int i = 0; i <= diff; i++) {
            DateTime current = dIni.add(Duration(days: i));
            if (current.weekday == DateTime.sunday) continue;
            String dataStr = _formatarData(current);
            
            var blocosRaw = crono[dataStr];
            if (blocosRaw is Map && blocosRaw.isNotEmpty) {
              blocosRaw.forEach((tempo, disc) {
                list.add({
                  'id': doc.id, 'titulo': ev['titulo'] ?? 'Prova', 'data': dataStr, 'tipo': 'Prova', 'descricao': ev['descricao'] ?? '',
                  'disciplina': disc, 'autorNome': ev['autorNome'] ?? '', 'autorId': ev['autorId'] ?? '', 'horario': tempo,
                  'isGeral': false, 'fixo': false, 'isSemanaProva': true, 'originalDoc': {...ev, 'id': doc.id},
                });
              });
            } else if (blocosRaw is List && blocosRaw.isNotEmpty) {
              for (var disc in List<String>.from(blocosRaw)) {
                list.add({
                  'id': doc.id, 'titulo': ev['titulo'] ?? 'Prova', 'data': dataStr, 'tipo': 'Prova', 'descricao': ev['descricao'] ?? '',
                  'disciplina': disc, 'autorNome': ev['autorNome'] ?? '', 'autorId': ev['autorId'] ?? '',
                  'isGeral': false, 'fixo': false, 'isSemanaProva': true, 'originalDoc': {...ev, 'id': doc.id},
                });
              }
            } else {
              list.add({
                'id': doc.id, 'titulo': ev['titulo'] ?? 'Semana de Prova', 'data': dataStr, 'tipo': 'Semana de Prova', 'descricao': ev['descricao'] ?? '',
                'disciplina': 'Período de Provas', 'autorNome': ev['autorNome'] ?? '', 'autorId': ev['autorId'] ?? '',
                'isGeral': false, 'fixo': false, 'isSemanaProva': true, 'originalDoc': {...ev, 'id': doc.id},
              });
            }
          }
        } catch (_) {}
      } else {
        String dataStr = ev['dataEvento'] ?? ev['data'] ?? '';
        if (dataStr.contains('-')) { final p = dataStr.split('-'); if (p.length == 3) dataStr = '${p[2]}/${p[1]}/${p[0]}'; }
        list.add({
          'id': doc.id, 'titulo': ev['titulo'] ?? '', 'data': dataStr, 'tipo': ev['tipo'] ?? '', 'descricao': ev['descricao'] ?? '',
          'disciplina': ev['disciplina'] ?? '', 'autorNome': ev['autorNome'] ?? '', 'autorId': ev['autorId'] ?? '',
          'isGeral': false, 'fixo': false, 'isSemanaProva': false, 'originalDoc': {...ev, 'id': doc.id},
        });
      }
    }
    return list;
  }

  Future<void> _exportarCalendarioParaPdf(List<Map<String, dynamic>> eventosDoAno) async {
    final corPrimariaPdf = _getPdfColor(AlunoDashboardController.corPrimaria);
    final usuario = ref.read(authProvider).value;
    Map<String, dynamic> dadosEscola = {};
    if (usuario != null) {
      try {
        final docEscola = await FirebaseFirestore.instance.collection('tenants').doc(usuario.id).get();
        if (docEscola.exists && docEscola.data() != null) dadosEscola = docEscola.data()!;
      } catch (_) {}
    }

    final nomeEscola = dadosEscola['nomeEscola'] ?? dadosEscola['nome'] ?? 'ESCOLA NÃO CONFIGURADA';
    final anoVigente = _dataFoco.year;
    final logoEscolaUrl = dadosEscola['logoUrl'] ?? dadosEscola['fotoUrl'] ?? dadosEscola['logo'];
    pw.ImageProvider? logoImg;
    if (logoEscolaUrl != null && logoEscolaUrl.isNotEmpty) {
      try { logoImg = await networkImage(logoEscolaUrl); } catch (_) {}
    } else {
      try {
        final bytes = await rootBundle.load('assets/logo.png');
        logoImg = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}
    }

    Map<String, List<Map<String, dynamic>>> eventosMapPdf = {};
    for (var e in eventosDoAno) {
      final dataStr = e['data']?.toString() ?? '';
      if (dataStr.isNotEmpty) {
        if (!eventosMapPdf.containsKey(dataStr)) eventosMapPdf[dataStr] = [];
        eventosMapPdf[dataStr]!.add(e);
      }
    }

    pw.Widget buildMesGradePdf(int mes) {
      final int diasNoMes = DateTime(anoVigente, mes + 1, 0).day;
      final int diasParaPular = DateTime(anoVigente, mes, 1).weekday - 1; 
      List<pw.Widget> linhasGrid = [];
      
      linhasGrid.add(pw.Container(color: PdfColors.grey100, child: pw.Row(children: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'].map((d) => pw.Expanded(child: pw.Container(height: 12, alignment: pw.Alignment.center, child: pw.Text(d, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800))))).toList())));
      List<pw.Widget> diasSemanaAtual = [];
      for (int i = 0; i < diasParaPular; i++) diasSemanaAtual.add(pw.Expanded(child: pw.Container(height: 14, decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey300, width: 0.5)))));
      List<String> legendasRodape = [];

      for (int dia = 1; dia <= diasNoMes; dia++) {
        String dataStr = "${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}/$anoVigente";
        List<Map<String, dynamic>> evDia = eventosMapPdf[dataStr] ?? [];
        PdfColor corFundoCelula = PdfColors.white; PdfColor corTextoCelula = PdfColors.black;
        
        if (evDia.isNotEmpty) {
           bool temFeriado = false;
           for(var ev in evDia) {
             if (ev['tipo'].toString().toLowerCase().contains('feriado') || ev['tipo'].toString().toLowerCase().contains('recesso')) temFeriado = true;
             
             String tituloPdf = ev['titulo'] ?? '';
             bool isProva = ev['tipo'].toString().toLowerCase().contains('prova');
             
             if (isProva && ev['disciplina'] != null && ev['disciplina'].toString().isNotEmpty && ev['disciplina'] != 'Período de Provas') {
               String mat = ev['disciplina'].toString();
               if (mat.contains(' - Prof.')) mat = mat.split(' - Prof.')[0].trim();
               tituloPdf = 'PROVA: $mat';
             } else if (ev['disciplina'] != null && ev['disciplina'].toString().isNotEmpty && ev['disciplina'] != 'Período de Provas') {
               tituloPdf += ' (${ev['disciplina']})';
             }
             
             legendasRodape.add("${dia.toString().padLeft(2, '0')}.${mes.toString().padLeft(2, '0')} - $tituloPdf");
           }
           if (temFeriado) { corFundoCelula = PdfColors.red600; corTextoCelula = PdfColors.white; } else { corFundoCelula = PdfColor.fromHex('#FFF59D'); }
        } else {
           if (diasSemanaAtual.length >= 5) corFundoCelula = PdfColors.grey100;
        }

        diasSemanaAtual.add(pw.Expanded(child: pw.Container(height: 14, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(color: corFundoCelula, border: pw.Border.all(color: PdfColors.grey300, width: 0.5)), child: pw.Text(dia.toString().padLeft(2, '0'), style: pw.TextStyle(fontSize: 8, color: corTextoCelula, fontWeight: evDia.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal)))));
        if (diasSemanaAtual.length == 7) { linhasGrid.add(pw.Row(children: diasSemanaAtual)); diasSemanaAtual = []; }
      }
      if (diasSemanaAtual.isNotEmpty) {
        while (diasSemanaAtual.length < 7) diasSemanaAtual.add(pw.Expanded(child: pw.Container(height: 14, decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey300, width: 0.5)))));
        linhasGrid.add(pw.Row(children: diasSemanaAtual));
      }
      while (linhasGrid.length < 7) { 
        List<pw.Widget> semanaVazia = [];
        for (int i = 0; i < 7; i++) semanaVazia.add(pw.Expanded(child: pw.Container(height: 14, decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey300, width: 0.5)))));
        linhasGrid.add(pw.Row(children: semanaVazia));
      }

      return pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: corPrimariaPdf, width: 1.5), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
             pw.Container(decoration: pw.BoxDecoration(color: corPrimariaPdf, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2.5))), padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Center(child: pw.Text('${_mesesNomes[mes]} $anoVigente'.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)))),
             pw.Column(children: linhasGrid),
             pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: legendasRodape.take(8).map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 6), maxLines: 1)).toList())))
          ]
        )
      );
    }

    final docPdf = pw.Document();
    docPdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImg != null) pw.Image(logoImg, width: 50, height: 50, fit: pw.BoxFit.contain) else pw.Container(width: 50, height: 50, decoration: const pw.BoxDecoration(color: PdfColors.blue100, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 12),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(nomeEscola.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: corPrimariaPdf)),
                      pw.Text('CALENDÁRIO DA TURMA - $anoVigente', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800, fontWeight: pw.FontWeight.bold)),
                  ])
                ]
              ),
              pw.SizedBox(height: 4), pw.Divider(thickness: 1, color: PdfColors.grey300), pw.SizedBox(height: 8),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    for (int row = 0; row < 4; row++)
                      pw.Expanded(child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [for (int col = 1; col <= 3; col++) pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(4), child: buildMesGradePdf(row * 3 + col)))]))
                  ]
                )
              ),
            ]
          );
        }
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => docPdf.save(), name: 'Calendario_Turma_$anoVigente.pdf');
  }

  void _abrirModalSemanasProva(List<Map<String, dynamic>> semanasProva) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.date_range_rounded, color: AlunoDashboardController.corPrimaria), 
            const SizedBox(width: 8), 
            const Expanded(child: Text('Semanas de Provas (Períodos)', style: TextStyle(fontWeight: FontWeight.bold)))
          ]
        ),
        content: SizedBox(
          width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 700, 
          height: isMobile ? MediaQuery.of(context).size.height * 0.8 : 500,
          child: semanasProva.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.event_busy, size: 48, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Nenhum período de prova cadastrado.', style: TextStyle(color: Colors.grey.shade600))]))
            : ListView.separated(
                itemCount: semanasProva.length, separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final semana = semanasProva[index];
                  Map<String, dynamic> cronograma = semana['cronograma'] ?? {};
                  final datasOrdenadas = cronograma.keys.toList()..sort((a, b) => (_converterDataString(a) ?? DateTime(2000)).compareTo(_converterDataString(b) ?? DateTime(2000)));

                  return Card(
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)), child: Text('Semana de Prova', style: TextStyle(color: Colors.red.shade900, fontSize: 10, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 12),
                              Expanded(child: Text(semana['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            ],
                          ),
                          const Divider(height: 24),
                          ...datasOrdenadas.map((dataStr) {
                            var blocos = cronograma[dataStr];
                            List<Widget> materiasWidgets = [];
                            
                            if (blocos is Map) {
                              final temposOrdenados = blocos.keys.toList()..sort();
                              for (var t in temposOrdenados) {
                                String discCompleta = blocos[t];
                                String mat = discCompleta; String prof = '';
                                if (mat.contains(' - Prof. ')) { var p = mat.split(' - Prof. '); mat = p[0]; prof = p[1]; }
                                
                                materiasWidgets.add(
                                  Container(
                                    width: 140,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: _getCorMateria(mat, false), border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getCorMateria(mat, true))),
                                        const SizedBox(height: 2),
                                        Text(mat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getCorMateria(mat, true)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        if (prof.isNotEmpty) Text(prof, style: TextStyle(fontSize: 9, color: _getCorMateria(mat, true).withAlpha(180)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  )
                                );
                              }
                            } else if (blocos is List) {
                              for (var d in blocos) {
                                materiasWidgets.add(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)), child: Text(d.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))));
                              }
                            }

                            if (materiasWidgets.isEmpty) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 80, child: Text(dataStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8, runSpacing: 8,
                                      children: materiasWidgets
                                    ),
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      )
    );
  }

  void _abrirModalDetalhesDia(DateTime data, List<Map<String, dynamic>> eventosDoDia) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agenda do Dia', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(_formatarData(data), style: TextStyle(fontWeight: FontWeight.bold, color: AlunoDashboardController.corPrimaria)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500, height: 400,
          child: eventosDoDia.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.event_busy, size: 48, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Agenda livre neste dia.', style: TextStyle(color: Colors.grey.shade500))]))
            : ListView.separated(
                itemCount: eventosDoDia.length, separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final evento = eventosDoDia[index];
                  final cor = _getCorPorTipo(evento['tipo']);
                  
                  final isProva = evento['tipo'].toString().toLowerCase().contains('prova');
                  String nomeMateria = evento['disciplina'] ?? '';
                  String nomeProf = '';

                  if (nomeMateria.contains(' - Prof.')) {
                    final partes = nomeMateria.split(' - Prof.');
                    nomeMateria = partes[0].trim();
                    nomeProf = 'Prof. ${partes[1].trim()}';
                  }

                  return Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(width: 6, decoration: BoxDecoration(color: cor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: cor.withAlpha(30), borderRadius: BorderRadius.circular(8)), child: Icon(_getIconePorTipo(evento['tipo']), color: cor)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        
                                        if (isProva && nomeMateria.isNotEmpty && nomeMateria != 'Período de Provas') ...[
                                          Text('PROVA: $nomeMateria', style: TextStyle(color: _getCorMateria(nomeMateria, true), fontSize: 18, fontWeight: FontWeight.bold)),
                                          if (nomeProf.isNotEmpty)
                                            Text(nomeProf, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: Text(evento['tipo'] ?? 'Prova', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                                              if (evento['horario'] != null) ...[
                                                const SizedBox(width: 8),
                                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)), child: Text(evento['horario'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)))
                                              ],
                                              const SizedBox(width: 8),
                                              Expanded(child: Text(evento['titulo'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ] else ...[
                                          Row(
                                            children: [
                                              Text(evento['tipo'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                                              if (evento['disciplina'] != null && evento['disciplina'].toString().isNotEmpty) ...[
                                                const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                                Expanded(child: Text(evento['disciplina'], style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                              ]
                                            ],
                                          ),
                                          Text(evento['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        ],

                                        if (evento['descricao'] != null && evento['descricao'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 4), Text(evento['descricao'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        ],
                                        if (evento['autorNome'] != null && evento['autorNome'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Row(children: [const Icon(Icons.person_outline, size: 12, color: Colors.grey), const SizedBox(width: 4), Text('Por: ${evento['autorNome']}', style: const TextStyle(fontSize: 10, color: Colors.grey))])
                                        ]
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
        actionsPadding: const EdgeInsets.all(24),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar Painel', style: TextStyle(color: Colors.grey)))],
      ),
    );
  }

  Widget _buildVisaoMes(Map<String, List<Map<String, dynamic>>> eventosPorData) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    final int diasNoMes = DateTime(_dataFoco.year, _dataFoco.month + 1, 0).day;
    final int diasParaPular = DateTime(_dataFoco.year, _dataFoco.month, 1).weekday - 1; 
    int linhasNecessarias = ((diasNoMes + diasParaPular) / 7).ceil();
    final corPrimaria = AlunoDashboardController.corPrimaria;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth < 800 ? 800.0 : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minWidth,
            child: Column(
              children: [
                Row(children: _diasSemanaAbrev.map((dia) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.blue.shade50, border: Border.all(color: Colors.white)), child: Text(dia, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))))).toList()),
                ...List.generate(linhasNecessarias, (linhaIndex) {
                  return Expanded(
                    child: Row(
                      children: List.generate(7, (colIndex) {
                        int diaReal = ((linhaIndex * 7) + colIndex) - diasParaPular + 1;
                        if (diaReal < 1 || diaReal > diasNoMes) return Expanded(child: Container(decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200))));

                        DateTime dataCelula = DateTime(_dataFoco.year, _dataFoco.month, diaReal);
                        List<Map<String, dynamic>> eventosDoDia = eventosPorData[_formatarData(dataCelula)] ?? [];
                        bool isHoje = _isMesmoDia(dataCelula, DateTime.now());

                        Color corBorda = isHoje ? corPrimaria : (eventosDoDia.isNotEmpty ? _getCorPorTipo(eventosDoDia.first['tipo']).withAlpha(150) : Colors.grey.shade200);
                        double larguraBorda = isHoje ? 2.0 : (eventosDoDia.isNotEmpty ? 1.5 : 1.0);

                        return Expanded(
                          child: InkWell(
                            onTap: () => _abrirModalDetalhesDia(dataCelula, eventosDoDia),
                            child: Container(
                              decoration: BoxDecoration(color: isHoje ? corPrimaria.withAlpha(20) : Colors.white, border: Border.all(color: corBorda, width: larguraBorda)),
                              padding: EdgeInsets.all(isMobile ? 2 : 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(padding: EdgeInsets.all(isMobile ? 4 : 6), decoration: BoxDecoration(color: isHoje ? corPrimaria : Colors.transparent, shape: BoxShape.circle), child: Text(diaReal.toString(), style: TextStyle(fontWeight: isHoje ? FontWeight.bold : FontWeight.normal, color: isHoje ? Colors.white : Colors.black87, fontSize: isMobile ? 12 : 14))),
                                  if (eventosDoDia.isNotEmpty)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: SingleChildScrollView(
                                            physics: const ClampingScrollPhysics(),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: eventosDoDia.take(isMobile ? 2 : 4).map((e) {
                                                bool isProva = e['tipo'].toString().toLowerCase().contains('prova');
                                                String textoDisplay = e['titulo'] ?? '';
                                                String nomeParaCor = textoDisplay;

                                                if (isProva && e['disciplina'] != null && e['disciplina'].toString().isNotEmpty && e['disciplina'] != 'Várias' && e['disciplina'] != 'Período de Provas') {
                                                  String mat = e['disciplina'].toString();
                                                  if (mat.contains(' - Prof.')) mat = mat.split(' - Prof.')[0].trim();
                                                  nomeParaCor = mat;
                                                  textoDisplay = 'PROVA: $mat';
                                                }

                                                Color corBase = isProva ? _getCorMateria(nomeParaCor, false) : _getCorPorTipo(e['tipo']);
                                                Color corTexto = isProva ? _getCorMateria(nomeParaCor, true) : corBase;

                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 2),
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  decoration: BoxDecoration(color: isProva ? corBase : corBase.withAlpha(30), borderRadius: BorderRadius.circular(4), border: Border.all(color: isProva ? corBase : corBase.withAlpha(80), width: 0.5)),
                                                  child: Text(textoDisplay, style: TextStyle(fontSize: isMobile ? 9 : 10, color: corTexto, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        )
                                      )
                                    )
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ],
            )
          )
        );
      }
    );
  }

  Widget _buildVisaoSemana(Map<String, List<Map<String, dynamic>>> eventosPorData) {
    final corPrimaria = AlunoDashboardController.corPrimaria;
    DateTime segundaFeira = _dataFoco.subtract(Duration(days: _dataFoco.weekday - 1));

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth < 800 ? 800.0 : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (index) {
                DateTime dataDia = segundaFeira.add(Duration(days: index));
                List<Map<String, dynamic>> eventosDoDia = eventosPorData[_formatarData(dataDia)] ?? [];
                bool isHoje = _isMesmoDia(dataDia, DateTime.now());

                Color corBorda = isHoje ? corPrimaria : (eventosDoDia.isNotEmpty ? _getCorPorTipo(eventosDoDia.first['tipo']).withAlpha(150) : Colors.grey.shade300);
                double larguraBorda = isHoje ? 2.0 : (eventosDoDia.isNotEmpty ? 1.5 : 1.0);

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: isHoje ? corPrimaria.withAlpha(20) : Colors.white, border: Border.all(color: corBorda, width: larguraBorda), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => _abrirModalDetalhesDia(dataDia, eventosDoDia),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isHoje ? corPrimaria : Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                            child: Column(children: [Text(_diasSemanaAbrev[index], style: TextStyle(fontWeight: FontWeight.bold, color: isHoje ? Colors.white : Colors.blueGrey)), const SizedBox(height: 4), Text(dataDia.day.toString().padLeft(2, '0'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isHoje ? Colors.white : Colors.black87))]),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(8), itemCount: eventosDoDia.length, separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final evento = eventosDoDia[idx];
                              final cor = _getCorPorTipo(evento['tipo']);
                              final isProva = evento['tipo'].toString().toLowerCase().contains('prova');
                              String nomeMateria = evento['disciplina'] ?? '';

                              if (nomeMateria.contains(' - Prof.')) {
                                nomeMateria = nomeMateria.split(' - Prof.')[0].trim();
                              }

                              Color corBase = isProva ? _getCorMateria(nomeMateria, false) : cor.withAlpha(30);
                              Color corTexto = isProva ? _getCorMateria(nomeMateria, true) : cor;
                              String textoExibicao = isProva && nomeMateria.isNotEmpty && nomeMateria != 'Período de Provas' ? 'PROVA: $nomeMateria' : (evento['titulo'] ?? '');

                              return InkWell(
                                onTap: () => _abrirModalDetalhesDia(dataDia, eventosDoDia),
                                child: Container(
                                  padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: corBase, borderRadius: BorderRadius.circular(8), border: Border.all(color: isProva ? corBase : cor.withAlpha(100))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      Text(textoExibicao, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTexto), maxLines: 2, overflow: TextOverflow.ellipsis), 
                                      if (evento['disciplina'] != null && evento['disciplina'].toString().isNotEmpty && !isProva) 
                                        Text(evento['disciplina'], style: TextStyle(fontSize: 10, color: Colors.grey.shade700))
                                    ]
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }),
            )
          )
        );
      }
    );
  }

  Widget _buildVisaoAno(Map<String, List<Map<String, dynamic>>> eventosPorData) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    final corPrimaria = AlunoDashboardController.corPrimaria;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isMobile ? 2 : 4, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.5),
      itemCount: 12,
      itemBuilder: (context, index) {
        int mes = index + 1;
        int qtdeEventos = 0;
        eventosPorData.forEach((dataStr, eventos) {
          final d = _converterDataString(dataStr);
          if (d != null && d.year == _dataFoco.year && d.month == mes) qtdeEventos += eventos.length;
        });

        bool isMesAtual = DateTime.now().year == _dataFoco.year && DateTime.now().month == mes;

        return InkWell(
          onTap: () => setState(() { _dataFoco = DateTime(_dataFoco.year, mes, 1); _modoVisualizacao = 'MÊS'; }),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isMesAtual ? corPrimaria.withAlpha(20) : Colors.white, border: Border.all(color: isMesAtual ? corPrimaria.withAlpha(100) : Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_mesesNomes[mes].toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isMesAtual ? corPrimaria : Colors.blueGrey)),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: qtdeEventos > 0 ? Colors.orange.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), child: Text('$qtdeEventos eventos', style: TextStyle(fontWeight: FontWeight.bold, color: qtdeEventos > 0 ? Colors.orange.shade800 : Colors.grey)))
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListaBusca(List<Map<String, dynamic>> eventos) {
    final filtrados = eventos.where((e) {
      final busca = _termoBusca.toLowerCase();
      return (e['titulo'] ?? '').toString().toLowerCase().contains(busca) || (e['descricao'] ?? '').toString().toLowerCase().contains(busca) || (e['disciplina'] ?? '').toString().toLowerCase().contains(busca);
    }).toList();

    if (filtrados.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), const Text('Nenhum evento encontrado.', style: TextStyle(color: Colors.grey, fontSize: 16))]));

    filtrados.sort((a, b) {
      final dataA = _converterDataString(a['data'] ?? '') ?? DateTime(2000); final dataB = _converterDataString(b['data'] ?? '') ?? DateTime(2000); return dataA.compareTo(dataB);
    });

    return ListView.separated(
      itemCount: filtrados.length, separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final evento = filtrados[index];
        final cor = _getCorPorTipo(evento['tipo']);
        
        final isProva = evento['tipo'].toString().toLowerCase().contains('prova');
        String nomeMateria = evento['disciplina'] ?? '';
        String nomeProf = '';

        if (nomeMateria.contains(' - Prof.')) {
          final partes = nomeMateria.split(' - Prof.');
          nomeMateria = partes[0].trim();
          nomeProf = 'Prof. ${partes[1].trim()}';
        }
        
        String textoExibicao = isProva && nomeMateria.isNotEmpty && nomeMateria != 'Período de Provas' ? 'PROVA: $nomeMateria' : (evento['titulo'] ?? '');

        return Card(
          elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 8, decoration: BoxDecoration(color: cor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: cor.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_getIconePorTipo(evento['tipo']), color: cor, size: 28), const SizedBox(height: 4), Text(evento['data'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 13))])),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            mainAxisAlignment: MainAxisAlignment.center, 
                            children: [
                              if (isProva && nomeMateria.isNotEmpty && nomeMateria != 'Período de Provas') ...[
                                Text(textoExibicao, style: TextStyle(color: _getCorMateria(nomeMateria, true), fontSize: 18, fontWeight: FontWeight.bold)),
                                if (nomeProf.isNotEmpty) Text(nomeProf, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: Text(evento['tipo'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                                    if (evento['horario'] != null) ...[
                                       const SizedBox(width: 8),
                                       Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)), child: Text(evento['horario'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)))
                                    ],
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(evento['titulo'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis))
                                  ]
                                )
                              ] else ...[
                                Text(evento['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
                                const SizedBox(height: 4), 
                                Row(
                                  children: [
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: Text(evento['tipo'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700))), 
                                    if (evento['disciplina'] != null && evento['disciplina'].toString().isNotEmpty) ...[const SizedBox(width: 8), Expanded(child: Text(evento['disciplina'], style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))]
                                  ]
                                )
                              ]
                            ]
                          )
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    final tenantId = AlunoDashboardController.tenantId;
    final turmaId = AlunoDashboardController.turmaId;
    final corPrimaria = AlunoDashboardController.corPrimaria;

    if (tenantId.isEmpty || turmaId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: corPrimaria, foregroundColor: Colors.white, elevation: 1,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/aluno')),
          title: const Text('Meu Calendário Escolar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        body: const Center(child: Text('Turma não encontrada.', style: TextStyle(color: Colors.grey, fontSize: 16))),
      );
    }

    final estadoCalendarioEscola = ref.watch(calendarioStreamProvider);

    String tituloPeriodo = '';
    if (_modoVisualizacao == 'MÊS' || _modoVisualizacao == 'SEMANA') {
      tituloPeriodo = '${_mesesNomes[_dataFoco.month]} ${_dataFoco.year}';
    } else {
      tituloPeriodo = '${_dataFoco.year}';
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: corPrimaria, foregroundColor: Colors.white, elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/aluno');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meu Calendário Escolar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('Provas e eventos da turma', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Wrap(
                spacing: 16, runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 300),
                    child: Row(
                      mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        IconButton(onPressed: () => _navegar(-1), icon: Icon(Icons.chevron_left_rounded, color: corPrimaria)),
                        Expanded(child: Text(tituloPeriodo, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: corPrimaria))),
                        IconButton(onPressed: () => _navegar(1), icon: Icon(Icons.chevron_right_rounded, color: corPrimaria)),
                        TextButton(onPressed: _irParaHoje, child: Text('HOJE', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria))),
                      ],
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId).collection('eventos').snapshots(),
                    builder: (context, snapTurma) {
                      final evTurma = snapTurma.data?.docs ?? [];
                      final listaSemanasProva = evTurma.where((d) => (d.data() as Map)['tipo'] == 'Semana de Prova').map((d) => {...d.data() as Map<String,dynamic>, 'id': d.id}).toList();

                      return Wrap(
                        spacing: 8, runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          if (listaSemanasProva.isNotEmpty)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade900, elevation: 0),
                              onPressed: () => _abrirModalSemanasProva(listaSemanasProva),
                              icon: const Icon(Icons.fact_check_rounded, size: 16),
                              label: const Text('Períodos de Prova'),
                            ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, elevation: 0),
                            onPressed: () {
                              List<Map<String, dynamic>> todosEventosPdf = _montarListaEventosGlobais(_dataFoco.year, evTurma, estadoCalendarioEscola.value);
                              _exportarCalendarioParaPdf(todosEventosPdf);
                            },
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: const Text('Exportar PDF'),
                          )
                        ],
                      );
                    }
                  ),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['SEMANA', 'MÊS', 'ANO'].map((modo) {
                        bool isAtivo = _modoVisualizacao == modo;
                        return InkWell(
                          onTap: () => setState(() => _modoVisualizacao = modo),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: isAtivo ? corPrimaria : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                            child: Text(modo, style: TextStyle(fontWeight: FontWeight.bold, color: isAtivo ? Colors.white : Colors.grey.shade600)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 250, height: 40,
                    child: TextField(
                      onChanged: (val) => _debouncer.run(() => setState(() => _termoBusca = val)),
                      decoration: InputDecoration(hintText: 'Pesquisar evento...', prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: Colors.grey.shade100, contentPadding: EdgeInsets.zero, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(turmaId).collection('eventos').snapshots(),
                builder: (context, snapshotTurma) {
                  if (snapshotTurma.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: corPrimaria));
                  
                  final eventosTurmaRaw = snapshotTurma.data?.docs ?? [];
                  List<Map<String, dynamic>> todosEventos = _montarListaEventosGlobais(_dataFoco.year, eventosTurmaRaw, estadoCalendarioEscola.value);

                  if (_termoBusca.isNotEmpty) {
                    return _buildListaBusca(todosEventos);
                  }

                  Map<String, List<Map<String, dynamic>>> eventosPorData = {};
                  for (var e in todosEventos) {
                    final dataStr = e['data']?.toString() ?? '';
                    if (dataStr.isNotEmpty) {
                      if (!eventosPorData.containsKey(dataStr)) eventosPorData[dataStr] = [];
                      eventosPorData[dataStr]!.add(e);
                    }
                  }

                  if (_modoVisualizacao == 'MÊS') {
                    return _buildVisaoMes(eventosPorData);
                  } else if (_modoVisualizacao == 'SEMANA') {
                    return _buildVisaoSemana(eventosPorData);
                  } else {
                    return _buildVisaoAno(eventosPorData);
                  }
                }
              ),
            )
          ],
        ),
      ),
    );
  }
}