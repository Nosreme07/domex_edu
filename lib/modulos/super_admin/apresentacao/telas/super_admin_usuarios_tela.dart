import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class SuperAdminUsuariosTela extends StatefulWidget {
  const SuperAdminUsuariosTela({super.key});

  @override
  State<SuperAdminUsuariosTela> createState() => _SuperAdminUsuariosTelaState();
}

class _SuperAdminUsuariosTelaState extends State<SuperAdminUsuariosTela> {
  // Simulação de usuários logados
  List<Map<String, dynamic>> usuariosMaster = [
    {'id': 'USR-01', 'nome': 'Emerson Fernandes', 'email': 'emerson.fernandesantos@gmail.com', 'telefone': '(81) 99999-9999', 'status': 'Ativo'},
  ];

  // ==========================================================
  // FUNÇÕES DE AÇÕES DO USUÁRIO
  // ==========================================================
  void _abrirFormularioUsuario({Map<String, dynamic>? usuarioParaEditar}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _FormularioUsuarioMasterDialog(
          usuarioInicial: usuarioParaEditar,
          aoSalvar: (dadosUsuario) {
            setState(() {
              if (usuarioParaEditar == null) {
                // É um usuário NOVO
                usuariosMaster.add(dadosUsuario);
              } else {
                // É uma EDIÇÃO
                final index = usuariosMaster.indexWhere((u) => u['id'] == usuarioParaEditar['id']);
                if (index != -1) {
                  usuariosMaster[index] = dadosUsuario;
                }
              }
            });

            // Se for criação de usuário novo, mostra o aviso da senha padrão
            if (usuarioParaEditar == null) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Usuário Criado!'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('O usuário poderá acessar o painel com as seguintes credenciais:'),
                      const SizedBox(height: 16),
                      Text('Login: ${dadosUsuario['email']}'),
                      const Text('Senha: Domex@123', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 8),
                      const Text('Ele poderá (e deverá) alterar a senha no primeiro acesso.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  actions: [
                    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
                  ],
                ),
              );
            }
          },
        );
      },
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
        content: Text('Tem certeza que deseja remover o acesso de ${usuario['nome']}?\n\nEsta ação não poderá ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() => usuariosMaster.removeWhere((u) => u['id'] == usuario['id']));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário excluído com sucesso.')));
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
        content: Text('Tem certeza que deseja zerar a senha de ${usuario['nome']}?\n\nA nova senha de acesso dele(a) passará a ser: Domex@123'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              // Aqui no futuro entrará a lógica do Firebase Auth para resetar a senha
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A senha foi resetada para Domex@123 com sucesso!'), backgroundColor: Colors.green));
            },
            child: const Text('Confirmar e Zerar Senha'),
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
            child: DataTable(
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
                    DataCell(Text(user['nome'], style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(user['email'])),
                    DataCell(Text(user['telefone'])),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: isAtivo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(16)),
                        child: Text(user['status'], style: TextStyle(color: isAtivo ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
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
    // Se for edição, preenchemos os campos
    if (widget.usuarioInicial != null) {
      _nomeCtrl.text = widget.usuarioInicial!['nome'];
      _emailCtrl.text = widget.usuarioInicial!['email'];
      _telCtrl.text = widget.usuarioInicial!['telefone'];
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
        'id': widget.usuarioInicial?['id'] ?? 'USR-${DateTime.now().millisecondsSinceEpoch}',
        'nome': _nomeCtrl.text,
        'email': _emailCtrl.text,
        'telefone': _telCtrl.text,
        'status': widget.usuarioInicial?['status'] ?? 'Ativo',
      };
      widget.aoSalvar(dados);
      Navigator.pop(context); // Fecha o form
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
                decoration: const InputDecoration(labelText: 'E-mail (Login)', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null,
              ),
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