import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/turma_provider.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

class AdminTurmaFormTela extends ConsumerStatefulWidget {
  final Map<String, dynamic>? turmaParaEditar;
  const AdminTurmaFormTela({super.key, this.turmaParaEditar});

  @override
  ConsumerState<AdminTurmaFormTela> createState() => _AdminTurmaFormTelaState();
}

class _AdminTurmaFormTelaState extends ConsumerState<AdminTurmaFormTela> {
  final _formKey = GlobalKey<FormState>();
  final _upperCase = UpperCaseTextFormatter();

  // Controladores
  final _nomeCustomizadoCtrl = TextEditingController();
  final _anoLetivoCtrl = TextEditingController(text: DateTime.now().year.toString());
  final _salaCtrl = TextEditingController();
  final _ordemCtrl = TextEditingController(text: '1');

  // Variáveis de Estado
  String? _turmaMecSelecionada;
  String? _turnoSelecionado;
  String? _statusSelecionado = 'FORMADA';

  // Listas de Opções
  final List<String> _turnos = ['MANHÃ', 'TARDE', 'NOITE', 'INTEGRAL'];
  final List<String> _statusOpcoes = ['FORMADA', 'EM FORMAÇÃO'];
  
  final List<String> _turmasMec = [
    'BERÇÁRIO', 'MATERNAL I', 'MATERNAL II', 'PRÉ-ESCOLA I', 'PRÉ-ESCOLA II',
    '1º ANO DO ENSINO FUNDAMENTAL', '2º ANO DO ENSINO FUNDAMENTAL', '3º ANO DO ENSINO FUNDAMENTAL',
    '4º ANO DO ENSINO FUNDAMENTAL', '5º ANO DO ENSINO FUNDAMENTAL', '6º ANO DO ENSINO FUNDAMENTAL',
    '7º ANO DO ENSINO FUNDAMENTAL', '8º ANO DO ENSINO FUNDAMENTAL', '9º ANO DO ENSINO FUNDAMENTAL',
    '1º ANO DO ENSINO MÉDIO', '2º ANO DO ENSINO MÉDIO', '3º ANO DO ENSINO MÉDIO',
    'OUTROS'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.turmaParaEditar != null) {
      final t = widget.turmaParaEditar!;
      
      // Lógica para saber se o nome salvo é padrão MEC ou Customizado (Outros)
      final nomeSalvo = t['nome'] ?? '';
      if (_turmasMec.contains(nomeSalvo)) {
        _turmaMecSelecionada = nomeSalvo;
      } else {
        _turmaMecSelecionada = 'OUTROS';
        _nomeCustomizadoCtrl.text = nomeSalvo;
      }

      _anoLetivoCtrl.text = t['anoLetivo'] ?? '';
      _salaCtrl.text = t['sala'] ?? '';
      _ordemCtrl.text = (t['nivelOrdenacao'] ?? 1).toString();
      _turnoSelecionado = t['turno'];
      
      // Compatibilidade com o status novo
      final statusSalvo = t['status'] ?? 'FORMADA';
      _statusSelecionado = _statusOpcoes.contains(statusSalvo) ? statusSalvo : 'FORMADA';
    }
  }

  @override
  void dispose() {
    _nomeCustomizadoCtrl.dispose(); _anoLetivoCtrl.dispose(); _salaCtrl.dispose(); _ordemCtrl.dispose();
    super.dispose();
  }

  void _salvarTurma() async {
    if (_formKey.currentState!.validate()) {
      if (_turmaMecSelecionada == null || _turnoSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha os campos obrigatórios.'), backgroundColor: Colors.red));
        return;
      }

      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.white)));

      try {
        final isEdicao = widget.turmaParaEditar != null;
        
        // Se for "OUTROS", pega o texto digitado. Se não, pega o valor do Dropdown MEC.
        final nomeFinal = _turmaMecSelecionada == 'OUTROS' ? _nomeCustomizadoCtrl.text.trim() : _turmaMecSelecionada!;

        String idParaSalvar = isEdicao 
            ? widget.turmaParaEditar!['id'] 
            : 'TURMA-${DateTime.now().millisecondsSinceEpoch}';

        final dados = {
          'id': idParaSalvar,
          'nome': nomeFinal,
          'anoLetivo': _anoLetivoCtrl.text,
          'turno': _turnoSelecionado,
          'sala': _salaCtrl.text,
          'nivelOrdenacao': int.tryParse(_ordemCtrl.text) ?? 99,
          'status': _statusSelecionado, // Agora salva como 'FORMADA' ou 'EM FORMAÇÃO'
          'dataCadastro': isEdicao ? widget.turmaParaEditar!['dataCadastro'] : DateTime.now().toIso8601String(),
        };

        await ref.read(turmaServiceProvider).salvarTurma(dados);

        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop(); // Fecha o loading
        context.pop(); // Volta pra tela de listagem
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turma salva com sucesso!'), backgroundColor: Colors.green));
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final isEdicao = widget.turmaParaEditar != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdicao ? 'Editar Turma' : 'Nova Turma'), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [Icon(Icons.meeting_room_rounded, color: corPrimaria), const SizedBox(width: 8), const Text('Dados da Turma', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                      const Divider(height: 32),
                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // DROPDOWN MEC
                          Expanded(
                            flex: 3, 
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Nome da Turma (Padrões MEC)', border: OutlineInputBorder()),
                              value: _turmaMecSelecionada,
                              items: _turmasMec.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setState(() => _turmaMecSelecionada = v),
                              validator: (v) => v == null ? 'Obrigatório' : null,
                            )
                          ),
                          const SizedBox(width: 16),
                          
                          // ANO LETIVO FORÇADO APENAS PARA NÚMEROS E 4 DÍGITOS
                          Expanded(
                            flex: 1, 
                            child: TextFormField(
                              controller: _anoLetivoCtrl, 
                              keyboardType: TextInputType.number, 
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly, // Apenas números
                                LengthLimitingTextInputFormatter(4) // Máximo de 4 caracteres
                              ],
                              decoration: const InputDecoration(labelText: 'Ano Letivo', border: OutlineInputBorder()), 
                              validator: (v) => (v == null || v.length < 4) ? 'Ano inválido' : null
                            )
                          ),
                        ],
                      ),
                      
                      // CAMPO CONDICIONAL PARA ABRIR APENAS SE FOR "OUTROS"
                      if (_turmaMecSelecionada == 'OUTROS') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                          child: TextFormField(
                            controller: _nomeCustomizadoCtrl,
                            inputFormatters: [_upperCase],
                            decoration: const InputDecoration(
                              labelText: 'Qual o nome desta turma extracurricular/customizada? (Ex: INGLÊS INTERMEDIÁRIO)', 
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder()
                            ),
                            validator: (v) => v!.isEmpty ? 'Informe o nome da turma' : null,
                          ),
                        )
                      ],

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Turno', border: OutlineInputBorder()),
                            value: _turnoSelecionado,
                            items: _turnos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _turnoSelecionado = v),
                            validator: (v) => v == null ? 'Obrigatório' : null,
                          )),
                          const SizedBox(width: 16),
                          
                          // SELECT PARA STATUS DA FORMAÇÃO
                          Expanded(child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Status da Turma', border: OutlineInputBorder()),
                            value: _statusSelecionado,
                            items: _statusOpcoes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _statusSelecionado = v),
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _salaCtrl, inputFormatters: [_upperCase], decoration: const InputDecoration(labelText: 'Sala / Local (Opcional)', border: OutlineInputBorder()))),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(controller: _ordemCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Ordem na Lista (1, 2, 3...)', hintText: 'Para ordenar no aplicativo', border: OutlineInputBorder()))),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: _salvarTurma,
                          icon: const Icon(Icons.check_rounded, color: Colors.white),
                          label: const Text('SALVAR TURMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      )
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