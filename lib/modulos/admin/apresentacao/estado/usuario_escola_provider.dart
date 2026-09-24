import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
          debugPrint('Erro no Firebase Auth: ${e.message}');
        }
      }
    } catch (e) {
      debugPrint('Erro ao inicializar App Secundário: $e');
    }
  }

  Future<void> salvarUsuario(Map<String, dynamic> dadosUsuario) async {
    dadosUsuario['escolaId'] = escolaId;
    dadosUsuario['dataCriacao'] = FieldValue.serverTimestamp();
    
    String idLogin = dadosUsuario['idLogin'].toString().toLowerCase().trim();
    
    if (idLogin.endsWith('@domex.com') || (codigoEscola.isNotEmpty && idLogin.endsWith('@$codigoEscola.com'))) {
      idLogin = idLogin.split('@')[0];
      dadosUsuario['idLogin'] = idLogin;
    }

    final emailAuth = idLogin.contains('@') ? idLogin : '$idLogin@$codigoEscola.com';
    dadosUsuario['email'] = emailAuth;

    if (dadosUsuario.containsKey('senha')) {
      await _garantirContaNoFirebaseAuth(emailAuth, dadosUsuario['senha']);
    } else {
      await _garantirContaNoFirebaseAuth(emailAuth, 'Domex@123');
    }
    
    if (!idLogin.contains('@')) {
      try {
        final docAntigo = await _db.doc('$idLogin@domex.com').get();
        if (docAntigo.exists) await docAntigo.reference.delete();
      } catch (_) {}
    }
    
    await _db.doc(idLogin).set(dadosUsuario, SetOptions(merge: true));
  }

  Future<void> resetarSenhaEGerarAuth(Map<String, dynamic> u) async {
    String idLogin = u['login'].toString().toLowerCase().trim();

    if (idLogin.endsWith('@domex.com') || (codigoEscola.isNotEmpty && idLogin.endsWith('@$codigoEscola.com'))) {
      idLogin = idLogin.split('@')[0];
    }

    final emailAuth = idLogin.contains('@') ? idLogin : '$idLogin@$codigoEscola.com';
    const senhaPadrao = 'Domex@123';

    await _garantirContaNoFirebaseAuth(emailAuth, senhaPadrao);
    
    if (!idLogin.contains('@')) {
      try {
        final docAntigo = await _db.doc('$idLogin@domex.com').get();
        if (docAntigo.exists) await docAntigo.reference.delete();
      } catch (_) {}
    }
    
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

  // ==========================================================================
  // EXCLUSÃO BLINDADA: Varre todo o banco garantindo a remoção do acesso
  // ==========================================================================
  Future<void> excluirAcessoCompleto({
    required String login,
    String? matricula,
    String? id,
    String? cpf,
    String? email,
  }) async {
    try {
      final Set<String> candidatos = {login.toLowerCase().trim()};
      if (matricula != null) candidatos.add(matricula.toLowerCase().trim());
      if (id != null) candidatos.add(id.toLowerCase().trim());
      if (cpf != null) candidatos.add(cpf.toLowerCase().trim());
      if (email != null) candidatos.add(email.toLowerCase().trim());

      final Set<String> extras = {};
      for (var c in candidatos) {
         if (c.contains('@')) extras.add(c.split('@')[0]);
      }
      candidatos.addAll(extras);

      final querySnap = await _db.where('escolaId', isEqualTo: escolaId).get();
      for (final doc in querySnap.docs) {
        final data = doc.data();
        final docIdLogin = (data['idLogin'] ?? '').toString().toLowerCase().trim();
        final docEmail = (data['email'] ?? '').toString().toLowerCase().trim();
        
        if (candidatos.contains(doc.id.toLowerCase().trim()) || 
            candidatos.contains(docIdLogin) || 
            candidatos.contains(docEmail)) {
          try {
            await doc.reference.delete();
          } catch (e) {
            debugPrint('Aviso exclusão: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Erro geral na exclusão: $e');
    }
  }

  Future<void> excluirUsuario(String idLoginRaw) async {
    await excluirAcessoCompleto(login: idLoginRaw);
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