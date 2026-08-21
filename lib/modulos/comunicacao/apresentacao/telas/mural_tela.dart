import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../estado/mural_provider.dart';

// Função auxiliar simples para formatar a data sem depender do pacote intl nesta etapa
String _formatarData(DateTime data) {
  return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
}

class MuralTela extends ConsumerStatefulWidget {
  const MuralTela({super.key});

  @override
  ConsumerState<MuralTela> createState() => _MuralTelaState();
}

class _MuralTelaState extends ConsumerState<MuralTela> {
  @override
  void initState() {
    super.initState();
    // Dispara a busca dos avisos ao entrar na tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(muralControllerProvider.notifier).carregarMural();
    });
  }

  void _abrirAviso(BuildContext context, dynamic aviso, Color corPrimaria) {
    // Se o aviso ainda não foi lido, dispara a confirmação legal no backend
    if (!aviso.foiLido) {
      ref.read(muralControllerProvider.notifier).marcarComoLido(aviso.id);
    }

    // Exibe o comunicado completo em um BottomSheet moderno
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24, left: 24, right: 24,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                aviso.titulo,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: corPrimaria),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(aviso.autor, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              const Divider(height: 32),
              Text(
                aviso.conteudo,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar e Confirmar Ciente'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estadoMural = ref.watch(muralControllerProvider);
    final corPrimaria = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mural de Avisos'),
      ),
      body: estadoMural.when(
        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
        error: (erro, _) => Center(child: Text('Erro: $erro')),
        data: (avisos) {
          if (avisos.isEmpty) return const Center(child: Text('Nenhum aviso no momento.'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: avisos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final aviso = avisos[index];
              final naoLido = !aviso.foiLido;

              return Card(
                elevation: naoLido ? 3 : 0, // Avisos não lidos saltam aos olhos
                color: naoLido ? Colors.white : Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: naoLido ? corPrimaria.withOpacity(0.5) : Colors.grey.shade200),
                ),
                child: InkWell(
                  onTap: () => _abrirAviso(context, aviso, corPrimaria),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Etiqueta de "NOVO" ou Ícone de "Lido"
                            naoLido 
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: corPrimaria.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'NOVO',
                                    style: TextStyle(color: corPrimaria, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : const Icon(Icons.done_all_rounded, size: 16, color: Colors.blue),
                              
                            Text(
                              _formatarData(aviso.dataEnvio),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          aviso.titulo,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: naoLido ? FontWeight.bold : FontWeight.w500,
                            color: naoLido ? Colors.black87 : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          aviso.conteudo,
                          maxLines: 2, // Mostra só um resumo no feed
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}