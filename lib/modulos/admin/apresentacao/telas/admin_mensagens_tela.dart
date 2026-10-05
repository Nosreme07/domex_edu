import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/turma_provider.dart';

class AdminMensagensTela extends ConsumerStatefulWidget {
  const AdminMensagensTela({super.key});

  @override
  ConsumerState<AdminMensagensTela> createState() => _AdminMensagensTelaState();
}

class _AdminMensagensTelaState extends ConsumerState<AdminMensagensTela> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _mensagemCtrl = TextEditingController();
  
  String _destinatario = 'TODA_ESCOLA'; 
  Map<String, dynamic>? _entidadeSelecionada;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensagemCtrl.dispose();
    super.dispose();
  }

  void _enviarMensagem() {
    if (_formKey.currentState!.validate()) {
      if (['ALUNO', 'PROFESSOR', 'TURMA', 'RESPONSAVEL'].contains(_destinatario) && _entidadeSelecionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, pesquise e selecione o destinatário exato na lista.'), backgroundColor: Colors.red));
        return;
      }
      
      // =========================================================
      // AQUI FICA A SUA LÓGICA DE SALVAR A MENSAGEM NO FIREBASE
      // =========================================================
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensagem enviada com sucesso!'), backgroundColor: Colors.green));
      _tituloCtrl.clear();
      _mensagemCtrl.clear();
      setState(() => _entidadeSelecionada = null);
    }
  }

  Widget _buildAutocompleteField({
    required String label, 
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) displayString,
    required Widget Function(Map<String, dynamic>) subtitleBuilder,
    required bool Function(Map<String, dynamic>, String) searchFilter,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<Map<String, dynamic>>(
        key: ValueKey(_destinatario), 
        displayStringForOption: displayString,
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) return items;
          return items.where((item) => searchFilter(item, textEditingValue.text.toLowerCase()));
        },
        onSelected: (selection) => setState(() => _entidadeSelecionada = selection),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: controller, focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label, 
              hintText: 'Digite para pesquisar...', 
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.blue), 
              border: const OutlineInputBorder(), 
              filled: true, 
              fillColor: Colors.blue.shade50.withAlpha(50)
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Pesquise e selecione um destinatário';
              if (_entidadeSelecionada == null || displayString(_entidadeSelecionada!) != v) return 'Selecione uma opção válida na lista suspensa que apareceu.';
              return null;
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8.0, borderRadius: BorderRadius.circular(8), color: Colors.white,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 250, maxWidth: constraints.maxWidth), 
                child: ListView.separated(
                  padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      title: Text(displayString(option), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                      subtitle: subtitleBuilder(option), 
                      hoverColor: Colors.blue.shade50, 
                      onTap: () => onSelected(option)
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    
    final alunosList = ref.watch(alunosStreamProvider).value ?? [];
    final professoresList = ref.watch(professoresStreamProvider).value ?? [];
    final turmasList = ref.watch(turmasStreamProvider).value ?? [];

    // ========================================================================
    // EXTRAÇÃO INTELIGENTE DE RESPONSÁVEIS DOS ALUNOS
    // Isso agrupa responsáveis pelo CPF para não duplicar se tiverem 2 filhos
    // e salva o nome dos alunos atrelados a eles para podermos pesquisar!
    // ========================================================================
    Map<String, Map<String, dynamic>> responsaveisMap = {};
    for (var aluno in alunosList) {
      final resps = aluno['responsaveis'] as List? ?? [];
      final alunoNome = aluno['nome'] ?? 'Aluno sem nome';
      
      for (var r in resps) {
        final cpf = r['cpf']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
        final nome = r['nome']?.toString() ?? 'Responsável';
        final email = r['email']?.toString() ?? '';
        
        // Usa o CPF como chave única (ou o nome se não tiver CPF)
        final key = cpf.isNotEmpty ? cpf : nome;
        
        if (key.trim().isEmpty) continue;

        if (responsaveisMap.containsKey(key)) {
          // Se o pai já tá na lista (tem outro filho), só adicionamos o nome do novo aluno
          responsaveisMap[key]!['alunosVinculados'] += ' / $alunoNome';
        } else {
          // Se é novo, cria a ficha dele
          responsaveisMap[key] = {
            'nome': nome,
            'cpf': r['cpf'] ?? '',
            'telefone': r['telefone'] ?? '',
            'email': email,
            'alunosVinculados': alunoNome,
            'idBusca': key, 
          };
        }
      }
    }
    
    // Converte o mapa agrupado de volta para uma lista
    final responsaveisList = responsaveisMap.values.toList();
    responsaveisList.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

    return Scaffold(
      appBar: AppBar(title: const Text('Comunicações e Avisos', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [Icon(Icons.campaign_rounded, color: corPrimaria, size: 32), const SizedBox(width: 12), const Text('Novo Aviso / Comunicado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 8),
                      Text('Envie mensagens, comunicados ou cobranças diretamente para o aplicativo.', style: TextStyle(color: Colors.grey.shade600)),
                      const Divider(height: 48),

                      DropdownButtonFormField<String>(
                        value: _destinatario,
                        decoration: const InputDecoration(labelText: 'Enviar para quem?', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people_alt_rounded)),
                        items: const [
                          DropdownMenuItem(value: 'TODA_ESCOLA', child: Text('Toda a Escola (Geral)')),
                          DropdownMenuItem(value: 'TODOS_PROFESSORES', child: Text('Todos os Professores')),
                          DropdownMenuItem(value: 'TURMA', child: Text('Uma Turma Específica')),
                          DropdownMenuItem(value: 'PROFESSOR', child: Text('Um Professor Específico')),
                          DropdownMenuItem(value: 'ALUNO', child: Text('Um Aluno Específico')),
                          DropdownMenuItem(value: 'RESPONSAVEL', child: Text('Um Responsável Específico')),
                        ],
                        onChanged: (val) { if (val != null) setState(() { _destinatario = val; _entidadeSelecionada = null; }); },
                      ),
                      
                      if (_destinatario == 'ALUNO') ...[
                        const SizedBox(height: 24),
                        _buildAutocompleteField(
                          label: 'Pesquisar Aluno (Nome ou Matrícula)', items: alunosList,
                          displayString: (a) => a['nome'] ?? 'Sem Nome',
                          searchFilter: (a, busca) => (a['nome'] ?? '').toString().toLowerCase().contains(busca) || (a['matricula'] ?? '').toString().toLowerCase().contains(busca),
                          subtitleBuilder: (a) => Text('Matrícula: ${a['matricula']} | Turma: ${a['turma'] ?? 'Não vinculada'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ),
                      ],

                      if (_destinatario == 'TURMA') ...[
                        const SizedBox(height: 24),
                        _buildAutocompleteField(
                          label: 'Pesquisar Turma (Nome ou Ano)', items: turmasList,
                          displayString: (t) => '${t['nome']} (${t['anoLetivo']})',
                          searchFilter: (t, busca) => (t['nome'] ?? '').toString().toLowerCase().contains(busca) || (t['anoLetivo'] ?? '').toString().toLowerCase().contains(busca),
                          subtitleBuilder: (t) => Text('Turno: ${t['turno'] ?? '-'} | Sala: ${t['sala'] ?? '-'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ),
                      ],

                      if (_destinatario == 'PROFESSOR') ...[
                        const SizedBox(height: 24),
                        _buildAutocompleteField(
                          label: 'Pesquisar Professor', items: professoresList,
                          displayString: (p) => p['nome'] ?? 'Sem Nome',
                          searchFilter: (p, busca) => (p['nome'] ?? '').toString().toLowerCase().contains(busca),
                          subtitleBuilder: (p) => Text('Disciplinas: ${(p['disciplinas'] as List? ?? []).join(', ')}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ),
                      ],

                      if (_destinatario == 'RESPONSAVEL') ...[
                        const SizedBox(height: 24),
                        _buildAutocompleteField(
                          label: 'Pesquisar Responsável (Nome do pai, da mãe ou do aluno)', 
                          items: responsaveisList,
                          displayString: (r) => r['nome'] ?? 'Sem Nome',
                          searchFilter: (r, busca) {
                            final nome = (r['nome'] ?? '').toString().toLowerCase();
                            final alunosRelacionados = (r['alunosVinculados'] ?? '').toString().toLowerCase();
                            final cpfLimpo = (r['cpf'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
                            final buscaLimpa = busca.replaceAll(RegExp(r'[^0-9]'), '');
                            
                            // Procura pelo nome do responsável, nome do aluno ou CPF!
                            return nome.contains(busca) || alunosRelacionados.contains(busca) || (buscaLimpa.isNotEmpty && cpfLimpo.contains(buscaLimpa));
                          },
                          subtitleBuilder: (r) => Text('Responsável por: ${r['alunosVinculados']}\nCPF: ${r['cpf']} | Tel: ${r['telefone']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ),
                      ],

                      const SizedBox(height: 24),
                      TextFormField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título do Aviso', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Informe o título do aviso' : null),
                      const SizedBox(height: 24),
                      TextFormField(controller: _mensagemCtrl, maxLines: 6, decoration: const InputDecoration(labelText: 'Escreva a sua mensagem...', alignLabelWithHint: true, border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'A mensagem não pode estar vazia' : null),
                      const SizedBox(height: 32),

                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: _enviarMensagem, icon: const Icon(Icons.send_rounded), label: const Text('ENVIAR COMUNICADO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}