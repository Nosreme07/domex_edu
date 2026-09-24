import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // <--- IMPORT ADICIONADO AQUI
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

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

  List<Map<String, dynamic>> _obterFeriadosNacionais(int ano) {
    return [
      {'id': 'feriado_1_$ano', 'titulo': 'Confrat. Universal', 'data': '01/01/$ano', 'tipo': 'Feriado / Recesso'},
      {'id': 'feriado_2_$ano', 'titulo': 'Tiradentes', 'data': '21/04/$ano', 'tipo': 'Feriado / Recesso'},
      {'id': 'feriado_3_$ano', 'titulo': 'Dia do Trabalhador', 'data': '01/05/$ano', 'tipo': 'Feriado / Recesso'},
      {'id': 'feriado_4_$ano', 'titulo': 'Indep. do Brasil', 'data': '07/09/$ano', 'tipo': 'Feriado / Recesso'},
      {'id': 'feriado_5_$ano', 'titulo': 'N. S. Aparecida', 'data': '12/10/$ano', 'tipo': 'Feriado / Recesso'},
      {'id': 'feriado_6_$ano', 'titulo': 'Finados', 'data': '02/11/$ano', 'tipo': 'Feriado / Recesso'},
      {'id': 'feriado_7_$ano', 'titulo': 'Proc. da República', 'data': '15/11/$ano', 'tipo': 'Feriado / Recesso'},
      {'id': 'feriado_8_$ano', 'titulo': 'Natal', 'data': '25/12/$ano', 'tipo': 'Feriado / Recesso'},
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

  void _abrirModalDetalhesDia(DateTime data, List<Map<String, dynamic>> eventosDoDia, Color corPrimaria) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agenda do Dia', style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text(_formatarData(data), style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria)),
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
                    Text('Nenhum evento registrado.', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: eventosDoDia.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final evento = eventosDoDia[index];
                  final cor = _getCorPorTipo(evento['tipo']);
                  
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }

  Widget _buildVisaoMes(Map<String, List<Map<String, dynamic>>> eventosPorData, bool isMobile, Color corPrimaria) {
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
              padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: corPrimaria.withAlpha(20), border: Border.all(color: Colors.white)),
              child: Text(dia, style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria, fontSize: isMobile ? 10 : 14)),
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

                Color corBorda = Colors.grey.shade200;
                double larguraBorda = 1.0;
                if (isHoje) {
                  corBorda = corPrimaria;
                  larguraBorda = 2.0;
                } else if (eventosDoDia.isNotEmpty) {
                  corBorda = _getCorPorTipo(eventosDoDia.first['tipo']).withAlpha(150); 
                  larguraBorda = 1.5;
                }

                return Expanded(
                  child: InkWell(
                    onTap: () => _abrirModalDetalhesDia(dataCelula, eventosDoDia, corPrimaria),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHoje ? corPrimaria.withAlpha(20) : Colors.white,
                        border: Border.all(color: corBorda, width: larguraBorda),
                      ),
                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isMobile ? 4 : 6),
                            decoration: BoxDecoration(
                              color: isHoje ? corPrimaria : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              diaReal.toString(),
                              style: TextStyle(
                                fontWeight: isHoje ? FontWeight.bold : FontWeight.normal, 
                                color: isHoje ? Colors.white : Colors.black87,
                                fontSize: isMobile ? 12 : 14
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (eventosDoDia.isNotEmpty)
                            Wrap(
                              spacing: 2, runSpacing: 2,
                              children: eventosDoDia.take(isMobile ? 3 : 5).map((e) {
                                return Container(
                                  width: isMobile ? 8 : 12, 
                                  height: isMobile ? 8 : 12, 
                                  decoration: BoxDecoration(
                                    color: _getCorPorTipo(e['tipo']), 
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.0)
                                  )
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

  Widget _buildVisaoSemana(Map<String, List<Map<String, dynamic>>> eventosPorData, bool isMobile, Color corPrimaria) {
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
          corBorda = corPrimaria;
          larguraBorda = 2.0;
        } else if (eventosDoDia.isNotEmpty) {
          corBorda = _getCorPorTipo(eventosDoDia.first['tipo']).withAlpha(150); 
        }

        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 1 : 4),
            decoration: BoxDecoration(
              color: isHoje ? corPrimaria.withAlpha(10) : Colors.white,
              border: Border.all(color: corBorda, width: larguraBorda),
              borderRadius: BorderRadius.circular(12)
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _abrirModalDetalhesDia(dataDia, eventosDoDia, corPrimaria),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
                    decoration: BoxDecoration(color: isHoje ? corPrimaria : Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                    child: Column(
                      children: [
                        Text(_diasSemanaAbrev[index], style: TextStyle(fontWeight: FontWeight.bold, color: isHoje ? Colors.white : Colors.blueGrey, fontSize: isMobile ? 10 : 14)),
                        const SizedBox(height: 4),
                        Text(dataDia.day.toString().padLeft(2, '0'), style: TextStyle(fontSize: isMobile ? 16 : 24, fontWeight: FontWeight.bold, color: isHoje ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.all(isMobile ? 4 : 8),
                    itemCount: eventosDoDia.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final evento = eventosDoDia[idx];
                      final cor = _getCorPorTipo(evento['tipo']);
                      return InkWell(
                        onTap: () => _abrirModalDetalhesDia(dataDia, eventosDoDia, corPrimaria),
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 4 : 8),
                          decoration: BoxDecoration(color: cor.withAlpha(30), borderRadius: BorderRadius.circular(8), border: Border.all(color: cor.withAlpha(100))),
                          child: Text(evento['titulo'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10 : 12, color: cor), maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _buildVisaoAno(Map<String, List<Map<String, dynamic>>> eventosPorData, bool isMobile, Color corPrimaria) {
    int colunas = isMobile ? 2 : 4;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: colunas, 
        crossAxisSpacing: 12, 
        mainAxisSpacing: 12, 
        childAspectRatio: isMobile ? 1.4 : 1.5
      ),
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
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            decoration: BoxDecoration(
              color: isMesAtual ? corPrimaria.withAlpha(20) : Colors.white,
              border: Border.all(color: isMesAtual ? corPrimaria.withAlpha(100) : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(16)
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_mesesNomes[mes].toUpperCase(), style: TextStyle(fontSize: isMobile ? 14 : 18, fontWeight: FontWeight.bold, color: isMesAtual ? corPrimaria : Colors.blueGrey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: qtdeEventos > 0 ? Colors.orange.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                  child: Text('$qtdeEventos eventos', style: TextStyle(fontWeight: FontWeight.bold, color: qtdeEventos > 0 ? Colors.orange.shade800 : Colors.grey, fontSize: isMobile ? 11 : 14)),
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
            const Text('Nenhum evento encontrado.', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(evento['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                child: Text(evento['tipo'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                              ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarioLogado = ref.watch(authProvider).value;
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    if (usuarioLogado == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final tenantId = usuarioLogado.tenantId; 
    final corPrimaria = usuarioLogado.corPrimaria;

    String tituloPeriodo = '';
    if (_modoVisualizacao == 'MÊS' || _modoVisualizacao == 'SEMANA') {
      tituloPeriodo = '${_mesesNomes[_dataFoco.month]} ${_dataFoco.year}';
    } else {
      tituloPeriodo = '${_dataFoco.year}';
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black87, 
        elevation: 1,
        // ====================================================================
        // AQUI ESTÁ O BOTÃO DE VOLTAR MANUAL INSERIDO NO APPBAR
        // ====================================================================
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/aluno'), // Volta para o Dashboard do Aluno
        ),
        title: const Text('Calendário Escolar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 32.0),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              width: double.infinity,
              child: isMobile 
                ? Column( 
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(onPressed: () => _navegar(-1), icon: const Icon(Icons.chevron_left_rounded, size: 22), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                              const SizedBox(width: 8),
                              Text(tituloPeriodo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corPrimaria)),
                              const SizedBox(width: 8),
                              IconButton(onPressed: () => _navegar(1), icon: const Icon(Icons.chevron_right_rounded, size: 22), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                            ],
                          ),
                          TextButton(
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            onPressed: () => setState(() => _dataFoco = DateTime.now()), 
                            child: const Text('HOJE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['SEM', 'MÊS', 'ANO'].map((modo) {
                                String valorReal = modo == 'SEM' ? 'SEMANA' : modo;
                                bool isAtivo = _modoVisualizacao == valorReal;
                                return InkWell(
                                  onTap: () => setState(() => _modoVisualizacao = valorReal),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: isAtivo ? corPrimaria : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                    child: Text(modo, style: TextStyle(fontWeight: FontWeight.bold, color: isAtivo ? Colors.white : Colors.grey.shade600, fontSize: 11)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: TextField(
                                onChanged: (val) => _debouncer.run(() => setState(() => _termoBusca = val)),
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Pesquisar...',
                                  prefixIcon: const Icon(Icons.search, size: 16),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  )
                : Row( 
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(onPressed: () => _navegar(-1), icon: const Icon(Icons.chevron_left_rounded)),
                          SizedBox(
                            width: 140,
                            child: Text(tituloPeriodo, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: corPrimaria)),
                          ),
                          IconButton(onPressed: () => _navegar(1), icon: const Icon(Icons.chevron_right_rounded)),
                          TextButton(onPressed: () => setState(() => _dataFoco = DateTime.now()), child: const Text('HOJE', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const Spacer(),
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
                                child: Text(modo, style: TextStyle(fontWeight: FontWeight.bold, color: isAtivo ? Colors.white : Colors.grey.shade600, fontSize: 12)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(width: 24),
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
                      ),
                    ],
                  ),
            ),
            SizedBox(height: isMobile ? 12 : 24),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('calendario').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: corPrimaria));
                  }
                  
                  final eventosRaw = snapshot.data?.docs.map((d) => d.data() as Map<String, dynamic>).toList() ?? [];

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
                    return _buildVisaoMes(eventosPorData, isMobile, corPrimaria);
                  } else if (_modoVisualizacao == 'SEMANA') {
                    return _buildVisaoSemana(eventosPorData, isMobile, corPrimaria);
                  } else {
                    return _buildVisaoAno(eventosPorData, isMobile, corPrimaria);
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