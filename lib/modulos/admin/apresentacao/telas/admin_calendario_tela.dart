import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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
  ConsumerState<AdminCalendarioTela> createState() =>
      _AdminCalendarioTelaState();
}

class _AdminCalendarioTelaState extends ConsumerState<AdminCalendarioTela> {
  DateTime _dataFoco = DateTime.now();
  String _modoVisualizacao = 'MÊS'; // ANO, MÊS, SEMANA
  String _termoBusca = '';
  final _debouncer = Debouncer(milliseconds: 400);

  final List<String> _mesesNomes = [
    '',
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  final List<String> _diasSemanaAbrev = [
    'SEG',
    'TER',
    'QUA',
    'QUI',
    'SEX',
    'SÁB',
    'DOM',
  ];

  // ==========================================================================
  // FERIADOS NACIONAIS FIXOS DO BRASIL
  // Gera automaticamente os feriados para o ano que o usuário está visualizando
  // ==========================================================================
  List<Map<String, dynamic>> _obterFeriadosNacionais(int ano) {
    return [
      {
        'id': 'feriado_1_$ano',
        'titulo': 'Confraternização Universal',
        'data': '01/01/$ano',
        'tipo': 'Feriado Nacional',
        'fixo': true,
      },
      {
        'id': 'feriado_2_$ano',
        'titulo': 'Tiradentes',
        'data': '21/04/$ano',
        'tipo': 'Feriado Nacional',
        'fixo': true,
      },
      {
        'id': 'feriado_3_$ano',
        'titulo': 'Dia do Trabalhador',
        'data': '01/05/$ano',
        'tipo': 'Feriado Nacional',
        'fixo': true,
      },
      {
        'id': 'feriado_4_$ano',
        'titulo': 'Independência do Brasil',
        'data': '07/09/$ano',
        'tipo': 'Feriado Nacional',
        'fixo': true,
      },
      {
        'id': 'feriado_5_$ano',
        'titulo': 'Nossa Senhora Aparecida',
        'data': '12/10/$ano',
        'tipo': 'Feriado Nacional',
        'fixo': true,
      },
      {
        'id': 'feriado_6_$ano',
        'titulo': 'Finados',
        'data': '02/11/$ano',
        'tipo': 'Feriado Nacional',
        'fixo': true,
      },
      {
        'id': 'feriado_7_$ano',
        'titulo': 'Proclamação da República',
        'data': '15/11/$ano',
        'tipo': 'Feriado Nacional',
        'fixo': true,
      },
      {
        'id': 'feriado_8_$ano',
        'titulo': 'Natal',
        'data': '25/12/$ano',
        'tipo': 'Feriado Nacional',
        'fixo': true,
      },
    ];
  }

  // ==========================================================================
  // FUNÇÕES UTILITÁRIAS DE DATA
  // ==========================================================================
  DateTime? _converterDataString(String dataStr) {
    try {
      final partes = dataStr.split('/');
      if (partes.length == 3) {
        return DateTime(
          int.parse(partes[2]),
          int.parse(partes[1]),
          int.parse(partes[0]),
        );
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
    return Colors.purple; // Cor para os eventos do tipo "Outro"
  }

  IconData _getIconePorTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('feriado') || t.contains('recesso'))
      return Icons.beach_access_rounded;
    if (t.contains('avaliação')) return Icons.edit_document;
    if (t.contains('reunião')) return Icons.groups_rounded;
    if (t.contains('escolar')) return Icons.event_rounded;
    return Icons.star_rounded; // Ícone para eventos do tipo "Outro"
  }

  // ==========================================================================
  // NAVEGAÇÃO DO CALENDÁRIO
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
  // MODAIS (ADICIONAR EVENTO E DETALHES DO DIA)
  // ==========================================================================
  void _confirmarExclusao(BuildContext context, Map<String, dynamic> evento) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Excluir Evento', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text('Deseja excluir o evento "${evento['titulo']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref
                  .read(calendarioServiceProvider)
                  .excluirEvento(evento['id']);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context); // Fecha o modal do dia também
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Evento excluído.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _abrirModalEvento({
    DateTime? dataPreSelecionada,
    Map<String, dynamic>? eventoExistente,
  }) {
    final formKey = GlobalKey<FormState>();
    final tituloCtrl = TextEditingController(
      text: eventoExistente?['titulo'] ?? '',
    );

    String dataInicial = '';
    if (eventoExistente != null) {
      dataInicial = eventoExistente['data'] ?? '';
    } else if (dataPreSelecionada != null) {
      dataInicial = _formatarData(dataPreSelecionada);
    }

    final dataCtrl = TextEditingController(text: dataInicial);
    final descCtrl = TextEditingController(
      text: eventoExistente?['descricao'] ?? '',
    );

    final listaTiposPadrao = [
      'Feriado / Recesso',
      'Evento Escolar',
      'Avaliação',
      'Reunião',
      'Outro',
    ];
    String tipoSelecionado = 'Evento Escolar';
    final tipoCustomCtrl = TextEditingController();

    // Se estiver editando e for um tipo diferente, marca como 'Outro' e preenche o campo
    if (eventoExistente != null &&
        !listaTiposPadrao.contains(eventoExistente['tipo'])) {
      tipoSelecionado = 'Outro';
      tipoCustomCtrl.text = eventoExistente['tipo'];
    } else if (eventoExistente != null) {
      tipoSelecionado = eventoExistente['tipo'];
    }

    final dataMask = MaskTextInputFormatter(
      mask: '##/##/####',
      filter: {"#": RegExp(r'[0-9]')},
    );
    if (dataInicial.isNotEmpty)
      dataMask.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: dataInicial),
      );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // StatefulBuilder para atualizar a UI do dropdown
        builder: (context, setStateModal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  eventoExistente == null
                      ? Icons.add_circle_outline
                      : Icons.edit,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  eventoExistente == null ? 'Novo Evento' : 'Editar Evento',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
                      decoration: const InputDecoration(
                        labelText: 'Título do Evento',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment
                          .start, // Alinha ao topo pro erro não quebrar o layout
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dataCtrl,
                            inputFormatters: [dataMask],
                            decoration: const InputDecoration(
                              labelText: 'Data (DD/MM/AAAA)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.length != 10)
                                return 'Data incompleta';

                              // VALIDAÇÃO INTELIGENTE DE DATA (Bloqueia dias > 31 e meses > 12)
                              final partes = v.split('/');
                              final dia = int.tryParse(partes[0]) ?? 0;
                              final mes = int.tryParse(partes[1]) ?? 0;
                              final ano = int.tryParse(partes[2]) ?? 0;

                              if (dia < 1 || dia > 31) return 'Dia inválido';
                              if (mes < 1 || mes > 12) return 'Mês inválido';

                              try {
                                final dataTeste = DateTime(ano, mes, dia);
                                // Se o DateTime corrigiu a data (ex: 30/02 virou 02/03), então a data original não existe
                                if (dataTeste.year != ano ||
                                    dataTeste.month != mes ||
                                    dataTeste.day != dia) {
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
                            value: tipoSelecionado,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                              border: OutlineInputBorder(),
                            ),
                            items: listaTiposPadrao
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setStateModal(() => tipoSelecionado = v!),
                          ),
                        ),
                      ],
                    ),

                    // CAMPO EXTRA SELECIONOU "OUTRO"
                    if (tipoSelecionado == 'Outro') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: tipoCustomCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Digite o tipo do evento',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.star_rounded,
                            color: Colors.purple,
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Por favor, informe o tipo' : null,
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descrição ou Observação (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.all(24),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final tipoFinal = tipoSelecionado == 'Outro'
                      ? tipoCustomCtrl.text.trim()
                      : tipoSelecionado;

                  final novoEvento = {
                    'id': eventoExistente?['id'],
                    'titulo': tituloCtrl.text.trim(),
                    'data': dataCtrl.text,
                    'tipo': tipoFinal,
                    'descricao': descCtrl.text.trim(),
                  };

                  await ref
                      .read(calendarioServiceProvider)
                      .salvarEvento(novoEvento);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (eventoExistente != null) Navigator.pop(context);
                  }
                },
                child: const Text('Salvar Evento'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirModalDetalhesDia(
    DateTime data,
    List<Map<String, dynamic>> eventosDoDia,
  ) {
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
                const Text(
                  'Agenda do Dia',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  _formatarData(data),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _abrirModalEvento(dataPreSelecionada: data);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo Evento'),
            ),
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
                      Icon(
                        Icons.event_busy,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Agenda livre neste dia.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: eventosDoDia.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final evento = eventosDoDia[index];
                    final cor = _getCorPorTipo(evento['tipo']);
                    final isFixo =
                        evento['fixo'] ==
                        true; // Trava para não apagar feriado nacional

                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              decoration: BoxDecoration(
                                color: cor,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: cor.withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getIconePorTipo(evento['tipo']),
                                        color: cor,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            evento['titulo'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            evento['tipo'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (evento['descricao'] != null &&
                                              evento['descricao']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              evento['descricao'],
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Se for feriado nacional gerado automático, esconde os botões
                                    if (!isFixo) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Editar',
                                        onPressed: () => _abrirModalEvento(
                                          eventoExistente: evento,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Excluir',
                                        onPressed: () =>
                                            _confirmarExclusao(context, evento),
                                      ),
                                    ] else ...[
                                      const Padding(
                                        padding: EdgeInsets.only(right: 16.0),
                                        child: Icon(
                                          Icons.lock_outline_rounded,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                    ],
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Fechar Painel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CONSTRUTORES DE VISÃO (ANO, MÊS, SEMANA, BUSCA)
  // ==========================================================================

  Widget _buildVisaoMes(
    Map<String, List<Map<String, dynamic>>> eventosPorData,
  ) {
    final int diasNoMes = DateTime(_dataFoco.year, _dataFoco.month + 1, 0).day;
    final DateTime primeiroDiaDoMes = DateTime(
      _dataFoco.year,
      _dataFoco.month,
      1,
    );
    final int diasParaPular = primeiroDiaDoMes.weekday - 1;

    int totalCelulas = diasNoMes + diasParaPular;
    int linhasNecessarias = (totalCelulas / 7).ceil();

    return Column(
      children: [
        Row(
          children: _diasSemanaAbrev
              .map(
                (dia) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.white),
                    ),
                    child: Text(
                      dia,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...List.generate(linhasNecessarias, (linhaIndex) {
          return Expanded(
            child: Row(
              children: List.generate(7, (colIndex) {
                int indiceGeral = (linhaIndex * 7) + colIndex;
                int diaReal = indiceGeral - diasParaPular + 1;

                if (diaReal < 1 || diaReal > diasNoMes) {
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                    ),
                  );
                }

                DateTime dataCelula = DateTime(
                  _dataFoco.year,
                  _dataFoco.month,
                  diaReal,
                );
                String dataStr = _formatarData(dataCelula);
                List<Map<String, dynamic>> eventosDoDia =
                    eventosPorData[dataStr] ?? [];
                bool isHoje = _isMesmoDia(dataCelula, DateTime.now());

                return Expanded(
                  child: InkWell(
                    onTap: () =>
                        _abrirModalDetalhesDia(dataCelula, eventosDoDia),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHoje
                            ? Colors.blue.shade50.withAlpha(100)
                            : Colors.white,
                        border: Border.all(
                          color: isHoje
                              ? Colors.blue.shade200
                              : Colors.grey.shade200,
                        ),
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
                              style: TextStyle(
                                fontWeight: isHoje
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isHoje ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (eventosDoDia.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: eventosDoDia.take(4).map((e) {
                                return Tooltip(
                                  message: e['titulo'],
                                  // BOLINHAS MAIORES PARA MELHOR VISUALIZAÇÃO
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getCorPorTipo(e['tipo']),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ), // Bordinha para destacar
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
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

  Widget _buildVisaoSemana(
    Map<String, List<Map<String, dynamic>>> eventosPorData,
  ) {
    DateTime segundaFeira = _dataFoco.subtract(
      Duration(days: _dataFoco.weekday - 1),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(7, (index) {
        DateTime dataDia = segundaFeira.add(Duration(days: index));
        String dataStr = _formatarData(dataDia);
        List<Map<String, dynamic>> eventosDoDia = eventosPorData[dataStr] ?? [];
        bool isHoje = _isMesmoDia(dataDia, DateTime.now());

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isHoje ? Colors.blue.shade50 : Colors.white,
              border: Border.all(
                color: isHoje ? Colors.blue.shade200 : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _abrirModalDetalhesDia(dataDia, eventosDoDia),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isHoje ? Colors.blue : Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _diasSemanaAbrev[index],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isHoje ? Colors.white : Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dataDia.day.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isHoje ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: eventosDoDia.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final evento = eventosDoDia[idx];
                      final cor = _getCorPorTipo(evento['tipo']);
                      return InkWell(
                        onTap: () =>
                            _abrirModalDetalhesDia(dataDia, eventosDoDia),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cor.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cor.withAlpha(100)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                evento['titulo'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: cor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildVisaoAno(
    Map<String, List<Map<String, dynamic>>> eventosPorData,
  ) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
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

        bool isMesAtual =
            DateTime.now().year == _dataFoco.year &&
            DateTime.now().month == mes;

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
              border: Border.all(
                color: isMesAtual ? Colors.blue.shade200 : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _mesesNomes[mes].toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isMesAtual ? Colors.blue.shade800 : Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: qtdeEventos > 0
                        ? Colors.orange.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$qtdeEventos eventos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: qtdeEventos > 0
                          ? Colors.orange.shade800
                          : Colors.grey,
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

  Widget _buildListaBusca(List<Map<String, dynamic>> eventos) {
    final filtrados = eventos.where((e) {
      final busca = _termoBusca.toLowerCase();
      return (e['titulo'] ?? '').toString().toLowerCase().contains(busca) ||
          (e['descricao'] ?? '').toString().toLowerCase().contains(busca);
    }).toList();

    if (filtrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum evento encontrado para esta pesquisa.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final evento = filtrados[index];
        final cor = _getCorPorTipo(evento['tipo']);
        final isFixo = evento['fixo'] == true;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getIconePorTipo(evento['tipo']),
                                color: cor,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                evento['data'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                evento['titulo'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  evento['tipo'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isFixo) ...[
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Editar',
                            onPressed: () =>
                                _abrirModalEvento(eventoExistente: evento),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Excluir',
                            onPressed: () =>
                                _confirmarExclusao(context, evento),
                          ),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.only(right: 16.0),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                        ],
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: const Text(
          'Calendário Escolar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        onPressed: () => _abrirModalEvento(),
        icon: const Icon(Icons.add),
        label: const Text(
          'Adicionar Evento',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            // BARRA SUPERIOR DE CONTROLES
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // Navegação de Datas
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _navegar(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      SizedBox(
                        width: 150,
                        child: Text(
                          tituloPeriodo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _navegar(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _irParaHoje,
                        child: const Text(
                          'HOJE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Seletor de Visão
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: ['SEMANA', 'MÊS', 'ANO'].map((modo) {
                        bool isAtivo = _modoVisualizacao == modo;
                        return InkWell(
                          onTap: () => setState(() => _modoVisualizacao = modo),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isAtivo
                                  ? Colors.deepPurple
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              modo,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isAtivo
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
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
                      onChanged: (val) => _debouncer.run(
                        () => setState(() => _termoBusca = val),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Pesquisar evento...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ÁREA DE CONTEÚDO PRINCIPAL
            Expanded(
              child: estadoCalendario.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: corPrimaria),
                ),
                error: (e, s) => Center(child: Text('Erro: $e')),
                data: (eventosRaw) {
                  // JUNTA OS EVENTOS DO BANCO COM OS FERIADOS NACIONAIS GERADOS
                  List<Map<String, dynamic>> todosEventos = List.from(
                    eventosRaw,
                  );
                  todosEventos.addAll(_obterFeriadosNacionais(_dataFoco.year));
                  // Adiciona do ano anterior e próximo para cobrir viradas de ano na visualização
                  todosEventos.addAll(
                    _obterFeriadosNacionais(_dataFoco.year - 1),
                  );
                  todosEventos.addAll(
                    _obterFeriadosNacionais(_dataFoco.year + 1),
                  );

                  if (_termoBusca.isNotEmpty) {
                    return _buildListaBusca(todosEventos);
                  }

                  // Agrupa os eventos por data
                  Map<String, List<Map<String, dynamic>>> eventosPorData = {};
                  for (var e in todosEventos) {
                    final dataStr = e['data']?.toString() ?? '';
                    if (dataStr.isNotEmpty) {
                      if (!eventosPorData.containsKey(dataStr))
                        eventosPorData[dataStr] = [];
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
