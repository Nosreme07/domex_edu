import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/turma_provider.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

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
  bool _enviando = false;

  // Filtros do Feed
  String _termoBuscaFeed = '';
  String _filtroDestinoFeed = 'TODOS';
  DateTime? _dataFiltroInicio;
  DateTime? _dataFiltroFim;
  int _limiteAvisos = 5; // Apenas as 5 últimas mensagens inicialmente
  
  late Future<List<Map<String, dynamic>>> _futureAvisos;

  @override
  void initState() {
    super.initState();
    _futureAvisos = _carregarTodosAvisos();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensagemCtrl.dispose();
    super.dispose();
  }

  void _recarregarFeed() {
    setState(() {
      _futureAvisos = _carregarTodosAvisos();
    });
  }

  Future<List<Map<String, dynamic>>> _carregarTodosAvisos() async {
    final user = ref.read(authProvider).value;
    if (user == null) return [];
    
    final db = FirebaseFirestore.instance;
    final tenantId = user.tenantId;
    List<Map<String, dynamic>> listaCompleta = [];

    // Busca avisos dentro das turmas
    final turmasSnap = await db.collection('tenants').doc(tenantId).collection('turmas').get();
    for (var t in turmasSnap.docs) {
      final avisosSnap = await t.reference.collection('avisos').get();
      for (var a in avisosSnap.docs) {
        final data = a.data();
        data['id'] = a.id;
        data['turmaId'] = t.id;
        data['turmaNome'] = t['nome'] ?? 'Turma';
        data['isProfessorGlobal'] = false;
        listaCompleta.add(data);
      }
    }

    // Busca avisos globais de professores
    final profsSnap = await db.collection('tenants').doc(tenantId).collection('avisos_professores').get();
    for (var a in profsSnap.docs) {
      final data = a.data();
      data['id'] = a.id;
      data['turmaNome'] = 'Corpo Docente';
      data['isProfessorGlobal'] = true;
      listaCompleta.add(data);
    }

    // Ordena do mais recente para o mais antigo
    listaCompleta.sort((a, b) {
      final tA = a['dataEnvio'] as Timestamp?;
      final tB = b['dataEnvio'] as Timestamp?;
      if (tA == null && tB == null) return 0;
      if (tA == null) return 1;
      if (tB == null) return -1;
      return tB.compareTo(tA);
    });

    // === DESDUPLICAÇÃO INTELIGENTE (Agrupa mensagens repetidas da escola inteira) ===
    List<Map<String, dynamic>> listaUnica = [];
    Set<String> assinaturas = {};
    
    for (var aviso in listaCompleta) {
       final tipo = aviso['tipoDestinatario'] ?? '';
       // Só agrupa se for um envio "Em Massa" para não encher a tela
       if (tipo == 'TODOS' || tipo == 'PROFESSORES') {
          final assinatura = "${tipo}_${aviso['mensagem']}_${aviso['remetenteId']}";
          if (!assinaturas.contains(assinatura)) {
              assinaturas.add(assinatura);
              listaUnica.add(aviso);
          }
       } else {
          // Se for específico para turma ou aluno, mostra normalmente
          listaUnica.add(aviso);
       }
    }

    return listaUnica;
  }

  Future<void> _excluirAviso(Map<String, dynamic> aviso) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text('Excluir Aviso')]),
        content: const Text('Tem certeza que deseja apagar este aviso permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          )
        ],
      )
    ) ?? false;

    if (!confirm) return;

    final user = ref.read(authProvider).value;
    if (user == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final tenantId = user.tenantId;
      final batch = db.batch();

      // Se a mensagem que estamos a apagar foi enviada em MASSA, apagamos de todas as turmas!
      if (aviso['tipoDestinatario'] == 'TODOS' || aviso['tipoDestinatario'] == 'PROFESSORES') {
          final turmasSnap = await db.collection('tenants').doc(tenantId).collection('turmas').get();
          for (var t in turmasSnap.docs) {
             final query = await t.reference.collection('avisos')
               .where('mensagem', isEqualTo: aviso['mensagem'])
               .where('tipoDestinatario', isEqualTo: aviso['tipoDestinatario'])
               .get();
             for(var d in query.docs) batch.delete(d.reference);
          }
          final profsGlobais = await db.collection('tenants').doc(tenantId).collection('avisos_professores')
               .where('mensagem', isEqualTo: aviso['mensagem'])
               .where('tipoDestinatario', isEqualTo: aviso['tipoDestinatario'])
               .get();
          for(var d in profsGlobais.docs) batch.delete(d.reference);
          
          await batch.commit();
      } else {
          // Apaga apenas o específico
          if (aviso['isProfessorGlobal'] == true) {
            await db.collection('tenants').doc(tenantId).collection('avisos_professores').doc(aviso['id']).delete();
          } else {
            await db.collection('tenants').doc(tenantId).collection('turmas').doc(aviso['turmaId']).collection('avisos').doc(aviso['id']).delete();
          }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aviso excluído com sucesso.'), backgroundColor: Colors.green));
        _recarregarFeed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _enviarMensagem() async {
    if (!_formKey.currentState!.validate()) return;

    if (['ALUNO', 'PROFESSOR', 'TURMA', 'RESPONSAVEL'].contains(_destinatario) && _entidadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, pesquise e selecione o destinatário exato na lista.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _enviando = true);

    try {
      final user = ref.read(authProvider).value;
      if (user == null) throw Exception('Usuário não logado.');
      
      final tenantId = user.tenantId;
      String nomeAdmin = 'Administração (Coord./Direção)';
      
      try {
        final dynamic u = user;
        final nome = u.nome ?? u.displayName ?? u.name;
        if (nome != null && nome.toString().trim().isNotEmpty) {
          nomeAdmin = 'Administração - $nome';
        }
      } catch (_) {}

      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final turmasRef = db.collection('tenants').doc(tenantId).collection('turmas');
      
      final turmasSnapDb = await turmasRef.get();
      final turmasDbList = turmasSnapDb.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      final titulo = _tituloCtrl.text.trim();
      final mensagem = _mensagemCtrl.text.trim();
      
      final msgComTitulo = titulo.isNotEmpty ? "📍 *$titulo*\n\n$mensagem" : mensagem;

      Map<String, dynamic> criarPayload(String tipoDest, {String? alunoId}) {
        return {
          'titulo': titulo,
          'mensagem': msgComTitulo,
          'dataEnvio': FieldValue.serverTimestamp(),
          'remetenteNome': nomeAdmin,
          'remetenteId': user.id,
          'tipoDestinatario': tipoDest,
          if (alunoId != null) 'alunoId': alunoId,
        };
      }

      if (_destinatario == 'TODA_ESCOLA' || _destinatario == 'TODOS_PROFESSORES') {
        final tipoDest = _destinatario == 'TODA_ESCOLA' ? 'TODOS' : 'PROFESSORES';
        for (var t in turmasDbList) {
          final novoAvisoRef = turmasRef.doc(t['id']).collection('avisos').doc();
          batch.set(novoAvisoRef, criarPayload(tipoDest));
        }

      } else if (_destinatario == 'TURMA') {
        final turmaId = _entidadeSelecionada!['id'].toString();
        final novoAvisoRef = turmasRef.doc(turmaId).collection('avisos').doc();
        batch.set(novoAvisoRef, criarPayload('TURMA'));

      } else if (_destinatario == 'ALUNO') {
        String turmaId = _entidadeSelecionada!['turmaId']?.toString() ?? '';
        final alunoId = _entidadeSelecionada!['docId']?.toString() ?? _entidadeSelecionada!['id']?.toString() ?? _entidadeSelecionada!['matricula']?.toString() ?? '';
        
        if (turmaId.isEmpty || turmaId == 'null') {
          final nomeTurmaAluno = (_entidadeSelecionada!['turma'] ?? '').toString().toUpperCase().trim();
          for (var t in turmasDbList) {
             final turnoFormatado = t['turno'] ?? '';
             final tNome = (t['nome'] ?? '').toString().toUpperCase().trim();
             final tAno = (t['anoLetivo'] ?? '').toString().toUpperCase().trim();
             
             final turmaNomeOficial = '$tNome ($tAno) - ${turnoFormatado.toUpperCase()}';
             final turmaNomeAntigo = '$tNome ($tAno)';
             
             if (nomeTurmaAluno.isNotEmpty && (
                 nomeTurmaAluno == turmaNomeOficial || 
                 nomeTurmaAluno == turmaNomeAntigo || 
                 nomeTurmaAluno == tNome ||
                 nomeTurmaAluno.contains(tNome) ||
                 tNome.contains(nomeTurmaAluno)
             )) {
               turmaId = t['id'].toString();
               break;
             }
          }
        }

        if (turmaId.isEmpty || turmaId == 'null') {
          throw Exception('A turma deste aluno não pôde ser identificada no sistema. Edite o cadastro do aluno, selecione a turma novamente e guarde.');
        }
        if (alunoId.isEmpty) throw Exception('ID do aluno não encontrado.');
        
        final novoAvisoRef = turmasRef.doc(turmaId).collection('avisos').doc();
        batch.set(novoAvisoRef, criarPayload('ALUNO', alunoId: alunoId));

      } else if (_destinatario == 'RESPONSAVEL') {
        final keyBusca = _entidadeSelecionada!['idBusca'];
        final alunosSnap = await db.collection('tenants').doc(tenantId).collection('alunos').where('status', isEqualTo: 'Ativo').get();
        
        bool encontrouFilho = false;
        for(var doc in alunosSnap.docs) {
           final alunoData = doc.data();
           final resps = alunoData['responsaveis'] as List? ?? [];
           
           bool isFilho = resps.any((r) {
             final cpfLimpo = (r['cpf']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), '');
             final nome = r['nome']?.toString() ?? '';
             return cpfLimpo == keyBusca || nome == keyBusca;
           });
           
           if (isFilho) {
             encontrouFilho = true;
             String turmaId = alunoData['turmaId']?.toString() ?? '';
             
             if (turmaId.isEmpty || turmaId == 'null') {
                final nomeTurmaAluno = (alunoData['turma'] ?? '').toString().toUpperCase().trim();
                for (var t in turmasDbList) {
                   final turnoFormatado = t['turno'] ?? '';
                   final tNome = (t['nome'] ?? '').toString().toUpperCase().trim();
                   final tAno = (t['anoLetivo'] ?? '').toString().toUpperCase().trim();
                   
                   final turmaNomeOficial = '$tNome ($tAno) - ${turnoFormatado.toUpperCase()}';
                   final turmaNomeAntigo = '$tNome ($tAno)';
                   
                   if (nomeTurmaAluno.isNotEmpty && (
                       nomeTurmaAluno == turmaNomeOficial || 
                       nomeTurmaAluno == turmaNomeAntigo || 
                       nomeTurmaAluno == tNome ||
                       nomeTurmaAluno.contains(tNome) ||
                       tNome.contains(nomeTurmaAluno)
                   )) {
                     turmaId = t['id'].toString();
                     break;
                   }
                }
             }

             if(turmaId.isNotEmpty && turmaId != 'null') {
                final novoAvisoRef = turmasRef.doc(turmaId).collection('avisos').doc();
                batch.set(novoAvisoRef, criarPayload('RESPONSAVEL', alunoId: doc.id));
             }
           }
        }
        if (!encontrouFilho) {
           throw Exception('Não foi possível encontrar em que turma os filhos deste responsável estão alocados.');
        }

      } else if (_destinatario == 'PROFESSOR') {
        final profId = _entidadeSelecionada!['id'];
        
        for (var t in turmasDbList) {
          final profs = t['professoresVinculados'] as List? ?? [];
          if(profs.any((p) => p['professorId'] == profId)) {
             final novoAvisoRef = turmasRef.doc(t['id']).collection('avisos').doc();
             final payload = criarPayload('PROFESSOR_ESPECIFICO');
             payload['professorAlvoId'] = profId;
             batch.set(novoAvisoRef, payload);
          }
        }
        
        final globalRef = db.collection('tenants').doc(tenantId).collection('avisos_professores').doc();
        final payloadGlobal = criarPayload('PROFESSOR_ESPECIFICO');
        payloadGlobal['professorAlvoId'] = profId;
        batch.set(globalRef, payloadGlobal);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensagem enviada com sucesso!'), backgroundColor: Colors.green));
        _tituloCtrl.clear();
        _mensagemCtrl.clear();
        setState(() => _entidadeSelecionada = null);
        _recarregarFeed(); // Recarrega o Feed de mensagens
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar mensagem: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  void _selecionarDatas() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'SELECIONE O PERÍODO',
      cancelText: 'CANCELAR',
      confirmText: 'OK',
      saveText: 'SALVAR',
      errorFormatText: 'Formato inválido',
      errorInvalidText: 'Data fora do limite',
      errorInvalidRangeText: 'Período inválido',
      fieldStartHintText: 'dd/mm/aaaa',
      fieldEndHintText: 'dd/mm/aaaa',
      fieldStartLabelText: 'Data de Início',
      fieldEndLabelText: 'Data de Fim',
      initialDateRange: _dataFiltroInicio != null && _dataFiltroFim != null
          ? DateTimeRange(start: _dataFiltroInicio!, end: _dataFiltroFim!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dataFiltroInicio = picked.start;
        _dataFiltroFim = picked.end;
      });
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
          if (_entidadeSelecionada != null && controller.text.isEmpty) {
             controller.text = displayString(_entidadeSelecionada!);
          }

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
                      onTap: () {
                         onSelected(option);
                         FocusScope.of(context).unfocus();
                      }
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

    Map<String, Map<String, dynamic>> responsaveisMap = {};
    for (var aluno in alunosList) {
      final resps = aluno['responsaveis'] as List? ?? [];
      final alunoNome = aluno['nome'] ?? 'Aluno sem nome';
      
      for (var r in resps) {
        final cpf = r['cpf']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
        final nome = r['nome']?.toString() ?? 'Responsável';
        final email = r['email']?.toString() ?? '';
        
        final key = cpf.isNotEmpty ? cpf : nome;
        if (key.trim().isEmpty) continue;

        if (responsaveisMap.containsKey(key)) {
          responsaveisMap[key]!['alunosVinculados'] += ' / $alunoNome';
        } else {
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
    
    final responsaveisList = responsaveisMap.values.toList();
    responsaveisList.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(title: const Text('Comunicações e Avisos', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1),
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // =========================================================================
            // LADO ESQUERDO: FORMULÁRIO DE ENVIO
            // =========================================================================
            Expanded(
              flex: isMobile ? 0 : 3,
              child: Card(
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [Icon(Icons.campaign_rounded, color: corPrimaria, size: 28), const SizedBox(width: 12), const Text('Novo Aviso / Comunicado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 8),
                        Text('Envie mensagens, comunicados ou cobranças.', style: TextStyle(color: Colors.grey.shade600)),
                        const Divider(height: 32),

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
                          const SizedBox(height: 20),
                          _buildAutocompleteField(
                            label: 'Pesquisar Aluno (Nome ou Matrícula)', items: alunosList,
                            displayString: (a) => a['nome'] ?? 'Sem Nome',
                            searchFilter: (a, busca) => (a['nome'] ?? '').toString().toLowerCase().contains(busca) || (a['matricula'] ?? '').toString().toLowerCase().contains(busca),
                            subtitleBuilder: (a) => Text('Matrícula: ${a['matricula']} | Turma: ${a['turma'] ?? 'Não vinculada'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ),
                        ],

                        if (_destinatario == 'TURMA') ...[
                          const SizedBox(height: 20),
                          _buildAutocompleteField(
                            label: 'Pesquisar Turma (Nome ou Ano)', items: turmasList,
                            displayString: (t) => '${t['nome']} (${t['anoLetivo']})',
                            searchFilter: (t, busca) => (t['nome'] ?? '').toString().toLowerCase().contains(busca) || (t['anoLetivo'] ?? '').toString().toLowerCase().contains(busca),
                            subtitleBuilder: (t) => Text('Turno: ${t['turno'] ?? '-'} | Sala: ${t['sala'] ?? '-'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ),
                        ],

                        if (_destinatario == 'PROFESSOR') ...[
                          const SizedBox(height: 20),
                          _buildAutocompleteField(
                            label: 'Pesquisar Professor', items: professoresList,
                            displayString: (p) => p['nome'] ?? 'Sem Nome',
                            searchFilter: (p, busca) => (p['nome'] ?? '').toString().toLowerCase().contains(busca),
                            subtitleBuilder: (p) => Text('Disciplinas: ${(p['disciplinas'] as List? ?? []).join(', ')}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ),
                        ],

                        if (_destinatario == 'RESPONSAVEL') ...[
                          const SizedBox(height: 20),
                          _buildAutocompleteField(
                            label: 'Pesquisar Responsável (Nome ou CPF)', 
                            items: responsaveisList,
                            displayString: (r) => r['nome'] ?? 'Sem Nome',
                            searchFilter: (r, busca) {
                              final nome = (r['nome'] ?? '').toString().toLowerCase();
                              final alunosRelacionados = (r['alunosVinculados'] ?? '').toString().toLowerCase();
                              final cpfLimpo = (r['cpf'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
                              final buscaLimpa = busca.replaceAll(RegExp(r'[^0-9]'), '');
                              
                              return nome.contains(busca) || alunosRelacionados.contains(busca) || (buscaLimpa.isNotEmpty && cpfLimpo.contains(buscaLimpa));
                            },
                            subtitleBuilder: (r) => Text('Responsável por: ${r['alunosVinculados']}\nCPF: ${r['cpf']} | Tel: ${r['telefone']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ),
                        ],

                        const SizedBox(height: 20),
                        TextFormField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título do Aviso (Opcional)', border: OutlineInputBorder()), validator: (v) => null),
                        const SizedBox(height: 20),
                        TextFormField(controller: _mensagemCtrl, maxLines: 5, decoration: const InputDecoration(labelText: 'Escreva a sua mensagem...', alignLabelWithHint: true, border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'A mensagem não pode estar vazia' : null),
                        const SizedBox(height: 24),

                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            onPressed: _enviando ? null : _enviarMensagem, 
                            icon: _enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded), 
                            label: Text(_enviando ? 'ENVIANDO...' : 'ENVIAR COMUNICADO', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            if (isMobile) const SizedBox(height: 24) else const SizedBox(width: 24),

            // =========================================================================
            // LADO DIREITO: FEED DE HISTÓRICO DE MENSAGENS (MURAL)
            // =========================================================================
            Expanded(
              flex: isMobile ? 0 : 4,
              child: SizedBox(
                height: isMobile ? null : MediaQuery.of(context).size.height - 130, // Força a tela a ser scrollable no lado direito
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        const Text('Histórico de Comunicações', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const Spacer(),
                        IconButton(
                          onPressed: _recarregarFeed,
                          icon: const Icon(Icons.refresh_rounded, color: Colors.blue),
                          tooltip: 'Atualizar Mural',
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // FILTROS
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Wrap(
                        spacing: 16, runSpacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            height: 40,
                            child: TextField(
                              onChanged: (val) => setState(() => _termoBuscaFeed = val),
                              decoration: InputDecoration(
                                hintText: 'Pesquisar...', prefixIcon: const Icon(Icons.search, size: 18),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            height: 40,
                            child: DropdownButtonFormField<String>(
                              value: _filtroDestinoFeed,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'TODOS', child: Text('Todos os Destinos', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'TODA_ESCOLA', child: Text('Toda a Escola', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'TURMA', child: Text('Apenas Turmas', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'PROFESSORES', child: Text('Para Professores', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'ALUNO', child: Text('Direcionados (Alunos)', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'RESPONSAVEL', child: Text('Direcionados (Resp.)', style: TextStyle(fontSize: 13))),
                              ],
                              onChanged: (val) { if (val != null) setState(() => _filtroDestinoFeed = val); },
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _dataFiltroInicio != null ? Colors.blue : Colors.black54,
                              side: BorderSide(color: _dataFiltroInicio != null ? Colors.blue : Colors.grey.shade300),
                            ),
                            onPressed: _selecionarDatas, 
                            icon: const Icon(Icons.calendar_month, size: 18), 
                            label: Text(
                              _dataFiltroInicio == null 
                                ? 'Filtrar Data' 
                                : '${DateFormat('dd/MM/yy').format(_dataFiltroInicio!)} até ${DateFormat('dd/MM/yy').format(_dataFiltroFim!)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (_dataFiltroInicio != null)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red, size: 20),
                              tooltip: 'Limpar Data',
                              onPressed: () => setState(() { _dataFiltroInicio = null; _dataFiltroFim = null; }),
                            )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // LISTA DE AVISOS
                    Expanded(
                      flex: isMobile ? 0 : 1, // Se for mobile, a SingleChild do Scaffold vai cuidar do tamanho
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _futureAvisos,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                          }

                          final todosAvisos = snapshot.data ?? [];
                          
                          // Aplica Filtros
                          final filtrados = todosAvisos.where((aviso) {
                            // Filtro Busca
                            final busca = _termoBuscaFeed.toLowerCase().trim();
                            if (busca.isNotEmpty) {
                               final texto = (aviso['mensagem'] ?? '').toString().toLowerCase();
                               final prof = (aviso['remetenteNome'] ?? '').toString().toLowerCase();
                               if (!texto.contains(busca) && !prof.contains(busca)) return false;
                            }

                            // Filtro Destino
                            final tipoDest = aviso['tipoDestinatario'] ?? '';
                            if (_filtroDestinoFeed != 'TODOS') {
                              if (_filtroDestinoFeed == 'TODA_ESCOLA' && tipoDest != 'TODOS') return false;
                              if (_filtroDestinoFeed == 'TURMA' && tipoDest != 'TURMA') return false;
                              if (_filtroDestinoFeed == 'PROFESSORES' && tipoDest != 'PROFESSORES' && tipoDest != 'PROFESSOR_ESPECIFICO') return false;
                              if (_filtroDestinoFeed == 'ALUNO' && tipoDest != 'ALUNO') return false;
                              if (_filtroDestinoFeed == 'RESPONSAVEL' && tipoDest != 'RESPONSAVEL') return false;
                            }

                            // Filtro Data
                            if (_dataFiltroInicio != null && _dataFiltroFim != null) {
                              final timeData = aviso['dataEnvio'] as Timestamp?;
                              if (timeData != null) {
                                final dataMsg = timeData.toDate();
                                if (dataMsg.isBefore(_dataFiltroInicio!) || dataMsg.isAfter(_dataFiltroFim!.add(const Duration(days: 1)))) {
                                  return false;
                                }
                              } else {
                                return false; // Se a data for nula (ainda a gravar)
                              }
                            }

                            return true;
                          }).toList();

                          if (filtrados.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.speaker_notes_off_rounded, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text('Nenhum aviso encontrado no sistema.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                                ],
                              ),
                            );
                          }

                          // LIMITAR VISUALIZAÇÃO ÀS N MENSAGENS INICIAIS
                          final exibidos = filtrados.take(_limiteAvisos).toList();
                          final bool temMais = filtrados.length > _limiteAvisos;

                          Widget listView = ListView.separated(
                            itemCount: exibidos.length + (temMais ? 1 : 0),
                            shrinkWrap: isMobile,
                            physics: isMobile ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              
                              if (index == exibidos.length) {
                                 return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: TextButton.icon(
                                      onPressed: () => setState(() => _limiteAvisos += 5),
                                      icon: const Icon(Icons.expand_more_rounded),
                                      label: const Text('Carregar Mais Avisos Antigos', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                 );
                              }

                              final aviso = exibidos[index];
                              
                              final dataEnvio = aviso['dataEnvio'];
                              final textoData = dataEnvio != null ? DateFormat('dd/MM/yy às HH:mm').format((dataEnvio as Timestamp).toDate()) : '';
                              
                              final tipoDest = aviso['tipoDestinatario'];
                              
                              String tagDestino = 'Para toda a turma';
                              Color corTag = Colors.blue;
                              
                              if (tipoDest == 'TODOS') {
                                tagDestino = 'Toda a Escola';
                                corTag = Colors.green;
                              } else if (tipoDest == 'PROFESSORES') {
                                tagDestino = 'Todos os Professores';
                                corTag = Colors.orange;
                              } else if (tipoDest == 'PROFESSOR_ESPECIFICO') {
                                tagDestino = 'Professor Específico';
                                corTag = Colors.orange.shade800;
                              } else if (tipoDest == 'ALUNO') {
                                tagDestino = 'Aluno Direcionado (${aviso['turmaNome']})';
                                corTag = Colors.purple;
                              } else if (tipoDest == 'RESPONSAVEL') {
                                tagDestino = 'Resp. Direcionado (${aviso['turmaNome']})';
                                corTag = Colors.red;
                              } else {
                                tagDestino = 'Turma: ${aviso['turmaNome']}';
                                corTag = Colors.blue;
                              }

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
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
                                            'De: ${aviso['remetenteNome'] ?? 'Direção'}', 
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          children: [
                                            Text(textoData, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 8),
                                            Tooltip(
                                              message: 'Apagar este aviso',
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(16),
                                                onTap: () => _excluirAviso(aviso),
                                                child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                              ),
                                            )
                                          ],
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: corTag.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                                      child: Text(tagDestino, style: TextStyle(color: corTag, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                                    Text(aviso['mensagem'] ?? '', style: TextStyle(fontSize: 14, color: Colors.grey.shade800))
                                  ],
                                ),
                              );
                            },
                          );

                          if (isMobile) {
                            return listView;
                          } else {
                            return SizedBox(
                              width: double.infinity,
                              child: listView,
                            );
                          }
                        },
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
  }
}