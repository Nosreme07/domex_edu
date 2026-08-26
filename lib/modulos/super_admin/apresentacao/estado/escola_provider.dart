import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // <-- NOVO: Para salvar arquivos!
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // <-- NOVO: Para reconhecer o XFile

// 1. Serviço que grava no Firestore (Coleção 'tenants') e no Storage (Logos)
class EscolaService {
  final _db = FirebaseFirestore.instance.collection('tenants');
  final _storage = FirebaseStorage.instance; // Referência para a nuvem de arquivos

  Future<void> salvarEscola(Map<String, dynamic> escolaDados) async {
    // 1. Verifica se existe uma foto (XFile) nova pendente de upload
    if (escolaDados.containsKey('arquivoLogo') && escolaDados['arquivoLogo'] != null) {
      final XFile arquivo = escolaDados['arquivoLogo'];
      
      // Define a "pasta" e o nome do arquivo lá no Storage (ex: logos/ESC-0001_logo.png)
      final caminhoStorage = _storage.ref().child('logos/${escolaDados['id']}_logo.png');
      
      try {
        // Lemos a imagem em Bytes (isso garante que funciona tanto na Web quanto no Celular)
        final bytes = await arquivo.readAsBytes();
        
        // Fazemos o upload para o Firebase Storage
        await caminhoStorage.putData(bytes, SettableMetadata(contentType: 'image/png'));
        
        // Pegamos o Link (URL) gerado pelo Storage
        final linkFoto = await caminhoStorage.getDownloadURL();
        
        // Colocamos o link de texto no mapa de dados da escola
        escolaDados['logoUrl'] = linkFoto;
      } catch (e) {
        throw Exception('Falha ao enviar a foto da logo: $e'); 
      }
    }

    // 2. Remove o objeto XFile do mapa para não dar o erro vermelho no Firestore!
    escolaDados.remove('arquivoLogo');

    // 3. Agora sim, salva no banco de dados com segurança
    await _db.doc(escolaDados['id']).set(escolaDados);
  }

  Future<void> atualizarStatus(String id, String novoStatus) async {
    await _db.doc(id).update({'status': novoStatus});
  }

  // NOVA FUNÇÃO ADICIONADA: Excluir Escola
  Future<void> excluirEscola(String id) async {
    await _db.doc(id).delete();
  }
}

final escolaServiceProvider = Provider((ref) => EscolaService());

final escolasStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('tenants').orderBy('id').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()).toList();
  });
});