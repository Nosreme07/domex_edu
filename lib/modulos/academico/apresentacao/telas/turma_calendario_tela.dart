import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class TurmaCalendarioTela extends ConsumerStatefulWidget {
  final Map<String, dynamic> turma;
  const TurmaCalendarioTela({super.key, required this.turma});

  @override
  ConsumerState<TurmaCalendarioTela> createState() => _TurmaCalendarioTelaState();
}

class _TurmaCalendarioTelaState extends ConsumerState<TurmaCalendarioTela> {
  DateTime _dataFiltro = DateTime.now();

  Future<List<String>> _buscarDisciplinasDoUsuario(String tenantId, String userId) async {
    try {
      final docProf = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('professores').doc(userId).get();
      if (docProf.exists && docProf.data() != null) {
        return List<String>.from(docProf.data()!['disciplinas'] ?? ['Geral']);
      }
    } catch (_) {}
    return ['Coordenação / Geral'];
  }

  void _abrirModalNovoEvento(Color corPrimaria, String tenantId, String usuarioNome, String usuarioId) {
    final ctrlTitulo = TextEditingController();
    final ctrlDescricao = TextEditingController();
    DateTime dataEscolhida = DateTime.now();
    String tipoSelecionado = 'Prova';
    String? disciplinaSelecionada;
    bool salvando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final dataFormatada = DateFormat('dd/MM/yyyy').format(dataEscolhida);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.event_available_rounded, color: corPrimaria),
                const SizedBox(width: 8),
                const Text('Novo Evento da Turma', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: ctrlTitulo, decoration: const InputDecoration(labelText: 'Título do Evento (Ex: Prova Bimestral)', border: OutlineInputBorder()), textCapitalization: TextCapitalization.sentences),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Tipo de Evento', border: OutlineInputBorder()),
                            value: tipoSelecionado,
                            items: ['Prova', 'Trabalho', 'Simulado', 'Reunião', 'Passeio', 'Feriado', 'Outros'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setModalState(() => tipoSelecionado = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(context: context, initialDate: dataEscolhida, firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (date != null) setModalState(() => dataEscolhida = date);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Data', border: OutlineInputBorder()),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dataFormatada), const Icon(Icons.calendar_month_rounded, color: Colors.grey)]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<String>>(
                      future: _buscarDisciplinasDoUsuario(tenantId, usuarioId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                        List<String> disciplinas = snapshot.data ?? ['Geral'];
                        disciplinaSelecionada ??= disciplinas.first;
                        if (!disciplinas.contains(disciplinaSelecionada)) disciplinas.add(disciplinaSelecionada!);

                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Disciplina', border: OutlineInputBorder()),
                          value: disciplinaSelecionada,
                          items: disciplinas.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (v) => setModalState(() => disciplinaSelecionada = v),
                        );
                      }
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: ctrlDescricao, maxLines: 3, decoration: const InputDecoration(labelText: 'Detalhes / Assuntos (Opcional)', border: OutlineInputBorder()), textCapitalization: TextCapitalization.sentences),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: salvando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white),
                onPressed: salvando ? null : () async {
                  if (ctrlTitulo.text.trim().isEmpty) return;
                  setModalState(() => salvando = true);
                  
                  try {
                    await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(widget.turma['id']).collection('eventos').add({
                      'titulo': ctrlTitulo.text.trim(),
                      'descricao': ctrlDescricao.text.trim(),
                      'tipo': tipoSelecionado,
                      'disciplina': disciplinaSelecionada ?? 'Geral',
                      'dataEvento': DateFormat('yyyy-MM-dd').format(dataEscolhida),
                      'dataCriacao': FieldValue.serverTimestamp(),
                      'autorId': usuarioId,
                      'autorNome': usuarioNome,
                    });
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento adicionado à turma!'), backgroundColor: Colors.green));
                  } catch (e) {
                    setModalState(() => salvando = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                  }
                },
                icon: salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_rounded),
                label: const Text('Salvar Evento'),
              )
            ],
          );
        }
      ),
    );
  }

  void _excluirEvento(String tenantId, String eventoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Evento', style: TextStyle(color: Colors.red)),
        content: const Text('Tem certeza que deseja apagar este evento do calendário da turma?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(widget.turma['id']).collection('eventos').doc(eventoId).delete();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Excluir'),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final tenantId = user.tenantId;
    final corPrimaria = user.corPrimaria;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calendário da Turma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.turma['nome'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Ir para data',
            onPressed: () async {
              final date = await showDatePicker(context: context, initialDate: _dataFiltro, firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (date != null) setState(() => _dataFiltro = date);
            }
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: corPrimaria, foregroundColor: Colors.white,
        onPressed: () => _abrirModalNovoEvento(corPrimaria, tenantId, user.nome, user.id),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Evento / Prova', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FILTRO LATERAL
          Container(
            width: 250, color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('MMMM yyyy', 'pt_BR').format(_dataFiltro).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: corPrimaria)),
                const SizedBox(height: 16),
                CalendarDatePicker(
                  initialDate: _dataFiltro, firstDate: DateTime(2020), lastDate: DateTime(2030),
                  onDateChanged: (date) => setState(() => _dataFiltro = date),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Dica: Use este calendário para marcar as semanas de prova, trabalhos e eventos. Todos os alunos verão no aplicativo deles.', style: TextStyle(fontSize: 12, color: Colors.black87)),
                )
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),
          
          // LISTA DE EVENTOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('turmas').doc(widget.turma['id']).collection('eventos').orderBy('dataEvento').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: corPrimaria));
                
                final eventos = snapshot.data?.docs ?? [];
                // Filtra para mostrar do mês selecionado em diante, ou apenas os do mês
                final eventosFiltrados = eventos.where((e) {
                  final dataEv = DateTime.parse(e['dataEvento']);
                  return dataEv.year == _dataFiltro.year && dataEv.month == _dataFiltro.month;
                }).toList();

                if (eventosFiltrados.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Nenhum evento para ${DateFormat('MMMM', 'pt_BR').format(_dataFiltro)}.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(32).copyWith(bottom: 100),
                  itemCount: eventosFiltrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final ev = eventosFiltrados[index].data() as Map<String, dynamic>;
                    final evId = eventosFiltrados[index].id;
                    final dataEv = DateTime.parse(ev['dataEvento']);
                    
                    Color corTag = Colors.grey;
                    if (ev['tipo'] == 'Prova') corTag = Colors.red;
                    if (ev['tipo'] == 'Trabalho') corTag = Colors.orange;
                    if (ev['tipo'] == 'Simulado') corTag = Colors.purple;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // DIA
                        SizedBox(
                          width: 80,
                          child: Column(
                            children: [
                              Text(DateFormat('EEE', 'pt_BR').format(dataEv).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                              Container(
                                margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: dataEv.day == DateTime.now().day && dataEv.month == DateTime.now().month ? corPrimaria : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                                child: Text('${dataEv.day}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: dataEv.day == DateTime.now().day && dataEv.month == DateTime.now().month ? Colors.white : Colors.black87)),
                              )
                            ],
                          ),
                        ),
                        // CARD DO EVENTO
                        Expanded(
                          child: Card(
                            elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: corTag.withAlpha(20), borderRadius: BorderRadius.circular(6)), child: Text(ev['tipo'] ?? '', style: TextStyle(color: corTag, fontSize: 10, fontWeight: FontWeight.bold))),
                                            const SizedBox(width: 8),
                                            Text(ev['disciplina'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(ev['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        if (ev['descricao'] != null && ev['descricao'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(ev['descricao'], style: TextStyle(color: Colors.grey.shade700)),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text('Marcado por: ${ev['autorNome'] ?? 'Desconhecido'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                  if (user.id == ev['autorId'] || user.email == 'admin@admin.com') // Regra básica de exclusão
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                      onPressed: () => _excluirEvento(tenantId, evId),
                                    )
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}