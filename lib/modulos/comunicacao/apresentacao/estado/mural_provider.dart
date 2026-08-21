import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// CORREÇÃO: Import usando o caminho relativo exato (apenas dois níveis acima)
import '../../dominio/entidades/aviso_entity.dart';

class MuralController extends AsyncNotifier<List<AvisoEntity>> {
  @override
  FutureOr<List<AvisoEntity>> build() {
    return [];
  }

  Future<void> carregarMural() async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      await Future.delayed(const Duration(seconds: 1));
      
      return [
        AvisoEntity(
          id: 'aviso_1',
          titulo: 'Rematrícula 2027 Aberta',
          conteudo: 'Informamos que o período de rematrícula antecipada com desconto já começou. Acesse o módulo financeiro para assinar o contrato.',
          autor: 'Direção Administrativa',
          dataEnvio: DateTime.now().subtract(const Duration(hours: 2)),
          foiLido: false,
        ),
        AvisoEntity(
          id: 'aviso_2',
          titulo: 'Feira de Ciências',
          conteudo: 'A feira ocorrerá nesta sexta-feira às 14h. Contamos com a presença de todos os pais.',
          autor: 'Coordenação Pedagógica',
          dataEnvio: DateTime.now().subtract(const Duration(days: 2)),
          foiLido: true,
          dataLeitura: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
    });
  }

  Future<void> marcarComoLido(String idAviso) async {
    if (state.value == null) return;

    final listaAtual = state.value!;
    
    // CORREÇÃO: Tipagem explícita (AvisoEntity aviso) para o Dart não se perder
    final novaLista = listaAtual.map((AvisoEntity aviso) {
      if (aviso.id == idAviso && !aviso.foiLido) {
        return aviso.copyWith(foiLido: true, dataLeitura: DateTime.now());
      }
      return aviso;
    }).toList();
    
    state = AsyncData(novaLista);
  }
}

final muralControllerProvider = 
    AsyncNotifierProvider<MuralController, List<AvisoEntity>>(() {
  return MuralController();
});