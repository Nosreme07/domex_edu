import '../../dominio/entidades/aluno_frequencia_entity.dart';
import '../../dominio/repositorios/i_diario_repositorio.dart';
import '../fontes_de_dados/diario_local_datasource.dart';
import '../modelos/aluno_frequencia_model.dart';

class DiarioRepositorioImpl implements IDiarioRepositorio {
  final IDiarioLocalDataSource localDataSource;
  // Nota técnica: Em produção, injetaremos também o IDiarioRemotoDataSource (API HTTP)
  
  DiarioRepositorioImpl(this.localDataSource);

  /// Gera uma chave única combinando a turma e o dia (Ex: "turma_101_2026-08-12")
  String _gerarChave(String idTurma, String data) => '${idTurma}_$data';

  @override
  Future<List<AlunoFrequenciaEntity>> buscarFrequenciaTurma(String idTurma, String data) async {
    final chave = _gerarChave(idTurma, data);
    
    // 1. Tenta carregar os dados rápidos do banco local (Offline)
    final cache = await localDataSource.buscarCache(chave);
    
    if (cache != null && cache.isNotEmpty) {
      return cache; // Retorna instantaneamente para o professor
    }

    // 2. Se não houver cache (primeiro acesso do dia), buscaria da API remota.
    // Simulando retorno da API HTTP:
    await Future.delayed(const Duration(seconds: 1));
    final dadosDaApi = [
      AlunoFrequenciaModel(idAluno: '1', nome: 'Ana Beatriz', presente: true),
      AlunoFrequenciaModel(idAluno: '2', nome: 'Carlos Eduardo', presente: true),
    ];

    // 3. Salva no banco local para funcionar offline da próxima vez
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

    // 2. Tenta enviar para a API em background (Sincronização)
    try {
      // TODO: Chamada HTTP POST para o Backend (Remoto)
      // await remotoDataSource.enviarFrequencia(idTurma, data, listaModel);
    } catch (e) {
      // Se falhar (sem Wi-Fi), o dado já está seguro no Hive local.
      // Uma rotina de background (Worker) pode tentar enviar novamente depois.
    }
  }
}