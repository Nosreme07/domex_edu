import '../modelos/tenant_model.dart';

abstract class IAuthRemotoDataSource {
  Future<TenantModel> buscarEscolaNaApi(String codigoEscola);
}

class AuthRemotoDataSourceImpl implements IAuthRemotoDataSource {
  @override
  Future<TenantModel> buscarEscolaNaApi(String codigoEscola) async {
    // Simula delay de rede de 1.5 segundos
    await Future.delayed(const Duration(milliseconds: 1500));

    // Simulação do Backend: Retornando as cores dinâmicas
    if (codigoEscola.toLowerCase() == 'conexao') {
      return TenantModel(
        id: 'tenant_123',
        nomeEscola: 'Conexão Infantil',
        logoUrl: 'https://exemplo.com/logo.png',
        corPrimariaHex: '#064E3B', // Dark Emerald
        corFundoHex: '#F8E7C9',    // Cream
      );
    } else {
      throw Exception('Escola não encontrada. Verifique o código.');
    }
  }
}