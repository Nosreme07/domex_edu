import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// FUNÇÕES AUXILIARES DE ANEXO
// ============================================================================
Future<void> _abrirLink(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

void _mostrarFotoAmpliadaGlobal(BuildContext context, String? url) {
  if (url == null || url.isEmpty) return;
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

      for (var turmaDoc in turmasSnap.docs) {
        final turmaData = turmaDoc.data();
        if (turmaData['status'] == 'Inativa') continue;

        // Verifica se o professor dá aula nesta turma e guarda as disciplinas dele
        final vinculados = turmaData['professoresVinculados'] as List? ?? [];
        List<String> minhasDisciplinasAqui = [];
        
        for (var v in vinculados) {
          if (v['professorId'] == profId || v['professorNome'] == user.nome) {
            minhasDisciplinasAqui.add((v['disciplina'] ?? '').toString().toUpperCase());
          }
        }

        // Se ele não dá aula nesta turma, salta para a próxima
        if (minhasDisciplinasAqui.isEmpty) continue;

        // Vai buscar os diários da turma
        final diariosSnap = await turmaDoc.reference.collection('diarios').get();

        for (var diarioDoc in diariosSnap.docs) {
          final d = diarioDoc.data();
          final status = d['status'] ?? 'NAO_INICIADA';
          final disciplinaDiario = (d['disciplina'] ?? 'Geral').toString().toUpperCase();

          // Só mostra se o Diário foi preenchido E se a disciplina do diário for uma das que ele leciona
          if (status != 'NAO_INICIADA' && (minhasDisciplinasAqui.contains(disciplinaDiario) || minhasDisciplinasAqui.contains('GERAL'))) {
            
            // Extrair a data do ID do documento ou do campo dataDiario
            String dataBanco = d['dataDiario'] ?? '';
            if (dataBanco.isEmpty && diarioDoc.id.contains('_')) {
              dataBanco = diarioDoc.id.split('_')[0];
            }

            diariosEncontrados.add({
              'id': diarioDoc.id,
              'turmaNome': '${turmaData['nome']} (${turmaData['anoLetivo']})',
              'disciplina': d['disciplina'] ?? 'Geral',
              'data': dataBanco,
              'dataExibicao': _formatarDataBR(dataBanco),
              'conteudo': d['conteudo'] ?? 'Sem conteúdo registrado.',
              'anexoUrl': d['anexoUrl'] ?? '',
              'status': status,
            });
          }
        }
      }

      // Ordenar do mais recente para o mais antigo
      diariosEncontrados.sort((a, b) => b['data'].compareTo(a['data']));

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
                // Barra de Pesquisa
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
                            _limiteExibicao = 5; // Reseta o limite ao buscar
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
                
                // Lista de Diários
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
                            
                            // Botão de carregar mais
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
                                  label: const Text(
                                    'Ver Histórico Completo', 
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                                  ),
                                ),
                              );
                            }

                            final diario = listaFiltrada[index];
                            final String anexoUrl = diario['anexoUrl'];
                            final bool temAnexo = anexoUrl.isNotEmpty;
                            final bool isPdf = anexoUrl.toLowerCase().contains('.pdf');

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
                                            diario['disciplina'], 
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 11)
                                          ),
                                        ),
                                        if (temAnexo) ...[
                                          const SizedBox(width: 8),
                                          Icon(Icons.attach_file_rounded, size: 14, color: Colors.grey.shade500),
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
                                        diario['conteudo'],
                                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                                      ),
                                    ),
                                    
                                    // Se houver anexo
                                    if (temAnexo) ...[
                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: InkWell(
                                          onTap: () {
                                            if (isPdf) {
                                              _abrirLink(anexoUrl);
                                            } else {
                                              _mostrarFotoAmpliadaGlobal(context, anexoUrl);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: isPdf ? Colors.red : Colors.blue, size: 24),
                                                const SizedBox(width: 8),
                                                const Text('Ver Anexo / Foto do Quadro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]
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