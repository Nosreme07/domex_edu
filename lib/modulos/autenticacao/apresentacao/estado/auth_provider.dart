import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- IMPORTANTE: Conexão real com a "Portaria"

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
      // 1. VERIFICAÇÃO DE ACESSO MASTER (SUPER ADMINS)
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
        }

        return UsuarioSessao(
          id: dadosEscola['id'] ?? snapshotEscola.docs.first.id,
          nome: 'Administração',
          email: email,
          perfil: 'admin_escola',
          nomeEscola: dadosEscola['nome'],
          corPrimaria: corDaEscola, 
        );
      }

      // B) Se não for a escola, verifica se é um Usuário (Professor, Secretaria, etc)
      final snapshotUsuario = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .get();

      if (snapshotUsuario.docs.isNotEmpty) {
        final dadosUsuario = snapshotUsuario.docs.first.data();

        if (dadosUsuario['status'] == 'Bloqueado') {
          await FirebaseAuth.instance.signOut();
          throw Exception('Seu acesso está bloqueado. Procure a secretaria da escola.');
        }

        // Busca as cores da escola desse usuário para deixar a interface personalizada
        final escolaId = dadosUsuario['escolaId'];
        Color corDaEscola = const Color(0xFF2C3E50);
        String nomeEscola = 'Escola';

        if (escolaId != null) {
           final docEscola = await FirebaseFirestore.instance.collection('tenants').doc(escolaId).get();
           if (docEscola.exists) {
             final dadosE = docEscola.data()!;
             nomeEscola = dadosE['nome'] ?? 'Escola';
             if (dadosE['corHex'] != null) {
               corDaEscola = Color(int.parse(dadosE['corHex'], radix: 16));
             }
           }
        }

        return UsuarioSessao(
          id: dadosUsuario['idLogin'] ?? snapshotUsuario.docs.first.id,
          nome: dadosUsuario['nome'] ?? 'Usuário',
          email: email,
          perfil: dadosUsuario['perfil'] ?? 'aluno', // Aqui ele descobre que é 'professor'!
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