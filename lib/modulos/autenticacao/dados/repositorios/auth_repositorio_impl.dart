import '../../dominio/entidades/tenant_entity.dart';
import '../../dominio/repositorios/i_auth_repositorio.dart';
import '../fontes_de_dados/auth_remoto_datasource.dart';

class AuthRepositorioImpl implements IAuthRepositorio {
  final IAuthRemotoDataSource remotoDataSource;

  AuthRepositorioImpl(this.remotoDataSource);

  @override
  Future<TenantEntity> buscarDadosDaEscola(String codigoEscola) async {
    // Aqui delegamos a busca para a API. O Model retornado pelo DataSource
    // é automaticamente aceito pois TenantModel estende TenantEntity.
    return await remotoDataSource.buscarEscolaNaApi(codigoEscola);
  }
}