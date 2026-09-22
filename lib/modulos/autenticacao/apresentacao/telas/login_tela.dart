import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../estado/auth_provider.dart';

class LoginTela extends ConsumerStatefulWidget {
  const LoginTela({super.key});

  @override
  ConsumerState<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends ConsumerState<LoginTela> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codigoEscolaController = TextEditingController(); // NOVO: Campo de Código da Escola
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codigoEscolaController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _executarLogin() {
    if (_formKey.currentState!.validate()) {
      String login = _emailController.text.trim().toLowerCase();
      String codigoEscola = _codigoEscolaController.text.trim().toLowerCase();
      
      // MÁGICA: Evita conflito entre escolas!
      if (!login.contains('@')) {
        if (codigoEscola.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Para acessar com Matrícula ou ID, informe o Código da Instituição.'), backgroundColor: Colors.red),
          );
          return;
        }
        login = '$login@$codigoEscola.com';
      }

      ref.read(authProvider.notifier).fazerLogin(login, _senhaController.text);
    }
  }

  void _abrirModalRecuperacaoSenha(Color corDominante) {
    final emailRecuperacaoController = TextEditingController(text: _emailController.text.trim().toLowerCase());
    if (!emailRecuperacaoController.text.contains('@')) emailRecuperacaoController.clear();
    
    final formKeyModal = GlobalKey<FormState>();
    bool enviando = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: corDominante),
                  const SizedBox(width: 8),
                  const Text('Recuperar Senha', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKeyModal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Digite o e-mail cadastrado na sua conta.\n(Atenção: Não é possível recuperar senha utilizando apenas matrícula ou ID)',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: emailRecuperacaoController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'E-mail cadastrado',
                          prefixIcon: Icon(Icons.email_outlined, color: corDominante),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty || !v.contains('@') ? 'Insira um e-mail válido' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actions: [
                TextButton(onPressed: enviando ? null : () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: corDominante, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  onPressed: enviando ? null : () async {
                    if (formKeyModal.currentState!.validate()) {
                      setStateModal(() => enviando = true);
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: emailRecuperacaoController.text.trim().toLowerCase());
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-mail enviado!'), backgroundColor: Colors.green));
                      } catch (e) {
                        setStateModal(() => enviando = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRO: E-mail não encontrado.'), backgroundColor: Colors.red));
                        }
                      }
                    }
                  },
                  child: enviando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enviar Link'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          final msgErro = error.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $msgErro', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
          );
        },
        data: (usuario) {
          if (usuario != null) {
            if (usuario.perfil == 'super_admin') context.go('/super-admin');
            else if (usuario.perfil == 'admin_escola') context.go('/admin');
            else if (usuario.perfil == 'professor') context.go('/professor');
            else if (usuario.perfil == 'aluno') context.go('/aluno'); 
          }
        },
      );
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    const corDominante = Color(0xFF2C3E50); 

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.school_rounded, size: 64, color: corDominante),
                      const SizedBox(height: 24),
                      const Text('Acesso ao Sistema', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: corDominante)),
                      const SizedBox(height: 8),
                      const Text('Insira seu e-mail, matrícula ou ID para acessar o seu painel.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 32),
                      
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'E-mail, Matrícula ou ID',
                          prefixIcon: const Icon(Icons.person_outline, color: corDominante),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Insira seu login' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // NOVO CAMPO: CÓDIGO DA ESCOLA
                      TextFormField(
                        controller: _codigoEscolaController,
                        decoration: InputDecoration(
                          labelText: 'Código da Instituição',
                          hintText: 'Apenas se usar Matrícula/ID',
                          prefixIcon: const Icon(Icons.domain_rounded, color: corDominante),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline, color: corDominante),
                          suffixIcon: IconButton(
                            icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Insira sua senha' : null,
                        onFieldSubmitted: (_) => _executarLogin(), 
                      ),
                      
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _abrirModalRecuperacaoSenha(corDominante),
                          child: const Text('Esqueceu a senha?', style: TextStyle(color: corDominante)),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: corDominante, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: isLoading ? null : _executarLogin,
                          child: isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Entrar no Sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}