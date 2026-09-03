import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:firebase_core/firebase_core.dart'; // Necessário para o App Secundário
import 'package:firebase_auth/firebase_auth.dart'; // Necessário para criar o Login
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; 

class EscolaService {
  final _db = FirebaseFirestore.instance.collection('tenants');
  final _storage = FirebaseStorage.instance; 
  final _firestoreGlobal = FirebaseFirestore.instance; // Usado para operações globais (Batch)

  Future<void> salvarEscola(Map<String, dynamic> escolaDados) async {
    if (escolaDados.containsKey('arquivoLogo') && escolaDados['arquivoLogo'] != null) {
      final XFile arquivo = escolaDados['arquivoLogo'];
      
      final caminhoStorage = _storage.ref().child('logos/${escolaDados['id']}_logo.png');
      
      try {
        final bytes = await arquivo.readAsBytes();
        await caminhoStorage.putData(bytes, SettableMetadata(contentType: 'image/png'));
        final linkFoto = await caminhoStorage.getDownloadURL();
        escolaDados['logoUrl'] = linkFoto;
      } catch (e) {
        throw Exception('Falha ao enviar a foto da logo: $e'); 
      }
    }

    escolaDados.remove('arquivoLogo');
    await _db.doc(escolaDados['id']).set(escolaDados);
  }

  Future<void> atualizarStatus(String id, String novoStatus) async {
    await _db.doc(id).update({'status': novoStatus});
  }

  Future<void> excluirEscola(String id) async {
    await _db.doc(id).delete();
  }

  // =========================================================================
  // NOVO: MOTOR DE PROVISIONAMENTO SAAS (Cria Escola, Login, Subdomínio e Pastas)
  // =========================================================================
  Future<void> provisionarNovaEscola({
    required String nomeFantasia,
    required String subdominio,
    required String nomeDiretor,
    required String emailDiretor,
    required String senhaDiretor,
  }) async {
    try {
      // 1. DESCOBRIR O PRÓXIMO ID (ESC-XXXX)
      final tenantsSnapshot = await _db.get();
      int maiorId = 0;
      for (var doc in tenantsSnapshot.docs) {
        if (doc.id.startsWith('ESC-')) {
          final numStr = doc.id.substring(4);
          final numero = int.tryParse(numStr) ?? 0;
          if (numero > maiorId) maiorId = numero;
        }
      }
      final novoIdEscola = 'ESC-${(maiorId + 1).toString().padLeft(4, '0')}';

      // 2. CRIAR O LOGIN DO DIRETOR SEM DESLOGAR O SUPER ADMIN
      // Inicializa uma instância temporária do Firebase apenas para criar o Auth
      FirebaseApp appSecundario = await Firebase.initializeApp(
        name: 'AppCriacaoTenant_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      
      UserCredential userCred = await FirebaseAuth.instanceFor(app: appSecundario)
          .createUserWithEmailAndPassword(email: emailDiretor, password: senhaDiretor);
      
      final String uidDiretor = userCred.user!.uid;
      
      // Fecha o app temporário para não interferir na sua sessão logada
      await appSecundario.delete();

      // 3. INICIAR O BATCH WRITE (Para salvar toda a estrutura atômica)
      WriteBatch batch = _firestoreGlobal.batch();

      // A) Documento Principal da Escola (Tenant)
      DocumentReference escolaRef = _db.doc(novoIdEscola);
      batch.set(escolaRef, {
        'id': novoIdEscola,
        'nomeFantasia': nomeFantasia,
        'subdominio': subdominio.toLowerCase().trim(),
        'emailAdmin': emailDiretor,
        'status': 'Ativo',
        'plano': 'Básico',
        'corPrimaria': '#FF9200', 
        'corSecundaria': '#33F133', 
        'dataCriacao': DateTime.now().toIso8601String(),
        'endereco': {'rua': '', 'numero': '', 'bairro': '', 'cidade': '', 'estado': ''},
      });

      // B) Permissão Global na coleção 'usuarios' (Essencial para o Login Funcionar)
      DocumentReference usuarioRef = _firestoreGlobal.collection('usuarios').doc(uidDiretor);
      batch.set(usuarioRef, {
        'uid': uidDiretor,
        'nome': nomeDiretor,
        'email': emailDiretor,
        'role': 'ADMIN', 
        'tenantId': novoIdEscola,
        'dataCadastro': DateTime.now().toIso8601String(),
      });

      // C) Cadastra o Diretor como funcionário dentro da escola
      DocumentReference diretorNaSecretariaRef = escolaRef.collection('secretaria').doc('SEC-01');
      batch.set(diretorNaSecretariaRef, {
        'id': 'SEC-01',
        'nome': nomeDiretor,
        'email': emailDiretor,
        'funcao': 'DIRETOR(A)',
        'status': 'Ativo',
        'dataCadastro': DateTime.now().toIso8601String(),
      });

      // D) Injeta documentos invisíveis "_setup" para forçar o Firebase a mostrar as pastas
      final colecoesVazias = ['alunos', 'professores', 'responsaveis', 'turmas'];
      for (String col in colecoesVazias) {
        DocumentReference setupRef = escolaRef.collection(col).doc('_setup');
        batch.set(setupRef, {
          'aviso': 'Documento de inicialização gerado automaticamente pelo sistema.',
          'dataCriacao': DateTime.now().toIso8601String(),
        });
      }

      // 4. ENVIA TUDO PARA O BANCO DE DADOS
      await batch.commit();

    } catch (e) {
      throw Exception('Falha ao provisionar a escola: $e');
    }
  }
}

final escolaServiceProvider = Provider((ref) => EscolaService());

final escolasStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('tenants').orderBy('id').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()).toList();
  });
});