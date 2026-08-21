import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dominio/entidades/aluno_frequencia_entity.dart';
import '../../dados/fontes_de_dados/diario_local_datasource.dart';
import '../../dados/repositorios/diario_repositorio_impl.dart';

// 1. Provedores de Dados (Injeção)
final diarioLocalDataSourceProvider = Provider((ref) => DiarioLocalDataSourceImpl());

final diarioRepositorioProvider = Provider((ref) {
  return DiarioRepositorioImpl(ref.watch(diarioLocalDataSourceProvider));
});

// 2. Controlador de Estado Moderno (AsyncNotifier)
class DiarioController extends AsyncNotifier<List<AlunoFrequenciaEntity>> {
  @override
  FutureOr<List<AlunoFrequenciaEntity>> build() {
    return []; // Inicia com lista vazia
  }

  Future<void> carregarTurma(String idTurma, String data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(diarioRepositorioProvider);
      return await repo.buscarFrequenciaTurma(idTurma, data);
    });
  }

  void alternarPresenca(String idAluno) {
    if (state.value == null) return;
    
    final listaAtual = state.value!;
    final novaLista = listaAtual.map((aluno) {
      // O Linter estava reclamando porque não garantimos o tipo. 
      // Agora está seguro.
      if (aluno.idAluno == idAluno && !aluno.faltaJustificada) {
        return aluno.copyWith(presente: !aluno.presente);
      }
      return aluno;
    }).toList();

    state = AsyncData(novaLista);
  }

  Future<void> salvarChamada(String idTurma, String data) async {
    if (state.value == null) return;
    
    final repo = ref.read(diarioRepositorioProvider);
    await repo.salvarFrequencia(idTurma, data, state.value!);
  }
}

final diarioControllerProvider = 
    AsyncNotifierProvider<DiarioController, List<AlunoFrequenciaEntity>>(() {
  return DiarioController();
});