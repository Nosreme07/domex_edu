import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

class UsuarioEscolaService {
  final String escolaId;
  final String codigoEscola; 
  final _db = FirebaseFirestore.instance.collection('usuarios');

  UsuarioEscolaService(this.escolaId, this.codigoEscola);

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
    final emailAuth = idLogin.contains('@') ? idLogin : '$idLogin@$codigoEscola.com';

    if (dadosUsuario.containsKey('senha')) {
      await _garantirContaNoFirebaseAuth(emailAuth, dadosUsuario['senha']);
    } else {
      await _garantirContaNoFirebaseAuth(emailAuth, 'Domex@123');
    }
    
    await _db.doc(idLogin).set(dadosUsuario, SetOptions(merge: true));
  }

  Future<void> resetarSenhaEGerarAuth(Map<String, dynamic> u) async {
    // Garante que pega a matrícula 100% limpa, ignorando erros antigos
    final idLogin = u['login'].toString().toLowerCase().trim();
    
    // Cria a credencial usando o domínio atualizado nas configurações
    final emailAuth = idLogin.contains('@') ? idLogin : '$idLogin@$codigoEscola.com';
    final senhaPadrao = 'Domex@123';

    await _garantirContaNoFirebaseAuth(emailAuth, senhaPadrao);
    
    // Sobrescreve os dados no banco, atualizando o email para o domínio correto!
    await _db.doc(idLogin).set({
      'idLogin': idLogin,
      'email': emailAuth, 
      'nome': u['nome'] ?? 'Usuário',
      'perfil': u['perfil'].toString().toLowerCase(),
      'status': u['status'] ?? 'Ativo',
      'escolaId': escolaId, 
      'senha': senhaPadrao,
      'precisaTrocarSenha': true,
    }, SetOptions(merge: true));
  }

  Future<void> excluirUsuario(String idLogin) async {
    await _db.doc(idLogin).delete();
  }
}

final usuarioEscolaServiceProvider = Provider<UsuarioEscolaService?>((ref) {
  final sessao = ref.watch(authProvider).value;
  if (sessao == null) return null;
  return UsuarioEscolaService(sessao.id, sessao.codigoEscola); 
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