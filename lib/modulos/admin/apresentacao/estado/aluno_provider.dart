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
    await _colecao.doc(dados['matricula'].toString()).set(dados);

    if (dados['temIrmao'] == true && dados['irmaosVinculadosRaw'] != null) {
      final matriculaAtual = dados['matricula'].toString();
      final nomeAtual = dados['nome'].toString();
      final irmaos = dados['irmaosVinculadosRaw'] as List;

      for (var irmao in irmaos) {
        final matIrmao = irmao['matricula'].toString();
        
        final docIrmao = await _colecao.doc(matIrmao).get();
        if (docIrmao.exists) {
          final dadosIrmao = docIrmao.data() as Map<String, dynamic>;
          final irmaosDoIrmao = List<Map<String, dynamic>>.from(dadosIrmao['irmaosVinculadosRaw'] ?? []);
          
          bool jaVinculado = irmaosDoIrmao.any((i) => i['matricula'].toString() == matriculaAtual);
          
          if (!jaVinculado) {
            irmaosDoIrmao.add({'nome': nomeAtual, 'matricula': matriculaAtual});
            
            await _colecao.doc(matIrmao).update({
              'temIrmao': true,
              'irmaosVinculadosRaw': irmaosDoIrmao,
              'irmaosVinculados': irmaosDoIrmao.map((i) => '${i['nome']} (${i['matricula']})'.toUpperCase()).toList(),
            });
          }
        }
      }
    }

    final docUsuario = FirebaseFirestore.instance.collection('usuarios').doc(dados['matricula'].toString());
    final snapUsuario = await docUsuario.get();

    if (snapUsuario.exists) {
      await docUsuario.update({
        'nome': dados['nome'],
        'telefone': dados['telefone'],
      });
    } else {
      await docUsuario.set({
        'idLogin': dados['matricula'].toString(),
        'nome': dados['nome'],
        'email': '', 
        'telefone': dados['telefone'],
        'perfil': 'aluno',
        'status': 'Inativo', 
        'escolaId': tenantId,
        'dataCriacao': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> excluirAluno(String matricula) async {
    await _colecao.doc(matricula).delete();
  }

  Future<String?> fazerUploadFoto(String matricula, Uint8List bytes, String extensao) async {
    try {
      final caminhoArquivo = 'tenants/$tenantId/alunos/$matricula/foto_perfil.$extensao';
      final ref = FirebaseStorage.instance.ref().child(caminhoArquivo);
      final metadados = SettableMetadata(contentType: 'image/$extensao');
      final uploadTask = await ref.putData(bytes, metadados);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Falha no Storage (Foto): $e');
    }
  }

  // === NOVA FUNÇÃO PARA UPLOAD DE DOCUMENTOS (PDF E IMAGENS) ===
  Future<String?> fazerUploadArquivo(String matricula, String nomeArquivo, Uint8List bytes, String extensao) async {
    try {
      final caminhoArquivo = 'tenants/$tenantId/alunos/$matricula/documentos/$nomeArquivo';
      final ref = FirebaseStorage.instance.ref().child(caminhoArquivo);
      
      String contentType = 'application/pdf';
      if (['jpg', 'jpeg', 'png'].contains(extensao.toLowerCase())) {
        contentType = 'image/${extensao.toLowerCase()}';
      }
      
      final metadados = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putData(bytes, metadados);
      
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Falha no Storage (Documento): $e');
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