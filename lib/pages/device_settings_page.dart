//Martim Santos - 22309746
//Sérgio Dias - 22304791

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeviceSettingsPage extends StatefulWidget {
  const DeviceSettingsPage({super.key});

  @override
  State<DeviceSettingsPage> createState() => _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends State<DeviceSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  List<Map<String, dynamic>> dispositivos = [];

  @override
  void initState() {
    super.initState();
    _carregarDispositivos();
  }

  Future<void> _carregarDispositivos() async {
    try {
      setState(() => isLoading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Utilizador não autenticado');
      }

      final sensoresSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('sensors')
          .get();

      final lista = sensoresSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'description': data['description'] ?? doc.id,
          'type': data['type'] ?? 'energy',
          'powerUnit': data['powerUnit'] ?? 'W',
          'energyUnit': data['energyUnit'] ?? 'kWh',
        };
      }).toList();

      setState(() {
        dispositivos = lista;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _mostrarErro('Erro ao carregar dispositivos: $e');
    }
  }

  Future<void> _alterarNomeDispositivo(
    String dispositivoId,
    String nomeAtual,
  ) async {
    final controller = TextEditingController(text: nomeAtual);

    final novoNome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar Nome do Dispositivo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Novo Nome',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('O nome não pode estar vazio'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F6036),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (novoNome != null && novoNome.isNotEmpty) {
      await _guardarNovoNome(dispositivoId, novoNome);
    }
  }

  Future<void> _guardarNovoNome(String dispositivoId, String novoNome) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('sensors')
          .doc(dispositivoId)
          .update({'description': novoNome});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nome alterado com sucesso!'),
          backgroundColor: Color(0xFF1F6036),
        ),
      );

      _carregarDispositivos(); // Recarrega a lista
    } catch (e) {
      _mostrarErro('Erro ao alterar nome: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Definições de Dispositivos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1F6036),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1F6036)),
            )
          : dispositivos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices_other, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum dispositivo encontrado',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dispositivos.length,
              itemBuilder: (context, index) {
                final dispositivo = dispositivos[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F6036).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.sensors,
                        color: Color(0xFF1F6036),
                        size: 28,
                      ),
                    ),
                    title: Text(
                      dispositivo['description'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'ID: ${dispositivo['id']}\nTipo: ${dispositivo['type']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF1F6036)),
                      onPressed: () => _alterarNomeDispositivo(
                        dispositivo['id'],
                        dispositivo['description'],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
