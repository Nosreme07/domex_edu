import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';
import '../estado/aluno_provider.dart';
import '../estado/professor_provider.dart';
import '../estado/secretaria_provider.dart';
import '../estado/turma_provider.dart';

// Importação da Tela de Usuários restaurada!
import 'admin_usuarios_form_tela.dart';

// ============================================================================
// FUNÇÃO GLOBAL: ABRIR FOTO EM TELA CHEIA
// ============================================================================
void _mostrarFotoAmpliada(BuildContext context, String url) {
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

// ============================================================================
// DEBOUNCER
// ============================================================================
class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

// ============================================================================
// TELA PRINCIPAL DE CADASTROS (TAB BAR DINÂMICA)
// ============================================================================
class AdminCadastrosTela extends ConsumerStatefulWidget {
  final int abaInicial;
  const AdminCadastrosTela({super.key, this.abaInicial = 0});

  @override
  ConsumerState<AdminCadastrosTela> createState() => _AdminCadastrosTelaState();
}

class _AdminCadastrosTelaState extends ConsumerState<AdminCadastrosTela> {
  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    
    // 1. Pegar o usuário logado para checar o perfil
    final usuario = ref.watch(authProvider).value;
    final perfil = usuario?.perfil ?? 'secretaria'; // Se for null, assume menor privilégio
    final isAdmin = perfil == 'admin_escola' || perfil == 'direcao';

    // 2. Montar as abas dinamicamente baseadas na permissão
    List<Widget> abas = [
      const Tab(icon: Icon(Icons.school_rounded), text: 'Alunos'),
      const Tab(icon: Icon(Icons.assignment_ind_rounded), text: 'Professores'),
    ];
    
    List<Widget> telas = [
      const _GestaoAlunosAba(),
      const _GestaoProfessoresAba(),
    ];

    // Se for Admin, ele pode gerenciar outros membros da secretaria
    if (isAdmin) {
      abas.add(const Tab(icon: Icon(Icons.support_agent_rounded), text: 'Secretaria'));
      telas.add(const _GestaoSecretariaAba());
    }

    // Todos podem ver turmas
    abas.add(const Tab(icon: Icon(Icons.meeting_room_rounded), text: 'Turmas'));
    telas.add(const _GestaoTurmasAba());

    // Apenas Admin pode gerenciar acessos e senhas do sistema
    if (isAdmin) {
      abas.add(const Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Usuários'));
      telas.add(const AdminUsuariosFormTela());
    }

    // Validação caso a aba inicial passada por rota seja maior que as abas disponíveis
    final initialIndex = widget.abaInicial >= abas.length ? 0 : widget.abaInicial;

    return DefaultTabController(
      length: abas.length, 
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          title: const Text(
            'Central de Cadastros',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            labelColor: corPrimaria,
            unselectedLabelColor: Colors.grey,
            indicatorColor: corPrimaria,
            indicatorWeight: 3,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: abas, // Injeta as abas dinâmicas aqui
          ),
        ),
        body: TabBarView(
          children: telas, // Injeta as telas correspondentes aqui
        ),
      ),
    );
  }
}
// ============================================================================
// 1. ABA DE ALUNOS
// ============================================================================
class _GestaoAlunosAba extends ConsumerStatefulWidget {
  const _GestaoAlunosAba();
  @override
  ConsumerState<_GestaoAlunosAba> createState() => _GestaoAlunosAbaState();
}

class _GestaoAlunosAbaState extends ConsumerState<_GestaoAlunosAba> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _termoBusca = '';
  String _filtroTurma = 'TODAS';
  String _filtroStatus = 'TODOS';
  final _debouncer = Debouncer(milliseconds: 400);

  void _confirmarExclusao(BuildContext context, Map<String, dynamic> aluno) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Atenção: Excluir Matrícula',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Tem certeza que deseja apagar definitivamente o registro de ${aluno['nome']} (Matrícula: ${aluno['matricula']})?\n\nEsta ação excluirá o aluno e os dados dos seus responsáveis (caso não estejam vinculados a outro irmão).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await ref.read(alunoServiceProvider).excluirAluno(aluno['matricula']);
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Matrícula excluída permanentemente.', style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Sim, Excluir Aluno'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarAnexosDialog(BuildContext context, List anexos) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.folder_shared_rounded, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Documentos Anexados', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: anexos.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final anexo = anexos[index];
                final isPDF = anexo['extensao'] == 'pdf';
                return ListTile(
                  leading: Icon(
                    isPDF ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    color: isPDF ? Colors.red : Colors.blue,
                    size: 32,
                  ),
                  title: Text(
                    anexo['nome'] ?? 'Documento',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.blue),
                    tooltip: 'Visualizar / Baixar',
                    onPressed: () async {
                      final url = anexo['url'];
                      if (url != null && await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      } else {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Arquivo ainda não sincronizado ou inválido.')),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _gerarEImprimirPdf(Map<String, dynamic> aluno) async {
    final doc = pw.Document();
    final usuario = ref.read(authProvider).value;
    Map<String, dynamic> dadosEscola = {};
    if (usuario != null) {
      try {
        final docEscola = await FirebaseFirestore.instance.collection('tenants').doc(usuario.id).get();
        if (docEscola.exists && docEscola.data() != null) {
          dadosEscola = docEscola.data()!;
        }
      } catch (e) {
        debugPrint('Erro ao buscar dados da escola pro PDF: $e');
      }
    }

    final nomeEscola = dadosEscola['nomeEscola'] ?? dadosEscola['nome'] ?? 'ESCOLA NÃO CONFIGURADA';
    final slogan = dadosEscola['slogan'] ?? '';
    final cnpj = dadosEscola['cnpj'] ?? '';
    final endEscola = dadosEscola['endereco'] ?? {};
    final logradouroEscola = endEscola['rua'] ?? '';
    final numeroEscola = endEscola['numero'] ?? '';
    final bairroEscola = endEscola['bairro'] ?? '';
    final cidadeEscola = endEscola['cidade'] ?? '';
    final ufEscola = endEscola['estado'] ?? '';

    String enderecoCompletoEscola = '';
    if (logradouroEscola.isNotEmpty) {
      enderecoCompletoEscola = '$logradouroEscola, Nº $numeroEscola - $bairroEscola, $cidadeEscola/$ufEscola';
    }

    final logoEscolaUrl = dadosEscola['logoUrl'] ?? dadosEscola['fotoUrl'] ?? dadosEscola['logo'];
    pw.ImageProvider? fotoAluno;
    if (aluno['fotoUrl'] != null) {
      try {
        fotoAluno = await networkImage(aluno['fotoUrl']);
      } catch (e) {
        debugPrint('Erro foto PDF: $e');
      }
    }

    pw.ImageProvider? logoEscolaImg;
    if (logoEscolaUrl != null && logoEscolaUrl.isNotEmpty) {
      try {
        logoEscolaImg = await networkImage(logoEscolaUrl);
      } catch (e) {
        debugPrint('Erro ao carregar logo da escola pro PDF: $e');
      }
    } else {
      try {
        final ByteData bytes = await rootBundle.load('assets/logo.png');
        logoEscolaImg = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (e) {
        debugPrint('Logo padrão não encontrada.');
      }
    }

    pw.Widget pdfLinha(String label, dynamic valorRaw) {
      final valor = (valorRaw?.toString() ?? '').trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey800)),
            pw.Expanded(child: pw.Text(valor.isEmpty ? 'Não informado' : valor, style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      );
    }

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
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
              ),
              child: pw.Text(titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue800)),
            ),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: conteudo),
          ],
        ),
      );
    }

    final agora = DateTime.now();
    final dataHora = "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} às ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";
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

    String textoIrmaosPdf = 'NÃO';
    if (aluno['temIrmao'] == true) {
      final listIrmaos = aluno['irmaosVinculados'] as List? ?? [];
      final infoLegado = aluno['irmaoSelecionado']?.toString().trim() ?? '';
      if (listIrmaos.isNotEmpty) {
        textoIrmaosPdf = 'SIM - ${listIrmaos.join(', ')}';
      } else if (infoLegado.isNotEmpty) {
        textoIrmaosPdf = 'SIM - $infoLegado';
      } else {
        textoIrmaosPdf = 'SIM';
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoEscolaImg != null)
                    pw.Image(logoEscolaImg, width: 60, height: 60, fit: pw.BoxFit.contain)
                  else
                    pw.Container(
                      width: 60, height: 60,
                      decoration: const pw.BoxDecoration(color: PdfColors.blue100, shape: pw.BoxShape.circle),
                      child: pw.Center(child: pw.Text('LOGO', style: pw.TextStyle(color: PdfColors.blue800))),
                    ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(nomeEscola.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700)),
                        if (slogan.isNotEmpty) pw.Text(slogan, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        if (cnpj.isNotEmpty) pw.Text('CNPJ: $cnpj', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        if (enderecoCompletoEscola.isNotEmpty) pw.Text('Endereço: $enderecoCompletoEscola', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FICHA CADASTRAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.Text('ALUNO', style: pw.TextStyle(fontSize: 14, color: PdfColors.blue800)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 2, color: PdfColors.orange700),
              pw.SizedBox(height: 12),
              pw.Expanded(
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.topLeft,
                  child: pw.Container(
                    width: PdfPageFormat.a4.availableWidth,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pdfBloco(
                          'DADOS PESSOAIS E ACADÊMICOS',
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Container(
                                width: 80, height: 100,
                                decoration: pw.BoxDecoration(color: PdfColors.grey200, border: pw.Border.all(color: PdfColors.grey400)),
                                child: fotoAluno != null
                                    ? pw.Image(fotoAluno, fit: pw.BoxFit.cover)
                                    : pw.Center(child: pw.Text('Sem Foto', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
                              ),
                              pw.SizedBox(width: 12),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pdfLinha('Nome', aluno['nome']),
                                    pw.Row(
                                      children: [
                                        pw.Expanded(child: pdfLinha('Matrícula', aluno['matricula'])),
                                        pw.Expanded(child: pdfLinha('R.A.', aluno['ra'])),
                                      ],
                                    ),
                                    pw.Row(
                                      children: [
                                        pw.Expanded(child: pdfLinha('Nascimento', aluno['dataNascimento'])),
                                        pw.Expanded(child: pdfLinha('Sexo', aluno['sexo'])),
                                      ],
                                    ),
                                    pw.Row(
                                      children: [
                                        pw.Expanded(child: pdfLinha('Celular', aluno['telefone'])),
                                        pw.Expanded(child: pdfLinha('CPF', aluno['cpf'])),
                                      ],
                                    ),
                                    pw.Row(
                                      children: [
                                        pw.Expanded(child: pdfLinha('RG', rgFormatado)),
                                        pw.Expanded(child: pdfLinha('Naturalidade', natFormatada)),
                                      ],
                                    ),
                                    pdfLinha('E-mail', aluno['email']),
                                    pw.SizedBox(height: 4),
                                    pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                                    pw.SizedBox(height: 4),
                                    pw.Row(
                                      children: [
                                        pw.Expanded(child: pdfLinha('Turma Principal', aluno['turma'])),
                                        pw.Expanded(child: pdfLinha('Irmão(s) na Escola', textoIrmaosPdf)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pdfBloco(
                          'ENDEREÇO',
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Expanded(flex: 3, child: pdfLinha('Logradouro', endLogradouro)),
                                  pw.Expanded(flex: 2, child: pdfLinha('Bairro', end['bairro'])),
                                ],
                              ),
                              pw.Row(
                                children: [
                                  pw.Expanded(flex: 3, child: pdfLinha('Cidade/UF', endCidade)),
                                  pw.Expanded(flex: 2, child: pdfLinha('Referência', end['referencia'])),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pdfBloco(
                                'RESPONSÁVEIS',
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    if (responsaveis.isNotEmpty)
                                      ...responsaveis.map((r) => pw.Padding(
                                        padding: const pw.EdgeInsets.only(bottom: 6),
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pdfLinha('Nome', r['nome']),
                                            pw.Row(
                                              children: [
                                                // PDF também limpando CPF visualmente
                                                pw.Expanded(child: pdfLinha('CPF', r['cpf']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '')),
                                                pw.Expanded(child: pdfLinha('Tel', r['telefone'])),
                                              ],
                                            ),
                                            pdfLinha('E-mail', r['email']),
                                          ],
                                        ),
                                      )),
                                    pdfLinha('Autoriza sair sozinho', aluno['autorizaSairSo'] == true ? 'SIM' : 'NÃO'),
                                  ],
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                              child: pdfBloco(
                                'AUTORIZADOS A BUSCAR',
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    if (autorizados.isNotEmpty)
                                      ...autorizados.map((p) => pdfLinha('Nome', '${p['nome']} (Tel: ${p['telefone']})'))
                                    else
                                      pdfLinha('Autorizados', 'Nenhum cadastrado'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pdfBloco(
                                'INFORMAÇÕES MÉDICAS',
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Row(
                                      children: [
                                        pw.Expanded(child: pdfLinha('Sangue', med['tipoSanguineo'])),
                                        pw.Expanded(child: pdfLinha('Problema', med['temProblema'] == true ? med['problema'] : 'NÃO')),
                                      ],
                                    ),
                                    pw.Row(
                                      children: [
                                        pw.Expanded(child: pdfLinha('Remédio', med['tomaRemedio'] == true ? med['remedio'] : 'NÃO')),
                                        pw.Expanded(child: pdfLinha('Alergia', med['temAlergia'] == true ? med['alergia'] : 'NÃO')),
                                      ],
                                    ),
                                    pdfLinha('Observações', med['observacoes']),
                                  ],
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                              child: pdfBloco(
                                'CONTATOS DE EMERGÊNCIA',
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    if (emergencia.isNotEmpty)
                                      ...emergencia.map((e) => pdfLinha('Nome', '${e['nome']} (Tel: ${e['telefone']})'))
                                    else
                                      pdfLinha('Contatos', 'Nenhum cadastrado'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Ficha gerada pelo sistema Domex Edu - $dataHora', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Ficha_${aluno['matricula']}.pdf');
  }

  Widget _buildSecao(IconData icone, String titulo, Color cor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icone, size: 20, color: cor),
          const SizedBox(width: 8),
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cor)),
        ],
      ),
    );
  }

  Widget _buildLinha(String label, dynamic valorRaw) {
    final valor = (valorRaw?.toString() ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: valor.isEmpty ? 'Não informado' : valor),
          ],
        ),
      ),
    );
  }

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
            Tooltip(
              message: 'Abrir WhatsApp',
              child: InkWell(
                onTap: () => launchUrl(Uri.parse('https://wa.me/55$numeroLimpo')),
                child: Image.asset('assets/whatsapp.png', width: 18, height: 18),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Ligar',
              child: InkWell(
                onTap: () => launchUrl(Uri.parse('tel:$numeroLimpo')),
                child: const Icon(Icons.phone, color: Colors.blue, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // MÉTODOS DE ABERTURA DE MODAIS DE BOLETIM E FREQUÊNCIA NO ADMIN
  // =========================================================================
  void _abrirBoletimModalAdmin(String tenantId, String turmaId, String alunoDocId, Color corPrimaria) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) {
            return _BoletimModal(
              tenantId: tenantId,
              turmaId: turmaId,
              alunoDocId: alunoDocId,
              corPrimaria: corPrimaria,
              scrollController: scrollController,
            );
          }
        );
      }
    );
  }

  void _abrirFrequenciaModalAdmin(String tenantId, String turmaId, String matricula, Color corPrimaria) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, scrollController) {
            return _FrequenciaModal(
              tenantId: tenantId,
              turmaId: turmaId,
              alunoMatricula: matricula,
              corPrimaria: corPrimaria,
              scrollController: scrollController,
            );
          }
        );
      }
    );
  }

  void _abrirFichaAluno(BuildContext context, Map<String, dynamic> aluno) async {
    final corPrimaria = Theme.of(context).primaryColor;
    final anexos = aluno['anexos'] as List? ?? [];
    
    String textoIrmaosFicha = 'NÃO';
    if (aluno['temIrmao'] == true) {
      final list = aluno['irmaosVinculados'] as List? ?? [];
      final infoLegado = aluno['irmaoSelecionado']?.toString().trim() ?? '';
      if (list.isNotEmpty) {
        textoIrmaosFicha = 'SIM: ${list.join(', ')}';
      } else if (infoLegado.isNotEmpty) {
        textoIrmaosFicha = 'SIM: $infoLegado';
      } else {
        textoIrmaosFicha = 'SIM';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final statusAtual = aluno['status'] ?? 'Ativo';
            final corStatus = statusAtual == 'Ativo'
                ? Colors.green
                : (statusAtual == 'Inadimplente' ? Colors.red : Colors.orange);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.all(0),
              title: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: corPrimaria.withAlpha(13),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: aluno['fotoUrl'] != null ? () => _mostrarFotoAmpliada(context, aluno['fotoUrl']) : null,
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white,
                            backgroundImage: aluno['fotoUrl'] != null ? NetworkImage(aluno['fotoUrl']) : null,
                            child: aluno['fotoUrl'] == null ? Icon(Icons.person, size: 32, color: corPrimaria) : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(aluno['nome'] ?? 'Aluno', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                              const SizedBox(height: 4),
                              Text('Matrícula: ${aluno['matricula']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          decoration: BoxDecoration(color: corStatus.withAlpha(30), borderRadius: BorderRadius.circular(8), border: Border.all(color: corStatus)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: ['Ativo', 'Inativo', 'Transferido', 'Inadimplente'].contains(statusAtual) ? statusAtual : 'Ativo',
                              icon: Icon(Icons.arrow_drop_down, color: corStatus),
                              style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'Ativo', child: Text('ATIVO')),
                                DropdownMenuItem(value: 'Inativo', child: Text('INATIVO')),
                                DropdownMenuItem(value: 'Transferido', child: Text('TRANSFERIDO')),
                                DropdownMenuItem(value: 'Inadimplente', child: Text('INADIMPLENTE')),
                              ],
                              onChanged: (novoStatus) async {
                                if (novoStatus != null) {
                                  try {
                                    await ref.read(alunoServiceProvider).atualizarStatus(aluno['matricula'], novoStatus);
                                    setStateModal(() => aluno['status'] = novoStatus);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (anexos.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade50,
                                foregroundColor: Colors.deepPurple,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              icon: const Icon(Icons.folder_open_rounded, size: 20),
                              label: Text('${anexos.length} Anexos', style: const TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _mostrarAnexosDialog(context, anexos),
                            ),
                          ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // =========================================================
                    // BOTÕES RÁPIDOS DE FREQUÊNCIA E BOLETIM (ACIONAM MODAL)
                    // =========================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            final turmaId = aluno['turmaId']?.toString() ?? '';
                            final tenantId = ref.read(authProvider).value?.tenantId ?? '';
                            final alunoDocId = (aluno['matricula'] ?? aluno['id'] ?? aluno['docId'] ?? '').toString();
                            
                            if (turmaId.isNotEmpty && tenantId.isNotEmpty) {
                              _abrirBoletimModalAdmin(tenantId, turmaId, alunoDocId, corPrimaria);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turma não vinculada para mostrar o boletim.')));
                            }
                          },
                          icon: Icon(Icons.analytics_rounded, color: corPrimaria),
                          label: Text('Acessar Boletim', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            final turmaId = aluno['turmaId']?.toString() ?? '';
                            final tenantId = ref.read(authProvider).value?.tenantId ?? '';
                            final matricula = (aluno['matricula'] ?? '').toString();
                            
                            if (turmaId.isNotEmpty && tenantId.isNotEmpty) {
                              _abrirFrequenciaModalAdmin(tenantId, turmaId, matricula, corPrimaria);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turma não vinculada para mostrar a frequência.')));
                            }
                          },
                          icon: Icon(Icons.fact_check_rounded, color: corPrimaria),
                          label: Text('Acessar Frequência', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
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
                                  _buildLinha('E-mail', aluno['email']),
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
                                  _buildLinha('Irmão(s)', textoIrmaosFicha),
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
                                          _buildLinha('CPF', r['cpf']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? ''), // <--- Força a mostrar o CPF limpo!
                                          _buildLinhaTelefone('Tel', r['telefone']),
                                          _buildLinha('E-mail', r['email']),
                                          const SizedBox(height: 4),
                                        ],
                                      ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corPrimaria,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar Ficha'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final estadoAlunos = ref.watch(alunosStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Alunos Matriculados',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              estadoAlunos.when(
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
                data: (alunos) {
                  final turmasSet = {'TODAS'};
                  for (var aluno in alunos) {
                    final t = (aluno['turma'] ?? '').toString().toUpperCase().trim();
                    if (t.isNotEmpty) {
                      turmasSet.add(t);
                    }
                  }
                  final listaTurmas = turmasSet.toList()..sort((a, b) => a == 'TODAS' ? -1 : a.compareTo(b));
                  if (!listaTurmas.contains(_filtroTurma)) {
                    _filtroTurma = 'TODAS';
                  }

                  return Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filtroTurma,
                        icon: const Icon(Icons.filter_alt_rounded, color: Colors.blue, size: 20),
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _filtroTurma = v);
                          }
                        },
                        items: listaTurmas.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t == 'TODAS' ? 'Todas as Turmas' : t, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)),
                        )).toList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Container(
                constraints: const BoxConstraints(maxWidth: 200),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _filtroStatus,
                    icon: const Icon(Icons.filter_alt_rounded, color: Colors.blue, size: 20),
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _filtroStatus = v);
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('Todos os Status', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'ATIVO', child: Text('Apenas Ativos', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'INATIVO', child: Text('Apenas Inativos', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'INADIMPLENTE', child: Text('Inadimplentes', style: TextStyle(color: Colors.black87))),
                      DropdownMenuItem(value: 'TRANSFERIDO', child: Text('Transferidos', style: TextStyle(color: Colors.black87))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 250,
                height: 40,
                child: TextField(
                  onChanged: (value) => _debouncer.run(() => setState(() => _termoBusca = value)),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar nome ou matrícula...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/admin/cadastros/aluno/novo'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Nova Matrícula'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: estadoAlunos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Erro ao carregar alunos: $e')),
              data: (alunos) {
                final alunosFiltrados = alunos.where((aluno) {
                  final busca = _termoBusca.toLowerCase().trim();
                  final nome = (aluno['nome'] ?? '').toString().toLowerCase();
                  final mat = (aluno['matricula'] ?? '').toString().toLowerCase();
                  final matchBusca = busca.isEmpty || nome.contains(busca) || mat.contains(busca);

                  final t = (aluno['turma'] ?? '').toString().toUpperCase().trim();
                  final matchTurma = _filtroTurma == 'TODAS' || t == _filtroTurma;

                  final status = (aluno['status'] ?? 'Ativo').toString().toUpperCase().trim();
                  final matchStatus = _filtroStatus == 'TODOS' || status == _filtroStatus;

                  return matchBusca && matchTurma && matchStatus;
                }).toList();

                if (alunosFiltrados.isEmpty) {
                  return const Center(child: Text('Nenhum aluno encontrado.', style: TextStyle(color: Colors.grey)));
                }

                alunosFiltrados.sort((a, b) => (a['nome'] ?? '').toString().toUpperCase().compareTo((b['nome'] ?? '').toString().toUpperCase()));

                return ListView.separated(
                  itemCount: alunosFiltrados.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final aluno = alunosFiltrados[index];
                    final statusAluno = aluno['status'] ?? 'Ativo';
                    final corStatusCard = statusAluno == 'Ativo' ? Colors.green : (statusAluno == 'Inadimplente' ? Colors.red : Colors.orange);

                    final temIrmao = aluno['temIrmao'] == true;
                    final irmaoInfo = aluno['irmaoSelecionado']?.toString().trim() ?? '';
                    final irmaosList = aluno['irmaosVinculados'] as List? ?? [];
                    String textoIrmao = '';

                    if (temIrmao) {
                      if (irmaosList.isNotEmpty) {
                        textoIrmao = 'Irmão(s): ${irmaosList.join(', ')}';
                      } else if (irmaoInfo.isNotEmpty) {
                        textoIrmao = 'Irmão(ã): $irmaoInfo';
                      } else {
                        textoIrmao = 'Possui irmão(ã) na escola';
                      }
                    }

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: statusAluno == 'Inadimplente' ? Colors.red.shade200 : Colors.grey.shade300,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: aluno['fotoUrl'] != null ? () => _mostrarFotoAmpliada(context, aluno['fotoUrl']) : null,
                              borderRadius: BorderRadius.circular(24),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: aluno['fotoUrl'] != null ? NetworkImage(aluno['fotoUrl']) : null,
                                child: aluno['fotoUrl'] == null ? const Icon(Icons.person, color: Colors.grey) : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(aluno['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Matrícula: ${aluno['matricula']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  if (temIrmao) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.family_restroom_rounded, size: 14, color: Colors.purple.shade400),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            textoIrmao,
                                            style: TextStyle(color: Colors.purple.shade600, fontSize: 11, fontWeight: FontWeight.bold),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(aluno['turma'] ?? 'Sem turma', style: TextStyle(color: Colors.grey.shade700)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: corStatusCard.withAlpha(30),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                statusAluno,
                                style: TextStyle(color: corStatusCard, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_rounded, color: Colors.blueGrey),
                                  tooltip: 'Visualizar Ficha',
                                  onPressed: () => _abrirFichaAluno(context, aluno),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                  tooltip: 'Editar Matrícula',
                                  onPressed: () => context.push('/admin/cadastros/aluno/novo', extra: aluno),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                  tooltip: 'Excluir Aluno',
                                  onPressed: () => _confirmarExclusao(context, aluno),
                                ),
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
// 2. ABA DE PROFESSORES
// ============================================================================
class _GestaoProfessoresAba extends ConsumerStatefulWidget {
  const _GestaoProfessoresAba();
  @override
  ConsumerState<_GestaoProfessoresAba> createState() => _GestaoProfessoresAbaState();
}

class _GestaoProfessoresAbaState extends ConsumerState<_GestaoProfessoresAba> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _termoBusca = '';
  String _filtroDisciplina = 'TODAS';
  final _debouncer = Debouncer(milliseconds: 400);

  void _confirmarExclusao(BuildContext context, Map<String, dynamic> professor) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Excluir Professor', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Tem certeza que deseja apagar o registro de ${professor['nome']}?\n\nEsta ação não poderá ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await ref.read(professorServiceProvider).excluirProfessor(professor['id']);
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Professor excluído.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Sim, Excluir'),
            ),
          ],
        );
      },
    );
  }

  void _abrirFichaProfessor(BuildContext context, Map<String, dynamic> prof, List<Map<String, dynamic>> turmasDoSistema) {
    final corPrimaria = Theme.of(context).primaryColor;
    final anexos = prof['anexos'] as List? ?? [];

    Widget buildLinha(String label, dynamic valorRaw) {
      final valor = (valorRaw?.toString() ?? '').trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: valor.isEmpty ? 'Não informado' : valor),
            ],
          ),
        ),
      );
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
              Tooltip(
                message: 'Abrir WhatsApp',
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse('https://wa.me/55$numeroLimpo')),
                  child: Image.asset('assets/whatsapp.png', width: 18, height: 18),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Ligar',
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:$numeroLimpo')),
                  child: const Icon(Icons.phone, color: Colors.blue, size: 18),
                ),
              ),
            ],
          ],
        ),
      );
    }

    List<String> turmasVinculadas = [];
    for (var t in turmasDoSistema) {
      final profsDaTurma = t['professoresVinculados'] as List? ?? [];
      if (profsDaTurma.any((pv) => pv['professorId'] == prof['id'])) {
        turmasVinculadas.add('${t['nome']} (${t['anoLetivo']})');
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final statusAtual = prof['status'] ?? 'Ativo';
            final isBloqueado = statusAtual == 'Inativo' || statusAtual == 'Bloqueado';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.all(0),
              title: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: corPrimaria.withAlpha(13),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: prof['fotoUrl'] != null ? () => _mostrarFotoAmpliada(context, prof['fotoUrl']) : null,
                      borderRadius: BorderRadius.circular(32),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        backgroundImage: prof['fotoUrl'] != null ? NetworkImage(prof['fotoUrl']) : null,
                        child: prof['fotoUrl'] == null ? Icon(Icons.assignment_ind_rounded, size: 32, color: corPrimaria) : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prof['nome'] ?? 'Professor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          const SizedBox(height: 4),
                          Text('ID: ${prof['id']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(isBloqueado ? 'INATIVO' : 'ATIVO', style: TextStyle(color: isBloqueado ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                        Switch(
                          value: !isBloqueado,
                          activeThumbColor: Colors.green,
                          inactiveThumbColor: Colors.red,
                          onChanged: (val) async {
                            final novoStatus = val ? 'Ativo' : 'Inativo';
                            try {
                              await ref.read(professorServiceProvider).atualizarStatus(prof['id'], novoStatus);
                              setStateModal(() => prof['status'] = novoStatus);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
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
                                  children: (prof['disciplinas'] as List? ?? []).map((d) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)),
                                    child: Text(d.toString(), style: const TextStyle(fontSize: 11, color: Colors.blue)),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('LECIONA NAS TURMAS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const Divider(),
                      if (turmasVinculadas.isEmpty)
                        const Text('Não está vinculado a nenhuma turma.', style: TextStyle(color: Colors.grey))
                      else
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: turmasVinculadas.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                            child: Text(t, style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                          )).toList(),
                        ),
                      const SizedBox(height: 24),
                      const Text('ENDEREÇO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const Divider(),
                      buildLinha('Logradouro', '${prof['endereco']?['rua'] ?? ''}, Nº ${prof['endereco']?['numero'] ?? ''}'),
                      buildLinha('Bairro/Cidade', '${prof['endereco']?['bairro'] ?? ''} - ${prof['endereco']?['cidade'] ?? ''}'),
                      const SizedBox(height: 24),
                      const Text('DOCUMENTOS E CERTIFICADOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const Divider(),
                      if (anexos.isEmpty)
                        const Text('Nenhum documento anexado ao perfil.', style: TextStyle(color: Colors.grey))
                      else
                        ...anexos.map((anexo) {
                          final isPDF = anexo['extensao'] == 'pdf';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8), elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                            child: ListTile(
                              leading: Icon(isPDF ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: isPDF ? Colors.red : Colors.blue),
                              title: Text(anexo['nome'] ?? 'Documento', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new_rounded, color: Colors.deepPurple),
                                tooltip: 'Visualizar / Baixar',
                                onPressed: () async {
                                  final url = anexo['url'];
                                  if (url != null && await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o arquivo.')));
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        }),
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
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _gerarAcessoProfessor(Map<String, dynamic> prof) async {
    final authNotif = ref.read(authProvider.notifier);
    final emailOriginal = prof['email']?.toString() ?? '';
    final cpfLimpo = (prof['cpf']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), ''); 
    final loginASerCriado = emailOriginal.isNotEmpty && emailOriginal.contains('@') ? emailOriginal : cpfLimpo;
    
    final senhaPadrao = 'prof${cpfLimpo.length >= 4 ? cpfLimpo.substring(0,4) : '1234'}';

    showDialog(
      context: context,
      builder: (ctx) {
        bool gerando = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Gerar Acesso Manual'),
              content: Text('Será criado o acesso para:\n\nLogin: $loginASerCriado\nSenha: $senhaPadrao\n\n(Se o login for apenas CPF, ele deverá informar o Código da Instituição na tela de entrada)'),
              actions: [
                TextButton(onPressed: gerando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: gerando ? null : () async {
                    setModalState(() => gerando = true);
                    try {
                      await authNotif.criarUsuarioManual(
                        email: loginASerCriado.contains('@') ? loginASerCriado : '$loginASerCriado@escola.com', 
                        senha: senhaPadrao,
                        nome: prof['nome'],
                        perfil: 'professor'
                      );
                      
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acesso criado com sucesso!'), backgroundColor: Colors.green));
                    } catch (e) {
                      setModalState(() => gerando = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: gerando ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirmar', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final estadoProfessores = ref.watch(professoresStreamProvider);
    final estadoTurmas = ref.watch(turmasStreamProvider);
    final turmas = estadoTurmas.value ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Professores Cadastrados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              estadoProfessores.when(
                loading: () => const SizedBox.shrink(),
                error: (erro, stack) => const SizedBox.shrink(),
                data: (professores) {
                  final disciplinasSet = {'TODAS'};
                  for (var prof in professores) {
                    final discList = prof['disciplinas'] as List? ?? [];
                    for (var d in discList) {
                      final str = d.toString().toUpperCase().trim();
                      if (str.isNotEmpty) {
                        disciplinasSet.add(str);
                      }
                    }
                  }
                  final listaDisciplinas = disciplinasSet.toList()..sort((a, b) => a == 'TODAS' ? -1 : a.compareTo(b));
                  if (!listaDisciplinas.contains(_filtroDisciplina)) {
                    _filtroDisciplina = 'TODAS';
                  }

                  return Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filtroDisciplina,
                        icon: const Icon(Icons.filter_alt_rounded, color: Colors.blue, size: 20),
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _filtroDisciplina = v);
                          }
                        },
                        items: listaDisciplinas.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t == 'TODAS' ? 'Todas as Matérias' : t, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)),
                        )).toList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 250, height: 40,
                child: TextField(
                  onChanged: (value) => _debouncer.run(() => setState(() => _termoBusca = value)),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar professor...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true, fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/admin/cadastros/professor/novo'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Novo Professor'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: estadoProfessores.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (erro, stack) => Center(child: Text('Erro ao carregar: $erro')),
              data: (professores) {
                final filtrados = professores.where((p) {
                  final nome = p['nome']?.toString() ?? '';
                  final id = p['id']?.toString() ?? '';
                  if (nome.trim().isEmpty || id.trim().isEmpty || id == 'null') {
                    return false;
                  }

                  final busca = _termoBusca.toLowerCase();
                  final matchBusca = nome.toLowerCase().contains(busca);

                  final discList = (p['disciplinas'] as List? ?? []).map((e) => e.toString().toUpperCase().trim()).toList();
                  final matchDisc = _filtroDisciplina == 'TODAS' || discList.contains(_filtroDisciplina);

                  return matchBusca && matchDisc;
                }).toList();

                if (filtrados.isEmpty) {
                  return const Center(child: Text('Nenhum professor encontrado com esses filtros.'));
                }

                filtrados.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

                return ListView.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final prof = filtrados[index];
                    final inativo = prof['status'] != 'Ativo';

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: inativo ? Colors.red.shade200 : Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: prof['fotoUrl'] != null ? () => _mostrarFotoAmpliada(context, prof['fotoUrl']) : null,
                              borderRadius: BorderRadius.circular(24),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: prof['fotoUrl'] != null ? NetworkImage(prof['fotoUrl']) : null,
                                child: prof['fotoUrl'] == null ? const Icon(Icons.assignment_ind_rounded, color: Colors.grey) : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(prof['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('ID: ${prof['id']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                (prof['disciplinas'] as List? ?? []).join(', '),
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: inativo ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16)),
                              child: Text(
                                prof['status'] ?? 'Ativo',
                                style: TextStyle(color: inativo ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.vpn_key_rounded, color: Colors.orange),
                                  tooltip: 'Gerar Acesso',
                                  onPressed: () => _gerarAcessoProfessor(prof),
                                ),
                                IconButton(icon: const Icon(Icons.visibility_rounded, color: Colors.blueGrey), tooltip: 'Visualizar Ficha', onPressed: () => _abrirFichaProfessor(context, prof, turmas)),
                                IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.blue), tooltip: 'Editar Professor', onPressed: () => context.push('/admin/cadastros/professor/novo', extra: prof)),
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
// 3. ABA DE SECRETÁRIA
// ============================================================================
class _GestaoSecretariaAba extends ConsumerStatefulWidget {
  const _GestaoSecretariaAba();
  @override
  ConsumerState<_GestaoSecretariaAba> createState() => _GestaoSecretariaAbaState();
}

class _GestaoSecretariaAbaState extends ConsumerState<_GestaoSecretariaAba> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _termoBusca = '';
  String _filtroFuncao = 'TODAS';
  final _debouncer = Debouncer(milliseconds: 400);

  void _confirmarExclusao(BuildContext context, Map<String, dynamic> membro) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Excluir Colaborador', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Text('Deseja excluir o registro de ${membro['nome']}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await ref.read(secretariaServiceProvider).excluirSecretaria(membro['id']);
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro excluído.'), backgroundColor: Colors.green));
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _abrirFichaSecretaria(BuildContext context, Map<String, dynamic> mem) {
    final corPrimaria = Theme.of(context).primaryColor;

    Widget buildLinha(String label, dynamic valorRaw) {
      final valor = (valorRaw?.toString() ?? '').trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: valor.isEmpty ? 'Não informado' : valor),
            ],
          ),
        ),
      );
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
              Tooltip(
                message: 'Abrir WhatsApp',
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse('https://wa.me/55$numeroLimpo')),
                  child: Image.asset('assets/whatsapp.png', width: 18, height: 18),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Ligar',
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:$numeroLimpo')),
                  child: const Icon(Icons.phone, color: Colors.blue, size: 18),
                ),
              ),
            ],
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final statusAtual = mem['status'] ?? 'Ativo';
            final isBloqueado = statusAtual == 'Inativo' || statusAtual == 'Bloqueado';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.all(0),
              title: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: corPrimaria.withAlpha(13), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(
                  children: [
                    InkWell(
                      onTap: mem['fotoUrl'] != null ? () => _mostrarFotoAmpliada(context, mem['fotoUrl']) : null,
                      borderRadius: BorderRadius.circular(32),
                      child: CircleAvatar(
                        radius: 32, backgroundColor: Colors.white,
                        backgroundImage: mem['fotoUrl'] != null ? NetworkImage(mem['fotoUrl']) : null,
                        child: mem['fotoUrl'] == null ? Icon(Icons.support_agent_rounded, size: 32, color: corPrimaria) : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mem['nome'] ?? 'Colaborador', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          const SizedBox(height: 4),
                          Text('ID: ${mem['id']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(isBloqueado ? 'INATIVO' : 'ATIVO', style: TextStyle(color: isBloqueado ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                        Switch(
                          value: !isBloqueado,
                          activeThumbColor: Colors.green, inactiveThumbColor: Colors.red,
                          onChanged: (val) async {
                            final novoStatus = val ? 'Ativo' : 'Inativo';
                            try {
                              await ref.read(secretariaServiceProvider).atualizarStatus(mem['id'], novoStatus);
                              setStateModal(() => mem['status'] = novoStatus);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              content: SizedBox(
                width: 600,
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
                                buildLinha('CPF', mem['cpf']),
                                buildLinha('Nascimento', mem['dataNascimento']),
                                buildLinhaContato('Celular', mem['telefone']),
                                buildLinha('E-mail', mem['email']),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ATUAÇÃO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                const Divider(),
                                buildLinha('Status', mem['status']),
                                const SizedBox(height: 4),
                                buildLinha('Função/Cargo', mem['funcao'] ?? 'Não informada'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('ENDEREÇO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const Divider(),
                      buildLinha('Logradouro', '${mem['endereco']?['rua'] ?? ''}, Nº ${mem['endereco']?['numero'] ?? ''}'),
                      buildLinha('Bairro/Cidade', '${mem['endereco']?['bairro'] ?? ''} - ${mem['endereco']?['cidade'] ?? ''}'),
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
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _gerarAcessoSecretaria(Map<String, dynamic> mem) async {
    final authNotif = ref.read(authProvider.notifier);
    final emailOriginal = mem['email']?.toString() ?? '';
    final cpfLimpo = (mem['cpf']?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), ''); 
    final loginASerCriado = emailOriginal.isNotEmpty && emailOriginal.contains('@') ? emailOriginal : cpfLimpo;
    
    final senhaPadrao = 'adm${cpfLimpo.length >= 4 ? cpfLimpo.substring(0,4) : '1234'}';

    showDialog(
      context: context,
      builder: (ctx) {
        bool gerando = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Gerar Acesso Manual'),
              content: Text('Será criado o acesso para:\n\nLogin: $loginASerCriado\nSenha: $senhaPadrao\n\n(Se o login for apenas CPF, ele deverá informar o Código da Instituição na tela de entrada)'),
              actions: [
                TextButton(onPressed: gerando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: gerando ? null : () async {
                    setModalState(() => gerando = true);
                    try {
                      await authNotif.criarUsuarioManual(
                        email: loginASerCriado.contains('@') ? loginASerCriado : '$loginASerCriado@escola.com', 
                        senha: senhaPadrao,
                        nome: mem['nome'],
                        perfil: 'admin_escola'
                      );
                      
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acesso criado com sucesso!'), backgroundColor: Colors.green));
                    } catch (e) {
                      setModalState(() => gerando = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: gerando ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirmar', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final estadoSecretaria = ref.watch(secretariaStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: estadoSecretaria.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, stack) => Center(child: Text('Erro: $erro')),
        data: (equipe) {
          final funcoesSet = {'TODAS'};
          for (var mem in equipe) {
            final funcao = (mem['funcao'] ?? '').toString().toUpperCase().trim();
            if (funcao.isNotEmpty) {
              funcoesSet.add(funcao);
            }
          }
          final listaFuncoes = funcoesSet.toList()..sort((a, b) => a == 'TODAS' ? -1 : a.compareTo(b));
          if (!listaFuncoes.contains(_filtroFuncao)) {
            _filtroFuncao = 'TODAS';
          }

          final filtrados = equipe.where((mem) {
            final nome = (mem['nome'] ?? '').toString().toLowerCase();
            final id = (mem['id'] ?? '').toString().toLowerCase();
            if (nome.trim().isEmpty || id.trim().isEmpty || id == 'null') {
              return false;
            }

            final busca = _termoBusca.toLowerCase().trim();
            final idApenasNumeros = id.replaceAll(RegExp(r'[^0-9]'), '');
            final funcao = (mem['funcao'] ?? '').toString().toUpperCase().trim();

            final matchBusca = busca.isEmpty || nome.contains(busca) || id.contains(busca) || idApenasNumeros.contains(busca);
            final matchFuncao = _filtroFuncao == 'TODAS' || funcao == _filtroFuncao;

            return matchBusca && matchFuncao;
          }).toList();

          filtrados.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Equipe da Secretaria', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filtroFuncao,
                        icon: const Icon(Icons.filter_alt_rounded, color: Colors.blue, size: 20),
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _filtroFuncao = v);
                          }
                        },
                        items: listaFuncoes.map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f == 'TODAS' ? 'Todas as Funções' : f, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)),
                        )).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 250, height: 40,
                    child: TextField(
                      onChanged: (value) => _debouncer.run(() => setState(() => _termoBusca = value)),
                      decoration: InputDecoration(
                        hintText: 'Pesquisar nome ou ID (ex: 03)...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        filled: true, fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/cadastros/secretaria/novo'),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Adicionar Equipe'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: filtrados.isEmpty
                    ? const Center(child: Text('Nenhum colaborador encontrado para o filtro/pesquisa.', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: filtrados.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final mem = filtrados[index];
                          final inativo = mem['status'] != 'Ativo';

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: inativo ? Colors.red.shade200 : Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: mem['fotoUrl'] != null ? NetworkImage(mem['fotoUrl']) : null,
                                    child: mem['fotoUrl'] == null ? const Icon(Icons.support_agent_rounded, color: Colors.grey) : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(mem['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text('ID: ${mem['id']}  |  Função: ${mem['funcao'] ?? 'Não informada'}  |  Tel: ${mem['telefone']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: inativo ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(16)),
                                    child: Text(
                                      mem['status'] ?? 'Ativo',
                                      style: TextStyle(color: inativo ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.vpn_key_rounded, color: Colors.orange),
                                        tooltip: 'Gerar Acesso',
                                        onPressed: () => _gerarAcessoSecretaria(mem),
                                      ),
                                      IconButton(icon: const Icon(Icons.visibility_rounded, color: Colors.blueGrey), tooltip: 'Visualizar Ficha', onPressed: () => _abrirFichaSecretaria(context, mem)),
                                      IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.blue), tooltip: 'Editar Cadastro', onPressed: () => context.push('/admin/cadastros/secretaria/novo', extra: mem)),
                                      IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red), tooltip: 'Excluir', onPressed: () => _confirmarExclusao(context, mem)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// 4. ABA DE TURMAS
// ============================================================================
class _GestaoTurmasAba extends ConsumerStatefulWidget {
  const _GestaoTurmasAba();
  @override
  ConsumerState<_GestaoTurmasAba> createState() => _GestaoTurmasAbaState();
}

class _GestaoTurmasAbaState extends ConsumerState<_GestaoTurmasAba> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _termoBusca = '';
  final _debouncer = Debouncer(milliseconds: 400);
  String _anoSelecionado = DateTime.now().year.toString();

  int _calcularPesoTurmaMEC(String nome) {
    final n = nome.toUpperCase();
    if (n.contains('MÉDIO') || n.contains('MEDIO') || n.contains('SÉRIE') || n.contains('SERIE') || n.contains('TERCEIRÃO')) {
      if (n.contains('1') || n.contains('PRIMEIR')) return 210;
      if (n.contains('2') || n.contains('SEGUND')) return 220;
      if (n.contains('3') || n.contains('TERCEIR')) return 230;
      return 200;
    }
    if (n.contains('ANO') || n.contains('FUNDAMENTAL')) {
      if (n.contains('1') || n.contains('PRIMEIR')) return 110;
      if (n.contains('2') || n.contains('SEGUND')) return 120;
      if (n.contains('3') || n.contains('TERCEIR')) return 130;
      if (n.contains('4') || n.contains('QUART')) return 140;
      if (n.contains('5') || n.contains('QUINT')) return 150;
      if (n.contains('6') || n.contains('SEXT')) return 160;
      if (n.contains('7') || n.contains('SÉTIM') || n.contains('SETIM')) return 170;
      if (n.contains('8') || n.contains('OITAV')) return 180;
      if (n.contains('9') || n.contains('NON')) return 190;
      return 100;
    }
    if (n.contains('BERÇÁRIO') || n.contains('BERCARIO')) return 10;
    if (n.contains('MATERNAL')) return 20;
    if (n.contains('INFANTIL I') || n.contains('INFANTIL 1') || n.contains('JARDIM I') || n.contains('JARDIM 1')) return 30;
    if (n.contains('INFANTIL II') || n.contains('INFANTIL 2') || n.contains('JARDIM II') || n.contains('JARDIM 2')) return 40;
    if (n.contains('INFANTIL III') || n.contains('INFANTIL 3')) return 50;
    if (n.contains('INFANTIL IV') || n.contains('INFANTIL 4') || n.contains('PRÉ I') || n.contains('PRÉ 1')) return 60;
    if (n.contains('INFANTIL V') || n.contains('INFANTIL 5') || n.contains('PRÉ II') || n.contains('PRÉ 2') || n.contains('PRÉ')) return 70;
    if (n.contains('INFANTIL')) return 80;
    return 999;
  }

  void _confirmarExclusao(BuildContext context, Map<String, dynamic> turma) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Excluir Turma', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text('Deseja realmente apagar a turma ${turma['nome']}?\n\nAtenção: Isso não apagará os alunos vinculados, but eles ficarão sem turma.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref.read(turmaServiceProvider).excluirTurma(turma['id']);
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turma excluída com sucesso!'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
                }
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
    super.build(context);
    final estadoTurmas = ref.watch(turmasStreamProvider);
    final estadoAlunos = ref.watch(alunosStreamProvider);
    final alunosDoSistema = estadoAlunos.value ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: estadoTurmas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, stack) => Center(child: Text('Erro ao carregar turmas: $erro')),
        data: (turmas) {
          final Set<String> anosSet = {DateTime.now().year.toString()};
          for (var t in turmas) {
            if (t['anoLetivo'] != null && t['anoLetivo'].toString().isNotEmpty) {
              anosSet.add(t['anoLetivo'].toString());
            }
          }
          final listaAnos = anosSet.toList()..sort((a, b) => b.compareTo(a));
          listaAnos.insert(0, 'TODOS');

          final filtradas = turmas.where((t) {
            final matchBusca = t['nome'].toString().toLowerCase().contains(_termoBusca.toLowerCase());
            final matchAno = _anoSelecionado == 'TODOS' || t['anoLetivo'] == _anoSelecionado;
            return matchBusca && matchAno;
          }).toList();

          filtradas.sort((a, b) {
            final pesoA = _calcularPesoTurmaMEC(a['nome'] ?? '');
            final pesoB = _calcularPesoTurmaMEC(b['nome'] ?? '');
            if (pesoA == pesoB) {
              return (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString());
            }
            return pesoA.compareTo(pesoB);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Turmas Cadastradas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: listaAnos.contains(_anoSelecionado) ? _anoSelecionado : listaAnos.first,
                        icon: const Icon(Icons.filter_alt_rounded, color: Colors.blue, size: 20),
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                        onChanged: (novoAno) {
                          if (novoAno != null) {
                            setState(() => _anoSelecionado = novoAno);
                          }
                        },
                        items: listaAnos.map((ano) => DropdownMenuItem(
                          value: ano,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(ano == 'TODOS' ? 'Todos os Anos' : 'Ano Letivo: $ano', style: const TextStyle(color: Colors.black87)),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 250, height: 40,
                    child: TextField(
                      onChanged: (value) => _debouncer.run(() => setState(() => _termoBusca = value)),
                      decoration: InputDecoration(
                        hintText: 'Pesquisar turma...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        filled: true, fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/cadastros/turma/novo'),
                    icon: const Icon(Icons.meeting_room_rounded),
                    label: const Text('Nova Turma'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: filtradas.isEmpty
                    ? Center(child: Text('Nenhuma turma encontrada para o filtro selecionado.', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.separated(
                        itemCount: filtradas.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final turma = filtradas[index];
                          final statusTurma = turma['status'] ?? 'FORMADA';
                          final emFormacao = statusTurma == 'EM FORMAÇÃO';
                          final arquivada = statusTurma == 'Inativa';
                          final isExtra = _calcularPesoTurmaMEC(turma['nome'] ?? '') == 999;
                          final profsCount = (turma['professoresVinculados'] as List? ?? []).length;
                          final idTurma = turma['id'].toString();
                          final turnoFormatado = turma['turno'] ?? '';
                          final turmaNomeOficial = '${turma['nome']} (${turma['anoLetivo']}) - $turnoFormatado'.toUpperCase();
                          final turmaNomeAntigo = '${turma['nome']} (${turma['anoLetivo']})'.toUpperCase();

                          int alunosCount = 0;
                          for (var a in alunosDoSistema) {
                            if (a['status'] == 'Transferido' || a['status'] == 'Inativo') {
                              continue;
                            }
                            final turmaAluno = (a['turma'] ?? '').toString().trim().toUpperCase();
                            final turmaIdAluno = (a['turmaId'] ?? '').toString().trim();
                            final turmasExtrasIds = List<String>.from(a['turmasExtrasIds'] ?? []);

                            if (turmaAluno == turmaNomeOficial || turmaAluno == turmaNomeAntigo || turmaIdAluno == idTurma || turmasExtrasIds.contains(idTurma)) {
                              alunosCount++;
                            }
                          }

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: arquivada ? Colors.red.shade200 : Colors.grey.shade300)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: arquivada ? Colors.red.shade50 : (isExtra ? Colors.purple.shade50 : Colors.blue.shade50),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isExtra ? Icons.extension_rounded : Icons.meeting_room_rounded,
                                      color: arquivada ? Colors.red : (isExtra ? Colors.purple : Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(child: Text('${turma['nome']} (${turma['anoLetivo']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                            if (isExtra)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.purple.shade600, borderRadius: BorderRadius.circular(4)),
                                                child: const Text('EXTRA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.meeting_room_outlined, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text('Sala: ${turma['sala'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                            const SizedBox(width: 12),
                                            Icon(Icons.people_alt_outlined, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text('$alunosCount Aluno(s)', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                            const SizedBox(width: 12),
                                            Icon(Icons.assignment_ind_outlined, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text('$profsCount Prof(s)', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(turma['turno'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: emFormacao ? Colors.orange.shade50 : (arquivada ? Colors.red.shade50 : Colors.green.shade50),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      statusTurma,
                                      style: TextStyle(
                                        color: emFormacao ? Colors.orange.shade700 : (arquivada ? Colors.red.shade700 : Colors.green.shade700),
                                        fontWeight: FontWeight.bold, fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_rounded, color: Colors.blueGrey),
                                        tooltip: 'Painel da Turma',
                                        onPressed: () => context.push('/admin/cadastros/turma/painel', extra: turma),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                        tooltip: 'Editar',
                                        onPressed: () => context.push('/admin/cadastros/turma/novo', extra: turma),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                        tooltip: 'Excluir',
                                        onPressed: () => _confirmarExclusao(context, turma),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMPONENTES DE MODAL REUTILIZADOS (BOLETIM E FREQUÊNCIA)
// ============================================================================
class _BoletimModal extends StatefulWidget {
  final String tenantId;
  final String turmaId;
  final String alunoDocId;
  final Color corPrimaria;
  final ScrollController scrollController;

  const _BoletimModal({required this.tenantId, required this.turmaId, required this.alunoDocId, required this.corPrimaria, required this.scrollController});

  @override
  State<_BoletimModal> createState() => _BoletimModalState();
}

class _BoletimModalState extends State<_BoletimModal> {
  String _bimestreAtivo = '1º Bimestre';

  String _calcularBimestre(DateTime data) {
    int mes = data.month;
    if (mes >= 2 && mes <= 4) return '1º Bimestre';
    if (mes >= 5 && mes <= 6) return '2º Bimestre';
    if (mes >= 7 && mes <= 9) return '3º Bimestre';
    return '4º Bimestre';
  }

  @override
  void initState() {
    super.initState();
    _bimestreAtivo = _calcularBimestre(DateTime.now());
  }

  Future<Map<String, dynamic>> _buscarDadosBoletim() async {
    final db = FirebaseFirestore.instance;
    final turmaRef = db.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId);
    
    final turmaSnap = await turmaRef.get();
    final avaliacoesSnap = await turmaRef.collection('avaliacoes').where('bimestre', isEqualTo: _bimestreAtivo).get();
    
    List<String> disciplinas = [];
    if (turmaSnap.exists) {
      final data = turmaSnap.data() as Map<String, dynamic>;
      if (data.containsKey('disciplinas') && data['disciplinas'] is List) {
        disciplinas = List<String>.from(data['disciplinas']);
      }
    }
    
    return {
      'disciplinas': disciplinas,
      'avaliacoes': avaliacoesSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList(),
    };
  }

  void _mostrarDetalhesDisciplina(String disciplina, List<Map<String, dynamic>> avaliacoes) {
    final avaliacoesFiltradas = avaliacoes.where((a) => a['contaParaMedia'] != false).toList();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(disciplina, style: TextStyle(fontWeight: FontWeight.bold, color: widget.corPrimaria)),
        content: SizedBox(
          width: double.maxFinite,
          child: avaliacoesFiltradas.isEmpty 
            ? const Text('Nenhuma avaliação lançada para a média nesta disciplina.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: avaliacoesFiltradas.length,
                separatorBuilder: (ctx, idx) => const Divider(),
                itemBuilder: (context, index) {
                  final a = avaliacoesFiltradas[index];
                  final nota = a['nota'];
                  final double max = a['maximo'];
                  final bool valida = a['valida'];
                  final bool isRec = a['isRecuperacao'];
                  final bool temNota = a['temNota'] ?? false;
                  
                  String sub = '';
                  if (isRec && valida) sub = 'Nota Substituta (Recuperação)';
                  if (isRec && !valida) sub = 'Descartada (Recuperação)';
                  if (!isRec && !valida) sub = 'Substituída';

                  final String textoNota = temNota ? '${nota.toStringAsFixed(1)} / ${max.toStringAsFixed(1)}' : '-';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a['nome'] ?? 'Avaliação', style: TextStyle(decoration: valida ? null : TextDecoration.lineThrough, color: valida ? Colors.black : Colors.grey)),
                    subtitle: sub.isNotEmpty ? Text(sub, style: TextStyle(color: valida ? Colors.purple : Colors.grey)) : null,
                    trailing: Text(textoNota, style: TextStyle(fontWeight: FontWeight.bold, decoration: valida ? null : TextDecoration.lineThrough, color: valida ? widget.corPrimaria : Colors.grey)),
                  );
                }
            )
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.analytics_rounded, color: widget.corPrimaria)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Meu Boletim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Notas consolidadas por disciplina', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ])),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '1º Bimestre', label: Text('1º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '2º Bimestre', label: Text('2º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '3º Bimestre', label: Text('3º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '4º Bimestre', label: Text('4º Bim', style: TextStyle(fontSize: 12)))
              ],
              selected: {_bimestreAtivo}, 
              onSelectionChanged: (s) => setState(() => _bimestreAtivo = s.first),
              style: SegmentedButton.styleFrom(selectedBackgroundColor: widget.corPrimaria.withAlpha(40), selectedForegroundColor: widget.corPrimaria),
            ),
          ),
        ),

        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _buscarDadosBoletim(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
              
              final dados = snapshot.data ?? {};
              final List<String> disciplinasTurma = dados['disciplinas'] ?? [];
              final List<Map<String, dynamic>> avaliacoes = dados['avaliacoes'] ?? [];

              Map<String, List<Map<String, dynamic>>> avaliacoesPorDisciplina = {};
              
              for (var d in disciplinasTurma) {
                avaliacoesPorDisciplina[d] = [];
              }
              
              for (var aval in avaliacoes) {
                final disciplina = aval['disciplina'] ?? 'Geral';
                final maximo = double.tryParse(aval['pontuacaoMaxima']?.toString() ?? '10') ?? 10.0;
                final isRecuperacao = aval['isRecuperacao'] == true;
                final contaParaMedia = aval['contaParaMedia'] ?? true;
                
                final notasMap = Map<String, dynamic>.from(aval['notas'] ?? {});
                final notaRaw = notasMap[widget.alunoDocId];
                final bool temNotaLancada = notaRaw != null && notaRaw.toString().isNotEmpty;
                final notaAluno = double.tryParse(notaRaw?.toString() ?? '0') ?? 0.0;

                if (!avaliacoesPorDisciplina.containsKey(disciplina)) {
                  avaliacoesPorDisciplina[disciplina] = [];
                }
                
                avaliacoesPorDisciplina[disciplina]!.add({
                  'nome': aval['nome'] ?? 'Avaliação',
                  'nota': notaAluno,
                  'maximo': maximo,
                  'isRecuperacao': isRecuperacao,
                  'contaParaMedia': contaParaMedia,
                  'valida': true,
                  'temNota': temNotaLancada,
                });
              }

              if (avaliacoesPorDisciplina.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Nenhuma disciplina ou nota neste bimestre.', style: TextStyle(color: Colors.grey.shade500))]));
              }

              Map<String, Map<String, dynamic>> boletim = {};

              for (var disciplina in avaliacoesPorDisciplina.keys) {
                var notasDaDisciplina = avaliacoesPorDisciplina[disciplina]!;
                
                var recuperacoes = notasDaDisciplina.where((n) => n['isRecuperacao'] == true && n['contaParaMedia'] != false).toList();
                var normais = notasDaDisciplina.where((n) => n['isRecuperacao'] != true && n['contaParaMedia'] != false).toList();

                for (var rec in recuperacoes) {
                  if (normais.isEmpty) continue;
                  
                  normais.sort((a, b) => ((a['nota'] / a['maximo']).compareTo(b['nota'] / b['maxima'])));
                  var piorNormal = normais.first;

                  double aproveitamentoRec = rec['maximo'] > 0 ? rec['nota'] / rec['maximo'] : 0.0;
                  double aproveitamentoPiorNormal = piorNormal['maximo'] > 0 ? piorNormal['nota'] / piorNormal['maximo'] : 0.0;

                  if (aproveitamentoRec > aproveitamentoPiorNormal) {
                    piorNormal['valida'] = false; 
                  } else {
                    rec['valida'] = false; 
                  }
                }

                double somaNotas = 0.0;
                double somaMaximos = 0.0;
                bool possuiAlgumaNota = false;

                for (var n in notasDaDisciplina) {
                  if (n['contaParaMedia'] != false && n['valida'] == true) {
                    if (n['temNota'] == true) {
                      possuiAlgumaNota = true;
                    }
                    somaNotas += n['nota'];
                    somaMaximos += n['maximo'];
                  }
                }
                
                double notaBoletim = somaNotas;
                if (notaBoletim > 10.0) notaBoletim = 10.0;

                boletim[disciplina] = {
                  'notaAluno': possuiAlgumaNota ? notaBoletim : null, 
                  'maximo': somaMaximos, 
                  'somaBruta': somaNotas,
                  'avaliacoes': notasDaDisciplina
                };
              }

              final disciplinasOrdem = boletim.keys.toList()..sort();

              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: disciplinasOrdem.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final disciplina = disciplinasOrdem[index];
                  final dados = boletim[disciplina]!;
                  final notaAluno = dados['notaAluno'] as double?;
                  final maximo = dados['maximo'] as double;
                  final somaBruta = dados['somaBruta'] as double;
                  final listaAvals = dados['avaliacoes'] as List<Map<String, dynamic>>;
                  
                  final bool acimaMedia = notaAluno != null && notaAluno >= 6.0; 
                  final Color corNota = notaAluno == null ? Colors.grey : (acimaMedia ? Colors.green.shade700 : Colors.red.shade700);
                  
                  final String textoNota = notaAluno != null ? '${notaAluno.toStringAsFixed(1)} / 10.0' : '-';

                  return InkWell(
                    onTap: () => _mostrarDetalhesDisciplina(disciplina, listaAvals),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.menu_book_rounded, color: Colors.blueGrey.shade300, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(disciplina, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(notaAluno == null ? 'Aguardando lançamento de notas' : 'Pontos: ${somaBruta.toStringAsFixed(1)} / ${maximo.toStringAsFixed(1)} distribuídos', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                    ]
                                  )
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: corNota.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              textoNota, 
                              style: TextStyle(color: corNota, fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}

class _FrequenciaModal extends StatefulWidget {
  final String tenantId;
  final String turmaId;
  final String alunoMatricula;
  final Color corPrimaria;
  final ScrollController scrollController;

  const _FrequenciaModal({
    required this.tenantId,
    required this.turmaId,
    required this.alunoMatricula,
    required this.corPrimaria,
    required this.scrollController,
  });

  @override
  State<_FrequenciaModal> createState() => _FrequenciaModalState();
}

class _FrequenciaModalState extends State<_FrequenciaModal> {
  String _bimestreAtivo = '1º Bimestre';
  int _mesAtivo = DateTime.now().month;

  List<int> _getMesesDoBimestre(String bimestre) {
    if (bimestre == '1º Bimestre') return [1, 2, 3, 4];
    if (bimestre == '2º Bimestre') return [5, 6];
    if (bimestre == '3º Bimestre') return [7, 8, 9];
    return [10, 11, 12];
  }

  String _getNomeMes(int mes) {
    const nomes = {
      1: 'Janeiro', 2: 'Fevereiro', 3: 'Março', 4: 'Abril',
      5: 'Maio', 6: 'Junho', 7: 'Julho', 8: 'Agosto',
      9: 'Setembro', 10: 'Outubro', 11: 'Novembro', 12: 'Dezembro'
    };
    return nomes[mes] ?? '';
  }

  String _calcularBimestre(DateTime data) {
    int mes = data.month;
    if (mes >= 1 && mes <= 4) return '1º Bimestre';
    if (mes >= 5 && mes <= 6) return '2º Bimestre';
    if (mes >= 7 && mes <= 9) return '3º Bimestre';
    return '4º Bimestre';
  }

  String _obterDiaSemanaAbrev(int weekday) {
    switch (weekday) {
      case 1: return 'Seg';
      case 2: return 'Ter';
      case 3: return 'Qua';
      case 4: return 'Qui';
      case 5: return 'Sex';
      case 6: return 'Sáb';
      case 7: return 'Dom';
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _bimestreAtivo = _calcularBimestre(DateTime.now());
    
    final mesesDoBimestre = _getMesesDoBimestre(_bimestreAtivo);
    if (!mesesDoBimestre.contains(_mesAtivo)) {
      _mesAtivo = mesesDoBimestre.last;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesesValidos = _getMesesDoBimestre(_bimestreAtivo);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: widget.corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.fact_check_rounded, color: widget.corPrimaria)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Frequência Escolar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Acompanhamento de faltas por matéria', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ])),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '1º Bimestre', label: Text('1º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '2º Bimestre', label: Text('2º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '3º Bimestre', label: Text('3º Bim', style: TextStyle(fontSize: 12))), 
                ButtonSegment(value: '4º Bimestre', label: Text('4º Bim', style: TextStyle(fontSize: 12)))
              ],
              selected: {_bimestreAtivo}, 
              onSelectionChanged: (s) {
                setState(() {
                  _bimestreAtivo = s.first;
                  _mesAtivo = _getMesesDoBimestre(_bimestreAtivo).first;
                });
              },
              style: SegmentedButton.styleFrom(selectedBackgroundColor: widget.corPrimaria.withAlpha(40), selectedForegroundColor: widget.corPrimaria),
            ),
          ),
        ),

        // Sub-aba de Meses
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: mesesValidos.map((m) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_getNomeMes(m)),
                selected: _mesAtivo == m,
                selectedColor: widget.corPrimaria.withAlpha(40),
                labelStyle: TextStyle(
                  color: _mesAtivo == m ? widget.corPrimaria : Colors.black87,
                  fontWeight: _mesAtivo == m ? FontWeight.bold : FontWeight.normal
                ),
                onSelected: (val) {
                  if (val) setState(() => _mesAtivo = m);
                }
              ),
            )).toList(),
          ),
        ),

        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('tenants').doc(widget.tenantId).collection('turmas').doc(widget.turmaId).collection('diarios').get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: widget.corPrimaria));
              
              int currentYear = DateTime.now().year;
              
              Map<String, List<Map<String, dynamic>>> diariPorDiaGeral = {}; 
              Map<String, List<Map<String, dynamic>>> frequenciaPorDisciplina = {};

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final docIdPartes = doc.id.split('_');
                  final dataDiarioStr = docIdPartes[0]; 
                  
                  try {
                    final p = dataDiarioStr.split('-');
                    final docYear = int.parse(p[0]);
                    final docMonth = int.parse(p[1]);
                    currentYear = docYear; 

                    if (data['status'] != 'NAO_INICIADA' && docMonth == _mesAtivo) {
                      final freq = Map<String, String>.from(data['frequencia'] ?? {});
                      final st = freq[widget.alunoMatricula] ?? 'P';
                      final disciplina = data['disciplina']?.toString() ?? 'Geral';
                      
                      if (!frequenciaPorDisciplina.containsKey(disciplina)) frequenciaPorDisciplina[disciplina] = [];
                      frequenciaPorDisciplina[disciplina]!.add({
                        'idSort': dataDiarioStr,
                        'data': "${p[2]}/${p[1]} (${_obterDiaSemanaAbrev(DateTime(docYear, docMonth, int.parse(p[2])).weekday)})", 
                        'status': st 
                      });

                      if (!diariPorDiaGeral.containsKey(dataDiarioStr)) diariPorDiaGeral[dataDiarioStr] = [];
                      diariPorDiaGeral[dataDiarioStr]!.add(data);
                    }
                  } catch (_) {}
                }
              }

              // ==========================================
              // CÁLCULO DA ABA GERAL (Todos os dias do mês)
              // ==========================================
              int daysInMonth = DateUtils.getDaysInMonth(currentYear, _mesAtivo);
              List<Map<String, dynamic>> diasGeralList = [];
              int totalDiasComAula = 0;
              int faltasGeral = 0;
              int presencasGeral = 0;

              for (int d = 1; d <= daysInMonth; d++) {
                final dataAtual = DateTime(currentYear, _mesAtivo, d);
                final dateStr = "$currentYear-${_mesAtivo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
                final diaSemana = _obterDiaSemanaAbrev(dataAtual.weekday);
                final displayDate = "${d.toString().padLeft(2, '0')}/${_mesAtivo.toString().padLeft(2, '0')} ($diaSemana)";

                if (diariPorDiaGeral.containsKey(dateStr)) {
                  totalDiasComAula++;
                  final aulasDoDia = diariPorDiaGeral[dateStr]!;
                  bool temP = false;
                  bool temA = false;
                  
                  for (var aula in aulasDoDia) {
                    final freq = Map<String, String>.from(aula['frequencia'] ?? {});
                    final st = freq[widget.alunoMatricula] ?? 'P';
                    if (st == 'P') temP = true;
                    else if (st == 'A') temA = true;
                  }

                  String statusDia = 'P';
                  if (temP) {
                    statusDia = 'P';
                    presencasGeral++;
                  } else if (temA) {
                    statusDia = 'A';
                    faltasGeral++;
                  } else {
                    statusDia = 'J';
                    faltasGeral++; 
                  }

                  diasGeralList.add({
                    'display': displayDate,
                    'status': statusDia,
                  });
                } else {
                  diasGeralList.add({
                    'display': displayDate,
                    'status': 'SEM_AULA',
                  });
                }
              }

              final double percPresencaGeral = totalDiasComAula == 0 ? 100.0 : (presencasGeral / totalDiasComAula) * 100;

              // FILTRA A MATÉRIA 'GERAL' DA LISTA DE SANFONAS (pois agora temos o Visão Geral do Mês)
              final disciplinasKeys = frequenciaPorDisciplina.keys
                  .where((k) => k.toUpperCase() != 'GERAL')
                  .toList()..sort();
              
              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: disciplinasKeys.length + 1, 
                itemBuilder: (context, index) {

                  // =======================
                  // ABA GERAL (Primeiro Item)
                  // =======================
                  if (index == 0) {
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: faltasGeral > 0, 
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: const Text('Visão Geral do Mês', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Text(
                                  'Faltas: $faltasGeral / $totalDiasComAula', 
                                  style: TextStyle(color: faltasGeral > 0 ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Presença: ${percPresencaGeral.toStringAsFixed(1)}%', 
                                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)
                                ),
                              ],
                            ),
                          ),
                          children: diasGeralList.map((d) {
                            final status = d['status'];
                            
                            if (status == 'SEM_AULA') {
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                leading: Icon(Icons.event_busy_rounded, color: Colors.grey.shade300, size: 20),
                                title: Text(d['display'], style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500, fontSize: 13)),
                                trailing: Text('-', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 16)),
                              );
                            }

                            Color corStatus = Colors.green; 
                            String textoStatus = 'Presente'; 
                            IconData iconeStatus = Icons.check_circle_rounded;

                            if (status == 'A') { corStatus = Colors.red; textoStatus = 'Falta'; iconeStatus = Icons.cancel_rounded; } 
                            else if (status == 'J') { corStatus = Colors.orange; textoStatus = 'Falta Justificada'; iconeStatus = Icons.info_rounded; }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              leading: Icon(Icons.event_available_rounded, color: Colors.grey.shade400, size: 20),
                              title: Text(d['display'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                decoration: BoxDecoration(color: corStatus.withAlpha(30), borderRadius: BorderRadius.circular(8)), 
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(iconeStatus, color: corStatus, size: 14), const SizedBox(width: 4),
                                    Text(textoStatus, style: TextStyle(color: corStatus, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                )
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }

                  // =======================
                  // DISCIPLINAS ESPECÍFICAS
                  // =======================
                  final disc = disciplinasKeys[index - 1];
                  final aulas = frequenciaPorDisciplina[disc]!..sort((a,b) => b['idSort']!.compareTo(a['idSort']!));
                  
                  final int totalAulas = aulas.length;
                  final int faltas = aulas.where((f) => f['status'] == 'A' || f['status'] == 'J').length;
                  final int presencas = totalAulas - faltas;
                  final double percPresenca = totalAulas == 0 ? 100.0 : (presencas / totalAulas) * 100;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: faltas > 0, 
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(disc.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text(
                                'Faltas: $faltas / $totalAulas', 
                                style: TextStyle(color: faltas > 0 ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Presença: ${percPresenca.toStringAsFixed(1)}%', 
                                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)
                              ),
                            ],
                          ),
                        ),
                        children: aulas.map((f) {
                          final status = f['status'];
                          Color corStatus = Colors.green; 
                          String textoStatus = 'Presente'; 
                          IconData iconeStatus = Icons.check_circle_rounded;

                          if (status == 'A') { corStatus = Colors.red; textoStatus = 'Falta'; iconeStatus = Icons.cancel_rounded; } 
                          else if (status == 'J') { corStatus = Colors.orange; textoStatus = 'Falta Justificada'; iconeStatus = Icons.info_rounded; }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            leading: Icon(Icons.event_available_rounded, color: Colors.grey.shade400, size: 20),
                            title: Text(f['data'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                              decoration: BoxDecoration(color: corStatus.withAlpha(30), borderRadius: BorderRadius.circular(8)), 
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(iconeStatus, color: corStatus, size: 14), const SizedBox(width: 4),
                                  Text(textoStatus, style: TextStyle(color: corStatus, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}