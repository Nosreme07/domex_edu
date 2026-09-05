import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class AlunoService {
  final String tenantId;

  AlunoService(this.tenantId);

  // Usamos "get" para garantir que a instância do Firebase seja chamada
  // APENAS no momento exato do uso, evitando o erro de "Null FirebaseFirestore".
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  Future<String> fazerUploadFoto(
    String matricula,
    Uint8List bytes,
    String extensao,
  ) async {
    final path = 'tenants/$tenantId/alunos/$matricula/foto_perfil.$extensao';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  Future<String> fazerUploadArquivo(
    String matricula,
    String nomeArquivo,
    Uint8List bytes,
    String extensao,
  ) async {
    final path = 'tenants/$tenantId/alunos/$matricula/anexos/$nomeArquivo';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  Future<void> salvarAluno(Map<String, dynamic> dadosAluno) async {
    dadosAluno['tenantId'] = tenantId;
    await _db
        .collection('tenants')
        .doc(tenantId)
        .collection('alunos')
        .doc(dadosAluno['matricula'])
        .set(dadosAluno);
  }

  Future<void> atualizarStatus(String matricula, String novoStatus) async {
    await _db
        .collection('tenants')
        .doc(tenantId)
        .collection('alunos')
        .doc(matricula)
        .update({'status': novoStatus});
  }

  // ==========================================================
  // EXCLUSÃO COMPLETA E SEGURA EM LOTE (BATCH)
  // ==========================================================
  Future<void> excluirAluno(String matricula) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Apaga a ficha do aluno
      final alunoRef = db
          .collection('tenants')
          .doc(tenantId)
          .collection('alunos')
          .doc(matricula);
      batch.delete(alunoRef);

      // 2. Apaga o login de acesso do aluno (se existir)
      final snapshotUsers = await db
          .collection('tenants')
          .doc(tenantId)
          .collection('usuarios')
          .where('idLogin', isEqualTo: matricula)
          .get();
      for (var doc in snapshotUsers.docs) {
        batch.delete(doc.reference); // Apaga do tenant local
        batch.delete(
          db.collection('usuarios').doc(doc.id),
        ); // Apaga do Auth global
      }

      // 3. Verifica os Responsáveis vinculados para limpeza
      final snapshotResponsaveis = await db
          .collection('tenants')
          .doc(tenantId)
          .collection('responsaveis')
          .get();
      for (var doc in snapshotResponsaveis.docs) {
        final dados = doc.data();
        final vinculosRaw = dados['alunosVinculadosRaw'] as List? ?? [];

        // Se este responsável tem o aluno excluído na lista de filhos
        if (vinculosRaw.any((v) => v['matricula'] == matricula)) {
          // Se só tem esse filho matriculado, apaga o responsável inteiro e seu acesso
          if (vinculosRaw.length == 1) {
            batch.delete(doc.reference); // Apaga ficha do responsável
            batch.delete(
              db.collection('usuarios').doc(doc.id),
            ); // Apaga acesso do responsável
          } else {
            // Se tem outros filhos matriculados, apenas desvincula o aluno apagado
            vinculosRaw.removeWhere((v) => v['matricula'] == matricula);

            // Recria a lista de texto visual
            List<String> vinculosTexto = [];
            for (var v in vinculosRaw) {
              vinculosTexto.add(
                '${v['nome']} (${v['matricula']})'.toUpperCase(),
              );
            }

            batch.update(doc.reference, {
              'alunosVinculadosRaw': vinculosRaw,
              'alunosVinculados': vinculosTexto,
            });
          }
        }
      }

      // Executa todas as exclusões e atualizações ao mesmo tempo!
      await batch.commit();
    } catch (e) {
      throw Exception('Falha ao excluir dados no banco: $e');
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
      .where('matricula', isNotEqualTo: '_setup') // Ignora documentos de setup
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});
