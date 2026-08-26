import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ============================================================================
// IMPORTS: TELAS GERAIS E APLICATIVO MOBILE
// ============================================================================
import '../../app.dart'; 
import '../../modulos/autenticacao/apresentacao/telas/login_tela.dart';
import '../../modulos/academico/apresentacao/telas/diario_tela.dart';
import '../../modulos/comunicacao/apresentacao/telas/mural_tela.dart';
import '../layout/dashboard_tela.dart';

// ============================================================================
// IMPORTS: BACKOFFICE ADMINISTRATIVO (PAINEL DA ESCOLA / INQUILINO)
// ============================================================================
import '../layout/admin_layout.dart';
import '../../modulos/admin/apresentacao/telas/admin_visao_geral_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_cadastros_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_aluno_form_tela.dart'; 
import '../../modulos/admin/apresentacao/telas/admin_professor_form_tela.dart'; 
import '../../modulos/admin/apresentacao/telas/admin_turma_form_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_configuracoes_tela.dart';

// ============================================================================
// IMPORTS: PAINEL MASTER (SUPER ADMIN / DONO DO SAAS)
// ============================================================================
import '../layout/super_admin_layout.dart';
import '../../modulos/super_admin/apresentacao/telas/super_admin_dashboard_tela.dart';
import '../../modulos/super_admin/apresentacao/telas/super_admin_usuarios_tela.dart';

class AppRotas {
  // Construtor privado para evitar a instanciação acidental desta classe
  AppRotas._();

  /// Função utilitária para descobrir se o cliente está acessando via subdomínio
  /// Exemplo: Ao acessar "escola1.domex.com", ele extrai o "escola1"
  /// Isso é vital para a arquitetura SaaS (Multi-tenant) no Flutter Web
  static String? extrairSubdominio() {
    if (kIsWeb) {
      final host = Uri.base.host;
      List<String> partes = host.split('.');
      // Verifica se possui subdomínio e ignora o padrão 'www'
      if (partes.length >= 3 && partes[0] != 'www') {
        return partes[0];
      }
    }
    return null;
  }

  // ============================================================================
  // CONFIGURAÇÃO CENTRAL DO ROTEADOR (GoRouter)
  // ============================================================================
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode, // Mostra logs de navegação apenas no modo debug
    
    // REDIRECIONAMENTO INTELIGENTE (Middlewares)
    // Se o usuário acessar um subdomínio diretamente na raiz ('/'), 
    // ele é forçado a ir para a tela de login daquela escola.
    redirect: (BuildContext context, GoRouterState state) {
      final subdominio = extrairSubdominio();
      if (state.matchedLocation == '/' && subdominio != null) {
        return '/login'; 
      }
      return null; 
    },

    routes: [
      // ==========================================================
      // GRUPO 1: ROTAS SOLTAS (Telas sem Menu Lateral Fixo)
      // ==========================================================
      GoRoute(path: '/', builder: (context, state) => const TelaInicialDomex()),
      GoRoute(path: '/login', builder: (context, state) => const LoginTela()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardTela()),
      GoRoute(path: '/mural', builder: (context, state) => const MuralTela()),
      
      // Rota com passagem de parâmetro via URL (ex: /diario/TURMA-01)
      GoRoute(
        path: '/diario/:idTurma',
        builder: (context, state) => DiarioTela(idTurma: state.pathParameters['idTurma']!),
      ),
      
      // ==========================================================
      // GRUPO 2: ESTRUTURA ADMINISTRATIVA DA ESCOLA (Tenant)
      // Utiliza ShellRoute para manter o AdminLayout (Menu Lateral) sempre visível
      // ==========================================================
      ShellRoute(
        builder: (context, state, child) {
          return AdminLayout(child: child);
        },
        routes: [
          // --- Dashboards e Paineis Principais ---
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminVisaoGeralTela(),
          ),
          
          GoRoute(
            path: '/admin/configuracoes',
            builder: (context, state) => const AdminConfiguracoesTela(),
          ),

          // --- Central de Cadastros (Com Abas) ---
          GoRoute(
            path: '/admin/cadastros',
            builder: (context, state) {
              // Lê o parâmetro "extra" para saber qual aba abrir (0=Alunos, 1=Profs, 2=Turmas)
              final aba = state.extra as int? ?? 0; 
              // O ValueKey força a reconstrução do widget se a aba mudar
              return AdminCadastrosTela(key: ValueKey(aba), abaInicial: aba);
            },
          ),
          
          // --- Formulários de Cadastro / Edição ---
          // Recebem os dados via `state.extra` caso seja uma edição
          GoRoute(
            path: '/admin/cadastros/aluno/novo',
            builder: (context, state) {
              final alunoParaEditar = state.extra as Map<String, dynamic>?;
              return AdminAlunoFormTela(alunoParaEditar: alunoParaEditar);
            },
          ),
          
          GoRoute(
            path: '/admin/cadastros/professor/novo',
            builder: (context, state) {
              final professorParaEditar = state.extra as Map<String, dynamic>?;
              return AdminProfessorFormTela(professorParaEditar: professorParaEditar);
            },
          ),

          GoRoute(
            path: '/admin/cadastros/turma/novo',
            builder: (context, state) {
              final turmaParaEditar = state.extra as Map<String, dynamic>?;
              return AdminTurmaFormTela(turmaParaEditar: turmaParaEditar);
            },
          ),
        ],
      ),

      // ==========================================================
      // GRUPO 3: ESTRUTURA MASTER / SUPER ADMIN (Dono do SaaS)
      // Utiliza ShellRoute para o Menu Lateral Escuro padrão do sistema
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