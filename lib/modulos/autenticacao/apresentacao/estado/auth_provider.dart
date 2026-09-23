import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

class UsuarioSessao {
  final String id;
  final String tenantId; // NOVO: Garante que sabemos de qual escola este usuário é!
  final String nome;
  final String email;
  final String perfil; 
  final String? nomeEscola;
  final String? dominioPersonalizado; 
  final Color corPrimaria;

  String get codigoEscola {
    if (dominioPersonalizado != null && dominioPersonalizado!.trim().isNotEmpty) {
      return dominioPersonalizado!.trim().toLowerCase();
    }
    
    if (nomeEscola == null) return 'escola';
    String codigo = nomeEscola!.toLowerCase();
    var comAcento = 'àáâãäåòóôõöøèéêëçìíîïùúûüñ';
    var semAcento = 'aaaaaaooooooeeeeciiiiuuuuun';
    for (int i = 0; i < comAcento.length; i++) {
      codigo = codigo.replaceAll(comAcento[i], semAcento[i]);
    }
    return codigo.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  UsuarioSessao({
    required this.id, required this.tenantId, required this.nome, required this.email,
    required this.perfil, this.nomeEscola, this.dominioPersonalizado,
    this.corPrimaria = const Color(0xFF2C3E50), 
  });
}

class AuthController extends AsyncNotifier<UsuarioSessao?> {
  @override
  Future<UsuarioSessao?> build() async {
    final usuarioFirebase = FirebaseAuth.instance.currentUser;
    if (usuarioFirebase != null && usuarioFirebase.email != null) {
      try {
        final List<String> emailsMaster = ['emerson.fernandesantos@gmail.com', 'suporte@jpsmicromaq.com.br'];
        if (emailsMaster.contains(usuarioFirebase.email)) {
          return UsuarioSessao(
            id: 'MASTER-01', tenantId: 'MASTER-01', nome: 'Emerson Fernandes', 
            email: usuarioFirebase.email!, perfil: 'super_admin', corPrimaria: Colors.deepPurple.shade900
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
    } catch (_) { return fallback; }
  }

  Future<UsuarioSessao> _buscarDadosNoFirestore(String emailAuthFirebase) async {
    String emailCompleto = emailAuthFirebase.toLowerCase().trim();
    
    // 1. TENTA ACHAR A ESCOLA PRIMEIRO
    final snapshotEscola = await FirebaseFirestore.instance.collection('tenants').where('email', isEqualTo: emailCompleto).get();
    
    if (snapshotEscola.docs.isNotEmpty) {
      final dadosEscola = snapshotEscola.docs.first.data();
      if (dadosEscola['status'] == 'Bloqueado') throw Exception('O acesso desta escola está bloqueado. Contate o suporte.');
      
      final escolaId = dadosEscola['id'] ?? snapshotEscola.docs.first.id;
      return UsuarioSessao(
        id: escolaId, tenantId: escolaId, 
        nome: 'Administração', 
        email: emailCompleto, 
        perfil: 'admin_escola',
        nomeEscola: dadosEscola['nomeEscola'] ?? dadosEscola['nome'], 
        dominioPersonalizado: dadosEscola['dominio'], 
        corPrimaria: _safelyParseColor(dadosEscola), 
      );
    }

    String prefixo = emailCompleto;
    if (emailCompleto.contains('@')) {
       prefixo = emailCompleto.split('@')[0];
    }

    Map<String, dynamic>? dadosUsuarioEncontrado;
    String perfilEncontrado = 'aluno';
    String? idEscolaEncontrada;

    // Busca acessos manuais globais 
    var snapUsuariosManuais = await FirebaseFirestore.instance.collection('usuarios').where('idLogin', isEqualTo: emailCompleto).get();
    if (snapUsuariosManuais.docs.isEmpty) {
      snapUsuariosManuais = await FirebaseFirestore.instance.collection('usuarios').where('idLogin', isEqualTo: prefixo).get();
    }
    if (snapUsuariosManuais.docs.isEmpty) {
      snapUsuariosManuais = await FirebaseFirestore.instance.collection('usuarios').where('email', isEqualTo: emailCompleto).get();
    }

    if (snapUsuariosManuais.docs.isNotEmpty) {
      dadosUsuarioEncontrado = snapUsuariosManuais.docs.first.data();
      perfilEncontrado = (dadosUsuarioEncontrado['perfil'] ?? 'admin').toString().toLowerCase();
      idEscolaEncontrada = dadosUsuarioEncontrado['escolaId'];
    }

    // Busca nas Subcoleções do Tenant
    if (dadosUsuarioEncontrado == null) {
      var snapQuery = await FirebaseFirestore.instance.collectionGroup('alunos').where('matricula', isEqualTo: prefixo).get();
      if (snapQuery.docs.isEmpty) {
         snapQuery = await FirebaseFirestore.instance.collectionGroup('alunos').where('email', isEqualTo: emailCompleto).get();
      }

      if (snapQuery.docs.isNotEmpty) {
        dadosUsuarioEncontrado = snapQuery.docs.first.data();
        dadosUsuarioEncontrado['id'] = snapQuery.docs.first.id;
        perfilEncontrado = 'aluno';
        idEscolaEncontrada = snapQuery.docs.first.reference.parent.parent?.id;
      } else {
        
        snapQuery = await FirebaseFirestore.instance.collectionGroup('professores').where('id', isEqualTo: prefixo).get();
        if (snapQuery.docs.isEmpty) {
           snapQuery = await FirebaseFirestore.instance.collectionGroup('professores').where('email', isEqualTo: emailCompleto).get();
        }

        if (snapQuery.docs.isNotEmpty) {
          dadosUsuarioEncontrado = snapQuery.docs.first.data();
          perfilEncontrado = 'professor';
          idEscolaEncontrada = snapQuery.docs.first.reference.parent.parent?.id;
        } else {
          
          snapQuery = await FirebaseFirestore.instance.collectionGroup('responsaveis').where('cpf', isEqualTo: prefixo).get();
          if (snapQuery.docs.isEmpty) {
             snapQuery = await FirebaseFirestore.instance.collectionGroup('responsaveis').where('email', isEqualTo: emailCompleto).get();
          }

          if (snapQuery.docs.isNotEmpty) {
            dadosUsuarioEncontrado = snapQuery.docs.first.data();
            perfilEncontrado = 'responsavel';
            idEscolaEncontrada = snapQuery.docs.first.reference.parent.parent?.id;
          }
        }
      }
    }

    if (dadosUsuarioEncontrado != null && idEscolaEncontrada != null) {
      if (dadosUsuarioEncontrado['status'] == 'Bloqueado' || dadosUsuarioEncontrado['status'] == 'Inativo') {
        throw Exception('Seu acesso está bloqueado. Procure a administração da escola.');
      }

      Color corDaEscola = const Color(0xFF2C3E50);
      String nomeEscola = 'Escola';
      String? dominioEscola;
      
      final docEscola = await FirebaseFirestore.instance.collection('tenants').doc(idEscolaEncontrada).get();
      if (docEscola.exists && docEscola.data() != null) {
        final dadosE = docEscola.data()!;
        nomeEscola = dadosE['nomeEscola'] ?? dadosE['nome'] ?? 'Escola';
        dominioEscola = dadosE['dominio']; 
        corDaEscola = _safelyParseColor(dadosE);
      }

      return UsuarioSessao(
        id: dadosUsuarioEncontrado['id'] ?? dadosUsuarioEncontrado['matricula'] ?? dadosUsuarioEncontrado['cpf'] ?? prefixo,
        tenantId: idEscolaEncontrada, // <--- SALVA O ID DA ESCOLA AQUI
        nome: dadosUsuarioEncontrado['nome'] ?? 'Usuário', 
        email: emailCompleto, 
        perfil: perfilEncontrado, 
        nomeEscola: nomeEscola, 
        dominioPersonalizado: dominioEscola,
        corPrimaria: corDaEscola,
      );
    }

    throw Exception('A sua senha está correta, mas a sua ficha não foi encontrada nos registos da escola.');
  }

  Future<void> fazerLogin(String email, String senha) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final List<String> emailsMaster = ['emerson.fernandesantos@gmail.com', 'suporte@jpsmicromaq.com.br'];
      if (emailsMaster.contains(email) && senha == '123456') {
        return UsuarioSessao(id: 'MASTER-01', tenantId: 'MASTER-01', nome: 'Emerson Fernandes', email: email, perfil: 'super_admin', corPrimaria: Colors.deepPurple.shade900);
      } 
      
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: senha);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') throw Exception('Cadastro não encontrado ou credenciais inválidas.');
        else if (e.code == 'wrong-password') throw Exception('Senha incorreta.');
        else throw Exception('Erro de autenticação: ${e.message}');
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