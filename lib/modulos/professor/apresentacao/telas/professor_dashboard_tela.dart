import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfessorDashboardTela extends ConsumerWidget {
  const ProfessorDashboardTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Painel de Aulas', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Olá, Professor(a)!', 
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal)
            ),
            const SizedBox(height: 8),
            Text(
              'Bem-vindo(a) ao seu diário de classe digital.', 
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700)
            ),
            const SizedBox(height: 32),
            
            // Área reservada para mostrar as turmas dele no futuro
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note_rounded, size: 80, color: Colors.teal.shade200),
                    const SizedBox(height: 16),
                    Text('Você não tem aulas agendadas para hoje.', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}