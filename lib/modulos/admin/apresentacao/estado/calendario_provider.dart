import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// SERVIÇO DE BANCO DE DADOS: CALENDÁRIO ESCOLAR
// ============================================================================
class CalendarioService {
  final String tenantId;
  CalendarioService(this.tenantId);

  CollectionReference get _colecao => FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .collection('calendario');

  Future<void> salvarEvento(Map<String, dynamic> dados) async {
    final id = dados['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    dados['id'] = id;

    // Converte a string de data (DD/MM/YYYY) para salvar de forma ordenável no banco, se necessário
    await _colecao.doc(id).set(dados, SetOptions(merge: true));
  }

  Future<void> excluirEvento(String id) async {
    await _colecao.doc(id).delete();
  }
}

// ============================================================================
// PROVIDERS (RIVERPOD)
// ============================================================================
final calendarioServiceProvider = Provider<CalendarioService>((ref) {
  final usuario = ref.read(authProvider).value;
  return CalendarioService(usuario?.id ?? 'escola_desconhecida');
});

final calendarioStreamProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.id)
      .collection('calendario')
      // A ordenação real dependerá de como salvarmos a data.
      // Por padrão, traremos tudo e ordenaremos no Flutter.
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});
