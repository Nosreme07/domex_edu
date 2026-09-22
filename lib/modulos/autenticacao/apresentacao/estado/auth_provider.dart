import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

class UsuarioSessao {
  final String id;
  final String nome;
  final String email;
  final String perfil; 
  final String? nomeEscola;
  final String? dominioPersonalizado; // NOVO CAMPO ADICIONADO
  final Color corPrimaria;

  // AGORA PRIORIZA O DOMÍNIO ESCOLHIDO NAS CONFIGURAÇÕES
  String get codigoEscola {
    if (dominioPersonalizado != null && dominioPersonalizado!.trim().isNotEmpty) {
      return dominioPersonalizado!.trim().toLowerCase();
    }
    
    // Fallback: se a escola ainda não configurou o domínio, gera a partir do nome
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
    required this.id, required this.nome, required this.email,
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
          return UsuarioSessao(id: 'MASTER-01', nome: 'Emerson Fernandes', email: usuarioFirebase.email!, perfil: 'super_admin', corPrimaria: Colors.deepPurple.shade900);
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
    final snapshotEscola = await FirebaseFirestore.instance.collection('tenants').where('email', isEqualTo: emailAuthFirebase).get();
    
    if (snapshotEscola.docs.isNotEmpty) {
      final dadosEscola = snapshotEscola.docs.first.data();
      if (dadosEscola['status'] == 'Bloqueado') throw Exception('O acesso desta escola está bloqueado. Contate o suporte.');
      
      return UsuarioSessao(
        id: dadosEscola['id'] ?? snapshotEscola.docs.first.id, 
        nome: 'Administração', 
        email: emailAuthFirebase, 
        perfil: 'admin_escola',
        nomeEscola: dadosEscola['nomeEscola'] ?? dadosEscola['nome'], 
        dominioPersonalizado: dadosEscola['dominio'], // LÊ DO BANCO AQUI!
        corPrimaria: _safelyParseColor(dadosEscola), 
      );
    }

    String loginBusca = emailAuthFirebase;
    if (loginBusca.contains('@')) {
       final partes = loginBusca.split('@');
       loginBusca = partes[0];
    }

    Map<String, dynamic>? dadosUsuarioEncontrado;
    String perfilEncontrado = 'aluno';
    String? idEscolaEncontrada;

    final snapUsuariosManuais = await FirebaseFirestore.instance.collection('usuarios').where('idLogin', isEqualTo: loginBusca).get();
    if (snapUsuariosManuais.docs.isNotEmpty) {
      dadosUsuarioEncontrado = snapUsuariosManuais.docs.first.data();
      perfilEncontrado = (dadosUsuarioEncontrado['perfil'] ?? 'admin').toString().toLowerCase();
      idEscolaEncontrada = dadosUsuarioEncontrado['escolaId'];
    }

    if (dadosUsuarioEncontrado == null) {
      final todasAsEscolas = await FirebaseFirestore.instance.collection('tenants').get();
      for (var escolaDoc in todasAsEscolas.docs) {
        final escolaIdRef = escolaDoc.id;

        final snapAluno = await escolaDoc.reference.collection('alunos').where('matricula', isEqualTo: loginBusca).get();
        if (snapAluno.docs.isNotEmpty) {
          dadosUsuarioEncontrado = snapAluno.docs.first.data();
          dadosUsuarioEncontrado['id'] = snapAluno.docs.first.id;
          perfilEncontrado = 'aluno';
          idEscolaEncontrada = escolaIdRef;
          break;
        }

        final snapProf = await escolaDoc.reference.collection('professores').where('id', isEqualTo: loginBusca).get();
        if (snapProf.docs.isNotEmpty) {
          dadosUsuarioEncontrado = snapProf.docs.first.data();
          perfilEncontrado = 'professor';
          idEscolaEncontrada = escolaIdRef;
          break;
        }

        final snapResp = await escolaDoc.reference.collection('responsaveis').where('cpf', isEqualTo: loginBusca).get();
        if (snapResp.docs.isNotEmpty) {
          dadosUsuarioEncontrado = snapResp.docs.first.data();
          perfilEncontrado = 'responsavel';
          idEscolaEncontrada = escolaIdRef;
          break;
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
        dominioEscola = dadosE['dominio']; // LÊ DO BANCO PARA O ALUNO TAMBÉM!
        corDaEscola = _safelyParseColor(dadosE);
      }

      return UsuarioSessao(
        id: dadosUsuarioEncontrado['id'] ?? dadosUsuarioEncontrado['matricula'] ?? dadosUsuarioEncontrado['cpf'] ?? loginBusca,
        nome: dadosUsuarioEncontrado['nome'] ?? 'Usuário', 
        email: emailAuthFirebase, 
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
        return UsuarioSessao(id: 'MASTER-01', nome: 'Emerson Fernandes', email: email, perfil: 'super_admin', corPrimaria: Colors.deepPurple.shade900);
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