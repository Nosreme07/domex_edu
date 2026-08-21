import '../../dominio/entidades/aluno_frequencia_entity.dart';
import '../../dominio/repositorios/i_diario_repositorio.dart';
import '../fontes_de_dados/diario_local_datasource.dart';
import '../modelos/aluno_frequencia_model.dart';

class DiarioRepositorioImpl implements IDiarioRepositorio {
  final IDiarioLocalDataSource localDataSource;
  
  DiarioRepositorioImpl(this.localDataSource);

  /// Gera uma chave única combinando a turma e o dia (Ex: "turma_101_2026-08-13")
  String _gerarChave(String idTurma, String data) => '${idTurma}_$data';

  @override
  Future<List<AlunoFrequenciaEntity>> buscarFrequenciaTurma(String idTurma, String data) async {
    final chave = _gerarChave(idTurma, data);
    
    // 1. Tenta carregar os dados rápidos do banco local (Offline)
    final cache = await localDataSource.buscarCache(chave);
    
    if (cache != null && cache.isNotEmpty) {
      return cache; // Retorna instantaneamente para o professor!
    }

    // 2. Se não houver cache (primeiro acesso do dia), simulamos a busca na API Remota.
    await Future.delayed(const Duration(seconds: 1));
    final dadosDaApi = [
      AlunoFrequenciaModel(idAluno: '1', nome: 'Ana Beatriz', presente: true),
      AlunoFrequenciaModel(idAluno: '2', nome: 'Carlos Eduardo', presente: true),
      // Adicionado um aluno com falta justificada (atestado) para você testar como a UI se comporta
      AlunoFrequenciaModel(idAluno: '3', nome: 'João Pedro', presente: false, faltaJustificada: true), 
    ];

    // 3. Salva no banco local para funcionar offline no próximo acesso
    await localDataSource.salvarCache(chave, dadosDaApi);

    return dadosDaApi;
  }

  @override
  Future<void> salvarFrequencia(String idTurma, String data, List<AlunoFrequenciaEntity> lista) async {
    final chave = _gerarChave(idTurma, data);
    
    // Converte Entidade -> Model
    final listaModel = lista.map((e) => AlunoFrequenciaModel(
      idAluno: e.idAluno, 
      nome: e.nome, 
      presente: e.presente, 
      faltaJustificada: e.faltaJustificada,
    )).toList();

    // 1. Salva IMEDIATAMENTE no banco local (Feedback rápido na UI)
    await localDataSource.salvarCache(chave, listaModel);

    // 2. Tenta enviar para a API (Sincronização Cloud). 
    // Como a arquitetura agora garante que está salvo no Hive, mesmo se falhar aqui, o dado não é perdido.
  }
}