import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class ProfessorService {
  final String tenantId;
  ProfessorService(this.tenantId);

  CollectionReference get _colecao => FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .collection('professores');

  Future<void> salvarProfessor(Map<String, dynamic> dados) async {
    await _colecao.doc(dados['id']).set(dados);
  }

  Future<String?> fazerUploadFoto(String idParaSalvar, Uint8List bytesFoto, String extensao) async {}

  Future<void> excluirProfessor(professor) async {}
}

final professorServiceProvider = Provider<ProfessorService>((ref) {
  final usuario = ref.watch(authProvider).value;
  return ProfessorService(usuario?.id ?? 'escola_desconhecida');
});

final professoresStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.id)
      .collection('professores')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});