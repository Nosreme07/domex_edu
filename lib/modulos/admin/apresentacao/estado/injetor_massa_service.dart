import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InjetorMassaService {
  final String tenantId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _rnd = Random();

  InjetorMassaService(this.tenantId);

  final List<String> _nomes = ['Ana', 'Bruno', 'Carlos', 'Daniela', 'Eduardo', 'Fernanda', 'Gabriel', 'Helena', 'Igor', 'Julia', 'Lucas', 'Mariana', 'Nicolas', 'Olivia', 'Pedro', 'Rafaela', 'Samuel', 'Tatiana', 'Vinicius', 'Yasmin'];
  final List<String> _sobrenomes = ['Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves', 'Pereira', 'Lima', 'Gomes', 'Costa', 'Ribeiro', 'Martins', 'Carvalho', 'Almeida'];
  final List<String> _disciplinas = ['Matemática', 'Português', 'História', 'Geografia', 'Física', 'Biologia', 'Inglês', 'Artes', 'Educação Física'];

  String _gerarNome() => '${_nomes[_rnd.nextInt(_nomes.length)]} ${_sobrenomes[_rnd.nextInt(_sobrenomes.length)]} ${_sobrenomes[_rnd.nextInt(_sobrenomes.length)]}'.toUpperCase();
  
  String _gerarCpf() => '${_rnd.nextInt(900)+100}.${_rnd.nextInt(900)+100}.${_rnd.nextInt(900)+100}-${_rnd.nextInt(90)+10}';
  
  String _gerarTelefone() => '(81) 9${_rnd.nextInt(8000)+1000}-${_rnd.nextInt(8000)+1000}';

  Future<void> saturarBanco(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Injetando 310 registros no Firebase...'),
            Text('Isso pode levar alguns segundos.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    try {
      // ==========================================
      // 1. CRIAR 10 TURMAS
      // ==========================================
      WriteBatch batchTurmas = _db.batch();
      List<Map<String, dynamic>> turmasCriadas = [];
      
      for (int i = 1; i <= 10; i++) {
        String idTurma = 'TURMA-2026-${i.toString().padLeft(2, '0')}';
        String nomeTurma = '${i}º ANO ${['A', 'B', 'C'][_rnd.nextInt(3)]}';
        
        var dadosTurma = {
          'id': idTurma,
          'nome': nomeTurma,
          'anoLetivo': '2026',
          'turno': ['MANHÃ', 'TARDE', 'INTEGRAL'][_rnd.nextInt(3)],
          'sala': 'SALA ${_rnd.nextInt(20) + 1}',
          'status': 'FORMADA',
          'dataCriacao': DateTime.now().toIso8601String(),
        };
        
        batchTurmas.set(_db.collection('tenants').doc(tenantId).collection('turmas').doc(idTurma), dadosTurma);
        turmasCriadas.add(dadosTurma);
      }
      await batchTurmas.commit();

      // ==========================================
      // 2. CRIAR 100 PROFESSORES
      // ==========================================
      WriteBatch batchProfs = _db.batch();
      WriteBatch batchUsuariosProfs = _db.batch();
      
      for (int i = 1; i <= 100; i++) {
        String idProf = 'PROF-${i.toString().padLeft(4, '0')}';
        String nomeProf = _gerarNome();
        
        var dadosProf = {
          'id': idProf,
          'nome': nomeProf,
          'cpf': _gerarCpf(),
          'telefone': _gerarTelefone(),
          'email': 'prof${i.toString().padLeft(4, '0')}@escola.com',
          'status': 'Ativo',
          'disciplinas': [_disciplinas[_rnd.nextInt(_disciplinas.length)], _disciplinas[_rnd.nextInt(_disciplinas.length)]].toSet().toList(),
          'dataCadastro': DateTime.now().toIso8601String(),
        };

        batchProfs.set(_db.collection('tenants').doc(tenantId).collection('professores').doc(idProf), dadosProf);
        
        // Sincroniza com a tabela de usuários
        batchUsuariosProfs.set(_db.collection('usuarios').doc(idProf), {
          'idLogin': idProf, 'nome': nomeProf, 'email': dadosProf['email'], 'perfil': 'professor', 'status': 'Ativo', 'escolaId': tenantId
        });
      }
      await batchProfs.commit();
      await batchUsuariosProfs.commit();

      // ==========================================
      // 3. CRIAR 200 ALUNOS
      // ==========================================
      WriteBatch batchAlunos1 = _db.batch(); // Firebase aceita max 500 operações por batch
      WriteBatch batchUsuariosAlunos = _db.batch();
      
      for (int i = 1; i <= 200; i++) {
        String matricula = '2026${i.toString().padLeft(4, '0')}';
        String nomeAluno = _gerarNome();
        var turmaSorteada = turmasCriadas[_rnd.nextInt(turmasCriadas.length)];
        
        var dadosAluno = {
          'matricula': matricula,
          'nome': nomeAluno,
          'cpf': _gerarCpf(),
          'telefone': _gerarTelefone(),
          'sexo': ['MASCULINO', 'FEMININO'][_rnd.nextInt(2)],
          'dataNascimento': '${_rnd.nextInt(28)+1}'.padLeft(2, '0') + '/05/2010',
          'turma': '${turmaSorteada['nome']} (${turmaSorteada['anoLetivo']}) - ${turmaSorteada['turno']}',
          'turmaId': turmaSorteada['id'],
          'status': ['Ativo', 'Ativo', 'Ativo', 'Inadimplente'][_rnd.nextInt(4)], // A maioria ativa, alguns inadimplentes
          'temIrmao': false,
          'responsaveis': [
            {'nome': _gerarNome(), 'cpf': _gerarCpf(), 'telefone': _gerarTelefone(), 'email': 'pai$i@email.com', 'principal': true}
          ],
          'endereco': {'rua': 'Rua Teste', 'numero': '$i', 'bairro': 'Centro', 'cidade': 'Recife', 'estado': 'PE'},
          'dataCadastro': DateTime.now().toIso8601String(),
        };

        batchAlunos1.set(_db.collection('tenants').doc(tenantId).collection('alunos').doc(matricula), dadosAluno);
        
        batchUsuariosAlunos.set(_db.collection('usuarios').doc(matricula), {
          'idLogin': matricula, 'nome': nomeAluno, 'telefone': dadosAluno['telefone'], 'perfil': 'aluno', 'status': 'Ativo', 'escolaId': tenantId
        });
      }
      await batchAlunos1.commit();
      await batchUsuariosAlunos.commit();

      if (context.mounted) {
        Navigator.pop(context); // Fecha o loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sistema Saturado: 10 Turmas, 100 Profs e 200 Alunos criados!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao injetar dados: $e'), backgroundColor: Colors.red));
      }
    }
  }
}