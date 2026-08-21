import '../entidades/tenant_entity.dart';
import '../repositorios/i_auth_repositorio.dart';

class BuscarTenantUseCase {
  final IAuthRepositorio repositorio;

  BuscarTenantUseCase(this.repositorio);

  Future<TenantEntity> call(String codigoEscola) async {
    if (codigoEscola.isEmpty) {
      throw Exception('O código da escola não pode ser vazio.');
    }
    // Delega a busca para a camada de dados
    return await repositorio.buscarDadosDaEscola(codigoEscola);
  }
}