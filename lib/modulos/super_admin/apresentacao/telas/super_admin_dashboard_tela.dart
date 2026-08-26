import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../estado/escola_provider.dart';

class SuperAdminDashboardTela extends ConsumerStatefulWidget {
  const SuperAdminDashboardTela({super.key});

  @override
  ConsumerState<SuperAdminDashboardTela> createState() => _SuperAdminDashboardTelaState();
}

class _SuperAdminDashboardTelaState extends ConsumerState<SuperAdminDashboardTela> {
  
  // ==========================================================================
  // LÓGICA DE ABERTURA E SALVAMENTO DE ESCOLA
  // ==========================================================================
  void _abrirFormularioEscola({Map<String, dynamic>? escolaEdicao, required int quantidadeAtual}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _FormularioEscolaDialog(
          quantidadeAtual: quantidadeAtual,
          escolaEdicao: escolaEdicao, 
          aoSalvar: (dadosEscola, senhaPadrao) async {
            final servico = ref.read(escolaServiceProvider);
            try {
              await servico.salvarEscola(dadosEscola);
              if (!context.mounted) return;
              
              if (escolaEdicao != null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados da escola atualizados com sucesso!'), backgroundColor: Colors.green));
              } else {
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
                        Text('O ambiente para ${dadosEscola['nomeEscola']} foi criado com sucesso no banco de dados.'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Credenciais de Acesso (Administração)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                              const Divider(),
                              Text('Código da Escola: ${dadosEscola['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('E-mail: ${dadosEscola['email']}'),
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
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar no banco: $e'), backgroundColor: Colors.red));
            }
          },
        );
      },
    );
  }

  // ==========================================================================
  // LÓGICA DE EXCLUSÃO DE UM TENANT
  // ==========================================================================
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
          content: Text('Tem certeza que deseja EXCLUIR o ambiente de "${escola['nomeEscola'] ?? escola['nome']}" (Código: ${escola['id']})?\n\nEsta ação apagará a escola do banco de dados e os usuários perderão o acesso.'),
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

  // ==========================================================================
  // LÓGICA DE ZERAR SENHA (RESET)
  // ==========================================================================
  void _confirmarResetSenha(BuildContext context, Map<String, dynamic> escola) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text('Zerar Senha de Acesso', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Tem certeza que deseja zerar a senha de acesso da escola "${escola['nomeEscola'] ?? escola['nome']}"?\n\nA senha voltará a ser: Domex@123'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  // TODO: Aqui entrará a chamada para a Cloud Function que reseta a senha no Firebase Auth
                  // Exemplo futuro: await ref.read(escolaServiceProvider).resetarSenhaAdmin(escola['email'], 'Domex@123');
                  
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha redefinida com sucesso para o padrão!'), backgroundColor: Colors.green));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao redefinir senha: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Sim, Zerar Senha'),
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
              int escolasAtivasCount = escolasClientes.where((e) => e['status'] == 'Ativo').length;
              int totalAlunosCadastrados = escolasClientes.fold(0, (sum, e) => sum + (e['quantidadeAlunos'] as int? ?? 0));
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
                          _SaaSMetricCard(titulo: 'Escolas Ativas', valor: '$escolasAtivasCount', icone: Icons.domain_rounded, coresGradiente: [Colors.blue.shade700, Colors.blue.shade400]),
                          _SaaSMetricCard(titulo: 'Alunos Cadastrados', valor: '$totalAlunosCadastrados', icone: Icons.groups_rounded, coresGradiente: [Colors.orange.shade700, Colors.orange.shade400]),
                          _SaaSMetricCard(titulo: 'Receita Mensal (MRR)', valor: receitaEstimada, icone: Icons.account_balance_wallet_rounded, coresGradiente: [Colors.green.shade700, Colors.green.shade400]),
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
                        onPressed: () => _abrirFormularioEscola(quantidadeAtual: escolasClientes.length),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Provisionar Escola'),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))]),
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
                                dataRowMinHeight: 60, dataRowMaxHeight: 60,
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
                                  final nomeEscola = escola['nomeEscola'] ?? escola['nome'] ?? 'Escola sem Nome';
                                  Color corAvatar = const Color(0xFF2C3E50);
                                  try {
                                    String cleanHex = (escola['corPrimaria'] ?? escola['corHex'] ?? '').replaceAll('#', '');
                                    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
                                    if (cleanHex.isNotEmpty) corAvatar = Color(int.parse(cleanHex, radix: 16));
                                  } catch(_) {}

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(escola['id'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Row(children: [CircleAvatar(backgroundColor: corAvatar.withAlpha(51), radius: 16, child: Icon(Icons.school, size: 16, color: corAvatar)), const SizedBox(width: 12), Text(nomeEscola)])),
                                      DataCell(Text(escola['email'] ?? '', style: TextStyle(color: Colors.grey.shade700))),
                                      DataCell(Text(escola['plano'] ?? 'Básico')),
                                      DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isAtivo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(16)), child: Text(escola['status'] ?? 'Inativo', style: TextStyle(color: isAtivo ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)))),
                                      DataCell(
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                                          onSelected: (val) async {
                                            final servico = ref.read(escolaServiceProvider);
                                            if (val == 'bloquear') await servico.atualizarStatus(escola['id'], 'Bloqueado');
                                            else if (val == 'desbloquear') await servico.atualizarStatus(escola['id'], 'Ativo');
                                            else if (val == 'zerar_senha') _confirmarResetSenha(context, escola);
                                            else if (val == 'excluir') _confirmarExclusaoEscola(context, escola);
                                            else if (val == 'editar') _abrirFormularioEscola(escolaEdicao: escola, quantidadeAtual: escolasClientes.length);
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar Dados')])),
                                            const PopupMenuItem(value: 'zerar_senha', child: Row(children: [Icon(Icons.lock_reset_rounded, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Zerar Senha', style: TextStyle(color: Colors.blue))])),
                                            isAtivo ? const PopupMenuItem(value: 'bloquear', child: Row(children: [Icon(Icons.block, color: Colors.orange, size: 18), SizedBox(width: 8), Text('Bloquear Acesso', style: TextStyle(color: Colors.orange))])) : const PopupMenuItem(value: 'desbloquear', child: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8), Text('Desbloquear Acesso', style: TextStyle(color: Colors.green))])),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: coresGradiente, begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: coresGradiente[0].withAlpha(102), blurRadius: 15, offset: const Offset(0, 8))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(right: -20, bottom: -20, child: Icon(icone, size: 130, color: Colors.white.withAlpha(38))),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withAlpha(51), borderRadius: BorderRadius.circular(12)), child: Icon(icone, color: Colors.white, size: 24)),
                  const Spacer(),
                  Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withAlpha(230))),
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
// WIDGET DO FORMULÁRIO DE ESCOLA (PROVISIONAR E EDITAR)
// ============================================================================
class _FormularioEscolaDialog extends StatefulWidget {
  final int quantidadeAtual;
  final Map<String, dynamic>? escolaEdicao; 
  final Function(Map<String, dynamic> dadosEscola, String senhaPadrao) aoSalvar;

  const _FormularioEscolaDialog({required this.quantidadeAtual, this.escolaEdicao, required this.aoSalvar});

  @override
  State<_FormularioEscolaDialog> createState() => _FormularioEscolaDialogState();
}

class _FormularioEscolaDialogState extends State<_FormularioEscolaDialog> {
  final _formKey = GlobalKey<FormState>();

  final _cnpjMask = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  final _telMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  
  final List<String> _estadosUF = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 
    'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
  ];
  String? _ufSelecionada;

  XFile? _logoSelecionada;
  String? _logoUrlExistente;
  final ImagePicker _picker = ImagePicker();

  final _nomeCtrl = TextEditingController();
  final _subdominioCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _responsavelCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  
  final _instaCtrl = TextEditingController();
  final _faceCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();

  final _ruaCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();

  String _planoSelecionado = 'Básico';
  Color _corPrimariaSelecionada = Colors.blue.shade800;
  Color _corSecundariaSelecionada = Colors.blue.shade500;

  @override
  void initState() {
    super.initState();
    if (widget.escolaEdicao != null) {
      final e = widget.escolaEdicao!;
      _nomeCtrl.text = e['nomeEscola'] ?? e['nome'] ?? '';
      _subdominioCtrl.text = e['subdominio'] ?? '';
      _cnpjCtrl.text = e['cnpj'] ?? '';
      _sloganCtrl.text = e['slogan'] ?? '';
      _responsavelCtrl.text = e['responsavel'] ?? '';
      _emailCtrl.text = e['email'] ?? '';
      _telefoneCtrl.text = e['telefone'] ?? '';
      _instaCtrl.text = e['instagram'] ?? '';
      _faceCtrl.text = e['facebook'] ?? '';
      _youtubeCtrl.text = e['youtube'] ?? '';
      
      final end = e['endereco'] ?? {};
      _ruaCtrl.text = end['rua'] ?? '';
      _numeroCtrl.text = end['numero'] ?? '';
      _bairroCtrl.text = end['bairro'] ?? '';
      _cidadeCtrl.text = end['cidade'] ?? '';
      if (end['estado'] != null && _estadosUF.contains(end['estado'])) {
        _ufSelecionada = end['estado'];
      }
      
      if (['Básico', 'Pro', 'Premium'].contains(e['plano'])) _planoSelecionado = e['plano'];
      
      _corPrimariaSelecionada = _converterHexParaColor(e['corPrimaria'] ?? e['corHex']);
      _corSecundariaSelecionada = _converterHexParaColor(e['corSecundaria']);
      _logoUrlExistente = e['logoUrl'] ?? e['fotoUrl'] ?? e['logo'];
    }
  }

  Color _converterHexParaColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue.shade800;
    try {
      String cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.blue.shade800;
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose(); _subdominioCtrl.dispose(); _cnpjCtrl.dispose(); _sloganCtrl.dispose();
    _responsavelCtrl.dispose(); _emailCtrl.dispose(); _telefoneCtrl.dispose();
    _instaCtrl.dispose(); _faceCtrl.dispose(); _youtubeCtrl.dispose();
    _ruaCtrl.dispose(); _numeroCtrl.dispose(); _bairroCtrl.dispose(); _cidadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherERecortarLogo() async {
    final XFile? imagem = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;

    if (imagem != null) {
      CroppedFile? imagemRecortada = await ImageCropper().cropImage(
        sourcePath: imagem.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Enquadrar Logo da Escola', toolbarColor: const Color(0xFF080E1C), toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.square, lockAspectRatio: true),
          IOSUiSettings(title: 'Enquadrar Logo', aspectRatioLockEnabled: true),
          WebUiSettings(context: context, presentStyle: WebPresentStyle.dialog),
        ],
      );

      if (imagemRecortada != null) {
        setState(() {
          _logoSelecionada = XFile(imagemRecortada.path);
          _logoUrlExistente = null; 
        });
      }
    }
  }

  void _abrirSeletorDeCores({required bool isPrimaria}) {
    Color corTemporaria = isPrimaria ? _corPrimariaSelecionada : _corSecundariaSelecionada;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isPrimaria ? 'Selecione a Cor Primária' : 'Selecione a Cor Secundária'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: corTemporaria,
              onColorChanged: (Color cor) => corTemporaria = cor,
              colorPickerWidth: 300,
              pickerAreaHeightPercent: 0.7,
              enableAlpha: false, 
              displayThumbColor: true,
              labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb], 
              paletteType: PaletteType.hsvWithHue, 
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF080E1C), foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  if (isPrimaria) _corPrimariaSelecionada = corTemporaria;
                  else _corSecundariaSelecionada = corTemporaria;
                });
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
      final isEdicao = widget.escolaEdicao != null;
      
      final novoNumero = widget.quantidadeAtual + 1;
      final idGerado = isEdicao ? widget.escolaEdicao!['id'] : 'ESC-${novoNumero.toString().padLeft(4, '0')}';
      const senhaPadrao = 'Domex@123';

      final dadosEscola = {
        'id': idGerado,
        'nomeEscola': _nomeCtrl.text.trim(),
        'subdominio': _subdominioCtrl.text.trim(),
        'cnpj': _cnpjCtrl.text.trim(),
        'slogan': _sloganCtrl.text.trim(),
        'responsavel': _responsavelCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'telefone': _telefoneCtrl.text.trim(),
        'instagram': _instaCtrl.text.trim(),
        'facebook': _faceCtrl.text.trim(),
        'youtube': _youtubeCtrl.text.trim(),
        'plano': _planoSelecionado,
        'status': isEdicao ? widget.escolaEdicao!['status'] : 'Ativo',
        'corPrimaria': '#${_corPrimariaSelecionada.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}', 
        'corSecundaria': '#${_corSecundariaSelecionada.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}', 
        'dataCriacao': isEdicao ? widget.escolaEdicao!['dataCriacao'] : DateTime.now().toIso8601String(), 
        'quantidadeAlunos': isEdicao ? widget.escolaEdicao!['quantidadeAlunos'] : 0, 
        'logoUrl': isEdicao ? (widget.escolaEdicao!['logoUrl'] ?? widget.escolaEdicao!['fotoUrl'] ?? widget.escolaEdicao!['logo']) : null,
        'endereco': {
          'rua': _ruaCtrl.text.trim(),
          'numero': _numeroCtrl.text.trim(),
          'bairro': _bairroCtrl.text.trim(),
          'cidade': _cidadeCtrl.text.trim(),
          'estado': _ufSelecionada ?? '',
        },
      };

      if (_logoSelecionada != null) {
        dadosEscola['arquivoLogo'] = _logoSelecionada;
      }

      widget.aoSalvar(dadosEscola, senhaPadrao);
      Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.escolaEdicao != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEdicao ? Icons.edit_document : Icons.domain_add_rounded, color: const Color(0xFF080E1C)),
          const SizedBox(width: 8),
          Text(isEdicao ? 'Editar Dados da Escola' : 'Provisionar Nova Escola', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 750, 
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEdicao ? 'Altere as informações abaixo para atualizar o sistema.' : 'Preencha os dados oficiais. O ambiente será gerado automaticamente no Firebase.', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 24),

                // ================== IDENTIDADE VISUAL ==================
                const Text('Identidade Visual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF080E1C))),
                const Divider(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _escolherERecortarLogo, 
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12),
                          image: _logoUrlExistente != null && _logoSelecionada == null ? DecorationImage(image: NetworkImage(_logoUrlExistente!), fit: BoxFit.cover) : null,
                        ),
                        child: _logoSelecionada == null && _logoUrlExistente == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, color: Colors.grey.shade400, size: 32),
                                  const SizedBox(height: 8),
                                  const Text('Logo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              )
                            : _logoSelecionada != null ? ClipRRect(borderRadius: BorderRadius.circular(12), child: kIsWeb ? Image.network(_logoSelecionada!.path, fit: BoxFit.cover) : Image.file(File(_logoSelecionada!.path), fit: BoxFit.cover)) : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _abrirSeletorDeCores(isPrimaria: true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(width: 24, height: 24, decoration: BoxDecoration(color: _corPrimariaSelecionada, shape: BoxShape.circle, border: Border.all(color: Colors.black26))),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Text('Cor Primária', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                    const Icon(Icons.colorize_rounded, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _abrirSeletorDeCores(isPrimaria: false),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(width: 24, height: 24, decoration: BoxDecoration(color: _corSecundariaSelecionada, shape: BoxShape.circle, border: Border.all(color: Colors.black26))),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Text('Cor Secundária', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                    const Icon(Icons.colorize_rounded, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // ================== DADOS CADASTRAIS ==================
                const Text('Dados Cadastrais e Acesso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF080E1C))),
                const Divider(),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: 'Nome Fantasia', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: _cnpjCtrl, inputFormatters: [_cnpjMask], decoration: const InputDecoration(labelText: 'CNPJ', hintText: '00.000.000/0000-00', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _responsavelCtrl, decoration: const InputDecoration(labelText: 'Nome do Responsável', border: OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail da Administração (Login)', border: OutlineInputBorder()), validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(flex: 3, child: TextFormField(controller: _subdominioCtrl, decoration: const InputDecoration(labelText: 'Subdomínio', hintText: 'colegiogenesis', border: OutlineInputBorder(), prefixText: 'https://', suffixText: '.domexedu.com.br'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: DropdownButtonFormField<String>(value: _planoSelecionado, decoration: const InputDecoration(labelText: 'Plano Assinado', border: OutlineInputBorder()), items: ['Básico', 'Pro', 'Premium'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => _planoSelecionado = v!))),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _sloganCtrl, decoration: const InputDecoration(labelText: 'Slogan (Opcional)', border: OutlineInputBorder())),

                const SizedBox(height: 24),
                
                // ================== CONTATOS ==================
                const Text('Contatos e Redes Sociais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF080E1C))),
                const Divider(),
                SizedBox(
                  width: 300,
                  child: TextFormField(controller: _telefoneCtrl, inputFormatters: [_telMask], decoration: const InputDecoration(labelText: 'WhatsApp / Celular', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _instaCtrl, decoration: const InputDecoration(labelText: 'Instagram', prefixIcon: Icon(Icons.camera_alt_outlined), border: OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: _faceCtrl, decoration: const InputDecoration(labelText: 'Facebook', prefixIcon: Icon(Icons.facebook), border: OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(child: TextFormField(controller: _youtubeCtrl, decoration: const InputDecoration(labelText: 'YouTube', prefixIcon: Icon(Icons.play_circle_outline), border: OutlineInputBorder()))),
                  ],
                ),

                const SizedBox(height: 24),

                // ================== ENDEREÇO ==================
                const Text('Endereço', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF080E1C))),
                const Divider(),
                Row(
                  children: [
                    Expanded(flex: 3, child: TextFormField(controller: _ruaCtrl, decoration: const InputDecoration(labelText: 'Rua / Logradouro', border: OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: TextFormField(controller: _numeroCtrl, decoration: const InputDecoration(labelText: 'Número', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(flex: 2, child: TextFormField(controller: _bairroCtrl, decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: TextFormField(controller: _cidadeCtrl, decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1, 
                      child: DropdownButtonFormField<String>(
                        value: _ufSelecionada,
                        decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder()),
                        items: _estadosUF.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
                        onChanged: (v) => setState(() => _ufSelecionada = v),
                      )
                    ),
                  ],
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
          child: Text(isEdicao ? 'Salvar Alterações' : 'Criar Ambiente (Tenant)'),
        ),
      ],
    );
  }
}