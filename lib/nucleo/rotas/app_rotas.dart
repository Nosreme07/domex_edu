import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ============================================================================
// IMPORTS DAS TELAS GERAIS E APLICATIVO MOBILE
// ============================================================================
import '../../app.dart'; 
import '../../modulos/autenticacao/apresentacao/telas/login_tela.dart';
import '../../modulos/academico/apresentacao/telas/diario_tela.dart';
import '../../modulos/comunicacao/apresentacao/telas/mural_tela.dart';
import '../layout/dashboard_tela.dart';

// ============================================================================
// IMPORTS DO BACKOFFICE ADMINISTRATIVO (DIREÇÃO DA ESCOLA)
// ============================================================================
import '../layout/admin_layout.dart';
import '../../modulos/admin/apresentacao/telas/admin_visao_geral_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_cadastros_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_aluno_form_tela.dart'; 
import '../../modulos/admin/apresentacao/telas/admin_professor_form_tela.dart'; 

// ============================================================================
// IMPORTS DO PAINEL MASTER (SUPER ADMIN / DONO DO SAAS)
// ============================================================================
import '../layout/super_admin_layout.dart';
import '../../modulos/super_admin/apresentacao/telas/super_admin_dashboard_tela.dart';
import '../../modulos/super_admin/apresentacao/telas/super_admin_usuarios_tela.dart';

class AppRotas {
  AppRotas._();

  // Função que descobre se o cliente está acessando via subdomínio (ex: escola.domex.com)
  static String? extrairSubdominio() {
    if (kIsWeb) {
      final host = Uri.base.host;
      List<String> partes = host.split('.');
      if (partes.length >= 3 && partes[0] != 'www') {
        return partes[0];
      }
    }
    return null;
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode, 
    
    // Redirecionamento automático caso seja um subdomínio
    redirect: (BuildContext context, GoRouterState state) {
      final subdominio = extrairSubdominio();
      if (state.matchedLocation == '/' && subdominio != null) {
        return '/login'; 
      }
      return null; 
    },

    routes: [
      // ==========================================================
      // ROTAS SOLTAS (Telas que não possuem Menu Lateral)
      // ==========================================================
      GoRoute(path: '/', builder: (context, state) => const TelaInicialDomex()),
      GoRoute(path: '/login', builder: (context, state) => const LoginTela()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardTela()),
      GoRoute(
        path: '/diario/:idTurma',
        builder: (context, state) => DiarioTela(idTurma: state.pathParameters['idTurma']!),
      ),
      GoRoute(path: '/mural', builder: (context, state) => const MuralTela()),
      
      // ==========================================================
      // 1. ESTRUTURA ADMINISTRATIVA DA ESCOLA (MENU LATERAL COLORIDO)
      // ==========================================================
      ShellRoute(
        builder: (context, state, child) {
          return AdminLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminVisaoGeralTela(),
          ),
          GoRoute(
            path: '/admin/cadastros',
            builder: (context, state) => const AdminCadastrosTela(),
          ),
          
          // ▼ ROTA DO ALUNO ▼
          GoRoute(
            path: '/admin/cadastros/aluno/novo',
            builder: (context, state) {
              final alunoParaEditar = state.extra as Map<String, dynamic>?;
              return AdminAlunoFormTela(alunoParaEditar: alunoParaEditar);
            },
          ),
          
          // ▼ ROTA DO PROFESSOR (PREPARADA PARA EDIÇÃO) ▼
          GoRoute(
            path: '/admin/cadastros/professor/novo',
            builder: (context, state) {
              final professorParaEditar = state.extra as Map<String, dynamic>?;
              return AdminProfessorFormTela(professorParaEditar: professorParaEditar);
            },
          ),
        ],
      ),

      // ==========================================================
      // 2. ESTRUTURA MASTER / SUPER ADMIN (MENU ESCURO PADRÃO)
      // ==========================================================
      ShellRoute(
        builder: (context, state, child) {
          return SuperAdminLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/super-admin',
            builder: (context, state) => const SuperAdminDashboardTela(),
          ),
          GoRoute(
            path: '/super-admin/usuarios',
            builder: (context, state) => const SuperAdminUsuariosTela(),
          ),
        ],
      ),
      
    ],
  );
}