import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class ResponsavelService {
  final String tenantId;
  ResponsavelService(this.tenantId);

  CollectionReference get _colecao => FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .collection('responsaveis');

  Future<void> salvarResponsavel(Map<String, dynamic> dados) async {
    // 1. Trava do E-mail Minúsculo
    if (dados['email'] != null && dados['email'].toString().isNotEmpty) {
      dados['email'] = dados['email'].toString().trim().toLowerCase();
    }

    // 2. Salva na pasta oficial de Responsáveis
    await _colecao.doc(dados['id']).set(dados);

    // 3. Sincronização Automática com a Tabela de Usuários (Central de Acessos)
    final docUsuario = FirebaseFirestore.instance.collection('usuarios').doc(dados['id']);
    final snapUsuario = await docUsuario.get();

    if (snapUsuario.exists) {
      await docUsuario.update({
        'nome': dados['nome'],
        'email': dados['email'],
        'telefone': dados['telefone'],
      });
    } else {
      await docUsuario.set({
        'idLogin': dados['id'],
        'nome': dados['nome'],
        'email': dados['email'],
        'telefone': dados['telefone'],
        'perfil': 'responsavel',
        'status': 'Inativo', // Já cai bloqueado aguardando liberação
        'escolaId': tenantId,
        'dataCriacao': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String?> fazerUploadFoto(String idParaSalvar, Uint8List bytesFoto, String extensao) async {
    try {
      final path = 'tenants/$tenantId/responsaveis/$idParaSalvar/foto_perfil.$extensao';
      final ref = FirebaseStorage.instance.ref().child(path);
      final metadata = SettableMetadata(contentType: 'image/$extensao');
      await ref.putData(bytesFoto, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Erro ao fazer upload: $e');
    }
  }

Future<void> excluirResponsavel(String id, {String? fotoUrl}) async {
    try {
      // 1. Apaga a ficha na aba de Responsáveis
      await _colecao.doc(id).delete();

      // 2. Sincronização: Apaga também o acesso na aba de Usuários
      await FirebaseFirestore.instance.collection('usuarios').doc(id).delete();

      // 3. Apaga a foto no banco de imagens, se existir
      if (fotoUrl != null && fotoUrl.isNotEmpty) {
        try {
          final refFoto = FirebaseStorage.instance.refFromURL(fotoUrl);
          await refFoto.delete();
        } catch (e) {
          // Apenas ignora se a foto já não existir
        }
      }
    } catch (e) {
      throw Exception('Erro ao excluir: $e');
    }
  }
}

final responsavelServiceProvider = Provider<ResponsavelService>((ref) {
  final usuario = ref.watch(authProvider).value;
  return ResponsavelService(usuario?.id ?? 'escola_desconhecida');
});

final responsavelStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.id)
      .collection('responsaveis')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});