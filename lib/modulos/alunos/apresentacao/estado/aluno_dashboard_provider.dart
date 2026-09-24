import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// ============================================================================
// PROVIDER 1: BUSCA OS DADOS DO PERFIL DO ALUNO (NOME, TURMA, FOTO, ETC)
// ============================================================================
final dadosAlunoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return null;

  final tenantId = usuario.tenantId;
  final alunoIdSeguro = usuario.id;
  final email = usuario.email.trim().toLowerCase();

  try {
    // 1ª Tentativa: Busca diretamente pela Matrícula validada no Auth
    var snap = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('alunos')
        .where('matricula', isEqualTo: alunoIdSeguro)
        .limit(1)
        .get();
        
    // 2ª Tentativa: Busca pelo E-mail real (caso tenha)
    if (snap.docs.isEmpty && email.isNotEmpty && !email.contains('@domex.com') && !email.contains(tenantId.toLowerCase())) {
      snap = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('alunos')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    }

    if (snap.docs.isNotEmpty) {
      final dados = snap.docs.first.data();
      dados['docId'] = snap.docs.first.id;
      return dados;
    }
  } catch (e) {
    print('Erro ao buscar dados do aluno: $e');
  }
  return null;
});

// ============================================================================
// PROVIDER 2: BUSCA AS PRÓXIMAS AVALIAÇÕES DA TURMA DO ALUNO
// ============================================================================
final avaliacoesAlunoStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, turmaId) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null || turmaId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.tenantId)
      .collection('turmas')
      .doc(turmaId)
      .collection('avaliacoes')
      .orderBy('dataCriacao', descending: true)
      .limit(5)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList());
});

// ============================================================================
// PROVIDER 3: BUSCA O MURAL DE AVISOS DA TURMA DO ALUNO
// ============================================================================
final avisosAlunoStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, turmaId) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null || turmaId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(usuario.tenantId)
      .collection('turmas')
      .doc(turmaId)
      .collection('avisos')
      .orderBy('dataEnvio', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList());
});

// ============================================================================
// PROVIDER 4: BUSCA A GRADE DE AULAS DA TURMA
// ============================================================================
final gradeAulasAlunoProvider = FutureProvider.family<List<dynamic>, String>((ref, turmaId) async {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null || turmaId.isEmpty) return [];

  try {
    final docTurma = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(usuario.tenantId)
        .collection('turmas')
        .doc(turmaId)
        .get();

    if (docTurma.exists) {
      final dados = docTurma.data() as Map<String, dynamic>;
      return dados['horarios'] as List? ?? [];
    }
  } catch (e) {
    print('Erro ao buscar grade de aulas: $e');
  }
  return [];
});