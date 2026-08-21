/// Representa a linha do aluno no Diário de Classe do Professor
class AlunoFrequenciaEntity {
  final String idAluno;
  final String nome;
  final bool presente;
  final bool faltaJustificada; // Caso a direção já tenha aprovado um atestado

  AlunoFrequenciaEntity({
    required this.idAluno,
    required this.nome,
    required this.presente,
    this.faltaJustificada = false,
  });

  // Método utilitário para criar uma cópia alterando o status (Imutabilidade exigida pelo Riverpod)
  AlunoFrequenciaEntity copyWith({bool? presente}) {
    return AlunoFrequenciaEntity(
      idAluno: idAluno,
      nome: nome,
      presente: presente ?? this.presente,
      faltaJustificada: faltaJustificada,
    );
  }
}