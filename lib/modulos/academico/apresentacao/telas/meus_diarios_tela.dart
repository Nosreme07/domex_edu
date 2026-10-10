import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// Importações cruciais para a geração de PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// FUNÇÕES AUXILIARES GLOBAIS DE ANEXO
// ============================================================================
Future<void> _abrirLink(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    // externalApplication força o sistema a baixar o arquivo na web ou no mobile
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// Visualizador Unificado de Imagem e PDF com botão de Download
void _mostrarAnexoAmpliadoGlobal(BuildContext context, String url, bool isPdf, Color corPrimaria) {
  if (url.isEmpty) return;
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho do Modal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: corPrimaria, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isPdf ? 'Visualizador de PDF' : 'Visualizador de Imagem', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            
            // Área de Visualização (Zoom para Imagens)
            Flexible(
              child: Container(
                width: double.infinity,
                color: Colors.grey.shade100,
                child: isPdf
                    ? Padding(
                        padding: const EdgeInsets.all(48.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 80),
                            const SizedBox(height: 16),
                            const Text('Arquivo em formato PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 8),
                            const Text('Toque no botão abaixo para baixar ou visualizar o arquivo detalhadamente.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      )
                    : ClipRRect(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48)),
                          ),
                        ),
                      ),
              ),
            ),
            
            // Rodapé com o Botão de Download
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: corPrimaria, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _abrirLink(url),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(isPdf ? 'Fazer Download / Abrir PDF' : 'Baixar Imagem', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            )
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// TELA PRINCIPAL: MEUS DIÁRIOS
// ============================================================================
class MeusDiariosTela extends ConsumerStatefulWidget {
  const MeusDiariosTela({super.key});

  @override
  ConsumerState<MeusDiariosTela> createState() => _MeusDiariosTelaState();
}

class _MeusDiariosTelaState extends ConsumerState<MeusDiariosTela> {
  String _termoPesquisa = '';
  List<Map<String, dynamic>> _todosMeusDiarios = [];
  bool _carregando = true;
  int _limiteExibicao = 5;

  @override
  void initState() {
    super.initState();
    _buscarMeusDiarios();
  }

  String _formatarDataBR(String dataBanco) {
    if (dataBanco.isEmpty) return '';
    try {
      final p = dataBanco.split('-');
      if (p.length == 3) {
        return '${p[2]}/${p[1]}/${p[0]}';
      }
    } catch (_) {}
    return dataBanco;
  }

  Future<void> _buscarMeusDiarios() async {
    setState(() => _carregando = true);
    try {
      final user = ref.read(authProvider).value;
      if (user == null) return;

      final tenantId = user.tenantId;
      final profId = user.id;

      final db = FirebaseFirestore.instance;
      final turmasSnap = await db.collection('tenants').doc(tenantId).collection('turmas').get();

      List<Map<String, dynamic>> diariosEncontrados = [];
      List<Future<void>> operacoesParalelas = [];

      for (var turmaDoc in turmasSnap.docs) {
        operacoesParalelas.add(() async {
          final turmaData = turmaDoc.data();
          if (turmaData['status'] == 'Inativa') return;

          final vinculados = turmaData['professoresVinculados'] as List<dynamic>? ?? [];
          List<String> minhasDisciplinasAqui = [];
          
          for (var v in vinculados) {
            final vinculacao = v as Map<String, dynamic>;
            if ((vinculacao['professorId'] ?? '').toString() == profId || (vinculacao['professorNome'] ?? '').toString() == user.nome) {
              minhasDisciplinasAqui.add((vinculacao['disciplina'] ?? '').toString().toUpperCase());
            }
          }

          if (minhasDisciplinasAqui.isEmpty) return;

          final diariosSnap = await turmaDoc.reference.collection('diarios').get();

          for (var diarioDoc in diariosSnap.docs) {
            final d = diarioDoc.data();
            final status = (d['status'] ?? 'NAO_INICIADA').toString();
            final disciplinaDiario = (d['disciplina'] ?? 'Geral').toString().toUpperCase();

            if (status != 'NAO_INICIADA' && (minhasDisciplinasAqui.contains(disciplinaDiario) || minhasDisciplinasAqui.contains('GERAL'))) {
              
              String dataBanco = (d['dataDiario'] ?? '').toString();
              if (dataBanco.isEmpty && diarioDoc.id.contains('_')) {
                dataBanco = diarioDoc.id.split('_')[0];
              }

              List<String> anexosUrls = [];
              final lstAnexos = d['anexosUrl'] as List<dynamic>? ?? [];
              for (var item in lstAnexos) {
                anexosUrls.add(item.toString());
              }
              if (d['anexoUrl'] != null && d['anexoUrl'].toString().isNotEmpty && anexosUrls.isEmpty) {
                anexosUrls.add(d['anexoUrl'].toString());
              }

              diariosEncontrados.add({
                'id': diarioDoc.id,
                'turmaNome': '${turmaData['nome']} (${turmaData['anoLetivo']})',
                'turno': (turmaData['turno'] ?? 'N/A').toString(),
                'disciplina': (d['disciplina'] ?? 'Geral').toString(),
                'data': dataBanco,
                'dataExibicao': _formatarDataBR(dataBanco),
                'conteudo': (d['conteudo'] ?? 'Sem conteúdo registrado.').toString(),
                'anexosUrls': anexosUrls,
                'status': status,
              });
            }
          }
        }());
      }

      await Future.wait(operacoesParalelas);

      diariosEncontrados.sort((a, b) => (b['data'] as String).compareTo(a['data'] as String));

      if (mounted) {
        setState(() {
          _todosMeusDiarios = diariosEncontrados;
          _carregando = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar diários: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ==========================================================================
  // FUNÇÃO DE GERAÇÃO DO PDF OTIMIZADO PARA 1 PÁGINA (Letras Menores)
  // ==========================================================================
  Future<void> _exportarDiarioPdf(BuildContext context, Map<String, dynamic> diario, Color corPrimaria) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final user = ref.read(authProvider).value;
      if (user == null) throw Exception("Usuário não está logado.");

      // 1. Buscar Dados Globais da Instituição
      final tenantDoc = await FirebaseFirestore.instance.collection('tenants').doc(user.tenantId).get();
      final tenantData = tenantDoc.data() ?? <String, dynamic>{};
      final nomeEscola = (tenantData['nomeEscola'] ?? user.nomeEscola ?? 'ESCOLA').toString();
      final logoUrl = (tenantData['logoUrl'] ?? tenantData['fotoUrl'] ?? tenantData['logo'] ?? '').toString();

      pw.ImageProvider? logoProvider;
      if (logoUrl.isNotEmpty) {
        try {
          logoProvider = await networkImage(logoUrl);
        } catch (_) {}
      }

      // 2. Extrair Imagens Anexadas ao Diário (Assincronamente e em Paralelo)
      final anexosUrls = diario['anexosUrls'] as List<String>? ?? [];
      final futuresImages = anexosUrls.where((url) => !url.toLowerCase().contains('.pdf')).map((url) async {
        try {
          return await networkImage(url);
        } catch (_) {
          return null; 
        }
      });
      
      final resolvedImages = await Future.wait(futuresImages);
      final List<pw.ImageProvider> anexosImages = resolvedImages.whereType<pw.ImageProvider>().toList();

      // 3. Montar a Estrutura do PDF
      final pdf = pw.Document();
      final pdfCorPrimaria = PdfColor.fromInt(corPrimaria.value);
      final dataGeracao = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final profNome = (user.nome ?? 'Professor').toString();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24), // Margem da folha reduzida
          
          // CABEÇALHO COM LOGO E NOME DA ESCOLA
          header: (context) {
            return pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoProvider != null)
                      pw.Container(
                        width: 40, height: 40, // Logo menorzinha
                        child: pw.Image(logoProvider),
                      ),
                    if (logoProvider != null) pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Text(
                        nomeEscola.toUpperCase(),
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: pdfCorPrimaria), // Fonte da escola menor
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                pw.SizedBox(height: 12),
              ],
            );
          },
          
          // RODAPÉ COM CARIMBO DE SISTEMA
          footer: (context) {
            return pw.Column(
              children: [
                pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Gerado pelo sistema DOMEX EDU - $dataGeracao', 
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600) // Texto super discreto no rodapé
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}', 
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)
                  ),
                ),
              ],
            );
          },
          
          // CORPO PRINCIPAL DO DIÁRIO (FONTES AJUSTADAS)
          build: (context) {
            return [
              pw.Center(
                child: pw.Text('DIÁRIO DE CLASSE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: pdfCorPrimaria)),
              ),
              pw.SizedBox(height: 16),
              
              pw.Container(
                padding: const pw.EdgeInsets.all(8), // Mais apertado e limpo
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Turma:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                              pw.Text('${diario['turmaNome']} - ${diario['turno']}', style: const pw.TextStyle(fontSize: 10)),
                              pw.SizedBox(height: 6),
                              pw.Text('Professor(a):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                              pw.Text(profNome, style: const pw.TextStyle(fontSize: 10)),
                            ],
                          )
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Disciplina:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                              pw.Text(diario['disciplina'].toString(), style: const pw.TextStyle(fontSize: 10)),
                              pw.SizedBox(height: 6),
                              pw.Text('Data da Aula:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                              pw.Text(diario['dataExibicao'].toString(), style: const pw.TextStyle(fontSize: 10)),
                            ],
                          )
                        ),
                      ]
                    )
                  ]
                )
              ),
              
              pw.SizedBox(height: 16),
              pw.Text('CONTEÚDO LECIONADO:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfCorPrimaria)),
              pw.SizedBox(height: 4),
              // Diminuiu o espaçamento das linhas de conteudo
              pw.Text(diario['conteudo'].toString(), style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5)), 

              if (anexosImages.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text('ANEXOS E REGISTROS DA AULA:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: pdfCorPrimaria)),
                pw.SizedBox(height: 8),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: anexosImages.map((img) {
                    return pw.Container(
                      width: 160, // Largura exata para caber 3 imagens na mesma linha da A4!
                      height: 110,
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                      child: pw.Image(img, fit: pw.BoxFit.cover),
                    );
                  }).toList(),
                )
              ]
            ];
          },
        ),
      );

      // Fecha o modal de carregamento
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Abre a tela de pré-visualização ou download nativo
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Diario_${diario['disciplina']}_${diario['dataExibicao'].toString().replaceAll('/', '-')}.pdf',
      );

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Fecha loading em caso de erro
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;

    // Aplica o filtro de pesquisa
    final listaFiltrada = _todosMeusDiarios.where((d) {
      if (_termoPesquisa.isEmpty) return true;
      final busca = _termoPesquisa.toLowerCase();
      final conteudo = d['conteudo'].toString().toLowerCase();
      final turma = d['turmaNome'].toString().toLowerCase();
      final disciplina = d['disciplina'].toString().toLowerCase();
      final data = d['dataExibicao'].toString().toLowerCase();

      return conteudo.contains(busca) || turma.contains(busca) || disciplina.contains(busca) || data.contains(busca);
    }).toList();

    final int totalItens = listaFiltrada.length;
    final int qtdExibidos = totalItens > _limiteExibicao ? _limiteExibicao : totalItens;
    final bool temMais = totalItens > _limiteExibicao;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Meus Diários de Classe', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _carregando
          ? Center(child: CircularProgressIndicator(color: corPrimaria))
          : Column(
              children: [
                // Barra de Pesquisa Fixa no Topo
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: corPrimaria,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Histórico de Aulas Lecionadas',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Encontre facilmente os registros das suas aulas passadas.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (v) {
                          setState(() {
                            _termoPesquisa = v;
                            _limiteExibicao = 5;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Pesquisar por data, turma, matéria ou conteúdo...',
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Lista de Diários em Estilo Cascata
                Expanded(
                  child: listaFiltrada.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                _termoPesquisa.isEmpty ? 'Você ainda não preencheu nenhum diário.' : 'Nenhum resultado encontrado.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: qtdExibidos + (temMais ? 1 : 0),
                          separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            
                            // Botão de Expandir Histórico
                            if (index == qtdExibidos) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: corPrimaria,
                                    backgroundColor: corPrimaria.withAlpha(20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 16)
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _limiteExibicao = totalItens;
                                    });
                                  },
                                  icon: const Icon(Icons.history_rounded),
                                  label: const Text('Ver Histórico Completo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              );
                            }

                            final diario = listaFiltrada[index];
                            final List<String> anexosUrls = diario['anexosUrls'] as List<String>;
                            final bool temAnexos = anexosUrls.isNotEmpty;

                            return Card(
                              elevation: 0,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: corPrimaria.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(Icons.menu_book_rounded, color: corPrimaria),
                                  ),
                                  title: Text(
                                    '${diario['turmaNome']} - ${diario['dataExibicao']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                          child: Text(
                                            diario['disciplina'].toString(), 
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 11)
                                          ),
                                        ),
                                        if (temAnexos) ...[
                                          const SizedBox(width: 8),
                                          Icon(Icons.attach_file_rounded, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text('${anexosUrls.length}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ]
                                      ],
                                    ),
                                  ),
                                  children: [
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Conteúdo Lecionado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        diario['conteudo'].toString(),
                                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                                      ),
                                    ),
                                    
                                    // Visualização de Miniaturas com Popup Dinâmico
                                    if (temAnexos) ...[
                                      const SizedBox(height: 16),
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Anexos (Fotos do Quadro / Materiais):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Wrap(
                                          spacing: 12, runSpacing: 12,
                                          children: anexosUrls.map((url) {
                                            final bool isPdf = url.toLowerCase().contains('.pdf');
                                            
                                            return Tooltip(
                                              message: 'Clique para expandir e baixar',
                                              child: InkWell(
                                                onTap: () => _mostrarAnexoAmpliadoGlobal(context, url, isPdf, corPrimaria),
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  width: 80, height: 80,
                                                  decoration: BoxDecoration(
                                                    color: isPdf ? Colors.red.shade50 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                    image: !isPdf 
                                                        ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                                                        : null,
                                                  ),
                                                  child: Stack(
                                                    children: [
                                                      if (isPdf)
                                                        const Center(child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 36)),
                                                      Positioned(
                                                        bottom: 0, left: 0, right: 0,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withAlpha(150),
                                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                                                          ),
                                                          child: Text(isPdf ? 'PDF' : 'FOTO', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 24),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    
                                    // BOTÃO EXPORTAR PDF DA AULA
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade50,
                                          foregroundColor: Colors.blue.shade700,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                                        ),
                                        onPressed: () => _exportarDiarioPdf(context, diario, corPrimaria),
                                        icon: const Icon(Icons.picture_as_pdf_rounded),
                                        label: const Text('Exportar para PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    )
                                  ],
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