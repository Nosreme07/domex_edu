import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class UsuarioEscolaService {
  final String escolaId;
  final _db = FirebaseFirestore.instance.collection('usuarios');

  UsuarioEscolaService(this.escolaId);

  Future<void> _garantirContaNoFirebaseAuth(String email, String senha) async {
    try {
      FirebaseApp appSecundario;
      try {
        appSecundario = Firebase.app('AppSecundario');
      } catch (e) {
        appSecundario = await Firebase.initializeApp(name: 'AppSecundario', options: Firebase.app().options);
      }
      final authSecundario = FirebaseAuth.instanceFor(app: appSecundario);
      try {
        await authSecundario.createUserWithEmailAndPassword(email: email, password: senha);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') {
          print('Erro no Firebase Auth: ${e.message}');
        }
      }
    } catch (e) {
      print('Erro ao inicializar App Secundário: $e');
    }
  }

  Future<void> salvarUsuario(Map<String, dynamic> dadosUsuario) async {
    dadosUsuario['escolaId'] = escolaId;
    dadosUsuario['dataCriacao'] = FieldValue.serverTimestamp();
    
    final idLogin = dadosUsuario['idLogin'].toString().toLowerCase().trim();
    final emailAuth = idLogin.contains('@') ? idLogin : '$idLogin@domex.com';

    if (dadosUsuario.containsKey('senha')) {
      await _garantirContaNoFirebaseAuth(emailAuth, dadosUsuario['senha']);
    } else {
      await _garantirContaNoFirebaseAuth(emailAuth, 'Domex@123');
    }
    
    await _db.doc(idLogin).set(dadosUsuario, SetOptions(merge: true));
  }

  // ==========================================================================
  // AGORA ELE RECEBE O MAPA INTEIRO PARA GUARDAR A ESCOLA E O PERFIL CORRETO
  // ==========================================================================
  Future<void> resetarSenhaEGerarAuth(Map<String, dynamic> u) async {
    final idLogin = u['login'].toString().toLowerCase().trim();
    final emailAuth = idLogin.contains('@') ? idLogin : '$idLogin@domex.com';
    final senhaPadrao = 'Domex@123';

    await _garantirContaNoFirebaseAuth(emailAuth, senhaPadrao);
    
    // Força a inserção dos dados essenciais para o login fluir!
    await _db.doc(idLogin).set({
      'idLogin': idLogin,
      'email': emailAuth,
      'nome': u['nome'] ?? 'Usuário',
      'perfil': u['perfil'].toString().toLowerCase(),
      'status': u['status'] ?? 'Ativo',
      'escolaId': escolaId, // Amarra perfeitamente à escola logada
      'senha': senhaPadrao,
      'precisaTrocarSenha': true,
    }, SetOptions(merge: true));
  }

  Future<void> excluirUsuario(String idLogin) async {
    await _db.doc(idLogin).delete();
  }
}

final usuarioEscolaServiceProvider = Provider<UsuarioEscolaService?>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return null;
  return UsuarioEscolaService(usuario.id); 
});

final usuariosEscolaStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final usuario = ref.watch(authProvider).value;
  if (usuario == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('usuarios')
      .where('escolaId', isEqualTo: usuario.id)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});