import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// SERVIÇO DE BANCO DE DADOS: PROFESSORES
// Esta classe concentra todas as regras de negócio para salvar, editar,
// atualizar status, excluir e consultar os professores da escola.
// ============================================================================
class ProfessorService {
  final String tenantId;

  // Construtor: Exige o ID da escola (Tenant) para isolar os dados
  ProfessorService(this.tenantId);

  // Atalho para acessar a pasta (coleção) exata de professores desta escola
  CollectionReference get _colecao => FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .collection('professores');

  // --------------------------------------------------------------------------
  // 1. SALVAR OU ATUALIZAR PROFESSOR
  // --------------------------------------------------------------------------
  Future<void> salvarProfessor(Map<String, dynamic> dados) async {
    // 1. Trava de E-mail (Sempre minúsculo e sem espaços para evitar erro de login)
    if (dados['email'] != null && dados['email'].toString().isNotEmpty) {
      dados['email'] = dados['email'].toString().trim().toLowerCase();
    }

    // 2. Salva o Perfil do Professor na pasta da Escola
    await _colecao.doc(dados['id']).set(dados);

    // 3. Sincronização Automática com a Tabela de Usuários (Central de Acessos)
    final docUsuario = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(dados['id']);
    final snapUsuario = await docUsuario.get();

    if (snapUsuario.exists) {
      // Se a credencial já existe, apenas atualiza os dados espelho (Mantém o status atual intacto)
      await docUsuario.update({
        'nome': dados['nome'],
        'email': dados['email'],
        'telefone': dados['telefone'],
      });
    } else {
      // Se é um professor novo, cria a credencial automaticamente como INATIVO
      await docUsuario.set({
        'idLogin': dados['id'],
        'nome': dados['nome'],
        'email': dados['email'],
        'telefone': dados['telefone'],
        'perfil': 'professor',
        'status':
            'Inativo', // Aguardando ativação/geração de acesso na aba de Usuários
        'escolaId': tenantId,
        'dataCriacao': FieldValue.serverTimestamp(),
      });
    }
  }

  // --------------------------------------------------------------------------
  // 2. UPLOAD DE FOTO E DOCUMENTOS (ANEXOS)
  // --------------------------------------------------------------------------
  Future<String?> fazerUploadFoto(
    String idParaSalvar,
    Uint8List bytesArquivo,
    String extensao,
  ) async {
    try {
      final path =
          'tenants/$tenantId/professores/$idParaSalvar/foto_perfil.$extensao';

      final ref = FirebaseStorage.instance.ref().child(path);

      final metadata = SettableMetadata(
        contentType: extensao == 'pdf' ? 'application/pdf' : 'image/$extensao',
      );

      await ref.putData(bytesArquivo, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Erro ao fazer upload: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 3. ATUALIZAR STATUS (ATIVO / INATIVO)
  // --------------------------------------------------------------------------
  Future<void> atualizarStatus(String idProfessor, String novoStatus) async {
    try {
      // 1. Atualiza na Ficha do Professor
      await _colecao.doc(idProfessor).update({'status': novoStatus});

      // 2. Atualiza na Tabela Global de Usuários (Corta o acesso ao app se for inativado)
      final docUsuario = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(idProfessor);
      final snapUsuario = await docUsuario.get();
      if (snapUsuario.exists) {
        // Se a escola inativar o professor, o status de login muda para "Bloqueado"
        final statusLogin = novoStatus == 'Inativo' ? 'Bloqueado' : 'Ativo';
        await docUsuario.update({'status': statusLogin});
      }
    } catch (e) {
      throw Exception('Erro ao atualizar status: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 4. EXCLUIR PROFESSOR (LIMPEZA COMPLETA)
  // --------------------------------------------------------------------------
  Future<void> excluirProfessor(String idProfessor, {String? fotoUrl}) async {
    try {
      // 1. Apaga a ficha na aba de Professores
      await _colecao.doc(idProfessor).delete();

      // 2. Sincronização: Apaga também o acesso na aba de Usuários
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(idProfessor)
          .delete();

      // 3. Apaga a foto no banco de imagens, se existir
      if (fotoUrl != null && fotoUrl.isNotEmpty) {
        try {
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

// ============================================================================
// PROVIDERS (RIVERPOD) - COMUNICAÇÃO COM AS TELAS
// ============================================================================

// Provider do Serviço: Instancia a classe passando a escola correta
final professorServiceProvider = Provider<ProfessorService>((ref) {
  final usuario = ref.watch(authProvider).value;
  return ProfessorService(usuario?.id ?? 'escola_desconhecida');
});

// Provider da Listagem: Fica escutando o Firebase em tempo real (Stream)
final professoresStreamProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null)
    return Stream.value([]); // Retorna lista vazia se não logado

  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.id)
      .collection('professores')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});
