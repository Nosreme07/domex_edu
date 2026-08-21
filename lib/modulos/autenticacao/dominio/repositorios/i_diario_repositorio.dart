import '../entidades/aluno_frequencia_entity.dart';

abstract class IDiarioRepositorio {
  /// Busca a lista de alunos (Prioriza o cache local, atualiza via API se tiver rede)
  Future<List<AlunoFrequenciaEntity>> buscarFrequenciaTurma(String idTurma, String data);
  
  /// Salva a chamada localmente e enfileira para sincronizar com o backend
  Future<void> salvarFrequencia(String idTurma, String data, List<AlunoFrequenciaEntity> lista);
}