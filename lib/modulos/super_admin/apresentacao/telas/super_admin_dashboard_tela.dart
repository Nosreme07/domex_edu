import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // NOVO IMPORT AQUI!

import '../estado/escola_provider.dart';

class SuperAdminDashboardTela extends ConsumerStatefulWidget {
  const SuperAdminDashboardTela({super.key});

  @override
  ConsumerState<SuperAdminDashboardTela> createState() => _SuperAdminDashboardTelaState();
}

class _SuperAdminDashboardTelaState extends ConsumerState<SuperAdminDashboardTela> {
  
  void _abrirFormularioNovaEscola(int quantidadeAtual) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _FormularioNovaEscolaDialog(
          quantidadeAtual: quantidadeAtual,
          aoSalvar: (novaEscola, senhaPadrao) async {
            final servico = ref.read(escolaServiceProvider);
            try {
              await servico.salvarEscola(novaEscola);
              
              if (!context.mounted) return;
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Escola Provisionada!', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('O ambiente para ${novaEscola['nome']} foi criado com sucesso no banco de dados.'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Credenciais de Acesso (Administração)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            const Divider(),
                            Text('Código da Escola: ${novaEscola['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('E-mail: ${novaEscola['email']}'),
                            Text('Senha Padrão: $senhaPadrao', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                            const SizedBox(height: 8),
                            const Text('*A escola poderá alterar esta senha no primeiro acesso.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF080E1C), foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Entendido'),
                    )
                  ],
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar no banco: $e'), backgroundColor: Colors.red));
            }
          },
        );
      },
    );
  }

  void _confirmarExclusaoEscola(BuildContext context, Map<String, dynamic> escola) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Excluir Escola Permanentemente', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Tem certeza que deseja EXCLUIR o ambiente de "${escola['nome']}" (Código: ${escola['id']})?\n\nEsta ação apagará a escola do banco de dados e os usuários perderão o acesso.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(context); 
                try {
                  await ref.read(escolaServiceProvider).excluirEscola(escola['id']);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escola excluída com sucesso.'), backgroundColor: Colors.red));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Sim, Excluir Escola'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final estadoEscolas = ref.watch(escolasStreamProvider);
    const corDominante = Color(0xFF080E1C);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Visão Geral (SaaS)', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: corDominante)),
          const SizedBox(height: 8),
          const Text('Monitore a saúde do seu sistema, escolas ativas e volume de alunos.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 32),

          estadoEscolas.when(
            loading: () => const Center(child: CircularProgressIndicator(color: corDominante)),
            error: (erro, stack) => Center(child: Text('Erro ao carregar escolas: $erro')),
            data: (escolasClientes) {
              final escolasAtivasCount = escolasClientes.where((e) => e['status'] == 'Ativo').length;
              const totalAlunosCadastrados = "0"; 
              const receitaEstimada = "R\$ 0,00";

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.count(
                        crossAxisCount: constraints.maxWidth > 900 ? 3 : 1,
                        crossAxisSpacing: 24, mainAxisSpacing: 24, shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2, 
                        children: [
                          _SaaSMetricCard(
                            titulo: 'Escolas Ativas', 
                            valor: '$escolasAtivasCount', 
                            icone: Icons.domain_rounded, 
                            coresGradiente: [Colors.blue.shade700, Colors.blue.shade400],
                          ),
                          _SaaSMetricCard(
                            titulo: 'Alunos Cadastrados', 
                            valor: totalAlunosCadastrados, 
                            icone: Icons.groups_rounded, 
                            coresGradiente: [Colors.orange.shade700, Colors.orange.shade400],
                          ),
                          _SaaSMetricCard(
                            titulo: 'Receita Mensal (MRR)', 
                            valor: receitaEstimada, 
                            icone: Icons.account_balance_wallet_rounded, 
                            coresGradiente: [Colors.green.shade700, Colors.green.shade400],
                          ),
                        ],
                      );
                    }
                  ),
                  
                  const SizedBox(height: 48),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Escolas Cadastradas (Tenants)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: corDominante, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                        onPressed: () => _abrirFormularioNovaEscola(escolasClientes.length),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Provisionar Escola'),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: escolasClientes.isEmpty 
                    ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nenhuma escola provisionada no banco de dados.')))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth), 
                              child: DataTable(
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: corDominante),
                                dataRowMinHeight: 60,
                                dataRowMaxHeight: 60,
                                columns: const [
                                  DataColumn(label: Text('Código')),
                                  DataColumn(label: Text('Nome Fantasia')),
                                  DataColumn(label: Text('E-mail Admin')),
                                  DataColumn(label: Text('Plano')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Ações')),
                                ],
                                rows: escolasClientes.map((escola) {
                                  final isAtivo = escola['status'] == 'Ativo';
                                  // Tratamento de cor segura
                                  Color corAvatar = const Color(0xFF2C3E50);
                                  if (escola['corHex'] != null && escola['corHex'].toString().isNotEmpty) {
                                    try {
                                      corAvatar = Color(int.parse(escola['corHex'], radix: 16));
                                    } catch(e) {
                                      corAvatar = const Color(0xFF2C3E50);
                                    }
                                  }

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(escola['id'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(backgroundColor: corAvatar.withOpacity(0.2), radius: 16, child: Icon(Icons.school, size: 16, color: corAvatar)),
                                            const SizedBox(width: 12),
                                            Text(escola['nome']),
                                          ],
                                        )
                                      ),
                                      DataCell(Text(escola['email'] ?? '', style: TextStyle(color: Colors.grey.shade700))),
                                      DataCell(Text(escola['plano'] ?? 'Básico')),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: isAtivo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(16)),
                                          child: Text(escola['status'], style: TextStyle(color: isAtivo ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                        )
                                      ),
                                      DataCell(
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                                          onSelected: (val) async {
                                            final servico = ref.read(escolaServiceProvider);
                                            if (val == 'bloquear') {
                                              await servico.atualizarStatus(escola['id'], 'Bloqueado');
                                            } else if (val == 'desbloquear') {
                                              await servico.atualizarStatus(escola['id'], 'Ativo');
                                            } else if (val == 'excluir') {
                                              _confirmarExclusaoEscola(context, escola);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar Dados')])),
                                            isAtivo 
                                                ? const PopupMenuItem(value: 'bloquear', child: Row(children: [Icon(Icons.block, color: Colors.orange, size: 18), SizedBox(width: 8), Text('Bloquear Acesso', style: TextStyle(color: Colors.orange))]))
                                                : const PopupMenuItem(value: 'desbloquear', child: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8), Text('Desbloquear Acesso', style: TextStyle(color: Colors.green))])),
                                            const PopupMenuItem(value: 'excluir', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Excluir Escola', style: TextStyle(color: Colors.red))])),
                                          ],
                                        )
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        }
                      ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SaaSMetricCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final List<Color> coresGradiente;

  const _SaaSMetricCard({required this.titulo, required this.valor, required this.icone, required this.coresGradiente});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: coresGradiente, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: coresGradiente[0].withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(right: -20, bottom: -20, child: Icon(icone, size: 130, color: Colors.white.withOpacity(0.15))),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icone, color: Colors.white, size: 24)),
                  const Spacer(),
                  Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.9))),
                  const SizedBox(height: 4),
                  Text(valor, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET DO FORMULÁRIO DE NOVA ESCOLA
// ============================================================================
class _FormularioNovaEscolaDialog extends StatefulWidget {
  final int quantidadeAtual;
  final Function(Map<String, dynamic> novaEscola, String senhaPadrao) aoSalvar;

  const _FormularioNovaEscolaDialog({required this.quantidadeAtual, required this.aoSalvar});

  @override
  State<_FormularioNovaEscolaDialog> createState() => _FormularioNovaEscolaDialogState();
}

class _FormularioNovaEscolaDialogState extends State<_FormularioNovaEscolaDialog> {
  final _formKey = GlobalKey<FormState>();

  final _cnpjMask = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  final _telMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  XFile? _logoSelecionada;
  final ImagePicker _picker = ImagePicker();

  final _nomeCtrl = TextEditingController();
  final _subdominioCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();

  String _planoSelecionado = 'Básico';
  
  // Cor padrão inicial
  Color _corSelecionada = Colors.blue.shade800;

  @override
  void dispose() {
    _nomeCtrl.dispose(); _subdominioCtrl.dispose(); _cnpjCtrl.dispose();
    _telefoneCtrl.dispose(); _emailCtrl.dispose(); _sloganCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherLogo() async {
    final XFile? imagem = await _picker.pickImage(source: ImageSource.gallery);
    if (imagem != null) setState(() => _logoSelecionada = imagem);
  }

  // ==================================================================
  // NOVO MÉTODO: ABRE O SELETOR DE CORES AVANÇADO
  // ==================================================================
  void _abrirSeletorDeCores() {
    Color corTemporaria = _corSelecionada;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Selecione a Cor da Escola'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _corSelecionada,
              onColorChanged: (Color cor) {
                corTemporaria = cor;
              },
              colorPickerWidth: 300,
              pickerAreaHeightPercent: 0.7,
              enableAlpha: false, // Desativa a barra de transparência (não precisamos pro sistema)
              displayThumbColor: true,
              labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb], // Mostra os campos Hexadecimal e RGB para digitar!
              paletteType: PaletteType.hsvWithHue, // Estilo clássico (espectro grande)
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF080E1C), foregroundColor: Colors.white),
              onPressed: () {
                setState(() => _corSelecionada = corTemporaria);
                Navigator.pop(ctx);
              },
              child: const Text('Confirmar Cor'),
            ),
          ],
        );
      },
    );
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      final novoNumero = widget.quantidadeAtual + 1;
      final idGerado = 'ESC-${novoNumero.toString().padLeft(4, '0')}';
      const senhaPadrao = 'Domex@123';

      final novaEscola = {
        'id': idGerado,
        'nome': _nomeCtrl.text,
        'subdominio': _subdominioCtrl.text,
        'cnpj': _cnpjCtrl.text,
        'telefone': _telefoneCtrl.text,
        'email': _emailCtrl.text,
        'slogan': _sloganCtrl.text,
        'plano': _planoSelecionado,
        'status': 'Ativo',
        // Adicionando FF para garantir que o formato no Firestore inclua Alpha 100% (ARGB)
        'corHex': 'FF${_corSelecionada.value.toRadixString(16).substring(2).toUpperCase()}', 
        'dataCriacao': DateTime.now().toIso8601String(), 
      };

      widget.aoSalvar(novaEscola, senhaPadrao);
      Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.domain_add_rounded, color: Color(0xFF080E1C)),
          SizedBox(width: 8),
          Text('Provisionar Nova Escola', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 600, 
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Preencha os dados oficiais. O ambiente será gerado automaticamente no Firebase.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _escolherLogo,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _logoSelecionada == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, color: Colors.grey.shade400, size: 32),
                                  const SizedBox(height: 8),
                                  const Text('Logo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb 
                                    ? Image.network(_logoSelecionada!.path, fit: BoxFit.cover)
                                    : Image.file(File(_logoSelecionada!.path), fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nomeCtrl,
                            decoration: const InputDecoration(labelText: 'Nome Fantasia', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _sloganCtrl,
                            decoration: const InputDecoration(labelText: 'Slogan (Opcional)', border: OutlineInputBorder()),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _subdominioCtrl,
                        decoration: const InputDecoration(labelText: 'Subdomínio', hintText: 'colegiogenesis', border: OutlineInputBorder(), prefixText: 'https://', suffixText: '.domexedu.com.br'),
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _cnpjCtrl, inputFormatters: [_cnpjMask], decoration: const InputDecoration(labelText: 'CNPJ (Opcional)', hintText: 'xx.xxx.xxx/xxxx-xx', border: OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: _telefoneCtrl, inputFormatters: [_telMask], decoration: const InputDecoration(labelText: 'Telefone de Contato', hintText: '(xx) xxxxx-xxxx', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(flex: 2, child: TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail da Administração (Login)', border: OutlineInputBorder()), validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null)),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _planoSelecionado,
                        decoration: const InputDecoration(labelText: 'Plano Assinado', border: OutlineInputBorder()),
                        items: ['Básico', 'Pro', 'Premium'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (v) => setState(() => _planoSelecionado = v!),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Text('Cor Primária do Ambiente (Branding):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                
                // ==========================================================
                // NOVO BOTÃO DE SELEÇÃO DE CORES
                // ==========================================================
                InkWell(
                  onTap: _abrirSeletorDeCores,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _corSelecionada,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Escolher Cor Personalizada',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.colorize_rounded, size: 20, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF080E1C), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed: _salvar,
          child: const Text('Criar Ambiente (Tenant)'),
        ),
      ],
    );
  }
}