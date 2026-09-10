import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

// 1. Entidade do Usuário Logado
class UsuarioSessao {
  final String id;
  final String nome;
  final String email;
  final String perfil; // 'super_admin', 'admin_escola', 'professor', 'secretaria', 'aluno'
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
    return null; 
  }

  // Helper para não quebrar o login caso a corHex ou corPrimaria venha zuada do Firebase
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

  Future<void> fazerLogin(String email, String senha) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      
      // ==========================================================
      // 1. VERIFICAÇÃO DE ACESSO MASTER (BACKDOOR HARDCODED)
      // Mantido para garantir que você não perca seu acesso antigo
      // ==========================================================
      final List<String> emailsMaster = [
        'emerson.fernandesantos@gmail.com',
        'suporte@jpsmicromaq.com.br', 
      ];

      if (emailsMaster.contains(email) && senha == '123456') {
        return UsuarioSessao(
          id: 'MASTER-01',
          nome: 'Emerson Fernandes',
          email: email,
          perfil: 'super_admin',
          corPrimaria: Colors.deepPurple.shade900,
        );
      } 

      // ==========================================================
      // 2. AUTENTICAÇÃO REAL NO FIREBASE AUTH (A PORTARIA)
      // ==========================================================
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: senha,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
           throw Exception('E-mail não encontrado ou credenciais inválidas.');
        } else if (e.code == 'wrong-password') {
           throw Exception('Senha incorreta.');
        } else {
           throw Exception('Erro de autenticação: ${e.message}');
        }
      }

      // ==========================================================
      // 3. IDENTIFICAÇÃO DE PERFIL NO BANCO DE DADOS (Firestore)
      // ==========================================================
      
      // A) Verifica se é o Dono da Escola (Admin / Tenant)
      final snapshotEscola = await FirebaseFirestore.instance
          .collection('tenants')
          .where('email', isEqualTo: email)
          .get();

      if (snapshotEscola.docs.isNotEmpty) {
        final dadosEscola = snapshotEscola.docs.first.data();
        
        if (dadosEscola['status'] == 'Bloqueado') {
          await FirebaseAuth.instance.signOut();
          throw Exception('O acesso desta escola está bloqueado. Contate o suporte da Domex.');
        }

        return UsuarioSessao(
          id: dadosEscola['id'] ?? snapshotEscola.docs.first.id,
          nome: 'Administração',
          email: email,
          perfil: 'admin_escola',
          nomeEscola: dadosEscola['nomeEscola'] ?? dadosEscola['nome'],
          corPrimaria: _safelyParseColor(dadosEscola), 
        );
      }

      // B) Verifica se é um Usuário de Acesso (Professor, Secretaria, Aluno)
      final snapshotUsuario = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .get();

      if (snapshotUsuario.docs.isNotEmpty) {
        final dadosUsuario = snapshotUsuario.docs.first.data();

        if (dadosUsuario['status'] == 'Bloqueado') {
          await FirebaseAuth.instance.signOut();
          throw Exception('Seu acesso está bloqueado. Procure a administração.');
        }

        String perfilAtribuido = dadosUsuario['perfil'] ?? 'aluno';
        if (dadosUsuario['role'] == 'SUPER_ADMIN') {
          perfilAtribuido = 'super_admin';
        }

        // Configura as cores e nomes baseado na escola onde ele trabalha
        final escolaId = dadosUsuario['escolaId'] ?? dadosUsuario['tenantId'];
        Color corDaEscola = const Color(0xFF2C3E50);
        String nomeEscola = 'SaaS Domex';

        if (perfilAtribuido == 'super_admin') {
          corDaEscola = Colors.deepPurple.shade900;
        } else if (escolaId != null) {
           final docEscola = await FirebaseFirestore.instance.collection('tenants').doc(escolaId).get();
           if (docEscola.exists && docEscola.data() != null) {
             final dadosE = docEscola.data()!;
             nomeEscola = dadosE['nomeEscola'] ?? dadosE['nome'] ?? 'Escola';
             corDaEscola = _safelyParseColor(dadosE);
           } else {
             await FirebaseAuth.instance.signOut();
             throw Exception('Não foi possível localizar o cadastro da sua instituição de ensino.');
           }
        }

        return UsuarioSessao(
          // ==============================================================
          // A MÁGICA ACONTECE AQUI:
          // Agora forçamos o sistema a usar o 'escolaId' na sessão. 
          // Todos os provedores de dados vão baixar os dados corretos!
          // ==============================================================
          id: escolaId ?? dadosUsuario['uid'] ?? snapshotUsuario.docs.first.id,
          nome: dadosUsuario['nome'] ?? 'Usuário',
          email: email,
          perfil: perfilAtribuido, 
          nomeEscola: nomeEscola,
          corPrimaria: corDaEscola,
        );
      }

      // C) Passou pela portaria do Auth, mas a ficha sumiu do banco de dados Firestore
      await FirebaseAuth.instance.signOut();
      throw Exception('Sua conta foi autenticada, mas seu perfil não foi encontrado no sistema.');
    });
  }

  Future<void> fazerLogout() async {
    await FirebaseAuth.instance.signOut(); // Desloga do Firebase também
    state = const AsyncData(null);
  }
}

// 3. Provedor Global
final authProvider = AsyncNotifierProvider<AuthController, UsuarioSessao?>(() {
  return AuthController();
});