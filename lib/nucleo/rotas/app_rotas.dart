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

// ---> TÉCNICA ANTI-BUG: ALIAS DE IMPORTAÇÃO PARA IGNORAR O CACHE <---
import '../../modulos/admin/apresentacao/telas/admin_cadastros_tela.dart'
    as central_cadastros;

import '../../modulos/admin/apresentacao/telas/admin_aluno_form_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_responsavel_form_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_professor_form_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_secretaria_form_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_turma_form_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_configuracoes_tela.dart';
import '../../modulos/admin/apresentacao/telas/admin_turma_painel_tela.dart';
// ---> NOVO IMPORT DO CALENDÁRIO <---
import '../../modulos/admin/apresentacao/telas/admin_calendario_tela.dart';

// ============================================================================
// IMPORTS: PAINEL MASTER (SUPER ADMIN / DONO DO SAAS)
// ============================================================================
import '../layout/super_admin_layout.dart';
import '../../modulos/super_admin/apresentacao/telas/super_admin_dashboard_tela.dart';
import '../../modulos/super_admin/apresentacao/telas/super_admin_usuarios_tela.dart';

// ============================================================================
// IMPORTS: PAINEL DO PROFESSOR
// ============================================================================
import '../../modulos/academico/layout/professor_layout.dart';
import '../../modulos/academico/apresentacao/telas/professor_dashboard_tela.dart';

class AppRotas {
  // Construtor privado para evitar a instanciação acidental desta classe
  AppRotas._();

  /// Função utilitária para descobrir se o cliente está acessando via subdomínio
  static String? extrairSubdominio() {
    if (kIsWeb) {
      // 1. Tenta pegar via parâmetro na URL (Ideal para testes no Localhost)
      // Exemplo: localhost:5000/?escola=primeiravisao
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('escola')) {
        return uri.queryParameters['escola'];
      }

      // 2. Tenta pegar via subdomínio real (Para quando estiver em Produção)
      final host = uri.host;
      if (host != 'localhost' && host != '127.0.0.1') {
        List<String> partes = host.split('.');
        if (partes.length >= 3 && partes[0] != 'www') {
          return partes[0];
        }
      }
    }
    return null;
  }

  // ============================================================================
  // CONFIGURAÇÃO CENTRAL DO ROTEADOR (GoRouter)
  // ============================================================================
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,

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
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardTela(),
      ),
      GoRoute(path: '/mural', builder: (context, state) => const MuralTela()),

      GoRoute(
        path: '/diario/:idTurma',
        builder: (context, state) =>
            DiarioTela(turmaId: state.pathParameters['idTurma']!),
      ),

      // ==========================================================
      // GRUPO 2: ESTRUTURA ADMINISTRATIVA DA ESCOLA (Tenant)
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
            path: '/admin/configuracoes',
            builder: (context, state) => const AdminConfiguracoesTela(),
          ),

          // --- NOVO: MÓDULO DE CALENDÁRIO ---
          GoRoute(
            path: '/admin/calendario',
            builder: (context, state) => const AdminCalendarioTela(),
          ),

          // --- Central de Cadastros (Com Abas) ---
          GoRoute(
            path: '/admin/cadastros',
            builder: (context, state) {
              final aba = state.extra as int? ?? 0;
              // USO DO ALIAS AQUI PARA BURLAR O CACHE
              return central_cadastros.AdminCadastrosTela(
                key: ValueKey(aba),
                abaInicial: aba,
              );
            },
          ),

          GoRoute(
            path: '/admin/cadastros/aluno/novo',
            builder: (context, state) {
              final alunoParaEditar = state.extra as Map<String, dynamic>?;
              return AdminAlunoFormTela(alunoParaEditar: alunoParaEditar);
            },
          ),

          GoRoute(
            path: '/admin/cadastros/responsavel/novo',
            builder: (context, state) {
              final responsavelParaEditar =
                  state.extra as Map<String, dynamic>?;
              return AdminResponsavelFormTela(
                responsavelParaEditar: responsavelParaEditar,
              );
            },
          ),

          GoRoute(
            path: '/admin/cadastros/professor/novo',
            builder: (context, state) {
              final professorParaEditar = state.extra as Map<String, dynamic>?;
              return AdminProfessorFormTela(
                professorParaEditar: professorParaEditar,
              );
            },
          ),

          GoRoute(
            path: '/admin/cadastros/secretaria/novo',
            builder: (context, state) {
              final membroParaEditar = state.extra as Map<String, dynamic>?;
              return AdminSecretariaFormTela(
                membroParaEditar: membroParaEditar,
              );
            },
          ),

          GoRoute(
            path: '/admin/cadastros/turma/novo',
            builder: (context, state) {
              final turmaParaEditar = state.extra as Map<String, dynamic>?;
              return AdminTurmaFormTela(turmaParaEditar: turmaParaEditar);
            },
          ),

          GoRoute(
            path: '/admin/cadastros/turma/painel',
            builder: (context, state) {
              final turmaExtra = state.extra as Map<String, dynamic>?;
              if (turmaExtra == null) {
                return const Scaffold(
                  body: Center(child: Text('Turma não encontrada.')),
                );
              }
              return AdminTurmaPainelTela(turma: turmaExtra);
            },
          ),
        ],
      ),

      // ==========================================================
      // GRUPO 3: ESTRUTURA MASTER / SUPER ADMIN (Dono do SaaS)
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

      // ==========================================================
      // GRUPO 4: ESTRUTURA DO PROFESSOR (Diário de Classe)
      // ==========================================================
      ShellRoute(
        builder: (context, state, child) {
          return ProfessorLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/professor',
            builder: (context, state) => const ProfessorDashboardTela(),
          ),
        ],
      ),
    ],
  );
}
