import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart'; 
import '../estado/calendario_provider.dart';

// ============================================================================
// DEBOUNCER PARA PESQUISA
// ============================================================================
class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class AdminCalendarioTela extends ConsumerStatefulWidget {
  const AdminCalendarioTela({super.key});

  @override
  ConsumerState<AdminCalendarioTela> createState() => _AdminCalendarioTelaState();
}

class _AdminCalendarioTelaState extends ConsumerState<AdminCalendarioTela> {
  DateTime _dataFoco = DateTime.now();
  String _modoVisualizacao = 'MÊS'; // ANO, MÊS, SEMANA
  String _termoBusca = '';
  final _debouncer = Debouncer(milliseconds: 400);

  final List<String> _mesesNomes = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
  final List<String> _diasSemanaAbrev = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

  // ==========================================================================
  // FERIADOS NACIONAIS FIXOS DO BRASIL
  // ==========================================================================
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

  // ==========================================================================
  // FUNÇÕES UTILITÁRIAS DE DATA E CORES
  // ==========================================================================
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

  bool _isMesmoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _getCorPorTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('feriado') || t.contains('recesso')) return Colors.red;
    if (t.contains('avaliação')) return Colors.orange;
    if (t.contains('reunião')) return Colors.blue;
    if (t.contains('escolar')) return Colors.green;
    return Colors.purple; 
  }

  IconData _getIconePorTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('feriado') || t.contains('recesso')) return Icons.beach_access_rounded;
    if (t.contains('avaliação')) return Icons.edit_document;
    if (t.contains('reunião')) return Icons.groups_rounded;
    if (t.contains('escolar')) return Icons.event_rounded;
    return Icons.star_rounded; 
  }

  PdfColor _getPdfColor(Color cor) {
    return PdfColor(
      (cor.r * 255.0).round().clamp(0, 255) / 255.0,
      (cor.g * 255.0).round().clamp(0, 255) / 255.0,
      (cor.b * 255.0).round().clamp(0, 255) / 255.0
    );
  }

  // ==========================================================================
  // NAVEGAÇÃO
  // ==========================================================================
  void _navegar(int direcao) {
    setState(() {
      if (_modoVisualizacao == 'MÊS') {
        _dataFoco = DateTime(_dataFoco.year, _dataFoco.month + direcao, 1);
      } else if (_modoVisualizacao == 'SEMANA') {
        _dataFoco = _dataFoco.add(Duration(days: 7 * direcao));
      } else if (_modoVisualizacao == 'ANO') {
        _dataFoco = DateTime(_dataFoco.year + direcao, _dataFoco.month, 1);
      }
    });
  }

  void _irParaHoje() {
    setState(() {
      _dataFoco = DateTime.now();
    });
  }

  // ==========================================================================
  // EXPORTAÇÃO DE PDF (CALENDÁRIO ANUAL 100% PREENCHIDO E ALINHADO)
  // ==========================================================================
  Future<void> _exportarCalendarioParaPdf(List<Map<String, dynamic>> eventosDoAno) async {
    final corTemaFlutter = Theme.of(context).primaryColor;
    final corPrimariaPdf = _getPdfColor(corTemaFlutter);
    
    final usuario = ref.read(authProvider).value;
    Map<String, dynamic> dadosEscola = {};
    if (usuario != null) {
      try {
        final docEscola = await FirebaseFirestore.instance.collection('tenants').doc(usuario.id).get();
        if (docEscola.exists && docEscola.data() != null) dadosEscola = docEscola.data()!;
      } catch (e) { debugPrint('Erro ao buscar dados escola PDF: $e'); }
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

    // --- FUNÇÃO QUE DESENHA A CAIXINHA DE UM MÊS ---
    pw.Widget buildMesGradePdf(int mes) {
      final int diasNoMes = DateTime(anoVigente, mes + 1, 0).day;
      final int diasParaPular = DateTime(anoVigente, mes, 1).weekday - 1; 

      List<pw.Widget> linhasGrid = [];
      
      // Cabeçalho dos dias da semana
      linhasGrid.add(
        pw.Container(
          color: PdfColors.grey100,
          child: pw.Row(
            children: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'].map((d) => 
              pw.Expanded(child: pw.Container(
                height: 12,
                alignment: pw.Alignment.center,
                child: pw.Text(d, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800))
              ))
            ).toList()
          )
        )
      );

      List<pw.Widget> diasSemanaAtual = [];
      
      // Preenche os dias iniciais vazios do mês
      for (int i = 0; i < diasParaPular; i++) {
        diasSemanaAtual.add(
          pw.Expanded(
            child: pw.Container(
              height: 14, 
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100, 
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5)
              )
            )
          )
        );
      }

      List<String> legendasRodape = [];

      for (int dia = 1; dia <= diasNoMes; dia++) {
        String dataStr = "${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}/$anoVigente";
        List<Map<String, dynamic>> evDia = eventosMapPdf[dataStr] ?? [];
        
        PdfColor corFundoCelula = PdfColors.white;
        PdfColor corTextoCelula = PdfColors.black;
        
        if (evDia.isNotEmpty) {
           bool temFeriado = false;
           for(var ev in evDia) {
             final t = ev['tipo'].toString().toLowerCase();
             if (t.contains('feriado') || t.contains('recesso')) temFeriado = true;
             legendasRodape.add("${dia.toString().padLeft(2, '0')}.${mes.toString().padLeft(2, '0')} - ${ev['titulo']}");
           }

           if (temFeriado) {
             corFundoCelula = PdfColors.red600;
             corTextoCelula = PdfColors.white;
           } else {
             corFundoCelula = PdfColor.fromHex('#FFF59D'); // Amarelinho claro
           }
        } else {
           if (diasSemanaAtual.length >= 5) corFundoCelula = PdfColors.grey100; // Cinza para sábado/domingo
        }

        diasSemanaAtual.add(
          pw.Expanded(
            child: pw.Container(
              height: 14,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(color: corFundoCelula, border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
              child: pw.Text(dia.toString().padLeft(2, '0'), style: pw.TextStyle(fontSize: 8, color: corTextoCelula, fontWeight: evDia.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal))
            )
          )
        );

        if (diasSemanaAtual.length == 7) {
          linhasGrid.add(pw.Row(children: diasSemanaAtual));
          diasSemanaAtual = [];
        }
      }

      // Preenche espaços vazios no final do mês
      if (diasSemanaAtual.isNotEmpty) {
        while (diasSemanaAtual.length < 7) {
          diasSemanaAtual.add(
            pw.Expanded(
              child: pw.Container(
                height: 14, 
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100, 
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5)
                )
              )
            )
          );
        }
        linhasGrid.add(pw.Row(children: diasSemanaAtual));
      }

      // FORÇA SEMPRE 6 SEMANAS NO GRID (para todos os meses ficarem do exato mesmo tamanho)
      while (linhasGrid.length < 7) { // 1 do cabeçalho + 6 de semanas
        List<pw.Widget> semanaVazia = [];
        for (int i = 0; i < 7; i++) {
          semanaVazia.add(
            pw.Expanded(
              child: pw.Container(
                height: 14, 
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100, 
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5)
                )
              )
            )
          );
        }
        linhasGrid.add(pw.Row(children: semanaVazia));
      }

      // Retorna o Mês Flexível (Expanded faz o trabalho dele se expandir na tela)
      return pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: corPrimariaPdf, width: 1.5), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
             pw.Container(
               decoration: pw.BoxDecoration(color: corPrimariaPdf, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2.5))),
               padding: const pw.EdgeInsets.symmetric(vertical: 4),
               child: pw.Center(child: pw.Text('${_mesesNomes[mes]} $anoVigente'.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)))
             ),
             pw.Column(children: linhasGrid),
             pw.Expanded( 
               child: pw.Container(
                 padding: const pw.EdgeInsets.all(4),
                 child: pw.Column(
                   crossAxisAlignment: pw.CrossAxisAlignment.start,
                   // Exibe os primeiros eventos (para caber tudo sem quebrar a tela)
                   children: legendasRodape.take(8).map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 6), maxLines: 1)).toList()
                 )
               )
             )
          ]
        )
      );
    }

    final docPdf = pw.Document();

    docPdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4, 
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ================= CABEÇALHO LIMPO E COMPACTO =================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImg != null)
                    pw.Image(logoImg, width: 50, height: 50, fit: pw.BoxFit.contain)
                  else
                    pw.Container(width: 50, height: 50, decoration: const pw.BoxDecoration(color: PdfColors.blue100, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(nomeEscola.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: corPrimariaPdf)),
                      pw.Text('CALENDÁRIO OFICIAL - ANO LETIVO $anoVigente', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800, fontWeight: pw.FontWeight.bold)),
                    ]
                  )
                ]
              ),
              
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              // ================= GRADE DOS 12 MESES (USANDO EXPANDED PARA PREENCHER 100%) =================
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    for (int row = 0; row < 4; row++)
                      pw.Expanded(
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            for (int col = 1; col <= 3; col++)
                              pw.Expanded(
                                child: pw.Padding(
                                  padding: const pw.EdgeInsets.all(4), // Espaçamento entre os meses
                                  child: buildMesGradePdf(row * 3 + col),
                                )
                              )
                          ]
                        )
                      )
                  ]
                )
              ),
            ]
          );
        }
      )
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => docPdf.save(), name: 'Calendario_Escolar_$anoVigente.pdf');
  }

  // ==========================================================================
  // MODAIS DE EVENTO E DETALHES
  // ==========================================================================
  void _confirmarExclusao(BuildContext context, Map<String, dynamic> evento) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Excluir Evento', style: TextStyle(color: Colors.red))]),
        content: Text('Deseja excluir o evento "${evento['titulo']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await ref.read(calendarioServiceProvider).excluirEvento(evento['id']);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento excluído.'), backgroundColor: Colors.green));
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _abrirModalEvento({DateTime? dataPreSelecionada, Map<String, dynamic>? eventoExistente}) {
    final formKey = GlobalKey<FormState>();
    final tituloCtrl = TextEditingController(text: eventoExistente?['titulo'] ?? '');
    
    String dataInicial = '';
    if (eventoExistente != null) {
      dataInicial = eventoExistente['data'] ?? '';
    } else if (dataPreSelecionada != null) {
      dataInicial = _formatarData(dataPreSelecionada);
    }

    final dataCtrl = TextEditingController(text: dataInicial);
    final descCtrl = TextEditingController(text: eventoExistente?['descricao'] ?? '');
    
    final listaTiposPadrao = ['Feriado / Recesso', 'Evento Escolar', 'Avaliação', 'Reunião', 'Outro'];
    String tipoSelecionado = 'Evento Escolar';
    final tipoCustomCtrl = TextEditingController();

    if (eventoExistente != null && !listaTiposPadrao.contains(eventoExistente['tipo'])) {
      tipoSelecionado = 'Outro';
      tipoCustomCtrl.text = eventoExistente['tipo'];
    } else if (eventoExistente != null) {
      tipoSelecionado = eventoExistente['tipo'];
    }

    final dataMask = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
    if (dataInicial.isNotEmpty) dataMask.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: dataInicial));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( 
        builder: (context, setStateModal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(eventoExistente == null ? Icons.add_circle_outline : Icons.edit, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(eventoExistente == null ? 'Novo Evento' : 'Editar Evento', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(labelText: 'Título do Evento', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dataCtrl,
                            inputFormatters: [dataMask],
                            decoration: const InputDecoration(labelText: 'Data (DD/MM/AAAA)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today, size: 20)),
                            validator: (v) {
                              if (v == null || v.length != 10) return 'Data incompleta';
                              
                              final partes = v.split('/');
                              final dia = int.tryParse(partes[0]) ?? 0;
                              final mes = int.tryParse(partes[1]) ?? 0;
                              final ano = int.tryParse(partes[2]) ?? 0;
                              
                              if (dia < 1 || dia > 31) return 'Dia inválido';
                              if (mes < 1 || mes > 12) return 'Mês inválido';
                              
                              try {
                                final dataTeste = DateTime(ano, mes, dia);
                                if (dataTeste.year != ano || dataTeste.month != mes || dataTeste.day != dia) {
                                  return 'Esta data não existe';
                                }
                              } catch (_) {
                                return 'Data inválida';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: listaTiposPadrao.contains(tipoSelecionado) ? tipoSelecionado : 'Outro',
                            decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                            items: listaTiposPadrao.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setStateModal(() => tipoSelecionado = v!),
                          ),
                        ),
                      ],
                    ),
                    
                    if (tipoSelecionado == 'Outro') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: tipoCustomCtrl,
                        decoration: const InputDecoration(labelText: 'Digite o tipo do evento', border: OutlineInputBorder(), prefixIcon: Icon(Icons.star_rounded, color: Colors.purple)),
                        validator: (v) => v!.isEmpty ? 'Por favor, informe o tipo' : null,
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Descrição ou Observação (Opcional)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.all(24),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final tipoFinal = tipoSelecionado == 'Outro' ? tipoCustomCtrl.text.trim() : tipoSelecionado;

                  final novoEvento = {
                    'id': eventoExistente?['id'],
                    'titulo': tituloCtrl.text.trim(),
                    'data': dataCtrl.text,
                    'tipo': tipoFinal,
                    'descricao': descCtrl.text.trim(),
                  };

                  await ref.read(calendarioServiceProvider).salvarEvento(novoEvento);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (eventoExistente != null) Navigator.pop(context); 
                  }
                },
                child: const Text('Salvar Evento'),
              ),
            ],
          );
        }
      ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Agenda do Dia', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text(_formatarData(data), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _abrirModalEvento(dataPreSelecionada: data);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo Evento'),
            )
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: eventosDoDia.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Agenda livre neste dia.', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: eventosDoDia.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final evento = eventosDoDia[index];
                  final cor = _getCorPorTipo(evento['tipo']);
                  final isFixo = evento['fixo'] == true; 
                  
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
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: cor.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                                    child: Icon(_getIconePorTipo(evento['tipo']), color: cor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(evento['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(evento['tipo'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                        if (evento['descricao'] != null && evento['descricao'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(evento['descricao'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        ]
                                      ],
                                    ),
                                  ),
                                  if (!isFixo) ...[
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: 'Editar', onPressed: () => _abrirModalEvento(eventoExistente: evento)),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Excluir', onPressed: () => _confirmarExclusao(context, evento)),
                                  ] else ...[
                                    const Padding(
                                      padding: EdgeInsets.only(right: 16.0),
                                      child: Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
                                    )
                                  ]
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar Painel', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  // ==========================================================================
  // CONSTRUTORES DE VISÃO DA GRADE
  // ==========================================================================
  Widget _buildVisaoMes(Map<String, List<Map<String, dynamic>>> eventosPorData) {
    final int diasNoMes = DateTime(_dataFoco.year, _dataFoco.month + 1, 0).day;
    final DateTime primeiroDiaDoMes = DateTime(_dataFoco.year, _dataFoco.month, 1);
    final int diasParaPular = primeiroDiaDoMes.weekday - 1; 

    int totalCelulas = diasNoMes + diasParaPular;
    int linhasNecessarias = (totalCelulas / 7).ceil();

    return Column(
      children: [
        Row(
          children: _diasSemanaAbrev.map((dia) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.blue.shade50, border: Border.all(color: Colors.white)),
              child: Text(dia, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ),
          )).toList(),
        ),
        ...List.generate(linhasNecessarias, (linhaIndex) {
          return Expanded(
            child: Row(
              children: List.generate(7, (colIndex) {
                int indiceGeral = (linhaIndex * 7) + colIndex;
                int diaReal = indiceGeral - diasParaPular + 1;

                if (diaReal < 1 || diaReal > diasNoMes) {
                  return Expanded(child: Container(decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200))));
                }

                DateTime dataCelula = DateTime(_dataFoco.year, _dataFoco.month, diaReal);
                String dataStr = _formatarData(dataCelula);
                List<Map<String, dynamic>> eventosDoDia = eventosPorData[dataStr] ?? [];
                bool isHoje = _isMesmoDia(dataCelula, DateTime.now());

                // LÓGICA DA BORDA COLORIDA NO APLICATIVO
                Color corBorda = Colors.grey.shade200;
                double larguraBorda = 1.0;
                if (isHoje) {
                  corBorda = Colors.blue.shade400;
                  larguraBorda = 2.0;
                } else if (eventosDoDia.isNotEmpty) {
                  corBorda = _getCorPorTipo(eventosDoDia.first['tipo']).withAlpha(150); 
                  larguraBorda = 1.5;
                }

                return Expanded(
                  child: InkWell(
                    onTap: () => _abrirModalDetalhesDia(dataCelula, eventosDoDia),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHoje ? Colors.blue.shade50.withAlpha(100) : Colors.white,
                        border: Border.all(color: corBorda, width: larguraBorda),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isHoje ? Colors.blue : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              diaReal.toString(),
                              style: TextStyle(fontWeight: isHoje ? FontWeight.bold : FontWeight.normal, color: isHoje ? Colors.white : Colors.black87),
                            ),
                          ),
                          const Spacer(),
                          if (eventosDoDia.isNotEmpty)
                            Wrap(
                              spacing: 4, runSpacing: 4,
                              children: eventosDoDia.take(5).map((e) {
                                return Tooltip(
                                  message: e['titulo'],
                                  child: Container(
                                    width: 12, height: 12, 
                                    decoration: BoxDecoration(
                                      color: _getCorPorTipo(e['tipo']), 
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.0)
                                    )
                                  ),
                                );
                              }).toList(),
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
    );
  }

  Widget _buildVisaoSemana(Map<String, List<Map<String, dynamic>>> eventosPorData) {
    DateTime segundaFeira = _dataFoco.subtract(Duration(days: _dataFoco.weekday - 1));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(7, (index) {
        DateTime dataDia = segundaFeira.add(Duration(days: index));
        String dataStr = _formatarData(dataDia);
        List<Map<String, dynamic>> eventosDoDia = eventosPorData[dataStr] ?? [];
        bool isHoje = _isMesmoDia(dataDia, DateTime.now());

        Color corBorda = Colors.grey.shade300;
        double larguraBorda = 1.0;
        if (isHoje) {
          corBorda = Colors.blue.shade400;
          larguraBorda = 2.0;
        } else if (eventosDoDia.isNotEmpty) {
          corBorda = _getCorPorTipo(eventosDoDia.first['tipo']).withAlpha(150); 
          larguraBorda = 1.5;
        }

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isHoje ? Colors.blue.shade50 : Colors.white,
              border: Border.all(color: corBorda, width: larguraBorda),
              borderRadius: BorderRadius.circular(12)
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _abrirModalDetalhesDia(dataDia, eventosDoDia),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: isHoje ? Colors.blue : Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                    child: Column(
                      children: [
                        Text(_diasSemanaAbrev[index], style: TextStyle(fontWeight: FontWeight.bold, color: isHoje ? Colors.white : Colors.blueGrey)),
                        const SizedBox(height: 4),
                        Text(dataDia.day.toString().padLeft(2, '0'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isHoje ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: eventosDoDia.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final evento = eventosDoDia[idx];
                      final cor = _getCorPorTipo(evento['tipo']);
                      return InkWell(
                        onTap: () => _abrirModalDetalhesDia(dataDia, eventosDoDia),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: cor.withAlpha(30), borderRadius: BorderRadius.circular(8), border: Border.all(color: cor.withAlpha(100))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(evento['titulo'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: cor), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
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
    );
  }

  Widget _buildVisaoAno(Map<String, List<Map<String, dynamic>>> eventosPorData) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.5),
      itemCount: 12,
      itemBuilder: (context, index) {
        int mes = index + 1;
        int qtdeEventos = 0;
        eventosPorData.forEach((dataStr, eventos) {
          final d = _converterDataString(dataStr);
          if (d != null && d.year == _dataFoco.year && d.month == mes) {
            qtdeEventos += eventos.length;
          }
        });

        bool isMesAtual = DateTime.now().year == _dataFoco.year && DateTime.now().month == mes;

        return InkWell(
          onTap: () {
            setState(() {
              _dataFoco = DateTime(_dataFoco.year, mes, 1);
              _modoVisualizacao = 'MÊS';
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isMesAtual ? Colors.blue.shade50 : Colors.white,
              border: Border.all(color: isMesAtual ? Colors.blue.shade200 : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(16)
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_mesesNomes[mes].toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isMesAtual ? Colors.blue.shade800 : Colors.blueGrey)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: qtdeEventos > 0 ? Colors.orange.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                  child: Text('$qtdeEventos eventos', style: TextStyle(fontWeight: FontWeight.bold, color: qtdeEventos > 0 ? Colors.orange.shade800 : Colors.grey)),
                )
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
      return (e['titulo'] ?? '').toString().toLowerCase().contains(busca) || (e['descricao'] ?? '').toString().toLowerCase().contains(busca);
    }).toList();

    if (filtrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Nenhum evento encontrado para esta pesquisa.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    filtrados.sort((a, b) {
      final dataA = _converterDataString(a['data'] ?? '') ?? DateTime(2000);
      final dataB = _converterDataString(b['data'] ?? '') ?? DateTime(2000);
      return dataA.compareTo(dataB);
    });

    return ListView.separated(
      itemCount: filtrados.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final evento = filtrados[index];
        final cor = _getCorPorTipo(evento['tipo']);
        final isFixo = evento['fixo'] == true;
        
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 8, decoration: BoxDecoration(color: cor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: cor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getIconePorTipo(evento['tipo']), color: cor, size: 28),
                              const SizedBox(height: 4),
                              Text(evento['data'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(evento['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                child: Text(evento['tipo'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                              ),
                            ],
                          ),
                        ),
                        if (!isFixo) ...[
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: 'Editar', onPressed: () => _abrirModalEvento(eventoExistente: evento)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Excluir', onPressed: () => _confirmarExclusao(context, evento)),
                        ] else ...[
                          const Padding(padding: EdgeInsets.only(right: 16.0), child: Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20))
                        ]
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
    final estadoCalendario = ref.watch(calendarioStreamProvider);
    final corPrimaria = Theme.of(context).primaryColor;

    String tituloPeriodo = '';
    if (_modoVisualizacao == 'MÊS' || _modoVisualizacao == 'SEMANA') {
      tituloPeriodo = '${_mesesNomes[_dataFoco.month]} ${_dataFoco.year}';
    } else {
      tituloPeriodo = '${_dataFoco.year}';
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1,
        title: const Text('Calendário Escolar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        onPressed: () => _abrirModalEvento(),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Evento', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            // BARRA SUPERIOR DE CONTROLES
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => _navegar(-1), icon: const Icon(Icons.chevron_left_rounded)),
                      SizedBox(
                        width: 150,
                        child: Text(tituloPeriodo, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
                      ),
                      IconButton(onPressed: () => _navegar(1), icon: const Icon(Icons.chevron_right_rounded)),
                      const SizedBox(width: 8),
                      TextButton(onPressed: _irParaHoje, child: const Text('HOJE', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const Spacer(),
                  
                  // ====== BOTÃO DE EXPORTAR PDF ======
                  estadoCalendario.when(
                    data: (eventosRaw) {
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, elevation: 0),
                        onPressed: () {
                          List<Map<String, dynamic>> todosEventos = List.from(eventosRaw);
                          todosEventos.addAll(_obterFeriadosNacionais(_dataFoco.year));
                          _exportarCalendarioParaPdf(todosEventos);
                        },
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Exportar PDF'),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (erro, stack) => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 24),
                  
                  // Seletor de Visão
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: ['SEMANA', 'MÊS', 'ANO'].map((modo) {
                        bool isAtivo = _modoVisualizacao == modo;
                        return InkWell(
                          onTap: () => setState(() => _modoVisualizacao = modo),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: isAtivo ? Colors.deepPurple : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                            child: Text(modo, style: TextStyle(fontWeight: FontWeight.bold, color: isAtivo ? Colors.white : Colors.grey.shade600)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Barra de Pesquisa
                  SizedBox(
                    width: 250,
                    height: 40,
                    child: TextField(
                      onChanged: (val) => _debouncer.run(() => setState(() => _termoBusca = val)),
                      decoration: InputDecoration(
                        hintText: 'Pesquisar evento...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ÁREA DE CONTEÚDO PRINCIPAL
            Expanded(
              child: estadoCalendario.when(
                loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
                error: (erro, stack) => Center(child: Text('Erro: $erro')),
                data: (eventosRaw) {
                  List<Map<String, dynamic>> todosEventos = List.from(eventosRaw);
                  todosEventos.addAll(_obterFeriadosNacionais(_dataFoco.year));
                  todosEventos.addAll(_obterFeriadosNacionais(_dataFoco.year - 1));
                  todosEventos.addAll(_obterFeriadosNacionais(_dataFoco.year + 1));

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