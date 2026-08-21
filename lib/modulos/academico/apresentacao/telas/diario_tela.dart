import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../estado/diario_provider.dart';

class DiarioTela extends ConsumerStatefulWidget {
  final String idTurma; // Ex: 'turma_101'
  
  const DiarioTela({
    super.key, 
    required this.idTurma,
  });

  @override
  ConsumerState<DiarioTela> createState() => _DiarioTelaState();
}

class _DiarioTelaState extends ConsumerState<DiarioTela> {
  late String _dataHojeStr;

  @override
  void initState() {
    super.initState();
    // Formata a data atual (Ex: 2026-08-13)
    _dataHojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Dispara o carregamento dos alunos assim que a tela abre
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(diarioControllerProvider.notifier).carregarTurma(widget.idTurma, _dataHojeStr);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuta a lista de alunos
    final estadoDiario = ref.watch(diarioControllerProvider);
    final corPrimaria = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Diário de Classe', style: TextStyle(fontSize: 18)),
            Text(
              'Turma ${widget.idTurma} • ${DateFormat('dd/MM').format(DateTime.now())}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      
      // Tratamento dos 3 estados: Carregando, Erro e Sucesso
      body: estadoDiario.when(
        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
        error: (erro, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Erro ao carregar turma: $erro'),
            ],
          ),
        ),
        data: (alunos) {
          if (alunos.isEmpty) {
            return const Center(child: Text('Nenhum aluno encontrado.'));
          }

          return Column(
            children: [
              // Cabeçalho de Instrução
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.blueGrey.shade50,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe, size: 16, color: Colors.black54),
                    SizedBox(width: 8),
                    Text(
                      'Deslize para a direita para marcar falta',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              // Lista de Alunos
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Espaço pro botão
                  itemCount: alunos.length,
                  itemBuilder: (context, index) {
                    final aluno = alunos[index];

                    return Dismissible(
                      key: Key(aluno.idAluno),
                      // Desabilita o swipe caso o aluno tenha atestado (Falta Justificada)
                      direction: aluno.faltaJustificada 
                          ? DismissDirection.none 
                          : DismissDirection.horizontal,
                          
                      // Ao deslizar, não remove da lista, apenas dispara a troca de status
                      confirmDismiss: (direction) async {
                        ref.read(diarioControllerProvider.notifier).alternarPresenca(aluno.idAluno);
                        return false; // Retorna false para o card voltar pro lugar
                      },
                      
                      // Fundo vermelho (Falta) - Swipe para a direita
                      background: Container(
                        color: Colors.red.shade400,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                      ),
                      
                      // Fundo verde (Presença) - Swipe para a esquerda
                      secondaryBackground: Container(
                        color: corPrimaria,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
                      ),
                      
                      // Card visual do aluno
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                            // Barra lateral indicando o status (Feedback visual instantâneo)
                            left: BorderSide(
                              color: aluno.faltaJustificada 
                                  ? Colors.orange 
                                  : (aluno.presente ? corPrimaria : Colors.red),
                              width: 6,
                            ),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child: Text(
                              aluno.nome.substring(0, 1),
                              style: TextStyle(color: corPrimaria, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            aluno.nome,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: aluno.faltaJustificada 
                              ? const Text('Atestado Médico (Falta Justificada)', style: TextStyle(color: Colors.orange))
                              : Text(aluno.presente ? 'Presente' : 'Faltou'),
                          
                          // Toggle alternativo (para professores que preferem clicar ao invés de deslizar)
                          trailing: aluno.faltaJustificada
                              ? const Icon(Icons.medical_information, color: Colors.orange)
                              : Switch.adaptive(
                                  value: aluno.presente,
                                  activeTrackColor: corPrimaria,
                                  onChanged: (_) {
                                    ref.read(diarioControllerProvider.notifier).alternarPresenca(aluno.idAluno);
                                  },
                                ),
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
      
      // Botão Flutuante (Fixo na parte inferior) para Salvar no Hive
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: estadoDiario.hasValue && estadoDiario.value!.isNotEmpty
          ? SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: 56,
              child: FloatingActionButton.extended(
                backgroundColor: corPrimaria,
                foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
                onPressed: () async {
                  await ref.read(diarioControllerProvider.notifier).salvarChamada(widget.idTurma, _dataHojeStr);
                  
                  if(context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chamada salva localmente com sucesso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Salvar Chamada', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          : null,
    );
  }
}