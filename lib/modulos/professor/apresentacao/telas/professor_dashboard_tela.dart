import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Importamos o provedor de Autenticação para saber quem está logado
import '../../../autenticacao/apresentacao/estado/auth_provider.dart';

// Importamos os provedores do Admin corrigindo os três níveis de pastas (../../../)
import '../../../admin/apresentacao/estado/professor_provider.dart';
import '../../../admin/apresentacao/estado/turma_provider.dart';

class ProfessorDashboardTela extends ConsumerStatefulWidget {
  const ProfessorDashboardTela({super.key});

  @override
  ConsumerState<ProfessorDashboardTela> createState() => _ProfessorDashboardTelaState();
}

class _ProfessorDashboardTelaState extends ConsumerState<ProfessorDashboardTela> {
  // Filtro de ano letivo (por padrão, o ano atual)
  String _anoSelecionado = DateTime.now().year.toString();

  @override
  Widget build(BuildContext context) {
    final corPrimaria = Theme.of(context).primaryColor;
    final usuarioLogado = ref.watch(authProvider).value;

    // Se o usuário ainda está carregando, mostra o loading
    if (usuarioLogado == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: corPrimaria)));
    }

    // Pega o e-mail do usuário logado (removido o ?. desnecessário)
    final emailUsuario = usuarioLogado.email.trim().toLowerCase();

    // Escutando as listas do banco de dados em tempo real
    final estadoProfessores = ref.watch(professoresStreamProvider);
    final estadoTurmas = ref.watch(turmasStreamProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: const Text('Portal do Professor', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Botão de Sair no topo direito
          IconButton(
            tooltip: 'Sair do Sistema',
            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
            onPressed: () {
              ref.read(authProvider.notifier).fazerLogout();
              context.go('/login');
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: estadoProfessores.when(
        loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
        error: (e, s) => Center(child: Text('Erro ao carregar dados: $e')),
        data: (professores) {
          // ==================================================================
          // 1. IDENTIFICAÇÃO DO PROFESSOR
          // Busca na lista de professores quem tem o e-mail igual ao do usuário logado
          // ==================================================================
          final profMap = professores.where((p) {
            final emailProf = (p['email'] ?? '').toString().trim().toLowerCase();
            return emailProf == emailUsuario;
          }).toList();

          // Se não encontrou nenhum professor com esse e-mail
          if (profMap.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Professor não encontrado.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('O e-mail ($emailUsuario) não está vinculado a nenhum professor.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final professorLogado = profMap.first;
          final isAtivo = professorLogado['status'] == 'Ativo';

          // Se o professor foi bloqueado ou inativado pela secretaria
          if (!isAtivo) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block_rounded, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Acesso Bloqueado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 8),
                  Text('Seu cadastro consta como inativo. Procure a secretaria.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final profId = professorLogado['id'];
          final profNome = professorLogado['nome'] ?? 'Professor';
          final profFoto = professorLogado['fotoUrl'];

          // ==================================================================
          // 2. BUSCA DAS TURMAS DO PROFESSOR
          // ==================================================================
          return estadoTurmas.when(
            loading: () => Center(child: CircularProgressIndicator(color: corPrimaria)),
            error: (e, s) => Center(child: Text('Erro ao carregar turmas: $e')),
            data: (turmas) {
              // Descobre todos os anos letivos disponíveis nessas turmas para o filtro
              final Set<String> anosSet = {DateTime.now().year.toString()};
              
              // Filtra apenas as turmas onde este professor está na lista de vinculados
              final minhasTurmasBrutas = turmas.where((t) {
                if (t['status'] == 'Inativa') return false; // Ignora turmas arquivadas
                
                final vinculados = t['professoresVinculados'] as List? ?? [];
                return vinculados.any((v) => v['professorId'] == profId);
              }).toList();

              for (var t in minhasTurmasBrutas) {
                if (t['anoLetivo'] != null && t['anoLetivo'].toString().isNotEmpty) {
                  anosSet.add(t['anoLetivo'].toString());
                }
              }

              final listaAnos = anosSet.toList()..sort((a, b) => b.compareTo(a));
              if (!listaAnos.contains(_anoSelecionado)) _anoSelecionado = listaAnos.first;

              // Filtra as turmas finais pelo Ano Letivo selecionado no Dropdown
              final minhasTurmas = minhasTurmasBrutas.where((t) => t['anoLetivo'] == _anoSelecionado).toList();

              // Ordena as turmas por nome (A-Z)
              minhasTurmas.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ========================================================
                    // CABEÇALHO (Boas-vindas e Filtro de Ano)
                    // ========================================================
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: corPrimaria.withAlpha(30),
                          backgroundImage: profFoto != null ? NetworkImage(profFoto) : null,
                          child: profFoto == null ? Icon(Icons.person, color: corPrimaria, size: 30) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Olá, $profNome 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text('Bem-vindo(a) ao seu painel acadêmico.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        
                        // Seletor de Ano Letivo
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white, 
                            borderRadius: BorderRadius.circular(12), 
                            border: Border.all(color: corPrimaria.withAlpha(80), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 20, color: corPrimaria),
                              const SizedBox(width: 8),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _anoSelecionado,
                                  icon: Padding(padding: const EdgeInsets.only(left: 8.0), child: Icon(Icons.keyboard_arrow_down_rounded, color: corPrimaria)),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: corPrimaria, fontSize: 16),
                                  onChanged: (novoAno) {
                                    if (novoAno != null) setState(() => _anoSelecionado = novoAno);
                                  },
                                  items: listaAnos.map((ano) => DropdownMenuItem(value: ano, child: Text('Ano: $ano'))).toList(),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Icon(Icons.meeting_room_rounded, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Text('Minhas Turmas em $_anoSelecionado (${minhasTurmas.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ========================================================
                    // GRID DE TURMAS DO PROFESSOR
                    // ========================================================
                    Expanded(
                      child: minhasTurmas.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_off_rounded, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text('Você não está vinculado a nenhuma turma em $_anoSelecionado.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              // Deixa responsivo: 1 coluna no celular, 2 no tablet, 3 ou 4 no PC
                              int colunas = 1;
                              if (constraints.maxWidth > 1200) {
                                colunas = 4;
                              } else if (constraints.maxWidth > 800) {
                                colunas = 3;
                              } else if (constraints.maxWidth > 600) {
                                colunas = 2;
                              }

                              return GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: colunas,
                                  crossAxisSpacing: 24,
                                  mainAxisSpacing: 24,
                                  childAspectRatio: 1.1, // Controla a altura do Card
                                ),
                                itemCount: minhasTurmas.length,
                                itemBuilder: (context, index) {
                                  final turma = minhasTurmas[index];
                                  
                                  // Descobre quais disciplinas ESSE professor dá NESSA turma
                                  final profsVinculados = turma['professoresVinculados'] as List? ?? [];
                                  final minhasDisciplinasNaTurma = profsVinculados
                                      .where((v) => v['professorId'] == profId)
                                      .map((v) => v['disciplina'].toString())
                                      .toList();

                                  return Card(
                                    elevation: 2,
                                    shadowColor: corPrimaria.withAlpha(40),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Título da Turma e Ícone
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(color: corPrimaria.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                                                child: Icon(Icons.meeting_room_rounded, color: corPrimaria, size: 28),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(turma['nome'] ?? 'Turma', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                    const SizedBox(height: 4),
                                                    Text('Turno: ${turma['turno'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          
                                          // Minhas Disciplinas (Tags azuis)
                                          const Text('Minhas Disciplinas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6, runSpacing: 6,
                                            children: minhasDisciplinasNaTurma.map((d) => 
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)),
                                                child: Text(d, style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                              )
                                            ).toList(),
                                          ),
                                          
                                          const Spacer(),
                                          const Divider(),
                                          
                                          // Botão Acessar Diário
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: corPrimaria,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                padding: const EdgeInsets.symmetric(vertical: 12)
                                              ),
                                              onPressed: () {
                                                // Rota que leva o professor para o Diário de Classe dessa turma
                                                context.push('/diario/${turma['id']}');
                                              },
                                              icon: const Icon(Icons.edit_document, size: 18),
                                              label: const Text('Abrir Diário de Classe', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                    ),
                  ],
                ),
              );
            }
          );
        }
      ),
    );
  }
}