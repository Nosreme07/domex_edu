import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importamos a sessão para saber qual escola está logada!
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// 1. O Serviço que salva e exclui dados na pasta ESPECÍFICA da escola
class TurmaService {
  final String tenantId; // Código da Escola (Ex: ESC-0001)

  TurmaService(this.tenantId);

  // O caminho agora é: tenants -> ESC-0001 -> turmas
  CollectionReference get _colecaoTurmas => FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .collection('turmas');

  Future<void> salvarTurma(Map<String, dynamic> turmaDados) async {
    await _colecaoTurmas.doc(turmaDados['id']).set(turmaDados);
  }

  Future<void> excluirTurma(String id) async {
    await _colecaoTurmas.doc(id).delete();
  }
}

// Provedor do Serviço (Pega o ID da escola logada automaticamente)
final turmaServiceProvider = Provider<TurmaService>((ref) {
  final usuario = ref.watch(authProvider).value;
  return TurmaService(usuario?.id ?? 'escola_desconhecida');
});

// 2. O Stream que escuta APENAS as turmas desta escola
final turmasStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final usuario = ref.watch(authProvider).value;
  
  // Se não tem ninguém logado, retorna vazio
  if (usuario == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.id) // Filtra pelo ID da escola (ESC-0001)
      .collection('turmas')
      .orderBy('nivelOrdenacao')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()).toList();
  });
});