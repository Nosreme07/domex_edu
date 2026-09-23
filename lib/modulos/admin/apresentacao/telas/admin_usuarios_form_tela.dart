import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';
import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/responsavel_provider.dart';
import '../estado/secretaria_provider.dart';
import '../estado/turma_provider.dart';
import '../estado/usuario_escola_provider.dart';

class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class AdminUsuariosFormTela extends ConsumerStatefulWidget {
  const AdminUsuariosFormTela({super.key});

  @override
  ConsumerState<AdminUsuariosFormTela> createState() => _AdminUsuariosFormTelaState();
}

class _AdminUsuariosFormTelaState extends ConsumerState<AdminUsuariosFormTela> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _termoBusca = '';
  String _filtroPerfil = 'TODOS';
  String _filtroStatus = 'TODOS';
  final _debouncer = Debouncer(milliseconds: 400);

  void _mostrarFotoAmpliada(String url) {
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

  void _confirmarExclusaoAcesso(Map<String, dynamic> u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Excluir Login de Acesso', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text('Deseja realmente apagar as credenciais de acesso de ${u['nome']} (${u['login']})?\n\nIsso removerá apenas o acesso dele ao sistema. O cadastro original da secretaria será mantido intacto.\n\nNota: Como a pessoa possui um cadastro ativo, ela continuará aparecendo nesta lista. Se deseja ocultá-la completamente, altere o status para Bloqueado/Inativo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final servico = ref.read(usuarioEscolaServiceProvider);
              if (servico != null) {
                // 1. Exclui o login exato exibido na tela
                await servico.excluirUsuario(u['login']);
                
                // 2. Exclui agressivamente todas as outras identidades que possam estar atreladas
                final doc = u['rawDoc'];
                if (doc != null) {
                   if (doc['matricula'] != null) await servico.excluirUsuario(doc['matricula']);
                   if (doc['id'] != null) await servico.excluirUsuario(doc['id']);
                   if (doc['cpf'] != null) await servico.excluirUsuario(doc['cpf']);
                   if (doc['email'] != null) await servico.excluirUsuario(doc['email']);
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credenciais de login excluídas. Cadastro base mantido.'), backgroundColor: Colors.green));
                }
              }
            },
            child: const Text('Sim, Excluir Acesso'),
          ),
        ],
      ),
    );
  }

  void _abrirFichaDetalhes(Map<String, dynamic> u, List<Map<String, dynamic>> turmasDoSistema) {
    final corPrimaria = Theme.of(context).primaryColor;
    final String perfil = u['perfil'].toString().toUpperCase();
    final doc = u['rawDoc'];
    
    final sessao = ref.read(authProvider).value;
    final codigoEscola = sessao?.codigoEscola ?? 'domex';
    
    final telefone = (u['telefone'] ?? '').toString();
    final numeroLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');

    Widget buildLinhaCopiavel(String label, String valor) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            SelectableText(
              valor.isEmpty ? 'Não informado' : valor, 
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      );
    }

    List<Widget> _construirInfoEspecifica() {
      List<Widget> widgets = [];
      
      if (perfil == 'ALUNO') {
        final resp = doc['responsaveis'] as List? ?? [];
        final respNomes = resp.map((r) => r['nome']).join(', ');
        widgets.add(buildLinhaCopiavel('Responsáveis', respNomes));
        widgets.add(buildLinhaCopiavel('Turma Regular', doc['turma'] ?? ''));
        
        final turmasExtras = List<String>.from(doc['turmasExtrasNomes'] ?? []);
        if (turmasExtras.isNotEmpty) {
          widgets.add(buildLinhaCopiavel('Turmas Extras', turmasExtras.join(', ')));
        }
      } 
      else if (perfil == 'RESPONSÁVEL') {
        final alunosList = doc['alunosVinculados'] as List? ?? [];
        widgets.add(buildLinhaCopiavel('Alunos Vinculados', alunosList.join('\n')));
      } 
      else if (perfil == 'PROFESSOR') {
        List<String> turmasVinculadas = [];
        for (var t in turmasDoSistema) {
          final profsDaTurma = t['professoresVinculados'] as List? ?? [];
          if (profsDaTurma.any((pv) => pv['professorId'] == doc['id'])) {
            turmasVinculadas.add('${t['nome']} (${t['anoLetivo']})');
          }
        }
        widgets.add(buildLinhaCopiavel('Leciona nas Turmas', turmasVinculadas.isEmpty ? 'Nenhuma turma' : turmasVinculadas.join(', ')));
        widgets.add(buildLinhaCopiavel('Disciplinas', (doc['disciplinas'] as List? ?? []).join(', ')));
      } 
      else if (perfil == 'SECRETARIA') {
        widgets.add(buildLinhaCopiavel('Função', doc['funcao'] ?? ''));
      }

      return widgets;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final isAtivo = u['status'] == 'Ativo';
            final corStatus = isAtivo ? Colors.green : Colors.red;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.all(0),
              title: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: u['cor'].withAlpha(15), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(
                  children: [
                    InkWell(
                      onTap: u['fotoUrl'] != null ? () => _mostrarFotoAmpliada(u['fotoUrl']) : null,
                      borderRadius: BorderRadius.circular(32),
                      child: CircleAvatar(
                        radius: 32, backgroundColor: Colors.white,
                        backgroundImage: u['fotoUrl'] != null ? NetworkImage(u['fotoUrl']) : null,
                        child: u['fotoUrl'] == null ? Icon(u['icone'], size: 32, color: u['cor']) : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(u['nome'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: u['cor'], borderRadius: BorderRadius.circular(4)),
                            child: Text(perfil, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: corStatus.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: corStatus.withAlpha(50))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(isAtivo ? Icons.check_circle : Icons.block, color: corStatus, size: 20),
                                const SizedBox(width: 8),
                                Text('Acesso: ${isAtivo ? 'ATIVO' : 'BLOQUEADO'}', style: TextStyle(fontWeight: FontWeight.bold, color: corStatus)),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAtivo ? Colors.red : Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              ),
                              onPressed: () async {
                                final novoStatus = isAtivo ? (perfil == 'ALUNO' ? 'Inativo' : 'Bloqueado') : 'Ativo';
                                try {
                                  if (perfil == 'ALUNO') {
                                    await ref.read(alunoServiceProvider).atualizarStatus(doc['matricula'], novoStatus);
                                  } else if (perfil == 'PROFESSOR') {
                                    await ref.read(professorServiceProvider).atualizarStatus(doc['id'], novoStatus);
                                  } else if (perfil == 'RESPONSÁVEL') {
                                    await ref.read(responsavelServiceProvider).atualizarStatus(doc['id'], novoStatus);
                                  } else if (perfil == 'SECRETARIA') {
                                    await ref.read(secretariaServiceProvider).atualizarStatus(doc['id'], novoStatus);
                                  } else {
                                    await ref.read(usuarioEscolaServiceProvider)!.salvarUsuario({...doc, 'status': novoStatus});
                                  }
                                  
                                  setStateModal(() => u['status'] = novoStatus);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Acesso $novoStatus com sucesso!'), backgroundColor: Colors.green));
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao mudar acesso: $e'), backgroundColor: Colors.red));
                                }
                              },
                              child: Text(isAtivo ? 'Bloquear Acesso' : 'Ativar Acesso', style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      buildLinhaCopiavel('Login no Sistema', u['login']),
                      
                      if (!u['login'].toString().contains('@'))
                        buildLinhaCopiavel('Código da Instituição', codigoEscola),
                      
                      if (telefone.isNotEmpty) ...[
                        Text('Contato', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SelectableText(telefone, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                            if (numeroLimpo.length >= 10) ...[
                              const SizedBox(width: 16),
                              Tooltip(
                                message: 'Abrir WhatsApp',
                                child: InkWell(
                                  onTap: () => launchUrl(Uri.parse('https://wa.me/55$numeroLimpo')),
                                  child: Image.asset('assets/whatsapp.png', width: 24, height: 24),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Tooltip(
                                message: 'Ligar',
                                child: InkWell(
                                  onTap: () => launchUrl(Uri.parse('tel:$numeroLimpo')),
                                  child: const Icon(Icons.phone, color: Colors.blue, size: 24),
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      const Divider(),
                      ..._construirInfoEspecifica(),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final servico = ref.read(usuarioEscolaServiceProvider);
                      if (servico != null) {
                        await servico.resetarSenhaEGerarAuth(u);
                      }
                      
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctxReset) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Conta Ativada & Senha Resetada!', style: TextStyle(color: Colors.green)),
                              ],
                            ),
                            content: Text(
                              'As credenciais de ${u['nome']} foram configuradas com sucesso no sistema de login.\n\n'
                              'Por favor, repasse as seguintes informações para o acesso:\n\n'
                              'Login de Acesso: ${u['login']}\n'
                              '${!u['login'].toString().contains('@') ? 'Código da Instituição: $codigoEscola\n' : ''}'
                              'Senha Provisória: Domex@123\n\n'
                              'No próximo login, o sistema exigirá a criação de uma nova senha.',
                              style: const TextStyle(fontSize: 15),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(ctxReset),
                                child: const Text('Entendido'),
                              )
                            ],
                          )
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao criar acesso: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  icon: const Icon(Icons.lock_reset_rounded, color: Colors.orange),
                  label: const Text('Gerar Acesso / Resetar Senha', style: TextStyle(color: Colors.orange)),
                ),
                const Spacer(),
                if (u['origem'] != 'MANUAL') ...[
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (perfil == 'ALUNO') context.push('/admin/cadastros/aluno/novo', extra: doc);
                      else if (perfil == 'PROFESSOR') context.push('/admin/cadastros/professor/novo', extra: doc);
                      else if (perfil == 'RESPONSÁVEL') context.push('/admin/cadastros/responsavel/novo', extra: doc);
                      else if (perfil == 'SECRETARIA') context.push('/admin/cadastros/secretaria/novo', extra: doc);
                    },
                    icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                    label: const Text('Ver / Editar Cadastro', style: TextStyle(color: Colors.blue)),
                  ),
                ],
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirModalAcessoManual(List alunos, List professores, List responsaveis, List secretaria, [Map<String, dynamic>? usuarioEdit]) {
    final formKey = GlobalKey<FormState>();
    final ctrlEmail = TextEditingController(text: usuarioEdit?['idLogin'] ?? '');
    String? tipoSelecionado = usuarioEdit != null ? usuarioEdit['perfil'].toString().toUpperCase() : null;
    String statusSelecionado = usuarioEdit?['status'] ?? 'Ativo';
    
    String? idPessoaSelecionada;
    Map<String, dynamic>? pessoaSelecionada;
    
    final bool isEdicao = usuarioEdit != null;
    bool salvando = false;

    String _getPessoaId(Map<String, dynamic> p, String tipo) {
      if (tipo == 'ALUNO') return p['matricula']?.toString() ?? '';
      if (tipo == 'RESPONSÁVEL') return p['cpf']?.toString() ?? '';
      return p['id']?.toString() ?? '';
    }

    List<Map<String, dynamic>> _obterLista(String? tipo) {
      if (tipo == 'ALUNO') return List<Map<String, dynamic>>.from(alunos);
      if (tipo == 'PROFESSOR') return List<Map<String, dynamic>>.from(professores);
      if (tipo == 'RESPONSÁVEL') return List<Map<String, dynamic>>.from(responsaveis);
      if (tipo == 'SECRETARIA') return List<Map<String, dynamic>>.from(secretaria);
      return [];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final corPrimaria = Theme.of(context).primaryColor;
          final listaPessoas = _obterLista(tipoSelecionado);
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(isEdicao ? Icons.edit_rounded : Icons.admin_panel_settings_rounded, color: corPrimaria),
                const SizedBox(width: 8),
                Text(isEdicao ? 'Editar Acesso' : 'Novo Acesso do Sistema', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecione o tipo de usuário e busque o cadastro desejado.\nA senha padrão será configurada como: Domex@123', 
                        style: TextStyle(color: Colors.grey, fontSize: 13)
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: ['ALUNO', 'RESPONSÁVEL', 'PROFESSOR', 'SECRETARIA'].contains(tipoSelecionado) ? tipoSelecionado : null,
                        decoration: InputDecoration(labelText: 'Tipo de Usuário', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        items: const [
                          DropdownMenuItem(value: 'ALUNO', child: Text('Aluno')),
                          DropdownMenuItem(value: 'RESPONSÁVEL', child: Text('Responsável')),
                          DropdownMenuItem(value: 'PROFESSOR', child: Text('Professor')),
                          DropdownMenuItem(value: 'SECRETARIA', child: Text('Secretaria')),
                        ],
                        onChanged: isEdicao ? null : (val) {
                          setModalState(() {
                            tipoSelecionado = val;
                            idPessoaSelecionada = null;
                            pessoaSelecionada = null;
                            ctrlEmail.clear();
                          });
                        },
                        validator: (v) => v == null ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 12),
                      
                      if (isEdicao)
                        TextFormField(
                          initialValue: '${usuarioEdit['nome']} (ID Vinculado)',
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Cadastro Vinculado',
                            filled: true, fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      else if (tipoSelecionado != null)
                        Autocomplete<Map<String, dynamic>>(
                          key: ValueKey(tipoSelecionado), 
                          displayStringForOption: (option) => '${option['nome']} (${_getPessoaId(option, tipoSelecionado!)})',
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) return listaPessoas; 
                            final busca = textEditingValue.text.toLowerCase();
                            return listaPessoas.where((p) {
                              final id = _getPessoaId(p, tipoSelecionado!).toLowerCase();
                              final nome = (p['nome'] ?? '').toString().toLowerCase();
                              return nome.contains(busca) || id.contains(busca);
                            });
                          },
                          onSelected: (Map<String, dynamic> val) {
                            setModalState(() {
                              idPessoaSelecionada = _getPessoaId(val, tipoSelecionado!);
                              pessoaSelecionada = val;
                              
                              if (val['email'] != null && val['email'].toString().isNotEmpty) {
                                ctrlEmail.text = val['email'];
                              } else {
                                ctrlEmail.clear();
                              }
                            });
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Pesquisar Cadastro',
                                hintText: 'Digite o nome ou ID...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                suffixIcon: const Icon(Icons.search_rounded),
                              ),
                              onChanged: (val) {
                                if (idPessoaSelecionada != null) {
                                  setModalState(() => idPessoaSelecionada = null);
                                }
                              },
                              validator: (v) => idPessoaSelecionada == null ? 'Selecione uma pessoa na lista' : null,
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 250, maxWidth: 450),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(option['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('ID: ${_getPessoaId(option, tipoSelecionado!)}'),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: ctrlEmail,
                        decoration: InputDecoration(
                          labelText: 'E-mail de Acesso (Login)',
                          hintText: 'Digite o e-mail do usuário',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.trim().isEmpty || !v.contains('@') ? 'Insira um e-mail válido' : null,
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<String>(
                        value: statusSelecionado,
                        decoration: InputDecoration(labelText: 'Status do Acesso', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        items: const [
                          DropdownMenuItem(value: 'Ativo', child: Text('Acesso Liberado', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                          DropdownMenuItem(value: 'Bloqueado', child: Text('Acesso Bloqueado', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                        ],
                        onChanged: (val) => setModalState(() => statusSelecionado = val!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: salvando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white),
                onPressed: salvando ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setModalState(() => salvando = true);
                    final servico = ref.read(usuarioEscolaServiceProvider);
                    
                    if (servico == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Serviço indisponível.'), backgroundColor: Colors.red));
                      setModalState(() => salvando = false);
                      return;
                    }

                    try {
                      final emailFinal = ctrlEmail.text.trim().toLowerCase();
                      
                      final dados = {
                        'idLogin': emailFinal,
                        'email': emailFinal,
                        'nome': isEdicao ? usuarioEdit!['nome'] : pessoaSelecionada!['nome'],
                        'perfil': tipoSelecionado,
                        'status': statusSelecionado,
                        'origem': isEdicao ? usuarioEdit!['origem'] : 'MANUAL',
                      };

                      if (!isEdicao) {
                         dados['senha'] = 'Domex@123';
                         dados['precisaTrocarSenha'] = true;
                         
                         final idRef = _getPessoaId(pessoaSelecionada!, tipoSelecionado!);
                         if (tipoSelecionado == 'ALUNO') dados['matricula'] = idRef;
                         if (tipoSelecionado == 'RESPONSÁVEL') dados['cpf'] = idRef;
                         if (tipoSelecionado == 'PROFESSOR' || tipoSelecionado == 'SECRETARIA') dados['idVinculo'] = idRef;
                      }

                      await servico.salvarUsuario(dados);
                      
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acesso salvo com sucesso!'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setModalState(() => salvando = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
                      }
                    }
                  }
                },
                icon: salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded),
                label: Text(salvando ? 'Salvando...' : 'Salvar Acesso', style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildErro(String titulo, Object? erro) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(erro.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final corPrimaria = Theme.of(context).primaryColor;

    final alunosAsync = ref.watch(alunosStreamProvider);
    final professoresAsync = ref.watch(professoresStreamProvider);
    final responsaveisAsync = ref.watch(responsavelStreamProvider);
    final secretariaAsync = ref.watch(secretariaStreamProvider);
    final manuaisAsync = ref.watch(usuariosEscolaStreamProvider);
    final turmasAsync = ref.watch(turmasStreamProvider);
    
    final sessao = ref.read(authProvider).value;
    final codigoEscola = sessao?.codigoEscola ?? 'domex';

    if (manuaisAsync.hasError) return _buildErro('Erro em Usuários', manuaisAsync.error);
    if (alunosAsync.hasError) return _buildErro('Erro em Alunos', alunosAsync.error);
    if (professoresAsync.hasError) return _buildErro('Erro em Professores', professoresAsync.error);
    if (responsaveisAsync.hasError) return _buildErro('Erro em Responsáveis', responsaveisAsync.error);
    if (secretariaAsync.hasError) return _buildErro('Erro em Secretaria', secretariaAsync.error);

    if (alunosAsync.isLoading || professoresAsync.isLoading || responsaveisAsync.isLoading || secretariaAsync.isLoading || manuaisAsync.isLoading || turmasAsync.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: corPrimaria),
            const SizedBox(height: 16),
            const Text('A estruturar os utilizadores do sistema...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final alunos = alunosAsync.value ?? [];
    final professores = professoresAsync.value ?? [];
    final responsaveis = responsaveisAsync.value ?? [];
    final secretaria = secretariaAsync.value ?? [];
    final manuais = manuaisAsync.value ?? [];
    final turmasDoSistema = turmasAsync.value ?? [];

    Map<String, Map<String, dynamic>> manuaisMap = {};
    for (var m in manuais) {
      manuaisMap[m['idLogin'].toString().toLowerCase().trim()] = m;
    }

    Map<String, String> nomeParaLogin = {};
    for (var m in manuais) {
      nomeParaLogin[m['nome'].toString().toLowerCase().trim()] = m['idLogin'].toString().toLowerCase().trim();
    }

    List<Map<String, dynamic>> todosUsuarios = [];

    void _adicionarAuto(Map<String, dynamic> data, String perfil, IconData icone, Color cor) {
      String idBase = '';
      if (perfil == 'ALUNO') idBase = (data['matricula'] ?? '').toString().toLowerCase().trim();
      else if (perfil == 'RESPONSÁVEL') idBase = (data['cpf'] ?? '').toString().toLowerCase().trim();
      else idBase = (data['id'] ?? '').toString().toLowerCase().trim();

      String loginChave = (data['email']?.toString().trim().isNotEmpty == true) 
          ? data['email'].toString().toLowerCase().trim() 
          : idBase;

      String nome = (data['nome'] ?? '').toString().toLowerCase().trim();
      String status = data['status'] ?? 'Ativo';
      
      // Recolhe todas as chaves que podem pertencer a esta mesma pessoa no banco de dados global
      Set<String> chavesEncontradas = {};

      if (manuaisMap.containsKey(loginChave)) chavesEncontradas.add(loginChave);
      if (idBase.isNotEmpty && manuaisMap.containsKey(idBase)) chavesEncontradas.add(idBase);
      if (idBase.isNotEmpty && manuaisMap.containsKey('$idBase@$codigoEscola.com')) chavesEncontradas.add('$idBase@$codigoEscola.com');
      if (idBase.isNotEmpty && manuaisMap.containsKey('$idBase@domex.com')) chavesEncontradas.add('$idBase@domex.com');
      if (nome.isNotEmpty && nomeParaLogin.containsKey(nome)) chavesEncontradas.add(nomeParaLogin[nome]!);

      if (chavesEncontradas.isNotEmpty) {
        String chavePrincipal = chavesEncontradas.first;
        status = manuaisMap[chavePrincipal]!['status'] ?? status;
        
        String emailAcesso = (manuaisMap[chavePrincipal]!['email'] ?? '').toString().trim().toLowerCase();
        if (emailAcesso.isNotEmpty) {
           loginChave = emailAcesso;
        } else if (!loginChave.contains('@')) {
           loginChave = manuaisMap[chavePrincipal]!['idLogin']?.toString().toLowerCase() ?? loginChave;
        }
        
        // Remove agressivamente TODAS as credenciais correspondentes para não sobrar nenhum "lixo" que gere um card manual duplicado
        for (var chave in chavesEncontradas) {
          manuaisMap.remove(chave); 
        }
      }

      todosUsuarios.add({
        'nome': data['nome'] ?? 'Sem Nome',
        'login': loginChave, 
        'telefone': data['telefone'] ?? '',
        'perfil': perfil,
        'status': status,
        'fotoUrl': data['fotoUrl'],
        'origem': 'AUTOMATICO',
        'icone': icone,
        'cor': cor,
        'rawDoc': data,
      });
    }

    for (var a in alunos) _adicionarAuto(a, 'ALUNO', Icons.school_rounded, Colors.blue);
    for (var p in professores) _adicionarAuto(p, 'PROFESSOR', Icons.assignment_ind_rounded, Colors.orange);
    for (var r in responsaveis) _adicionarAuto(r, 'RESPONSÁVEL', Icons.family_restroom_rounded, Colors.green);
    for (var s in secretaria) _adicionarAuto(s, 'SECRETARIA', Icons.support_agent_rounded, Colors.teal);

    for (var m in manuaisMap.values) {
      todosUsuarios.add({
        'nome': m['nome'] ?? 'Sem Nome',
        'login': m['idLogin'],
        'telefone': '',
        'perfil': (m['perfil'] ?? 'INDEFINIDO').toString().toUpperCase(),
        'status': m['status'] ?? 'Ativo',
        'fotoUrl': null,
        'origem': 'MANUAL',
        'icone': Icons.admin_panel_settings_rounded,
        'cor': Colors.purple,
        'rawDoc': m,
      });
    }

    final filtrados = todosUsuarios.where((u) {
      final busca = _termoBusca.toLowerCase();
      final nome = (u['nome'] ?? '').toString().toLowerCase();
      final login = (u['login'] ?? '').toString().toLowerCase();
      final matchBusca = nome.contains(busca) || login.contains(busca);

      final perfil = (u['perfil'] ?? '').toString().toUpperCase();
      final matchPerfil = _filtroPerfil == 'TODOS' || perfil.contains(_filtroPerfil);

      final status = (u['status'] ?? '').toString().toUpperCase();
      final matchStatus = _filtroStatus == 'TODOS' || status == _filtroStatus;

      return matchBusca && matchPerfil && matchStatus;
    }).toList();

    filtrados.sort((a, b) => a['nome'].toString().compareTo(b['nome'].toString()));

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Todos os Usuários (${filtrados.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filtroPerfil,
                    icon: const Icon(Icons.filter_alt_rounded, color: Colors.blue, size: 20),
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                    onChanged: (v) {
                      if (v != null) setState(() => _filtroPerfil = v);
                    },
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('Todos os Perfis', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'ALUNO', child: Text('Alunos', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'PROFESSOR', child: Text('Professores', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'RESPONSÁVEL', child: Text('Responsáveis', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'SECRETARIA', child: Text('Secretaria', style: TextStyle(color: Colors.black87))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filtroStatus,
                    icon: const Icon(Icons.security, color: Colors.blue, size: 20),
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                    onChanged: (v) {
                      if (v != null) setState(() => _filtroStatus = v);
                    },
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('Todos os Status', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'ATIVO', child: Text('Apenas Ativos', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'BLOQUEADO', child: Text('Apenas Bloqueados/Inativos', style: TextStyle(color: Colors.black87))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              SizedBox(
                width: 250, height: 40,
                child: TextField(
                  onChanged: (value) => _debouncer.run(() => setState(() => _termoBusca = value)),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar nome ou login...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true, fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              ElevatedButton.icon(
                onPressed: () => _abrirModalAcessoManual(alunos, professores, responsaveis, secretaria), 
                style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white),
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: const Text('Novo Acesso Manual'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: filtrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Nenhum utilizador encontrado para a sua pesquisa.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    )
                  )
                : ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final u = filtrados[index];
                      final isAtivo = u['status'] == 'Ativo';
                      final Color corItem = u['cor'];

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isAtivo ? Colors.grey.shade300 : Colors.red.shade300, width: isAtivo ? 1 : 1.5),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _abrirFichaDetalhes(u, turmasDoSistema),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: u['fotoUrl'] != null ? () => _mostrarFotoAmpliada(u['fotoUrl']) : null,
                                  borderRadius: BorderRadius.circular(24),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: corItem.withAlpha(30),
                                    backgroundImage: u['fotoUrl'] != null ? NetworkImage(u['fotoUrl']) : null,
                                    child: u['fotoUrl'] == null ? Icon(u['icone'], color: corItem) : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.login_rounded, size: 12, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text('${u['login']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: corItem.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(u['icone'], size: 14, color: corItem),
                                          const SizedBox(width: 6),
                                          Text(u['perfil'].toString().toUpperCase(), style: TextStyle(color: corItem, fontWeight: FontWeight.bold, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  decoration: BoxDecoration(color: isAtivo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: isAtivo ? Colors.green.shade200 : Colors.red.shade200)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: isAtivo ? 'Ativo' : 'Bloqueado',
                                      icon: Icon(Icons.arrow_drop_down, color: isAtivo ? Colors.green.shade700 : Colors.red.shade700, size: 16),
                                      style: TextStyle(color: isAtivo ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 11),
                                      items: const [
                                        DropdownMenuItem(value: 'Ativo', child: Text('ATIVO')),
                                        DropdownMenuItem(value: 'Bloqueado', child: Text('BLOQUEADO')),
                                      ],
                                      onChanged: (novoStatus) async {
                                        if (novoStatus != null && novoStatus != (isAtivo ? 'Ativo' : 'Bloqueado')) {
                                          try {
                                            String statusFinal = novoStatus;
                                            if (u['perfil'] == 'ALUNO' && novoStatus == 'Bloqueado') statusFinal = 'Inativo';

                                            if (u['perfil'] == 'ALUNO') {
                                              await ref.read(alunoServiceProvider).atualizarStatus(u['rawDoc']['matricula'], statusFinal);
                                            } else if (u['perfil'] == 'PROFESSOR') {
                                              await ref.read(professorServiceProvider).atualizarStatus(u['rawDoc']['id'], statusFinal);
                                            } else if (u['perfil'] == 'RESPONSÁVEL') {
                                              await ref.read(responsavelServiceProvider).atualizarStatus(u['rawDoc']['id'], statusFinal);
                                            } else if (u['perfil'] == 'SECRETARIA') {
                                              await ref.read(secretariaServiceProvider).atualizarStatus(u['rawDoc']['id'], statusFinal);
                                            } else {
                                              await ref.read(usuarioEscolaServiceProvider)!.salvarUsuario({...u['rawDoc'], 'status': statusFinal});
                                            }
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Acesso de ${u['nome']} alterado.'), backgroundColor: Colors.green));
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                                          }
                                        }
                                      },
                                    )
                                  )
                                ),
                                const SizedBox(width: 24),
                                
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.red), 
                                  tooltip: 'Excluir Acesso', 
                                  onPressed: () => _confirmarExclusaoAcesso(u)
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}