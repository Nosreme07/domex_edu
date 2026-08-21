class AvisoEntity {
  final String id;
  final String titulo;
  final String conteudo;
  final String autor;
  final DateTime dataEnvio;
  final bool foiLido;
  final DateTime? dataLeitura;

  AvisoEntity({
    required this.id,
    required this.titulo,
    required this.conteudo,
    required this.autor,
    required this.dataEnvio,
    required this.foiLido,
    this.dataLeitura,
  });

  AvisoEntity copyWith({bool? foiLido, DateTime? dataLeitura}) {
    return AvisoEntity(
      id: id,
      titulo: titulo,
      conteudo: conteudo,
      autor: autor,
      dataEnvio: dataEnvio,
      foiLido: foiLido ?? this.foiLido,
      dataLeitura: dataLeitura ?? this.dataLeitura,
    );
  }
}