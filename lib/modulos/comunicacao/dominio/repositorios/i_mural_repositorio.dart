import '../entidades/aviso_entity.dart';

abstract class IMuralRepositorio {
  Future<List<AvisoEntity>> buscarAvisos(String idEscola, String idUsuario);
  // Esta função registra no backend (Firebase/PostgreSQL) a hora exata da leitura
  Future<void> registrarLeitura(String idAviso, String idUsuario);
}