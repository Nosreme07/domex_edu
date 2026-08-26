import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// Serviço para gerenciar os usuários da escola
class UsuarioEscolaService {
  final String escolaId;
  final _db = FirebaseFirestore.instance.collection('usuarios');

  UsuarioEscolaService(this.escolaId);

  Future<void> salvarUsuario(Map<String, dynamic> dadosUsuario) async {
    // Garante que o usuário fique amarrado à escola atual
    dadosUsuario['escolaId'] = escolaId;
    dadosUsuario['dataCriacao'] = FieldValue.serverTimestamp();
    
    // O ID do documento será a matrícula/ID digitada para facilitar
    await _db.doc(dadosUsuario['idLogin']).set(dadosUsuario, SetOptions(merge: true));
  }

  Future<void> excluirUsuario(String idLogin) async {
    await _db.doc(idLogin).delete();
  }
}

// Provider do Serviço (depende da escola logada)
final usuarioEscolaServiceProvider = Provider<UsuarioEscolaService?>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return null;
  return UsuarioEscolaService(usuario.id); // O ID do admin logado é o ID da escola
});

// Provider para listar os usuários em tempo real na tabela
final usuariosEscolaStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('usuarios')
      .where('escolaId', isEqualTo: usuario.id)
      .orderBy('nome')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});