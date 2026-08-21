import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // IMPORT DO FIREBASE ADICIONADO

// 1. Entidade do Usuário Logado
class UsuarioSessao {
  final String id;
  final String nome;
  final String email;
  final String perfil; // 'super_admin', 'admin_escola', 'professor'
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
      // 2. BUSCA NO FIREBASE: VERIFICA SE É UMA ESCOLA CLIENTE
      // ==========================================================
      final snapshotEscola = await FirebaseFirestore.instance
          .collection('tenants')
          .where('email', isEqualTo: email)
          .get();

      if (snapshotEscola.docs.isNotEmpty) {
        // O e-mail foi encontrado no banco de dados do SaaS!
        final dadosEscola = snapshotEscola.docs.first.data();
        
        // Bloqueio de Inadimplência
        if (dadosEscola['status'] == 'Bloqueado') {
          throw Exception('O acesso desta escola está bloqueado. Contate o suporte da Domex.');
        }

        // Verifica a senha (Nesta fase, usamos a senha padrão)
        if (senha == 'Domex@123') {
          
          // Transforma a cor salva no banco (Hexadecimal) em Color do Flutter
          Color corDaEscola = const Color(0xFF2C3E50); // Cor padrão se der erro
          if (dadosEscola['corHex'] != null) {
            corDaEscola = Color(int.parse(dadosEscola['corHex'], radix: 16));
          }

          return UsuarioSessao(
            id: dadosEscola['id'],
            nome: 'Administração',
            email: email,
            perfil: 'admin_escola',
            nomeEscola: dadosEscola['nome'],
            corPrimaria: corDaEscola, // A mágica visual acontece aqui!
          );
        } else {
          throw Exception('E-mail ou senha incorretos.');
        }
      }

      // ==========================================================
      // 3. LOGIN SIMULADO DO PROFESSOR (Até criarmos a tabela deles)
      // ==========================================================
      if (email == 'professor@escola.com' && senha == '123456') {
        return UsuarioSessao(
          id: 'PROF-01',
          nome: 'Marta Vieira',
          email: email,
          perfil: 'professor',
          nomeEscola: 'Escola Demonstração',
          corPrimaria: Colors.blue.shade800,
        );
      } 
      
      throw Exception('E-mail não encontrado no sistema.');
    });
  }

  void fazerLogout() {
    state = const AsyncData(null);
  }
}

// 3. Provedor Global
final authProvider = AsyncNotifierProvider<AuthController, UsuarioSessao?>(() {
  return AuthController();
});