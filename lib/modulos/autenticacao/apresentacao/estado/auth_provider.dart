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
      
      // A) Verifica se é o Dono da Escola (Admin)
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

        Color corDaEscola = const Color(0xFF2C3E50); 
        if (dadosEscola['corHex'] != null) {
          corDaEscola = Color(int.parse(dadosEscola['corHex'], radix: 16));
        } else if (dadosEscola['corPrimaria'] != null) {
          String cleanHex = dadosEscola['corPrimaria'].replaceAll('#', '');
          if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
          corDaEscola = Color(int.parse(cleanHex, radix: 16));
        }

        return UsuarioSessao(
          id: dadosEscola['id'] ?? snapshotEscola.docs.first.id,
          nome: 'Administração',
          email: email,
          perfil: 'admin_escola',
          nomeEscola: dadosEscola['nomeEscola'] ?? dadosEscola['nome'],
          corPrimaria: corDaEscola, 
        );
      }

      // B) Verifica se é um Usuário (Super Admin novo, Professor, Secretaria, etc)
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

        // --- A CORREÇÃO ESTÁ AQUI ---
        // Descobre se o usuário é um novo Super Admin cadastrado via painel
        String perfilAtribuido = dadosUsuario['perfil'] ?? 'aluno';
        if (dadosUsuario['role'] == 'SUPER_ADMIN') {
          perfilAtribuido = 'super_admin';
        }

        // Configura as cores e nomes baseado no perfil
        final escolaId = dadosUsuario['escolaId'] ?? dadosUsuario['tenantId'];
        Color corDaEscola = const Color(0xFF2C3E50);
        String nomeEscola = 'SaaS Domex';

        if (perfilAtribuido == 'super_admin') {
          // Cores exclusivas do Super Admin
          corDaEscola = Colors.deepPurple.shade900;
        } else if (escolaId != null) {
           // Busca as cores da escola para professores/secretaria
           final docEscola = await FirebaseFirestore.instance.collection('tenants').doc(escolaId).get();
           if (docEscola.exists) {
             final dadosE = docEscola.data()!;
             nomeEscola = dadosE['nomeEscola'] ?? dadosE['nome'] ?? 'Escola';
             
             if (dadosE['corHex'] != null) {
               corDaEscola = Color(int.parse(dadosE['corHex'], radix: 16));
             } else if (dadosE['corPrimaria'] != null) {
                String cleanHex = dadosE['corPrimaria'].replaceAll('#', '');
                if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
                corDaEscola = Color(int.parse(cleanHex, radix: 16));
             }
           }
        }

        return UsuarioSessao(
          id: dadosUsuario['uid'] ?? dadosUsuario['idLogin'] ?? snapshotUsuario.docs.first.id,
          nome: dadosUsuario['nome'] ?? 'Usuário',
          email: email,
          perfil: perfilAtribuido, 
          nomeEscola: nomeEscola,
          corPrimaria: corDaEscola,
        );
      }

      // C) Passou pela portaria, mas a ficha sumiu do banco de dados
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