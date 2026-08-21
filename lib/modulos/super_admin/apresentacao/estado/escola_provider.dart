import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Serviço que grava no Firestore (Coleção 'tenants')
class EscolaService {
  final _db = FirebaseFirestore.instance.collection('tenants');

  Future<void> salvarEscola(Map<String, dynamic> escolaDados) async {
    await _db.doc(escolaDados['id']).set(escolaDados);
  }

  Future<void> atualizarStatus(String id, String novoStatus) async {
    await _db.doc(id).update({'status': novoStatus});
  }

  // NOVA FUNÇÃO ADICIONADA: Excluir Escola
  Future<void> excluirEscola(String id) async {
    await _db.doc(id).delete();
  }
}

final escolaServiceProvider = Provider((ref) => EscolaService());

final escolasStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('tenants').orderBy('id').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()).toList();
  });
});