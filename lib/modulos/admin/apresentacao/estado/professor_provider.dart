import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; 
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

  Future<String?> fazerUploadFoto(String idParaSalvar, Uint8List bytesFoto, String extensao) async {
    try {
      final path = 'tenants/$tenantId/professores/$idParaSalvar/foto_perfil.$extensao';
      
      // Chamando a instância EXATAMENTE na hora de usar, para evitar o erro 'undefined' no Web
      final ref = FirebaseStorage.instance.ref().child(path);
      
      final metadata = SettableMetadata(
        contentType: 'image/$extensao',
      );

      // Envia a imagem
      await ref.putData(bytesFoto, metadata);
      
      // Retorna a URL pública gerada
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Erro ao fazer upload da foto: $e');
    }
  }

  Future<void> excluirProfessor(String idProfessor, {String? fotoUrl}) async {
    try {
      // 1. Apaga do Firestore
      await _colecao.doc(idProfessor).delete();

      // 2. Se o professor tinha uma foto, apaga do Storage
      if (fotoUrl != null && fotoUrl.isNotEmpty) {
        try {
          // Chamando a instância EXATAMENTE na hora de usar
          final refFoto = FirebaseStorage.instance.refFromURL(fotoUrl);
          await refFoto.delete();
        } catch (e) {
          debugPrint('Foto não encontrada no Storage ou erro ao apagar: $e');
        }
      }
    } catch (e) {
      throw Exception('Erro ao excluir professor: $e');
    }
  }
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