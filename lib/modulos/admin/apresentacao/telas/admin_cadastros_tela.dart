import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/turma_provider.dart';

class AdminCadastrosTela extends ConsumerStatefulWidget {
  const AdminCadastrosTela({super.key});

  @override
  ConsumerState<AdminCadastrosTela> createState() => _AdminCadastrosTelaState();
}

class _AdminCadastrosTelaState extends ConsumerState<AdminCadastrosTela> {
  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;

    return DefaultTabController(
      length: 4, 
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 1,
          title: const Text('Central de Cadastros', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelColor: corPrimaria, unselectedLabelColor: Colors.grey, indicatorColor: corPrimaria, indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.school_rounded), text: 'Alunos'),
              Tab(icon: Icon(Icons.assignment_ind_rounded), text: 'Professores'),
              Tab(icon: Icon(Icons.meeting_room_rounded), text: 'Turmas'),
              Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Usuários'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GestaoAlunosAba(),
            _GestaoProfessoresAba(),
            _GestaoTurmasAba(),
            _VisualizacaoTabela(titulo: 'Usuários Administrativos', colunas: ['ID', 'Nome', 'E-mail', 'Nível de Acesso'], dadosSimulados: []),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 1. COMPONENTE DA ABA DE ALUNOS 
// ============================================================================
class _GestaoAlunosAba extends ConsumerStatefulWidget {
  const _GestaoAlunosAba();

  @override
  ConsumerState<_GestaoAlunosAba> createState() => _GestaoAlunosAbaState();
}

class _GestaoAlunosAbaState extends ConsumerState<_GestaoAlunosAba> {
  String _termoBusca = '';

  void _confirmarExclusao(BuildContext context, Map<String, dynamic> aluno) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Atenção: Excluir Matrícula', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
          content: Text('Tem certeza que deseja apagar definitivamente o registro de ${aluno['nome']} (Matrícula: ${aluno['matricula']})?\n\nEsta ação não poderá ser desfeita.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await ref.read(alunoServiceProvider).excluirAluno(aluno['matricula']);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Matrícula excluída permanentemente.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Sim, Excluir Aluno'),
            ),
          ],
        );
      },
    );
  }

  // --- ZOOM NA FOTO ---
  void _mostrarFotoAmpliada(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(url, fit: BoxFit.contain))),
            Positioned(top: 16, right: 16, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 32), onPressed: () => Navigator.pop(ctx))),
          ],
        ),
      ),
    );
  }

// --- GERAR E IMPRIMIR PDF (FORMATO BLOCOS) ---
  Future<void> _gerarEImprimirPdf(Map<String, dynamic> aluno) async {
    final doc = pw.Document();

    // 1. Tenta baixar a foto do aluno
    pw.ImageProvider? fotoAluno;
    if (aluno['fotoUrl'] != null) {
      try {
        fotoAluno = await networkImage(aluno['fotoUrl']);
      } catch (e) {
        debugPrint('Erro ao carregar foto pro PDF: $e');
      }
    }

    // 2. Formatador de Linhas (Mais compacto para caber nos blocos)
    pw.Widget pdfLinha(String label, dynamic valorRaw) {
      final valor = (valorRaw?.toString() ?? '').trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey800)),
            pw.Expanded(child: pw.Text(valor.isEmpty ? 'Não informado' : valor, style: const pw.TextStyle(fontSize: 9))),
          ]
        )
      );
    }

    // 3. NOVO: Construtor de Blocos (Cards)
    pw.Widget pdfBloco(String titulo, pw.Widget conteudo) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho do Bloco
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
              ),
              child: pw.Text(titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue800)),
            ),
            // Conteúdo do Bloco
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: conteudo,
            ),
          ]
        ),
      );
    }

    // 4. Preparando Variáveis Seguras
    final agora = DateTime.now();
    final dataHora = "${agora.day.toString().padLeft(2,'0')}/${agora.month.toString().padLeft(2,'0')}/${agora.year} às ${agora.hour.toString().padLeft(2,'0')}:${agora.minute.toString().padLeft(2,'0')}";
    
    final responsaveis = aluno['responsaveis'] as List? ?? [];
    final autorizados = aluno['pessoasAutorizadas'] as List? ?? [];
    final emergencia = aluno['emergencia'] as List? ?? [];
    
    final end = aluno['endereco'] ?? {};
    final med = aluno['fichaMedica'] ?? {};
    
    final orgao = aluno['orgaoExpedidor']?.toString().trim() ?? '';
    final rgFormatado = '${aluno['rg'] ?? ''} ${orgao.isNotEmpty ? '($orgao)' : ''}'.trim();
    final natFormatada = '${aluno['naturalidade'] ?? ''} / ${aluno['estadoNaturalidade'] ?? ''}'.trim();
    final endLogradouro = '${end['rua'] ?? ''}, Nº ${end['numero'] ?? ''}'.trim();
    final endCidade = '${end['cidade'] ?? ''} - ${end['estado'] ?? ''}'.trim();

    // 5. Montando o Documento
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- CABEÇALHO DA ESCOLA ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ESCOLA CONEXÃO', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700)),
                      pw.Text('Educação que transforma o futuro', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ]
                  ),
                  pw.Text('FICHA CADASTRAL DO ALUNO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                ]
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 2, color: PdfColors.orange700),
              pw.SizedBox(height: 12),

              // --- CORPO DA FICHA EM BLOCOS ---
              pw.Expanded(
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.topLeft,
                  child: pw.Container(
                    width: PdfPageFormat.a4.availableWidth,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        
                        // BLOCO 1: DADOS PESSOAIS E ACADÊMICOS
                        pdfBloco('DADOS PESSOAIS E ACADÊMICOS', pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 80, height: 100,
                              decoration: pw.BoxDecoration(color: PdfColors.grey200, border: pw.Border.all(color: PdfColors.grey400)),
                              child: fotoAluno != null ? pw.Image(fotoAluno, fit: pw.BoxFit.cover) : pw.Center(child: pw.Text('Sem Foto', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pdfLinha('Nome', aluno['nome']),
                                  pw.Row(children: [ pw.Expanded(child: pdfLinha('Matrícula', aluno['matricula'])), pw.Expanded(child: pdfLinha('R.A.', aluno['ra'])) ]),
                                  pw.Row(children: [ pw.Expanded(child: pdfLinha('Nascimento', aluno['dataNascimento'])), pw.Expanded(child: pdfLinha('Sexo', aluno['sexo'])) ]),
                                  pw.Row(children: [ pw.Expanded(child: pdfLinha('Celular', aluno['telefone'])), pw.Expanded(child: pdfLinha('CPF', aluno['cpf'])) ]),
                                  pw.Row(children: [ pw.Expanded(child: pdfLinha('RG', rgFormatado)), pw.Expanded(child: pdfLinha('Naturalidade', natFormatada)) ]),
                                  pw.SizedBox(height: 4),
                                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                                  pw.SizedBox(height: 4),
                                  pw.Row(children: [ pw.Expanded(child: pdfLinha('Turma', aluno['turma'])), pw.Expanded(child: pdfLinha('Irmão na Escola', aluno['temIrmao'] == true ? 'SIM - ${aluno['irmaoSelecionado']}' : 'NÃO')) ]),
                                ]
                              )
                            )
                          ]
                        )),

                        // BLOCO 2: ENDEREÇO
                        pdfBloco('ENDEREÇO', pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(children: [ pw.Expanded(flex: 3, child: pdfLinha('Logradouro', endLogradouro)), pw.Expanded(flex: 2, child: pdfLinha('Bairro', end['bairro'])) ]),
                            pw.Row(children: [ pw.Expanded(flex: 3, child: pdfLinha('Cidade/UF', endCidade)), pw.Expanded(flex: 2, child: pdfLinha('Referência', end['referencia'])) ]),
                          ]
                        )),

                        // BLOCOS LADO A LADO: RESPONSÁVEIS E AUTORIZADOS
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pdfBloco('RESPONSÁVEIS', pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  if (responsaveis.isNotEmpty)
                                    ...responsaveis.map((r) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                      pdfLinha('Nome', r['nome']),
                                      pw.Row(children: [ pw.Expanded(child: pdfLinha('CPF', r['cpf'])), pw.Expanded(child: pdfLinha('Tel', r['telefone'])) ]),
                                    ]))),
                                  pdfLinha('Autoriza sair sozinho', aluno['autorizaSairSo'] == true ? 'SIM' : 'NÃO'),
                                ]
                              ))
                            ),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                              child: pdfBloco('AUTORIZADOS A BUSCAR', pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  if (autorizados.isNotEmpty) ...autorizados.map((p) => pdfLinha('Nome', '${p['nome']} (Tel: ${p['telefone']})')) else pdfLinha('Autorizados', 'Nenhum cadastrado'),
                                ]
                              ))
                            )
                          ]
                        ),

                        // BLOCOS LADO A LADO: SAÚDE E EMERGÊNCIA
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pdfBloco('INFORMAÇÕES MÉDICAS', pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(children: [ pw.Expanded(child: pdfLinha('Sangue', med['tipoSanguineo'])), pw.Expanded(child: pdfLinha('Problema', med['temProblema'] == true ? med['problema'] : 'NÃO')) ]),
                                  pw.Row(children: [ pw.Expanded(child: pdfLinha('Remédio', med['tomaRemedio'] == true ? med['remedio'] : 'NÃO')), pw.Expanded(child: pdfLinha('Alergia', med['temAlergia'] == true ? med['alergia'] : 'NÃO')) ]),
                                  pdfLinha('Observações', med['observacoes']),
                                ]
                              ))
                            ),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                              child: pdfBloco('CONTATOS DE EMERGÊNCIA', pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  if (emergencia.isNotEmpty) ...emergencia.map((e) => pdfLinha('Nome', '${e['nome']} (Tel: ${e['telefone']})')) else pdfLinha('Contatos', 'Nenhum cadastrado'),
                                ]
                              ))
                            )
                          ]
                        ),
                        
                      ]
                    )
                  )
                )
              ),

              // --- RODAPÉ ---
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Ficha cadastral gerada pelo sistema de gestão escolar Domex Edu - $dataHora', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
            ]
          );
        }
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Ficha_${aluno['matricula']}.pdf');
  }

  Widget _buildSecao(IconData icone, String titulo, Color cor) {
    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Row(children: [Icon(icone, size: 20, color: cor), const SizedBox(width: 8), Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cor))]));
  }

  Widget _buildLinha(String label, dynamic valorRaw) {
    final valor = (valorRaw?.toString() ?? '').trim();
    return Padding(padding: const EdgeInsets.only(bottom: 6.0), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: valor.isEmpty ? 'Não informado' : valor)])));
  }

// --- BOTÕES MÁGICOS DE WHATSAPP E TELEFONE COM A SUA LOGO ---
  Widget _buildLinhaTelefone(String label, dynamic valorRaw) {
    final telefone = (valorRaw?.toString() ?? '').trim();
    final numeroLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
          Text(telefone.isEmpty ? 'Não informado' : telefone, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          if (numeroLimpo.length >= 10) ...[
            const SizedBox(width: 8),
            // Botão do WhatsApp usando a sua imagem
            Tooltip(
              message: 'Abrir WhatsApp',
              child: InkWell(
                onTap: () => launchUrl(Uri.parse('https://wa.me/55$numeroLimpo')),
                child: Image.asset('assets/whatsapp.png', width: 18, height: 18), // AQUI ESTÁ SUA LOGO!
              ),
            ),
            const SizedBox(width: 12),
            // Botão de Ligação (mantido o padrão)
            Tooltip(
              message: 'Ligar',
              child: InkWell(
                onTap: () => launchUrl(Uri.parse('tel:$numeroLimpo')),
                child: const Icon(Icons.phone, color: Colors.blue, size: 18),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // --- MODAL DA FICHA CADASTRAL COMPLETA ---
  void _abrirFichaAluno(BuildContext context, Map<String, dynamic> aluno) {
    final corPrimaria = Theme.of(context).primaryColor;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.all(0),
          title: Container(
            padding: const EdgeInsets.all(24),
            // CORREÇÃO: Usando withAlpha(13) que equivale a 0.05 de opacidade sem dar erro de versão
            decoration: BoxDecoration(color: corPrimaria.withAlpha(13), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              children: [
                InkWell(
                  onTap: aluno['fotoUrl'] != null ? () => _mostrarFotoAmpliada(context, aluno['fotoUrl']) : null,
                  child: CircleAvatar(radius: 32, backgroundColor: Colors.white, backgroundImage: aluno['fotoUrl'] != null ? NetworkImage(aluno['fotoUrl']) : null, child: aluno['fotoUrl'] == null ? Icon(Icons.person, size: 32, color: corPrimaria) : null),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(aluno['nome'] ?? 'Aluno', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), const SizedBox(height: 4), Text('Matrícula: ${aluno['matricula']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14))])),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          content: SizedBox(
            width: 800,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSecao(Icons.person_rounded, 'Dados Pessoais', corPrimaria),
                              _buildLinha('R.A.', aluno['ra']),
                              _buildLinha('Nascimento', aluno['dataNascimento']),
                              _buildLinha('Sexo', aluno['sexo']),
                              _buildLinhaTelefone('Celular', aluno['telefone']),
                              _buildLinha('CPF', aluno['cpf']),
                              _buildLinha('RG', '${aluno['rg'] ?? ''} ${aluno['orgaoExpedidor'] != null && aluno['orgaoExpedidor'].toString().isNotEmpty ? '(${aluno['orgaoExpedidor']})' : ''}'),
                              _buildLinha('Naturalidade', '${aluno['naturalidade'] ?? ''} / ${aluno['estadoNaturalidade'] ?? ''}'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSecao(Icons.school_rounded, 'Acadêmico', corPrimaria),
                              _buildLinha('Turma', aluno['turma']),
                              _buildLinha('Status', aluno['status']),
                              _buildLinha('Irmão(ã)', aluno['temIrmao'] == true ? 'SIM - ${aluno['irmaoSelecionado']}' : 'NÃO'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSecao(Icons.family_restroom_rounded, 'Responsáveis e Endereço', corPrimaria),
                              if (aluno['responsaveis'] != null)
                                ...(aluno['responsaveis'] as List).map((r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLinha('Nome', r['nome']),
                                      _buildLinha('CPF', r['cpf']),
                                      _buildLinhaTelefone('Tel', r['telefone']),
                                      _buildLinha('E-mail', r['email']),
                                      const SizedBox(height: 4),
                                    ],
                                  )
                                )),
                              const SizedBox(height: 8),
                              _buildLinha('Endereço', '${aluno['endereco']?['rua'] ?? ''}, ${aluno['endereco']?['numero'] ?? ''} - ${aluno['endereco']?['bairro'] ?? ''} - ${aluno['endereco']?['cidade'] ?? ''} / ${aluno['endereco']?['estado'] ?? ''}'),
                              _buildLinha('Referência', aluno['endereco']?['referencia']),
                              _buildLinha('Autorizado sair sozinho?', aluno['autorizaSairSo'] == true ? 'SIM' : 'NÃO'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSecao(Icons.badge_rounded, 'Autorizados a Buscar', Colors.deepPurple),
                              if (aluno['pessoasAutorizadas'] != null && (aluno['pessoasAutorizadas'] as List).isNotEmpty)
                                ...(aluno['pessoasAutorizadas'] as List).map((p) => _buildLinhaTelefone(p['nome'] ?? 'Autorizado', p['telefone']))
                              else
                                const Text('Ninguém cadastrado.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSecao(Icons.medical_information_rounded, 'Ficha Médica', corPrimaria),
                              _buildLinha('Tipo Sanguíneo', aluno['fichaMedica']?['tipoSanguineo']),
                              _buildLinha('Problema de Saúde', aluno['fichaMedica']?['temProblema'] == true ? 'SIM: ${aluno['fichaMedica']?['problema']}' : 'NÃO'),
                              _buildLinha('Remédio', aluno['fichaMedica']?['tomaRemedio'] == true ? 'SIM: ${aluno['fichaMedica']?['remedio']}' : 'NÃO'),
                              _buildLinha('Alergia', aluno['fichaMedica']?['temAlergia'] == true ? 'SIM: ${aluno['fichaMedica']?['alergia']}' : 'NÃO'),
                              _buildLinha('Observações', aluno['fichaMedica']?['observacoes']),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSecao(Icons.emergency_rounded, 'Contatos de Emergência', Colors.red.shade400),
                              if (aluno['emergencia'] != null && (aluno['emergencia'] as List).isNotEmpty)
                                ...(aluno['emergencia'] as List).map((e) => _buildLinhaTelefone(e['nome'] ?? 'Emergência', e['telefone']))
                              else
                                const Text('Nenhum contato cadastrado.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.all(24),
          actions: [
            TextButton.icon(
              onPressed: () => _gerarEImprimirPdf(aluno),
              icon: const Icon(Icons.print_rounded, color: Colors.blue),
              label: const Text('Exportar PDF / Imprimir', style: TextStyle(color: Colors.blue)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar Ficha'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final estadoAlunos = ref.watch(alunosStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Alunos Matriculados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              SizedBox(width: 250, height: 40, child: TextField(onChanged: (value) => setState(() => _termoBusca = value), decoration: InputDecoration(hintText: 'Pesquisar nome ou matrícula...', prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(vertical: 0), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/admin/cadastros/aluno/novo'), 
                icon: const Icon(Icons.person_add_alt_1_rounded), 
                label: const Text('Nova Matrícula')
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: estadoAlunos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (erro, stack) => Center(child: Text('Erro ao carregar alunos: $erro')),
              data: (alunos) {
                final alunosFiltrados = alunos.where((aluno) {
                  final busca = _termoBusca.toLowerCase();
                  return aluno['nome'].toString().toLowerCase().contains(busca) || aluno['matricula'].toString().toLowerCase().contains(busca);
                }).toList();

                if (alunosFiltrados.isEmpty) return const Center(child: Text('Nenhum aluno encontrado.', style: TextStyle(color: Colors.grey)));

                return ListView.separated(
                  itemCount: alunosFiltrados.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final aluno = alunosFiltrados[index];
                    final isInadimplente = aluno['status'] == 'Inadimplente';

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isInadimplente ? Colors.red.shade200 : Colors.grey.shade300)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: aluno['fotoUrl'] != null ? () => _mostrarFotoAmpliada(context, aluno['fotoUrl']) : null,
                              borderRadius: BorderRadius.circular(24),
                              child: CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade200, backgroundImage: aluno['fotoUrl'] != null ? NetworkImage(aluno['fotoUrl']) : null, child: aluno['fotoUrl'] == null ? const Icon(Icons.person, color: Colors.grey) : null),
                            ),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(aluno['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text('Matrícula: ${aluno['matricula']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
                            Expanded(flex: 2, child: Text(aluno['turma'] ?? 'Sem turma', style: TextStyle(color: Colors.grey.shade700))),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isInadimplente ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16)), child: Text(aluno['status'] ?? 'Ativo', style: TextStyle(color: isInadimplente ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12))),
                            const SizedBox(width: 24),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.visibility_rounded, color: Colors.blueGrey), tooltip: 'Visualizar Ficha Completa', onPressed: () => _abrirFichaAluno(context, aluno)),
                                IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.blue), tooltip: 'Editar Matrícula', onPressed: () => context.push('/admin/cadastros/aluno/novo', extra: aluno)),
                                IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red), tooltip: 'Excluir Aluno', onPressed: () => _confirmarExclusao(context, aluno)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. COMPONENTE DA ABA DE PROFESSORES
// ============================================================================
class _GestaoProfessoresAba extends ConsumerStatefulWidget {
  const _GestaoProfessoresAba();
  @override
  ConsumerState<_GestaoProfessoresAba> createState() => _GestaoProfessoresAbaState();
}

class _GestaoProfessoresAbaState extends ConsumerState<_GestaoProfessoresAba> {
  String _termoBusca = '';

  void _confirmarExclusao(BuildContext context, Map<String, dynamic> professor) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Excluir Professor', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
          content: Text('Tem certeza que deseja apagar o registro de ${professor['nome']}?\n\nEsta ação não poderá ser desfeita.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await ref.read(professorServiceProvider).excluirProfessor(professor['id']);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Professor excluído.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Sim, Excluir'),
            ),
          ],
        );
      },
    );
  }

  // --- ZOOM NA FOTO DO PROFESSOR ---
  void _mostrarFotoAmpliada(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(url, fit: BoxFit.contain))),
            Positioned(top: 16, right: 16, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 32), onPressed: () => Navigator.pop(ctx))),
          ],
        ),
      ),
    );
  }

  // MODAL DA FICHA DO PROFESSOR
  void _abrirFichaProfessor(BuildContext context, Map<String, dynamic> prof) {
    final corPrimaria = Theme.of(context).primaryColor;
    
    Widget buildLinha(String label, dynamic valorRaw) {
      final valor = (valorRaw?.toString() ?? '').trim();
      return Padding(padding: const EdgeInsets.only(bottom: 6.0), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: valor.isEmpty ? 'Não informado' : valor)])));
    }

    Widget buildLinhaContato(String label, dynamic valorRaw) {
      final telefone = (valorRaw?.toString() ?? '').trim();
      final numeroLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');
      return Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
            Text(telefone.isEmpty ? 'Não informado' : telefone, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            if (numeroLimpo.length >= 10) ...[
              const SizedBox(width: 8),
              Tooltip(message: 'Abrir WhatsApp', child: InkWell(onTap: () => launchUrl(Uri.parse('https://wa.me/55$numeroLimpo')), child: Image.asset('assets/whatsapp.png', width: 18, height: 18))),
              const SizedBox(width: 12),
              Tooltip(message: 'Ligar', child: InkWell(onTap: () => launchUrl(Uri.parse('tel:$numeroLimpo')), child: const Icon(Icons.phone, color: Colors.blue, size: 18))),
            ]
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.all(0),
          title: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: corPrimaria.withAlpha(13), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              children: [
                InkWell(
                  onTap: prof['fotoUrl'] != null ? () => _mostrarFotoAmpliada(context, prof['fotoUrl']) : null,
                  borderRadius: BorderRadius.circular(32),
                  child: CircleAvatar(radius: 32, backgroundColor: Colors.white, backgroundImage: prof['fotoUrl'] != null ? NetworkImage(prof['fotoUrl']) : null, child: prof['fotoUrl'] == null ? Icon(Icons.assignment_ind_rounded, size: 32, color: corPrimaria) : null),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(prof['nome'] ?? 'Professor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), const SizedBox(height: 4), Text('ID: ${prof['id']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14))])),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DADOS PESSOAIS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            const Divider(),
                            buildLinha('CPF', prof['cpf']),
                            buildLinha('Nascimento', prof['dataNascimento']),
                            buildLinhaContato('Celular', prof['telefone']),
                            buildLinha('E-mail', prof['email']),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ATUAÇÃO PROFISSIONAL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            const Divider(),
                            buildLinha('Status', prof['status']),
                            const SizedBox(height: 4),
                            const Text('Disciplinas:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: (prof['disciplinas'] as List? ?? []).map((d) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)), child: Text(d.toString(), style: const TextStyle(fontSize: 11, color: Colors.blue)))).toList(),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('ENDEREÇO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const Divider(),
                  buildLinha('Logradouro', '${prof['endereco']?['rua'] ?? ''}, Nº ${prof['endereco']?['numero'] ?? ''}'),
                  buildLinha('Bairro/Cidade', '${prof['endereco']?['bairro'] ?? ''} - ${prof['endereco']?['cidade'] ?? ''}'),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.all(24),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar Ficha'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ESTA É A LINHA QUE ATIVA A CONEXÃO COM O FIREBASE!
    final estadoProfessores = ref.watch(professoresStreamProvider); 

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Professores Cadastrados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              SizedBox(width: 250, height: 40, child: TextField(onChanged: (value) => setState(() => _termoBusca = value), decoration: InputDecoration(hintText: 'Pesquisar professor...', prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(vertical: 0), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/admin/cadastros/professor/novo'), 
                icon: const Icon(Icons.person_add_alt_1_rounded), 
                label: const Text('Novo Professor')
              )
            ],
          ),
          const SizedBox(height: 24),
          
          // TABELA DEFINITIVA DOS PROFESSORES CONECTADA AO FIREBASE
          Expanded(
            child: estadoProfessores.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (erro, stack) => Center(child: Text('Erro ao carregar: $erro')),
              data: (professores) {
                final filtrados = professores.where((p) => p['nome'].toString().toLowerCase().contains(_termoBusca.toLowerCase())).toList();
                
                if (filtrados.isEmpty) return const Center(child: Text('Nenhum professor encontrado.'));

                return ListView.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final prof = filtrados[index];
                    final inativo = prof['status'] != 'Ativo';

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: inativo ? Colors.red.shade200 : Colors.grey.shade300)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            // ZOOM NA FOTO DIRETO NA TABELA
                            InkWell(
                              onTap: prof['fotoUrl'] != null ? () => _mostrarFotoAmpliada(context, prof['fotoUrl']) : null,
                              borderRadius: BorderRadius.circular(24),
                              child: CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade200, backgroundImage: prof['fotoUrl'] != null ? NetworkImage(prof['fotoUrl']) : null, child: prof['fotoUrl'] == null ? const Icon(Icons.assignment_ind_rounded, color: Colors.grey) : null),
                            ),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(prof['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text('ID: ${prof['id']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
                            Expanded(flex: 2, child: Text((prof['disciplinas'] as List? ?? []).join(', '), style: TextStyle(color: Colors.grey.shade700, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: inativo ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16)), child: Text(prof['status'] ?? 'Ativo', style: TextStyle(color: inativo ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12))),
                            const SizedBox(width: 24),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.visibility_rounded, color: Colors.blueGrey), tooltip: 'Visualizar Ficha', onPressed: () => _abrirFichaProfessor(context, prof)),
                                
                                // BOTÃO DE EDITAR QUE MANDA OS DADOS PARA O FORMULÁRIO PREENCHER SOZINHO!
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Colors.blue), 
                                  tooltip: 'Editar Professor', 
                                  onPressed: () => context.push('/admin/cadastros/professor/novo', extra: prof)
                                ),
                                
                                IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red), tooltip: 'Excluir', onPressed: () => _confirmarExclusao(context, prof)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. COMPONENTE DA ABA DE TURMAS
// ============================================================================
class _GestaoTurmasAba extends ConsumerStatefulWidget {
  const _GestaoTurmasAba();
  @override
  ConsumerState<_GestaoTurmasAba> createState() => _GestaoTurmasAbaState();
}

class _GestaoTurmasAbaState extends ConsumerState<_GestaoTurmasAba> {
  String _termoBusca = '';

  void _confirmarExclusao(BuildContext context, Map<String, dynamic> turma) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Excluir Turma', style: TextStyle(color: Colors.red))]),
        content: Text('Deseja realmente apagar a turma ${turma['nome']}?\n\nAtenção: Isso não apagará os alunos vinculados, mas eles ficarão sem turma.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref.read(turmaServiceProvider).excluirTurma(turma['id']);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turma excluída com sucesso!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Sim, Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estadoTurmas = ref.watch(turmasStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Turmas Cadastradas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              SizedBox(width: 250, height: 40, child: TextField(onChanged: (value) => setState(() => _termoBusca = value), decoration: InputDecoration(hintText: 'Pesquisar turma...', prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(vertical: 0), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/admin/cadastros/turma/novo'), 
                icon: const Icon(Icons.meeting_room_rounded), 
                label: const Text('Nova Turma')
              )
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: estadoTurmas.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (erro, stack) => Center(child: Text('Erro ao carregar turmas: $erro')),
              data: (turmas) {
                final filtradas = turmas.where((t) => t['nome'].toString().toLowerCase().contains(_termoBusca.toLowerCase())).toList();
                
                if (filtradas.isEmpty) return const Center(child: Text('Nenhuma turma cadastrada no sistema.'));

                return ListView.separated(
                  itemCount: filtradas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final turma = filtradas[index];
                    
                    // Lógica de cores atualizada para o status "FORMADA" e "EM FORMAÇÃO"
                    final statusTurma = turma['status'] ?? 'FORMADA';
                    final emFormacao = statusTurma == 'EM FORMAÇÃO';
                    final arquivada = statusTurma == 'Inativa'; // Caso de legado ou arquivamento

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: arquivada ? Colors.red.shade200 : Colors.grey.shade300)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: arquivada ? Colors.red.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.meeting_room_rounded, color: arquivada ? Colors.red : Colors.blue),
                            ),
                            const SizedBox(width: 16),
                            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${turma['nome']} (${turma['anoLetivo']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text('Sala: ${turma['sala'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13))])),
                            Expanded(flex: 2, child: Row(children: [Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.grey.shade600), const SizedBox(width: 4), Text(turma['turno'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold))])),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                              decoration: BoxDecoration(color: emFormacao ? Colors.orange.shade50 : (arquivada ? Colors.red.shade50 : Colors.green.shade50), borderRadius: BorderRadius.circular(16)), 
                              child: Text(statusTurma, style: TextStyle(color: emFormacao ? Colors.orange.shade700 : (arquivada ? Colors.red.shade700 : Colors.green.shade700), fontWeight: FontWeight.bold, fontSize: 12))
                            ),
                            
                            const SizedBox(width: 24),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.blue), tooltip: 'Editar', onPressed: () => context.push('/admin/cadastros/turma/novo', extra: turma)),
                                IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red), tooltip: 'Excluir', onPressed: () => _confirmarExclusao(context, turma)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualizacaoTabela extends StatelessWidget { final String titulo; final List<String> colunas; final List dadosSimulados; const _VisualizacaoTabela({required this.titulo, required this.colunas, required this.dadosSimulados}); @override Widget build(BuildContext context) { return const Center(child: Text('Usuários')); } }