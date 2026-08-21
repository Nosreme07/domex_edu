import '../../dominio/entidades/tenant_entity.dart';

/// O Model estende a Entidade pura do domínio adicionando a capacidade
/// de serialização (from/toJson) para conversar com a API HTTP.
class TenantModel extends TenantEntity {
  TenantModel({
    required super.id,
    required super.nomeEscola,
    required super.logoUrl,
    required super.corPrimariaHex,
    required super.corFundoHex,
  });

  /// Factory para converter o JSON vindo do backend em um objeto Dart
  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] ?? '',
      nomeEscola: json['nomeEscola'] ?? 'Escola Desconhecida',
      logoUrl: json['logoUrl'] ?? '',
      corPrimariaHex: json['corPrimariaHex'] ?? '#064E3B', // Fallback Emerald
      corFundoHex: json['corFundoHex'] ?? '#F8E7C9',       // Fallback Cream
    );
  }

  /// Converte o objeto Dart de volta para JSON (útil para chamadas POST/PUT)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nomeEscola': nomeEscola,
      'logoUrl': logoUrl,
      'corPrimariaHex': corPrimariaHex,
      'corFundoHex': corFundoHex,
    };
  }
}