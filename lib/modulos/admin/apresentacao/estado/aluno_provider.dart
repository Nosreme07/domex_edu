import 'dart:typed_data'; // NOVO: Para trabalhar com os bytes da imagem
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // NOVO: Pacote do Storage
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class AlunoService {
  final String tenantId;
  AlunoService(this.tenantId);

  CollectionReference get _colecao => FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .collection('alunos');

  Future<void> salvarAluno(Map<String, dynamic> dados) async {
    await _colecao.doc(dados['matricula']).set(dados);
  }

  Future<void> excluirAluno(String matricula) async {
    await _colecao.doc(matricula).delete();
  }

// =======================================================
  // UPLOAD DA FOTO PARA O STORAGE
  // =======================================================
  Future<String?> fazerUploadFoto(String matricula, Uint8List bytes, String extensao) async {
    try {
      final caminhoArquivo = 'tenants/$tenantId/alunos/$matricula.$extensao';
      final ref = FirebaseStorage.instance.ref().child(caminhoArquivo);
      
      final metadados = SettableMetadata(contentType: 'image/$extensao');
      final uploadTask = await ref.putData(bytes, metadados);
      
      final urlGerada = await uploadTask.ref.getDownloadURL();
      return urlGerada;
    } catch (e) {
      // Agora ele não esconde mais o erro, ele joga na tela!
      throw Exception('Falha no Storage: $e');
    }
  }
}

final alunoServiceProvider = Provider<AlunoService>((ref) {
  final usuario = ref.watch(authProvider).value;
  return AlunoService(usuario?.id ?? 'escola_desconhecida');
});

final alunosStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.id)
      .collection('alunos')
      .orderBy('nome')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});