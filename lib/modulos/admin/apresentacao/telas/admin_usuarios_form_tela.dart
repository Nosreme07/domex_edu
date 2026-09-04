import 'dart:async'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';
import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/secretaria_provider.dart'; 

// ============================================================================
// FORMATADOR PARA TUDO MAIÚSCULO
// ============================================================================
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// ============================================================================
// DEBOUNCER PRIVADO PARA OTIMIZAR A PESQUISA
// ============================================================================
class _Debouncer {
  final int milliseconds;
  Timer? _timer;
  _Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

// ============================================================================
// PROVIDER INTERNO PARA GESTÃO DOS USUÁRIOS DE ACESSO
// ============================================================================
class _UsuarioEscolaService {
  final String escolaId;
  final _db = FirebaseFirestore.instance.collection('usuarios');

  _UsuarioEscolaService(this.escolaId);

  Future<void> salvarUsuario(Map<String, dynamic> dadosUsuario, bool isEdicao, String senhaPadrao) async {
    dadosUsuario['escolaId'] = escolaId;
    dadosUsuario['tenantId'] = escolaId;

    if (!isEdicao) {
      FirebaseApp appSecundario = await Firebase.initializeApp(
        name: 'AppCriacaoAcesso_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      
      UserCredential userCred = await FirebaseAuth.instanceFor(app: appSecundario)
          .createUserWithEmailAndPassword(email: dadosUsuario['email'], password: senhaPadrao);
      
      final String novoUid = userCred.user!.uid;
      await appSecundario.delete();

      dadosUsuario['uid'] = novoUid;
      dadosUsuario['dataCriacao'] = DateTime.now().toIso8601String();
      await _db.doc(novoUid).set(dadosUsuario, SetOptions(merge: true));

    } else {
      String docId = dadosUsuario['docId'] ?? dadosUsuario['idLogin'];
      dadosUsuario.remove('docId'); 
      await _db.doc(docId).set(dadosUsuario, SetOptions(merge: true));
    }
  }

  Future<void> atualizarStatus(String docId, String novoStatus) async {
    await _db.doc(docId).update({'status': novoStatus});
  }

  Future<void> excluirUsuario(String docId) async {
    await _db.doc(docId).delete();
  }
}

final _usuarioEscolaServiceProvider = Provider<_UsuarioEscolaService?>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) {
    return null;
  }
  return _UsuarioEscolaService(usuario.id);
});

final _usuariosEscolaStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('usuarios')
      .where('escolaId', isEqualTo: usuario.id)
      .snapshots()
      .map((snapshot) {
        final lista = snapshot.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id; 
          return data;
        }).toList();
        lista.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));
        return lista;
      });
});

// ============================================================================
// TELA PRINCIPAL DE GESTÃO DE USUÁRIOS
// ============================================================================
class AdminUsuariosFormTela extends ConsumerStatefulWidget {
  const AdminUsuariosFormTela({super.key});

  @override
  ConsumerState<AdminUsuariosFormTela> createState() => _AdminUsuariosFormTelaState();
}

class _AdminUsuariosFormTelaState extends ConsumerState<AdminUsuariosFormTela> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; 

  String _termoBusca = ''; 
  String? _perfilAtivo; 
  final _debouncer = _Debouncer(milliseconds: 400); 

  Widget _buildContatos(String? telefoneStr, String? emailStr) {
    final telefone = (telefoneStr ?? '').trim();
    final email = (emailStr ?? '').trim();
    
    if (telefone.isEmpty && email.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.black54));
    }

    final numeroLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (telefone.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(telefone, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              if (numeroLimpo.length >= 10) ...[
                const SizedBox(width: 8),
                Tooltip(message: 'Abrir WhatsApp', child: InkWell(onTap: () => launchUrl(Uri.parse('https://wa.me/55$numeroLimpo')), child: Image.asset('assets/whatsapp.png', width: 16, height: 16))),
                const SizedBox(width: 8),
                Tooltip(message: 'Ligar', child: InkWell(onTap: () => launchUrl(Uri.parse('tel:$numeroLimpo')), child: const Icon(Icons.phone, color: Colors.blue, size: 16))),
              ]
            ],
          ),
        if (email.isNotEmpty && !email.contains('@aluno.com')) 
          Text(email, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
      ],
    );
  }

  String _obterPerfilDisplay(String perfilRaw) {
    final p = perfilRaw.toLowerCase();
    if (p == 'responsavel' || p == 'responsável') {
      return 'RESPONSÁVEL';
    }
    if (p == 'secretaria' || p == 'secretária') {
      return 'FUNCIONÁRIO / EQUIPE';
    }
    if (p == 'aluno') {
      return 'ALUNO';
    }
    if (p == 'professor') {
      return 'PROFESSOR';
    }
    return p.toUpperCase();
  }

  void _abrirFormularioUsuario({Map<String, dynamic>? usuarioEdicao, required List<Map<String, dynamic>> usuariosExistentes}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _FormularioUsuarioDialog(
          usuarioEdicao: usuarioEdicao,
          usuariosExistentes: usuariosExistentes, 
          aoSalvar: (dados, senhaPadrao) async {
            final servico = ref.read(_usuarioEscolaServiceProvider);
            if (servico != null) {
              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
              
              try {
                await servico.salvarUsuario(dados, usuarioEdicao != null, senhaPadrao);
                if (!context.mounted) {
                  return;
                }
                
                Navigator.pop(context); 
                Navigator.pop(context); 
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(usuarioEdicao == null ? 'Acesso criado com sucesso! A senha padrão é $senhaPadrao' : 'Acesso atualizado!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            }
          },
        );
      },
    );
  }

  void _visualizarUsuario(Map<String, dynamic> usuario) {
    final corPrimaria = Theme.of(context).primaryColor;
    final perfilVisual = _obterPerfilDisplay(usuario['perfil']?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.all(0),
        title: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: corPrimaria.withAlpha(13), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, size: 32, color: corPrimaria),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(usuario['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), const SizedBox(height: 4), Text('Acesso: $perfilVisual', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))
            ],
          ),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLinhaExibicao('Matrícula / ID (Acesso):', Text(usuario['idLogin']?.toString() ?? '-')),
              _buildLinhaExibicao('E-mail (Login):', Text(usuario['email']?.toString().contains('@aluno.com') == true ? 'Login via Matrícula' : (usuario['email'] ?? 'Não cadastrado'))),
              _buildLinhaExibicao('Telefone:', Text(usuario['telefone']?.toString().isNotEmpty == true ? usuario['telefone'] : 'Não informado')),
              _buildLinhaExibicao('Status do Acesso:', Text(usuario['status'] ?? 'Ativo')),
              const Divider(height: 32),
              const Text('Vínculos (Alunos Dependentes):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 8),
              if (usuario['alunosVinculados'] != null && (usuario['alunosVinculados'] as List).isNotEmpty)
                ...(usuario['alunosVinculados'] as List).map((a) => Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Row(children: [const Icon(Icons.school, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(a.toString())])))
              else
                const Text('Nenhum vínculo cadastrado.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.all(24),
        actions: [
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('Fechar Ficha'))
        ],
      )
    );
  }

  Widget _buildLinhaExibicao(String label, Widget widgetValor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), Expanded(child: widgetValor)]),
    );
  }

  void _alternarStatus(Map<String, dynamic> usuario) {
    final statusAtual = usuario['status'] ?? 'Ativo';
    final novoStatus = statusAtual == 'Ativo' ? 'Bloqueado' : 'Ativo';
    final verbo = novoStatus == 'Bloqueado' ? 'BLOQUEAR' : 'DESBLOQUEAR';
    final idReal = usuario['docId'] ?? usuario['idLogin'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(novoStatus == 'Bloqueado' ? Icons.lock : Icons.lock_open, color: novoStatus == 'Bloqueado' ? Colors.orange : Colors.green), const SizedBox(width: 8), Text('$verbo Acesso')]),
        content: Text('Tem certeza que deseja $verbo o acesso de ${usuario['nome']}?\n\nEle ${novoStatus == 'Bloqueado' ? 'NÃO conseguirá' : 'conseguirá'} acessar o sistema.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: novoStatus == 'Bloqueado' ? Colors.orange : Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await ref.read(_usuarioEscolaServiceProvider)?.atualizarStatus(idReal, novoStatus);
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Acesso $novoStatus com sucesso!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red));
              }
            },
            child: Text('Sim, $verbo'),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusao(Map<String, dynamic> usuario) {
    final idReal = usuario['docId'] ?? usuario['idLogin'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Excluir Usuário de Acesso', style: TextStyle(color: Colors.red))]),
        content: Text('Tem certeza que deseja apagar o acesso de ${usuario['nome']}?\n\nIsso apagará apenas a credencial de login, os dados da pessoa na escola permanecem intactos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await ref.read(_usuarioEscolaServiceProvider)?.excluirUsuario(idReal);
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário excluído.'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Sim, Excluir'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContador(String titulo, int valor, MaterialColor cor, String perfilId) {
    final isSelecionado = _perfilAtivo == perfilId;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (_perfilAtivo == perfilId) { 
              _perfilAtivo = null; 
              _termoBusca = ''; 
            } else { 
              _perfilAtivo = perfilId; 
              _termoBusca = ''; 
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelecionado ? cor.shade50 : Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelecionado ? cor.shade400 : Colors.grey.shade300, width: isSelecionado ? 2 : 1),
            boxShadow: isSelecionado ? [BoxShadow(color: cor.withAlpha(40), blurRadius: 10, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Text(valor.toString(), style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: isSelecionado ? cor.shade700 : Colors.black87)),
              const SizedBox(height: 4),
              Text(titulo, style: TextStyle(color: isSelecionado ? cor.shade700 : Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabelaCabecalho(Color corPrimaria) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Matrícula / ID', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria))),
          Expanded(flex: 3, child: Text('Nome do Usuário', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria))),
          Expanded(flex: 3, child: Text('Contato / E-mail', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria))),
          Expanded(flex: 3, child: Text('Vínculos', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria))),
          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria))),
          Expanded(flex: 2, child: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTabelaLinha(Map<String, dynamic> user, List<Map<String, dynamic>> listaTotal) {
    final listaAlunos = user['alunosVinculados'] as List? ?? [];
    final vinculoTexto = listaAlunos.isNotEmpty ? listaAlunos.join(' | ') : '-';
    final isBloqueado = user['status'] == 'Bloqueado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(user['idLogin'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text(user['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 3, child: _buildContatos(user['telefone'], user['email'])),
          Expanded(flex: 3, child: Text(vinculoTexto, style: const TextStyle(fontSize: 13, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: isBloqueado ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)), child: Text(isBloqueado ? 'Bloqueado' : 'Ativo', style: TextStyle(color: isBloqueado ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12))))),
          Expanded(
            flex: 2, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.visibility_rounded, color: Colors.blueGrey, size: 20), tooltip: 'Visualizar', onPressed: () => _visualizarUsuario(user)),
                IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20), tooltip: 'Editar Cadastro', onPressed: () => _abrirFormularioUsuario(usuarioEdicao: user, usuariosExistentes: listaTotal)),
                IconButton(icon: Icon(isBloqueado ? Icons.lock_open_rounded : Icons.lock_outline_rounded, color: isBloqueado ? Colors.green : Colors.orange, size: 20), tooltip: isBloqueado ? 'Desbloquear' : 'Bloquear', onPressed: () => _alternarStatus(user)),
                IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20), tooltip: 'Excluir', onPressed: () => _confirmarExclusao(user)),
              ],
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    
    final estadoUsuarios = ref.watch(_usuariosEscolaStreamProvider);
    final corPrimaria = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestão de Usuários e Acessos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Gerencie credenciais de login para alunos, responsáveis, professores e equipe.', style: TextStyle(color: Colors.grey)),
                ],
              ),
              const Spacer(),

              estadoUsuarios.when(
                loading: () => const SizedBox.shrink(),
                error: (erro, stack) => const SizedBox.shrink(),
                data: (lista) => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                  onPressed: () => _abrirFormularioUsuario(usuariosExistentes: lista),
                  icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                  label: const Text('Novo Acesso', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          estadoUsuarios.when(
            loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
            error: (erro, stack) => Center(child: Text('Erro ao carregar usuários: $erro')),
            data: (lista) {
              
              int countAlunos = 0; 
              int countResps = 0; 
              int countProfs = 0; 
              int countSecs = 0;
              
              for (var u in lista) {
                final p = (u['perfil'] ?? '').toString().toLowerCase().replaceAll('á', 'a');
                if (p == 'aluno') {
                  countAlunos++;
                } else if (p == 'professor') {
                  countProfs++;
                } else if (p == 'responsavel') {
                  countResps++;
                } else if (p == 'secretaria') {
                  countSecs++;
                }
              }

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildCardContador('Alunos', countAlunos, Colors.blue, 'aluno'),
                        const SizedBox(width: 16),
                        _buildCardContador('Responsáveis', countResps, Colors.orange, 'responsavel'),
                        const SizedBox(width: 16),
                        _buildCardContador('Professores', countProfs, Colors.deepPurple, 'professor'),
                        const SizedBox(width: 16),
                        _buildCardContador('Equipe / Funcionários', countSecs, Colors.teal, 'secretaria'),
                      ],
                    ),
                    const SizedBox(height: 32),

                    if (_perfilAtivo == null)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.touch_app_rounded, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text('Selecione um perfil acima', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54)),
                              const SizedBox(height: 8),
                              const Text('Clique em um dos cards para pesquisar e visualizar os acessos.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) => _debouncer.run(() => setState(() => _termoBusca = value)),
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [UpperCaseTextFormatter()],
                              decoration: InputDecoration(
                                hintText: 'Pesquisar ${_obterPerfilDisplay(_perfilAtivo!)} (Nome ou ID)...', 
                                prefixIcon: Icon(Icons.search_rounded, color: Colors.blue.shade700), 
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16), 
                                filled: true, fillColor: Colors.blue.shade50, 
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade700, width: 2)),
                              )
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                          child: Builder(
                            builder: (context) {
                              final filtrados = lista.where((u) {
                                final perfilBase = (u['perfil'] ?? '').toString().toLowerCase().replaceAll('á', 'a');
                                if (perfilBase != _perfilAtivo) {
                                  return false;
                                }
                                if (_termoBusca.trim().isEmpty) {
                                  return true;
                                }

                                final busca = _termoBusca.toUpperCase();
                                final nome = (u['nome'] ?? '').toString().toUpperCase();
                                final id = (u['idLogin'] ?? '').toString().toUpperCase();
                                
                                return nome.contains(busca) || id.contains(busca);
                              }).toList();

                              if (filtrados.isEmpty) {
                                return const Center(child: Text('Nenhum usuário encontrado para esta pesquisa.', style: TextStyle(color: Colors.grey)));
                              }

                              return Column(
                                children: [
                                  _buildTabelaCabecalho(corPrimaria),
                                  Expanded(child: ListView.builder(itemCount: filtrados.length, itemBuilder: (context, index) => _buildTabelaLinha(filtrados[index], lista))),
                                ],
                              );
                            }
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODAL DINÂMICO DE CADASTRO COM CRIAÇÃO AUTOMÁTICA NO FIREBASE AUTH
// ============================================================================
class _FormularioUsuarioDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? usuarioEdicao;
  final List<Map<String, dynamic>> usuariosExistentes;
  final void Function(Map<String, dynamic>, String) aoSalvar;

  const _FormularioUsuarioDialog({
    super.key,
    this.usuarioEdicao, 
    required this.usuariosExistentes,
    required this.aoSalvar,
  });

  @override
  ConsumerState<_FormularioUsuarioDialog> createState() => _FormularioUsuarioDialogState();
}

class _FormularioUsuarioDialogState extends ConsumerState<_FormularioUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _idLoginCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController(); 
  final _emailCtrl = TextEditingController(); 
  
  final _telMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  String _perfilSelecionado = 'aluno';
  final List<Map<String, dynamic>> _alunosSelecionadosResponsavel = [];

  @override
  void initState() {
    super.initState();
    if (widget.usuarioEdicao != null) {
      final u = widget.usuarioEdicao!;
      _nomeCtrl.text = u['nome'] ?? '';
      _idLoginCtrl.text = u['idLogin'] ?? '';
      _telefoneCtrl.text = u['telefone'] ?? '';
      _emailCtrl.text = u['email'] ?? '';
      
      if (_emailCtrl.text.contains('@aluno.com')) {
        _emailCtrl.text = '';
      }
      
      _perfilSelecionado = u['perfil'] ?? 'aluno';

      if (_perfilSelecionado == 'responsavel' && u['alunosVinculadosRaw'] != null) {
        final listaRaw = u['alunosVinculadosRaw'] as List;
        for (var item in listaRaw) {
          _alunosSelecionadosResponsavel.add(Map<String, dynamic>.from(item));
        }
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose(); 
    _idLoginCtrl.dispose(); 
    _telefoneCtrl.dispose(); 
    _emailCtrl.dispose();
    super.dispose();
  }

  void _gerarIdSecretaria() {
    int maxId = 0;
    for (var u in widget.usuariosExistentes) {
      if (u['perfil'] == 'secretaria' && u['idLogin'].toString().startsWith('SEC-')) {
        final numeroStr = u['idLogin'].toString().replaceFirst('SEC-', '');
        final numero = int.tryParse(numeroStr);
        if (numero != null && numero > maxId) {
          maxId = numero;
        }
      }
    }
    _idLoginCtrl.text = 'SEC-${(maxId + 1).toString().padLeft(3, '0')}';
  }

  void _confirmarZerarSenha() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.lock_reset, color: Colors.blue), SizedBox(width: 8), Text('Zerar Senha / Esqueci a Senha')]),
        content: Text('Deseja enviar um e-mail de redefinição de senha para ${_emailCtrl.text}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-mail de redefinição enviado com sucesso!'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar e-mail: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Enviar Link de Redefinição'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.usuarioEdicao != null;
    final corPrimaria = Theme.of(context).primaryColor;
    final bool isAluno = _perfilSelecionado == 'aluno';

    final estadoAlunos = ref.watch(alunosStreamProvider);
    final estadoProfessores = ref.watch(professoresStreamProvider);
    final estadoSecretaria = ref.watch(secretariaStreamProvider);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isEdicao ? Icons.edit : Icons.person_add, color: corPrimaria),
              const SizedBox(width: 8),
              Text(isEdicao ? 'Editar Acesso' : 'Novo Usuário de Acesso', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          if (isEdicao && _emailCtrl.text.isNotEmpty && !isAluno)
            TextButton.icon(icon: const Icon(Icons.lock_reset_rounded, color: Colors.blue), label: const Text('Redefinir Senha', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)), onPressed: _confirmarZerarSenha)
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _perfilSelecionado,
                  isExpanded: true, 
                  decoration: const InputDecoration(labelText: 'Perfil de Acesso', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'aluno', child: Text('ALUNO')),
                    DropdownMenuItem(value: 'responsavel', child: Text('RESPONSÁVEL')),
                    DropdownMenuItem(value: 'professor', child: Text('PROFESSOR')),
                    DropdownMenuItem(value: 'secretaria', child: Text('FUNCIONÁRIO / EQUIPE')),
                  ],
                  onChanged: isEdicao ? null : (v) {
                    setState(() {
                      _perfilSelecionado = v!;
                      _alunosSelecionadosResponsavel.clear();
                      _nomeCtrl.clear();
                      _idLoginCtrl.clear();
                      _telefoneCtrl.clear();
                      _emailCtrl.clear();
                      if (_perfilSelecionado == 'secretaria') {
                        _gerarIdSecretaria();
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),

                // ===============================================
                // CASO 1: ALUNO
                // ===============================================
                if (!isEdicao && _perfilSelecionado == 'aluno') ...[
                  const Text('Buscar no Cadastro da Escola:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  estadoAlunos.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Erro: $err'),
                    data: (listaAlunosRaw) {
                      final listaAlunos = List<Map<String, dynamic>>.from(listaAlunosRaw);
                      listaAlunos.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

                      if (listaAlunos.isEmpty) {
                        return const Text('Nenhum aluno cadastrado.', style: TextStyle(color: Colors.red));
                      }
                      
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return DropdownMenu<String>(
                            width: constraints.maxWidth,
                            enableFilter: true, enableSearch: true, requestFocusOnTap: true,
                            leadingIcon: const Icon(Icons.search),
                            label: const Text('Pesquisar Aluno (Nome ou Matrícula)'),
                            inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
                            dropdownMenuEntries: listaAlunos.map((aluno) {
                              return DropdownMenuEntry<String>(
                                value: aluno['matricula'].toString(),
                                label: '${aluno['nome']} (Matrícula: ${aluno['matricula']})'.toUpperCase(),
                              );
                            }).toList(),
                            onSelected: (matriculaSelecionada) {
                              if (matriculaSelecionada != null) {
                                final aluno = listaAlunos.firstWhere((a) => a['matricula'].toString() == matriculaSelecionada);
                                setState(() {
                                  _nomeCtrl.text = (aluno['nome'] ?? '').toString().toUpperCase();
                                  _idLoginCtrl.text = aluno['matricula']?.toString() ?? '';
                                  _telefoneCtrl.text = aluno['telefone'] ?? '';
                                  _emailCtrl.text = aluno['email'] ?? '';
                                });
                              }
                            },
                          );
                        }
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // ===============================================
                // CASO 2: PROFESSOR
                // ===============================================
                if (!isEdicao && _perfilSelecionado == 'professor') ...[
                  const Text('Buscar no Cadastro da Escola:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  estadoProfessores.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Erro: $err'),
                    data: (listaProfsRaw) {
                      final listaProfs = List<Map<String, dynamic>>.from(listaProfsRaw);
                      listaProfs.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

                      if (listaProfs.isEmpty) {
                        return const Text('Nenhum professor cadastrado.', style: TextStyle(color: Colors.red));
                      }
                      
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return DropdownMenu<String>(
                            width: constraints.maxWidth, enableFilter: true, enableSearch: true, requestFocusOnTap: true, leadingIcon: const Icon(Icons.search),
                            label: const Text('Pesquisar Professor (Nome ou ID)'),
                            inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
                            dropdownMenuEntries: listaProfs.map((prof) => DropdownMenuEntry<String>(value: prof['id'].toString(), label: '${prof['nome']} (ID: ${prof['id']})'.toUpperCase())).toList(),
                            onSelected: (idSelecionado) {
                              if (idSelecionado != null) {
                                final prof = listaProfs.firstWhere((p) => p['id'].toString() == idSelecionado);
                                setState(() {
                                  _nomeCtrl.text = (prof['nome'] ?? '').toString().toUpperCase();
                                  _idLoginCtrl.text = prof['id']?.toString() ?? '';
                                  _telefoneCtrl.text = prof['telefone'] ?? '';
                                  _emailCtrl.text = prof['email'] ?? ''; 
                                });
                              }
                            },
                          );
                        }
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // ===============================================
                // CASO 3: FUNCIONÁRIO DA SECRETARIA
                // ===============================================
                if (!isEdicao && _perfilSelecionado == 'secretaria') ...[
                  const Text('Buscar no Cadastro da Equipe (Secretaria):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  estadoSecretaria.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Erro: $err'),
                    data: (listaSecRaw) {
                      final listaSec = List<Map<String, dynamic>>.from(listaSecRaw);
                      listaSec.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

                      if (listaSec.isEmpty) {
                        return const Text('Nenhum funcionário cadastrado.', style: TextStyle(color: Colors.red));
                      }
                      
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return DropdownMenu<String>(
                            width: constraints.maxWidth, enableFilter: true, enableSearch: true, requestFocusOnTap: true, leadingIcon: const Icon(Icons.search),
                            label: const Text('Pesquisar Funcionário (Nome ou ID)'),
                            inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
                            dropdownMenuEntries: listaSec.map((mem) => DropdownMenuEntry<String>(value: mem['id'].toString(), label: '${mem['nome']} (ID: ${mem['id']} - ${mem['funcao']})'.toUpperCase())).toList(),
                            onSelected: (idSelecionado) {
                              if (idSelecionado != null) {
                                final mem = listaSec.firstWhere((m) => m['id'].toString() == idSelecionado);
                                setState(() {
                                  _nomeCtrl.text = (mem['nome'] ?? '').toString().toUpperCase();
                                  _idLoginCtrl.text = mem['id']?.toString() ?? '';
                                  _telefoneCtrl.text = mem['telefone'] ?? '';
                                  _emailCtrl.text = mem['email'] ?? ''; 
                                });
                              }
                            },
                          );
                        }
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // ===============================================
                // CASO 4: RESPONSÁVEL
                // ===============================================
                if (_perfilSelecionado == 'responsavel') ...[
                  const Text('Vincular Aluno(s) / Dependentes ao Responsável:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  estadoAlunos.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Erro: $err'),
                    data: (listaAlunosRaw) {
                      final listaAlunos = List<Map<String, dynamic>>.from(listaAlunosRaw);
                      listaAlunos.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

                      if (listaAlunos.isEmpty) {
                        return const Text('Nenhum aluno cadastrado.', style: TextStyle(color: Colors.red));
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return DropdownMenu<String>(
                                width: constraints.maxWidth, enableFilter: true, enableSearch: true, requestFocusOnTap: true, leadingIcon: const Icon(Icons.person_add_alt_1), label: const Text('Pesquisar Aluno para Vincular'), inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
                                dropdownMenuEntries: listaAlunos.map((aluno) {
                                  final irmaoInfo = (aluno['temIrmao'] == true && aluno['irmaoSelecionado'] != null) ? ' [Irmão(ã): ${aluno['irmaoSelecionado']}]' : '';
                                  return DropdownMenuEntry<String>(value: aluno['matricula'].toString(), label: '${aluno['nome']} (Matrícula: ${aluno['matricula']})$irmaoInfo'.toUpperCase());
                                }).toList(),
                                onSelected: (matriculaSelecionada) {
                                  if (matriculaSelecionada != null) {
                                    final aluno = listaAlunos.firstWhere((a) => a['matricula'].toString() == matriculaSelecionada);
                                    if (!_alunosSelecionadosResponsavel.any((a) => a['matricula'] == aluno['matricula'])) {
                                      setState(() {
                                        _alunosSelecionadosResponsavel.add(aluno);
                                        if (!isEdicao && _idLoginCtrl.text.isEmpty) {
                                          _idLoginCtrl.text = 'RESP-${aluno['matricula']}';
                                        }
                                      });
                                    }
                                  }
                                },
                              );
                            }
                          ),
                          const SizedBox(height: 12),
                          if (_alunosSelecionadosResponsavel.isNotEmpty) ...[
                            Wrap(spacing: 8, runSpacing: 8, children: _alunosSelecionadosResponsavel.map((aluno) {
                                return Chip(avatar: const Icon(Icons.school, size: 16), label: Text('${aluno['nome']} (${aluno['matricula']})'.toUpperCase()), onDeleted: () { setState(() { _alunosSelecionadosResponsavel.removeWhere((a) => a['matricula'] == aluno['matricula']); }); });
                              }).toList()),
                            const SizedBox(height: 16),
                          ],
                        ],
                      );
                    },
                  ),
                ],

                TextFormField(
                  controller: _nomeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _idLoginCtrl,
                        enabled: !isEdicao, 
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: const InputDecoration(labelText: 'Matrícula / ID Interno', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _telefoneCtrl,
                        inputFormatters: [_telMask],
                        decoration: const InputDecoration(labelText: 'Telefone / WhatsApp', border: OutlineInputBorder(), hintText: '(00) 00000-0000'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailCtrl,
                  enabled: !isEdicao, 
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: isAluno ? 'E-mail Pessoal (Opcional)' : 'E-mail de Acesso (Login)', 
                    border: const OutlineInputBorder(), 
                    hintText: 'exemplo@escola.com',
                    filled: isEdicao,
                    fillColor: isEdicao ? Colors.grey.shade100 : null
                  ),
                  validator: (v) {
                    if (isAluno) {
                      return null; 
                    }
                    return (v == null || v.isEmpty || !v.contains('@')) ? 'Insira um e-mail válido para o login' : null;
                  },
                ),
                if (isEdicao && !isAluno)
                  const Padding(padding: EdgeInsets.only(top: 4.0), child: Text('O e-mail de acesso não pode ser alterado.', style: TextStyle(color: Colors.red, fontSize: 11))),

                if (!isEdicao) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(child: Text('A senha padrão para este acesso será: ${isAluno ? '123456' : 'Domex@123'}', style: const TextStyle(color: Colors.orange, fontSize: 13))),
                      ],
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              
              String emailParaSalvar = _emailCtrl.text.trim().toLowerCase();
              if (isAluno && emailParaSalvar.isEmpty) {
                emailParaSalvar = '${_idLoginCtrl.text.trim()}@aluno.com'.toLowerCase();
              }

              final dadosSalvar = {
                'nome': _nomeCtrl.text.trim(),
                'idLogin': _idLoginCtrl.text.trim(),
                'telefone': _telefoneCtrl.text.trim(),
                'email': emailParaSalvar,
                'perfil': _perfilSelecionado == 'responsavel' || _perfilSelecionado == 'responsável' ? 'responsavel' 
                        : _perfilSelecionado == 'secretaria' || _perfilSelecionado == 'secretária' ? 'secretaria' 
                        : _perfilSelecionado,
                'status': isEdicao ? widget.usuarioEdicao!['status'] : 'Ativo',
                if (isEdicao) 'docId': widget.usuarioEdicao!['docId'],
                if (_perfilSelecionado == 'responsavel' || _perfilSelecionado == 'responsável') ...{
                  'alunosVinculados': _alunosSelecionadosResponsavel.map((a) => '${a['nome']} (${a['matricula']})'.toUpperCase()).toList(),
                  'alunosVinculadosRaw': _alunosSelecionadosResponsavel.map((a) => {'nome': a['nome'], 'matricula': a['matricula']}).toList(),
                }
              };

              final senhaParaSalvar = isAluno ? '123456' : 'Domex@123';
              
              widget.aoSalvar(dadosSalvar, senhaParaSalvar);
            }
          },
          child: const Text('Salvar Acesso'),
        ),
      ],
    );
  }
}