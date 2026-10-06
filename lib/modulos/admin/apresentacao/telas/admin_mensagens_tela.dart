import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensagemCtrl.dispose();
    super.dispose();
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
      final turmasList = ref.read(turmasStreamProvider).value ?? [];

      final titulo = _tituloCtrl.text.trim();
      final mensagem = _mensagemCtrl.text.trim();
      
      // Concatena o título com a mensagem para que ecrãs que só leiam o campo "mensagem" mostrem o título a negrito!
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
        final turmasSnap = await turmasRef.get();
        for (var doc in turmasSnap.docs) {
          final novoAvisoRef = turmasRef.doc(doc.id).collection('avisos').doc();
          batch.set(novoAvisoRef, criarPayload(tipoDest));
        }

      } else if (_destinatario == 'TURMA') {
        final turmaId = _entidadeSelecionada!['id'].toString();
        final novoAvisoRef = turmasRef.doc(turmaId).collection('avisos').doc();
        batch.set(novoAvisoRef, criarPayload('TURMA'));

      } else if (_destinatario == 'ALUNO') {
        String turmaId = _entidadeSelecionada!['turmaId']?.toString() ?? '';
        final alunoId = _entidadeSelecionada!['docId']?.toString() ?? _entidadeSelecionada!['id']?.toString() ?? _entidadeSelecionada!['matricula']?.toString() ?? '';
        
        // CORREÇÃO: Se o aluno não tiver o turmaId, procura pelo nome da turma na lista de turmas
        if (turmaId.isEmpty) {
          final nomeTurmaAluno = (_entidadeSelecionada!['turma'] ?? '').toString().toUpperCase().trim();
          for (var t in turmasList) {
             final turnoFormatado = t['turno'] ?? '';
             final turmaNomeOficial = '${t['nome']} (${t['anoLetivo']}) - $turnoFormatado'.toUpperCase();
             final turmaNomeAntigo = '${t['nome']} (${t['anoLetivo']})'.toUpperCase();
             if (nomeTurmaAluno == turmaNomeOficial || nomeTurmaAluno == turmaNomeAntigo) {
               turmaId = t['id'].toString();
               break;
             }
          }
        }

        if (turmaId.isEmpty) throw Exception('Não foi possível identificar a turma deste aluno. Edite o cadastro dele e salve novamente a turma.');
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
             
             // CORREÇÃO: Busca o ID da turma se estiver vazio
             if (turmaId.isEmpty) {
                final nomeTurmaAluno = (alunoData['turma'] ?? '').toString().toUpperCase().trim();
                for (var t in turmasList) {
                   final turnoFormatado = t['turno'] ?? '';
                   final turmaNomeOficial = '${t['nome']} (${t['anoLetivo']}) - $turnoFormatado'.toUpperCase();
                   final turmaNomeAntigo = '${t['nome']} (${t['anoLetivo']})'.toUpperCase();
                   if (nomeTurmaAluno == turmaNomeOficial || nomeTurmaAluno == turmaNomeAntigo) {
                     turmaId = t['id'].toString();
                     break;
                   }
                }
             }

             if(turmaId.isNotEmpty) {
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
        final turmasSnap = await turmasRef.get();
        
        // Dispara a mensagem para os murais de todas as turmas onde este professor leciona
        for (var doc in turmasSnap.docs) {
          final data = doc.data();
          final profs = data['professoresVinculados'] as List? ?? [];
          if(profs.any((p) => p['professorId'] == profId)) {
             final novoAvisoRef = turmasRef.doc(doc.id).collection('avisos').doc();
             final payload = criarPayload('PROFESSOR_ESPECIFICO');
             payload['professorAlvoId'] = profId;
             batch.set(novoAvisoRef, payload);
          }
        }
        
        // Também salva de forma global caso o professor abra um painel central de notificações
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
          // Se já havia uma entidade selecionada e mudou de aba, preenchemos o campo automaticamente
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
                         FocusScope.of(context).unfocus(); // Fecha o teclado/dropdown ao selecionar
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
        ),
      ),
    );
  }
}