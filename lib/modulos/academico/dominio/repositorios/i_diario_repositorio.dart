import '../entidades/aluno_frequencia_entity.dart';

/// Contrato que define como o diário busca e salva a chamada.
abstract class IDiarioRepositorio {
  /// Busca a lista de alunos (Prioriza o cache local, atualiza via API se precisar)
  Future<List<AlunoFrequenciaEntity>> buscarFrequenciaTurma(String idTurma, String data);
  
  /// Salva a chamada localmente e enfileira para sincronizar com o backend
  Future<void> salvarFrequencia(String idTurma, String data, List<AlunoFrequenciaEntity> lista);
}