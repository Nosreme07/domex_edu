import 'dart:typed_data'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
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
    // 1. Trava de E-mail (Sempre minúsculo e sem espaços)
    if (dados['email'] != null && dados['email'].toString().isNotEmpty) {
      dados['email'] = dados['email'].toString().trim().toLowerCase();
    }

    // 2. Salva o Perfil do Aluno na pasta da Escola
    await _colecao.doc(dados['matricula'].toString()).set(dados);

    // 3. Sincronização Automática com a Tabela de Usuários (Central de Acessos)
    final docUsuario = FirebaseFirestore.instance.collection('usuarios').doc(dados['matricula'].toString());
    final snapUsuario = await docUsuario.get();

    if (snapUsuario.exists) {
      // Atualiza os dados espelho (Mantém o status atual intacto)
      await docUsuario.update({
        'nome': dados['nome'],
        'email': dados['email'],
        'telefone': dados['telefone'],
      });
    } else {
      // Se é um aluno novo, cria a credencial automaticamente como INATIVO
      await docUsuario.set({
        'idLogin': dados['matricula'].toString(),
        'nome': dados['nome'],
        'email': dados['email'],
        'telefone': dados['telefone'],
        'perfil': 'aluno',
        'status': 'Inativo', // Aguardando ativação
        'escolaId': tenantId,
        'dataCriacao': FieldValue.serverTimestamp(),
      });
    }
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