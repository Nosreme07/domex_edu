import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../estado/auth_provider.dart';

class LoginTela extends ConsumerStatefulWidget {
  const LoginTela({super.key});

  @override
  ConsumerState<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends ConsumerState<LoginTela> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _executarLogin() {
    if (_formKey.currentState!.validate()) {
      ref.read(authProvider.notifier).fazerLogin(
            _emailController.text.trim(),
            _senhaController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuta mudanças no estado de autenticação para navegar ou mostrar erro
    ref.listen(authProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          final msgErro = error.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msgErro), backgroundColor: Colors.red),
          );
        },
        data: (usuario) {
          if (usuario != null) {
            // ROTEAMENTO INTELIGENTE BASEADO NO PERFIL
            if (usuario.perfil == 'super_admin') {
              context.go('/super-admin');
            } else if (usuario.perfil == 'admin_escola') {
              context.go('/admin');
            } else if (usuario.perfil == 'professor') {
              context.go('/dashboard');
            }
          }
        },
      );
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // Cores padronizadas do Domex Edu Global
    const corDominante = Color(0xFF2C3E50); 
    final corFundo = Colors.grey.shade100;

    return Scaffold(
      backgroundColor: corFundo,
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
                      // Logotipo Domex Global
                      const Icon(Icons.school_rounded, size: 64, color: corDominante),
                      const SizedBox(height: 24),
                      const Text(
                        'Acesso ao Sistema',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: corDominante),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Insira suas credenciais para entrar no seu ambiente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 32),
                      
                      // Campo de E-mail
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: const Icon(Icons.email_outlined, color: corDominante),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: corDominante, width: 2),
                          ),
                        ),
                        validator: (v) => v!.isEmpty || !v.contains('@') ? 'Insira um e-mail válido' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Campo de Senha
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: corDominante, width: 2),
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'Insira sua senha' : null,
                        onFieldSubmitted: (_) => _executarLogin(), // Permite logar dando Enter
                      ),
                      
                      // Esqueci a Senha
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recuperação de senha em breve.')));
                          },
                          child: const Text('Esqueceu a senha?', style: TextStyle(color: corDominante)),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Botão Entrar
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: corDominante,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
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