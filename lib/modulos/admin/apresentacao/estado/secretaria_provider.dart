import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// SERVIÇO DE BANCO DE DADOS: SECRETARIA E EQUIPE
// Esta classe concentra todas as regras de negócio para salvar, editar,
// atualizar status, excluir e consultar os membros da equipe da escola.
// ============================================================================
class SecretariaService {
  final String tenantId;

  SecretariaService(this.tenantId);

  CollectionReference get _colecao => FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .collection('secretaria');

  // --------------------------------------------------------------------------
  // 1. SALVAR OU ATUALIZAR COLABORADOR
  // --------------------------------------------------------------------------
  Future<void> salvarSecretaria(Map<String, dynamic> dados) async {
    // 1. Trava do E-mail Minúsculo
    if (dados['email'] != null && dados['email'].toString().isNotEmpty) {
      dados['email'] = dados['email'].toString().trim().toLowerCase();
    }

    // 2. Salva na pasta oficial da Secretaria
    await _colecao.doc(dados['id']).set(dados);

    // 3. Sincronização Automática com a Tabela de Usuários (Central de Acessos)
    final docUsuario = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(dados['id']);
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
        'perfil': 'secretaria',
        'status':
            'Inativo', // Já cai bloqueado aguardando liberação na aba Usuários!
        'escolaId': tenantId,
        'dataCriacao': FieldValue.serverTimestamp(),
      });
    }
  }

  // --------------------------------------------------------------------------
  // 2. UPLOAD DE FOTO
  // --------------------------------------------------------------------------
  Future<String?> fazerUploadFoto(
    String idParaSalvar,
    Uint8List bytesFoto,
    String extensao,
  ) async {
    try {
      final path =
          'tenants/$tenantId/secretaria/$idParaSalvar/foto_perfil.$extensao';
      final ref = FirebaseStorage.instance.ref().child(path);
      final metadata = SettableMetadata(contentType: 'image/$extensao');
      await ref.putData(bytesFoto, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Erro ao fazer upload: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 3. ATUALIZAR STATUS (ATIVO / INATIVO)
  // --------------------------------------------------------------------------
  Future<void> atualizarStatus(String id, String novoStatus) async {
    try {
      // 1. Atualiza na Ficha do Colaborador
      await _colecao.doc(id).update({'status': novoStatus});

      // 2. Atualiza na Tabela Global de Usuários (Corta acesso ao app se inativado)
      final docUsuario = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(id);
      final snapUsuario = await docUsuario.get();
      if (snapUsuario.exists) {
        final statusLogin = novoStatus == 'Inativo' ? 'Bloqueado' : 'Ativo';
        await docUsuario.update({'status': statusLogin});
      }
    } catch (e) {
      throw Exception('Erro ao atualizar status: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 4. EXCLUIR COLABORADOR (LIMPEZA COMPLETA)
  // --------------------------------------------------------------------------
  Future<void> excluirSecretaria(String id, {String? fotoUrl}) async {
    try {
      // 1. Apaga a ficha da aba de Secretaria
      await _colecao.doc(id).delete();

      // 2. Apaga o acesso na aba de Usuários Globais
      await FirebaseFirestore.instance.collection('usuarios').doc(id).delete();

      // 3. Apaga a foto do banco de imagens
      if (fotoUrl != null && fotoUrl.isNotEmpty) {
        try {
          final refFoto = FirebaseStorage.instance.refFromURL(fotoUrl);
          await refFoto.delete();
        } catch (e) {
          debugPrint('Foto não encontrada no Storage ou erro ao apagar: $e');
        }
      }
    } catch (e) {
      throw Exception('Erro ao excluir: $e');
    }
  }
}

// ============================================================================
// PROVIDERS (RIVERPOD) - COMUNICAÇÃO COM AS TELAS
// ============================================================================
final secretariaServiceProvider = Provider<SecretariaService>((ref) {
  final usuario = ref.watch(authProvider).value;
  return SecretariaService(usuario?.id ?? 'escola_desconhecida');
});

final secretariaStreamProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.id)
      .collection('secretaria')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});
