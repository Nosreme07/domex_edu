import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// SERVIÇO DE BANCO DE DADOS: RESPONSÁVEIS
// Esta classe concentra todas as regras de negócio para salvar, editar,
// excluir e consultar os responsáveis financeiros vinculados à escola.
// ============================================================================
class ResponsavelService {
  final String tenantId;

  // Construtor: Exige o ID da escola (Tenant) para garantir que os dados
  // não se misturem com outras escolas do sistema.
  ResponsavelService(this.tenantId);

  // Atalho para acessar a pasta (coleção) exata de responsáveis desta escola
  CollectionReference get _colecao => FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .collection('responsaveis');

  // --------------------------------------------------------------------------
  // 1. SALVAR OU ATUALIZAR RESPONSÁVEL
  // --------------------------------------------------------------------------
  Future<void> salvarResponsavel(Map<String, dynamic> dados) async {
    // Trava de segurança: Garante que o e-mail não tenha espaços ou letras maiúsculas
    // Isso evita erros no Firebase Auth na hora do login.
    if (dados['email'] != null && dados['email'].toString().isNotEmpty) {
      dados['email'] = dados['email'].toString().trim().toLowerCase();
    }

    // Grava a ficha oficial do Responsável dentro da escola (Tenant)
    await _colecao.doc(dados['id']).set(dados);

    // ========================================================================
    // SINCRONIZAÇÃO COM A TABELA GLOBAL DE USUÁRIOS (PORTARIA DO APLICATIVO)
    // Se a secretária editou o e-mail ou o nome do responsável, isso atualiza
    // o acesso dele no aplicativo automaticamente.
    // ========================================================================
    final docUsuario = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(dados['id']);
    final snapUsuario = await docUsuario.get();

    if (snapUsuario.exists) {
      // Se ele já tem acesso, apenas atualiza os dados básicos
      await docUsuario.update({
        'nome': dados['nome'],
        'email': dados['email'],
        'telefone': dados['telefone'],
      });
    } else {
      // Se é um responsável novo, cria a intenção de acesso dele como Inativo.
      // (O acesso oficial para logar será gerado quando a secretária for na aba de Usuários).
      await docUsuario.set({
        'idLogin': dados['id'],
        'nome': dados['nome'],
        'email': dados['email'],
        'telefone': dados['telefone'],
        'perfil': 'responsavel',
        'status':
            'Inativo', // Já cai bloqueado aguardando liberação na aba de Usuários
        'escolaId': tenantId,
        'dataCriacao': FieldValue.serverTimestamp(),
      });
    }
  }

  // --------------------------------------------------------------------------
  // 2. UPLOAD DE FOTO DE PERFIL
  // Envia a imagem do responsável para o Firebase Storage e retorna o link (URL)
  // --------------------------------------------------------------------------
  Future<String?> fazerUploadFoto(
    String idParaSalvar,
    Uint8List bytesFoto,
    String extensao,
  ) async {
    try {
      // Monta o caminho organizando por Escola -> Responsável -> Foto
      final path =
          'tenants/$tenantId/responsaveis/$idParaSalvar/foto_perfil.$extensao';
      final ref = FirebaseStorage.instance.ref().child(path);

      // Salva indicando que é uma imagem
      final metadata = SettableMetadata(contentType: 'image/$extensao');
      await ref.putData(bytesFoto, metadata);

      // Devolve o link da internet para salvar no banco de dados
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Erro ao fazer upload da foto: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 3. ATUALIZAR STATUS (BLOQUEAR / DESBLOQUEAR)
  // --------------------------------------------------------------------------
  Future<void> atualizarStatus(String id, String novoStatus) async {
    try {
      // 1. Atualiza na Ficha do Responsável
      await _colecao.doc(id).update({'status': novoStatus});

      // 2. Atualiza na Tabela Global de Usuários (Corta o acesso ao app na hora)
      final docUsuario = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(id);
      final snapUsuario = await docUsuario.get();
      if (snapUsuario.exists) {
        await docUsuario.update({'status': novoStatus});
      }
    } catch (e) {
      throw Exception('Erro ao atualizar status: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 4. EXCLUIR RESPONSÁVEL
  // Remove todos os rastros do responsável do sistema
  // --------------------------------------------------------------------------
  Future<void> excluirResponsavel(String id, {String? fotoUrl}) async {
    try {
      // 1. Apaga a ficha de cadastro na aba de Responsáveis
      await _colecao.doc(id).delete();

      // 2. Sincronização: Apaga também o "crachá" de acesso na aba de Usuários
      await FirebaseFirestore.instance.collection('usuarios').doc(id).delete();

      // 3. Apaga a foto no banco de imagens, caso ele tenha uma
      if (fotoUrl != null && fotoUrl.isNotEmpty) {
        try {
          final refFoto = FirebaseStorage.instance.refFromURL(fotoUrl);
          await refFoto.delete();
        } catch (e) {
          // Apenas ignora silenciosamente se a foto já não existir lá
        }
      }
    } catch (e) {
      throw Exception('Erro ao excluir responsável: $e');
    }
  }
}

// ============================================================================
// PROVIDERS (RIVERPOD) - COMUNICAÇÃO COM AS TELAS
// ============================================================================

// Provider do Serviço: Instancia a classe acima passando a escola correta
final responsavelServiceProvider = Provider<ResponsavelService>((ref) {
  final usuario = ref.watch(authProvider).value;
  // Fallback caso o usuário não esteja logado na memória (evita quebra da tela)
  return ResponsavelService(usuario?.id ?? 'escola_desconhecida');
});

// Provider da Listagem: Fica escutando o Firebase em tempo real (Stream)
// e atualiza a tela automaticamente sempre que um responsável é criado ou modificado.
final responsavelStreamProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final usuario = ref.watch(authProvider).value;

  if (usuario == null) {
    return Stream.value([]); // Retorna lista vazia se não tiver logado
  }

  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.id)
      .collection('responsaveis')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});
