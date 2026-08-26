import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// PROVIDERS INTERNOS (GARANTE QUE NÃO FALTE NENHUMA IMPORTAÇÃO)
// ============================================================================
class _UsuarioEscolaService {
  final String escolaId;
  final _db = FirebaseFirestore.instance.collection('usuarios');

  _UsuarioEscolaService(this.escolaId);

  Future<void> salvarUsuario(Map<String, dynamic> dadosUsuario) async {
    dadosUsuario['escolaId'] = escolaId;
    dadosUsuario['dataCriacao'] = FieldValue.serverTimestamp();
    await _db.doc(dadosUsuario['idLogin']).set(dadosUsuario, SetOptions(merge: true));
  }
}

final _usuarioEscolaServiceProvider = Provider<_UsuarioEscolaService?>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return null;
  return _UsuarioEscolaService(usuario.id);
});

final _usuariosEscolaStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('usuarios')
      .where('escolaId', isEqualTo: usuario.id)
      .orderBy('nome')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

// ============================================================================
// TELA PRINCIPAL DE GESTÃO DE USUÁRIOS
// ============================================================================
class AdminUsuariosFormTela extends ConsumerStatefulWidget {
  const AdminUsuariosFormTela({super.key});

  @override
  ConsumerState<AdminUsuariosFormTela> createState() => _AdminUsuariosFormTelaState();
}

class _AdminUsuariosFormTelaState extends ConsumerState<AdminUsuariosFormTela> {
  
  void _abrirFormularioUsuario({Map<String, dynamic>? usuarioEdicao}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _FormularioUsuarioDialog(
          usuarioEdicao: usuarioEdicao,
          aoSalvar: (dados) async {
            final servico = ref.read(_usuarioEscolaServiceProvider);
            if (servico != null) {
              try {
                await servico.salvarUsuario(dados);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usuário salvo com sucesso!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
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

  @override
  Widget build(BuildContext context) {
    final estadoUsuarios = ref.watch(_usuariosEscolaStreamProvider);
    final corPrimaria = Theme.of(context).primaryColor;

    return Padding(
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
                  Text('Gestão de Usuários', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Gerencie alunos, responsáveis, professores e secretárias.', style: TextStyle(color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: corPrimaria,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: () => _abrirFormularioUsuario(),
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                label: const Text('Novo Usuário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: estadoUsuarios.when(
                loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
                error: (erro, stack) => Center(child: Text('Erro ao carregar usuários: $erro')),
                data: (lista) {
                  if (lista.isEmpty) {
                    return const Center(
                      child: Text('Nenhum usuário cadastrado nesta escola ainda.', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return SingleChildScrollView(
                    child: DataTable(
                      headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria),
                      columns: const [
                        DataColumn(label: Text('Matrícula / ID')),
                        DataColumn(label: Text('Nome do Usuário')),
                        DataColumn(label: Text('Perfil')),
                        DataColumn(label: Text('Ações')),
                      ],
                      rows: lista.map((user) {
                        return DataRow(
                          cells: [
                            DataCell(Text(user['idLogin'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(user['nome'] ?? '')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100, 
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user['perfil']?.toString().toUpperCase() ?? '', 
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              )
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.grey),
                                onPressed: () => _abrirFormularioUsuario(usuarioEdicao: user),
                              )
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODAL DE CADASTRO / EDIÇÃO DE USUÁRIO
// ============================================================================
class _FormularioUsuarioDialog extends StatefulWidget {
  final Map<String, dynamic>? usuarioEdicao;
  final Function(Map<String, dynamic>) aoSalvar;

  const _FormularioUsuarioDialog({this.usuarioEdicao, required this.aoSalvar});

  @override
  State<_FormularioUsuarioDialog> createState() => _FormularioUsuarioDialogState();
}

class _FormularioUsuarioDialogState extends State<_FormularioUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _idLoginCtrl = TextEditingController();
  
  String _perfilSelecionado = 'aluno';

  @override
  void initState() {
    super.initState();
    if (widget.usuarioEdicao != null) {
      _nomeCtrl.text = widget.usuarioEdicao!['nome'] ?? '';
      _idLoginCtrl.text = widget.usuarioEdicao!['idLogin'] ?? '';
      _perfilSelecionado = widget.usuarioEdicao!['perfil'] ?? 'aluno';
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _idLoginCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.usuarioEdicao != null;
    final corPrimaria = Theme.of(context).primaryColor;

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEdicao ? Icons.edit : Icons.person_add, color: corPrimaria),
          const SizedBox(width: 8),
          Text(isEdicao ? 'Editar Usuário' : 'Novo Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _perfilSelecionado, // Corrigido o aviso do Flutter
                decoration: const InputDecoration(labelText: 'Perfil de Acesso', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'aluno', child: Text('Aluno')),
                  DropdownMenuItem(value: 'responsavel', child: Text('Responsável')),
                  DropdownMenuItem(value: 'professor', child: Text('Professor')),
                  DropdownMenuItem(value: 'secretaria', child: Text('Secretária')),
                ],
                onChanged: (v) => setState(() => _perfilSelecionado = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idLoginCtrl,
                enabled: !isEdicao, // Trava a edição do ID após criado
                decoration: const InputDecoration(
                  labelText: 'Matrícula / ID de Acesso', 
                  border: OutlineInputBorder(),
                  helperText: 'O usuário usará este código para fazer login.'
                ),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              if (!isEdicao) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(child: Text('A senha padrão para novos usuários será: Mudar@123', style: TextStyle(color: Colors.orange))),
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.aoSalvar({
                'nome': _nomeCtrl.text.trim(),
                'idLogin': _idLoginCtrl.text.trim(),
                'perfil': _perfilSelecionado,
                'status': 'Ativo'
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Salvar Usuário'),
        ),
      ],
    );
  }
}