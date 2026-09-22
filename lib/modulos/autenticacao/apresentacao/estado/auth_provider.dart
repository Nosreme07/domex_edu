import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

// 1. Entidade do Usuário Logado
class UsuarioSessao {
  final String id;
  final String nome;
  final String email;
  final String perfil; 
  final String? nomeEscola;
  final Color corPrimaria;

  UsuarioSessao({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.nomeEscola,
    this.corPrimaria = const Color(0xFF2C3E50), 
  });
}

// 2. Controlador de Autenticação
class AuthController extends AsyncNotifier<UsuarioSessao?> {
  
  @override
  Future<UsuarioSessao?> build() async {
    final usuarioFirebase = FirebaseAuth.instance.currentUser;

    if (usuarioFirebase != null && usuarioFirebase.email != null) {
      try {
        final List<String> emailsMaster = ['emerson.fernandesantos@gmail.com', 'suporte@jpsmicromaq.com.br'];
        if (emailsMaster.contains(usuarioFirebase.email)) {
          return UsuarioSessao(
            id: 'MASTER-01',
            nome: 'Emerson Fernandes',
            email: usuarioFirebase.email!,
            perfil: 'super_admin',
            corPrimaria: Colors.deepPurple.shade900,
          );
        }
        return await _buscarDadosNoFirestore(usuarioFirebase.email!);
      } catch (e) {
        await FirebaseAuth.instance.signOut();
        return null;
      }
    }
    return null; 
  }

  Color _safelyParseColor(Map<String, dynamic> dados) {
    Color fallback = const Color(0xFF2C3E50);
    String? corBruta = dados['corHex'] ?? dados['corPrimaria'];
    
    if (corBruta == null || corBruta.isEmpty) return fallback;
    
    try {
      String cleanHex = corBruta.replaceAll('#', '').replaceAll('Color(0xff', '').replaceAll(')', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  Future<UsuarioSessao> _buscarDadosNoFirestore(String email) async {
    // A) Verifica se é o Admin da Escola
    final snapshotEscola = await FirebaseFirestore.instance.collection('tenants').where('email', isEqualTo: email).get();

    if (snapshotEscola.docs.isNotEmpty) {
      final dadosEscola = snapshotEscola.docs.first.data();
      if (dadosEscola['status'] == 'Bloqueado') {
        throw Exception('O acesso desta escola está bloqueado. Contate o suporte.');
      }
      return UsuarioSessao(
        id: dadosEscola['id'] ?? snapshotEscola.docs.first.id,
        nome: 'Administração', email: email, perfil: 'admin_escola',
        nomeEscola: dadosEscola['nomeEscola'] ?? dadosEscola['nome'],
        corPrimaria: _safelyParseColor(dadosEscola), 
      );
    }

    // B) Verifica na coleção global de acessos
    var snapshotUsuario = await FirebaseFirestore.instance.collection('usuarios').where('idLogin', isEqualTo: email).get();

    if (snapshotUsuario.docs.isEmpty) {
        snapshotUsuario = await FirebaseFirestore.instance.collection('usuarios').where('email', isEqualTo: email).get();
    }

    if (snapshotUsuario.docs.isEmpty && email.endsWith('@domex.com')) {
       final idOriginal = email.replaceAll('@domex.com', '');
       snapshotUsuario = await FirebaseFirestore.instance.collection('usuarios').where('idLogin', isEqualTo: idOriginal).get();
    }

    if (snapshotUsuario.docs.isNotEmpty) {
      final dadosUsuario = snapshotUsuario.docs.first.data();

      if (dadosUsuario['status'] == 'Bloqueado' || dadosUsuario['status'] == 'Inativo') {
        throw Exception('Seu acesso está bloqueado. Procure a administração.');
      }

      String perfilAtribuido = dadosUsuario['perfil'] ?? 'aluno';
      if (dadosUsuario['role'] == 'SUPER_ADMIN') perfilAtribuido = 'super_admin';

      final escolaId = dadosUsuario['escolaId'] ?? dadosUsuario['tenantId'];
      Color corDaEscola = const Color(0xFF2C3E50);
      String nomeEscola = 'SaaS Domex';

      if (perfilAtribuido == 'super_admin') {
        corDaEscola = Colors.deepPurple.shade900;
      } else if (escolaId != null) {
         var docEscola = await FirebaseFirestore.instance.collection('tenants').doc(escolaId).get();
         
         // Tenta buscar por ID alternativo caso a chave primária não bata
         if (!docEscola.exists) {
            final query = await FirebaseFirestore.instance.collection('tenants').where('id', isEqualTo: escolaId).get();
            if (query.docs.isNotEmpty) docEscola = query.docs.first;
         }

         if (docEscola.exists && docEscola.data() != null) {
           final dadosE = docEscola.data()!;
           nomeEscola = dadosE['nomeEscola'] ?? dadosE['nome'] ?? 'Escola';
           corDaEscola = _safelyParseColor(dadosE);
         } else {
           throw Exception('Não foi possível localizar o cadastro da sua instituição de ensino.');
         }
      } else {
         throw Exception('O seu utilizador não está vinculado a nenhuma escola. Peça ao diretor para redefinir a sua senha.');
      }

      return UsuarioSessao(
        id: escolaId ?? dadosUsuario['uid'] ?? snapshotUsuario.docs.first.id,
        nome: dadosUsuario['nome'] ?? 'Usuário', email: email, perfil: perfilAtribuido.toLowerCase(), 
        nomeEscola: nomeEscola, corPrimaria: corDaEscola,
      );
    }

    throw Exception('Sua conta foi autenticada, mas seu perfil não foi encontrado no sistema.');
  }

  Future<void> fazerLogin(String email, String senha) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final List<String> emailsMaster = ['emerson.fernandesantos@gmail.com', 'suporte@jpsmicromaq.com.br'];
      if (emailsMaster.contains(email) && senha == '123456') {
        return UsuarioSessao(
          id: 'MASTER-01', nome: 'Emerson Fernandes', email: email, perfil: 'super_admin', corPrimaria: Colors.deepPurple.shade900,
        );
      } 
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: senha);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
           throw Exception('[ERRO] Login não encontrado ou senha inválida.');
        } else if (e.code == 'wrong-password') {
           throw Exception('[ERRO] Senha incorreta.');
        } else {
           throw Exception('[ERRO] ${e.message}');
        }
      }
      try {
        return await _buscarDadosNoFirestore(email);
      } catch (e) {
        await FirebaseAuth.instance.signOut();
        rethrow;
      }
    });
  }

  Future<void> fazerLogout() async {
    await FirebaseAuth.instance.signOut(); 
    state = const AsyncData(null); 
  }
}

final authProvider = AsyncNotifierProvider<AuthController, UsuarioSessao?>(() {
  return AuthController();
});