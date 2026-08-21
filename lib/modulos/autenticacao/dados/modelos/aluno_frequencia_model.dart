import '../../dominio/entidades/aluno_frequencia_entity.dart';

class AlunoFrequenciaModel extends AlunoFrequenciaEntity {
  AlunoFrequenciaModel({
    required super.idAluno,
    required super.nome,
    required super.presente,
    super.faltaJustificada,
  });

  factory AlunoFrequenciaModel.fromJson(Map<dynamic, dynamic> json) {
    return AlunoFrequenciaModel(
      idAluno: json['idAluno'] ?? '',
      nome: json['nome'] ?? '',
      presente: json['presente'] ?? true,
      faltaJustificada: json['faltaJustificada'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idAluno': idAluno,
      'nome': nome,
      'presente': presente,
      'faltaJustificada': faltaJustificada,
    };
  }
}