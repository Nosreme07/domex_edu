import 'package:hive/hive.dart';
import '../modelos/aluno_frequencia_model.dart';

abstract class IDiarioLocalDataSource {
  Future<void> salvarCache(String chaveTurmaData, List<AlunoFrequenciaModel> alunos);
  Future<List<AlunoFrequenciaModel>?> buscarCache(String chaveTurmaData);
}

class DiarioLocalDataSourceImpl implements IDiarioLocalDataSource {
  // Nome da "tabela" (Box) no banco local Hive
  static const String boxName = 'diario_offline_box';

  @override
  Future<void> salvarCache(String chaveTurmaData, List<AlunoFrequenciaModel> alunos) async {
    final box = await Hive.openBox(boxName);
    // Converte a lista de Models para uma lista de Maps e salva no disco
    final listaJson = alunos.map((a) => a.toJson()).toList();
    await box.put(chaveTurmaData, listaJson);
  }

  @override
  Future<List<AlunoFrequenciaModel>?> buscarCache(String chaveTurmaData) async {
    final box = await Hive.openBox(boxName);
    final dados = box.get(chaveTurmaData);

    if (dados != null && dados is List) {
      // Reconstrói os Models a partir dos dados gravados localmente
      return dados.map((e) => AlunoFrequenciaModel.fromJson(e as Map)).toList();
    }
    return null;
  }
}