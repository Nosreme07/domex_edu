import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================================
// PROVIDER PARA BUSCAR OS USUÁRIOS MASTER NO FIREBASE
// ============================================================================
final superAdminsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  // Busca na coleção global de 'usuarios' apenas aqueles que tem a role 'SUPER_ADMIN'
  return FirebaseFirestore.instance
      .collection('usuarios')
      .where('role', isEqualTo: 'SUPER_ADMIN')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

class SuperAdminUsuariosTela extends ConsumerStatefulWidget {
  const SuperAdminUsuariosTela({super.key});

  @override
  ConsumerState<SuperAdminUsuariosTela> createState() => _SuperAdminUsuariosTelaState();
}

class _SuperAdminUsuariosTelaState extends ConsumerState<SuperAdminUsuariosTela> {

  // ==========================================================
  // FUNÇÕES DE AÇÕES DO USUÁRIO NO BANCO DE DADOS
  // ==========================================================
  void _abrirFormularioUsuario({Map<String, dynamic>? usuarioParaEditar}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _FormularioUsuarioMasterDialog(
          usuarioInicial: usuarioParaEditar,
          aoSalvar: (dadosUsuario) async {
            
            // Mostra tela de carregamento
            showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));

            try {
              final db = FirebaseFirestore.instance;

              if (usuarioParaEditar == null) {
                // =======================================
                // É UM USUÁRIO NOVO (CRIAR AUTH E BANCO)
                // =======================================
                final auth = FirebaseAuth.instance;
                
                // Cria o usuário na Authentication do Firebase
                UserCredential cred = await auth.createUserWithEmailAndPassword(
                  email: dadosUsuario['email'], 
                  password: 'Domex@123'
                );

                final novoUid = cred.user!.uid;
                
                // Salva os dados na coleção de usuários
                await db.collection('usuarios').doc(novoUid).set({
                  'uid': novoUid,
                  'nome': dadosUsuario['nome'],
                  'email': dadosUsuario['email'],
                  'telefone': dadosUsuario['telefone'],
                  'role': 'SUPER_ADMIN', 
                  'status': 'Ativo',
                  'dataCadastro': DateTime.now().toIso8601String(),
                });

                // Força deslogar pois o Firebase logou no usuário novo automaticamente
                await auth.signOut();

              } else {
                // =======================================
                // É UMA EDIÇÃO (ATUALIZAR APENAS O BANCO)
                // =======================================
                final uid = usuarioParaEditar['uid'];
                await db.collection('usuarios').doc(uid).update({
                  'nome': dadosUsuario['nome'],
                  'telefone': dadosUsuario['telefone'],
                  // Não podemos atualizar o email direto pelo Firestore, precisa ser via Auth
                });
              }

              if (!context.mounted) return;
              Navigator.pop(context); // Fecha loading
              Navigator.pop(context); // Fecha modal do form

              // Avisos visuais
              if (usuarioParaEditar == null) {
                _mostrarAvisoSenhaPadrao(dadosUsuario['email']);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário atualizado!'), backgroundColor: Colors.green));
              }

            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context); // Fecha loading
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
              }
            }
          },
        );
      },
    );
  }

  void _mostrarAvisoSenhaPadrao(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuário Criado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('O usuário poderá acessar o painel com as seguintes credenciais:'),
            const SizedBox(height: 16),
            Text('Login: $email'),
            const Text('Senha: Domex@123', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 8),
            const Text('Ele precisará alterar a senha no primeiro acesso.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('Atenção: Por segurança após criar as credenciais, você foi deslogado do sistema. Por favor, faça login novamente.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white), 
            onPressed: () {
              Navigator.pop(ctx);
            }, 
            child: const Text('Voltar para o Login')
          ),
        ],
      ),
    );
  }

  void _confirmarExclusaoUsuario(Map<String, dynamic> usuario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Excluir Usuário', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Tem certeza que deseja remover o acesso de ${usuario['nome']}?\n\nEle não poderá mais acessar o painel SaaS.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // Remove apenas o acesso no banco para não dar conflito Auth
                await FirebaseFirestore.instance.collection('usuarios').doc(usuario['uid']).delete();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário excluído com sucesso.'), backgroundColor: Colors.red));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _confirmarResetSenha(Map<String, dynamic> usuario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Zerar Senha', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Deseja enviar um link de redefinição de senha para o e-mail de ${usuario['nome']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: usuario['email']);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link de redefinição enviado para o e-mail do usuário.'), backgroundColor: Colors.green));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar link: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Enviar Link'),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LAYOUT DA PÁGINA
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final listagemUsuarios = ref.watch(superAdminsStreamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestão de Usuários Master', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  SizedBox(height: 8),
                  Text('Equipe da JPS MICROMAQ com acesso ao painel.', style: TextStyle(color: Colors.black54)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                onPressed: () => _abrirFormularioUsuario(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Novo Usuário'),
              )
            ],
          ),
          const SizedBox(height: 32),
          
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: listagemUsuarios.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              error: (e, stack) => Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('Erro: $e'))),
              data: (usuariosMaster) {
                if (usuariosMaster.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nenhum usuário Master encontrado.')));
                }
                
                return DataTable(
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  columns: const [
                    DataColumn(label: Text('Nome')),
                    DataColumn(label: Text('E-mail')),
                    DataColumn(label: Text('Telefone')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Ações')),
                  ],
                  rows: usuariosMaster.map((user) {
                    final isAtivo = user['status'] == 'Ativo';
                    return DataRow(
                      cells: [
                        DataCell(Text(user['nome'] ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(user['email'] ?? 'Sem E-mail')),
                        DataCell(Text(user['telefone'] ?? 'Não informado')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: isAtivo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(16)),
                            child: Text(user['status'] ?? 'Inativo', style: TextStyle(color: isAtivo ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        ),
                        DataCell(
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (val) {
                              if (val == 'editar') {
                                _abrirFormularioUsuario(usuarioParaEditar: user);
                              } else if (val == 'reset_senha') {
                                _confirmarResetSenha(user);
                              } else if (val == 'excluir') {
                                _confirmarExclusaoUsuario(user);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Editar')])),
                              const PopupMenuItem(value: 'reset_senha', child: Row(children: [Icon(Icons.lock_reset, color: Colors.orange, size: 18), SizedBox(width: 8), Text('Zerar Senha')])),
                              const PopupMenuItem(value: 'excluir', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Excluir', style: TextStyle(color: Colors.red))])),
                            ],
                          )
                        ),
                      ],
                    );
                  }).toList(),
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET DO FORMULÁRIO (Modal de Edição/Criação)
// ============================================================================
class _FormularioUsuarioMasterDialog extends StatefulWidget {
  final Map<String, dynamic>? usuarioInicial;
  final Function(Map<String, dynamic>) aoSalvar;

  const _FormularioUsuarioMasterDialog({this.usuarioInicial, required this.aoSalvar});

  @override
  State<_FormularioUsuarioMasterDialog> createState() => _FormularioUsuarioMasterDialogState();
}

class _FormularioUsuarioMasterDialogState extends State<_FormularioUsuarioMasterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _telMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    if (widget.usuarioInicial != null) {
      _nomeCtrl.text = widget.usuarioInicial!['nome'] ?? '';
      _emailCtrl.text = widget.usuarioInicial!['email'] ?? '';
      _telCtrl.text = widget.usuarioInicial!['telefone'] ?? '';
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      final dados = {
        'nome': _nomeCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'telefone': _telCtrl.text.trim(),
      };
      widget.aoSalvar(dados);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.usuarioInicial != null;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Text(isEdicao ? 'Editar Usuário Master' : 'Novo Usuário Master', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Este usuário terá acesso total ao painel SaaS da Domex.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                enabled: !isEdicao, // O email não pode ser editado pois é chave do Auth
                decoration: InputDecoration(labelText: 'E-mail (Login)', border: const OutlineInputBorder(), fillColor: isEdicao ? Colors.grey.shade100 : null, filled: isEdicao),
                validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null,
              ),
              if (isEdicao)
                const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 4), child: Text('O e-mail de acesso não pode ser alterado.', style: TextStyle(color: Colors.red, fontSize: 11)))),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telCtrl,
                inputFormatters: [_telMask],
                decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
          onPressed: _salvar,
          child: Text(isEdicao ? 'Atualizar Usuário' : 'Salvar Usuário'),
        ),
      ],
    );
  }
}