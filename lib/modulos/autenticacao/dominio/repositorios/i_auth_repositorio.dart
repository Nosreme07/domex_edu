import '../entidades/tenant_entity.dart';

/// Contrato (Interface) que define as regras de busca de dados da escola.
/// A camada de Domínio não se importa se isso vem de uma API, do Firebase ou localmente.
abstract class IAuthRepositorio {
  Future<TenantEntity> buscarDadosDaEscola(String codigoEscola);
}