//Martim Santos - 22309746
//Sérgio Dias - 22304791

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/energy_sample.dart';

class IoTService {
  final _controller = StreamController<EnergySample>.broadcast();
  Stream<EnergySample> get stream => _controller.stream;

  Timer? _timer;
  final Random _rand = Random();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  // MAPA: Chave = ID do documento (ex: Sensor1), Valor = Descrição (ex: Sala)
  Map<String, String> _activeSensors = {};

  // Mapa para energia acumulada (controlado pelo ID do sensor)
  final Map<String, double> _energy = {};

  IoTService({required this.userId});

  void start() {
    _loadExistingSensors().then((_) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        // Itera sobre os IDs dos sensores
        for (final sensorId in _activeSensors.keys) {
          _emit(sensorId);
        }
      });
    });
  }

  Future<void> _loadExistingSensors() async {
    try {
      final snapshot = await _db
          .collection("users")
          .doc(userId)
          .collection("sensors")
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Limpa o mapa atual
        _activeSensors.clear();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final sensorId = doc.id;
          // Se tiver descrição usa, se não usa o ID
          final description = data['description'] ?? sensorId;

          _activeSensors[sensorId] = description;
        }
        print('Sensores carregados: $_activeSensors');
      } else {
        print('⚠️ Nenhum sensor encontrado. A criar padrões...');
        await _initializeDefaultSensors();
      }
    } catch (e) {
      print('Erro ao carregar sensores: $e');
    }
  }

  Future<void> _initializeDefaultSensors() async {
    // Definir ID e Descrição inicial
    final defaultSensors = {
      "Sensor1": "Sala",
      "Sensor2": "Cozinha",
      "Sensor3": "Quarto",
    };

    try {
      for (final entry in defaultSensors.entries) {
        final sensorId = entry.key;
        final description = entry.value;

        await _db
            .collection("users")
            .doc(userId)
            .collection("sensors")
            .doc(sensorId)
            .set({
              'type': 'energy',
              'description': description,
              'powerUnit': 'W',
              'energyUnit': 'kWh',
            }, SetOptions(merge: true));

        // Atualiza o mapa local
        _activeSensors[sensorId] = description;
      }
      print('Sensores padrão criados com sucesso!');
    } catch (e) {
      print('Erro ao criar sensores padrão: $e');
    }
  }

  Future<void> _emit(String sensorId) async {
    // Busca a descrição correspondente a este ID
    final description = _activeSensors[sensorId] ?? sensorId;

    final voltage = 215 + _rand.nextDouble() * 15;
    final current = _rand.nextDouble() * 10;
    final watts = voltage * current;

    if (!_energy.containsKey(sensorId)) {
      _energy[sensorId] = 0;
    }

    // Energia acumulada
    _energy[sensorId] = _energy[sensorId]! + (watts / 1000 / 3600);

    // Para a app (gráfico/dashboard), enviamos a DESCRIÇÃO (ex: "Sala")
    final sample = EnergySample(DateTime.now(), description, watts);
    _controller.add(sample);

    // Para o Firebase, gravamos dentro do documento com o ID (ex: "Sensor1")
    await _db
        .collection("users")
        .doc(userId)
        .collection("sensors")
        .doc(sensorId)
        .collection("readings")
        .add({
          "timestamp": sample.time.millisecondsSinceEpoch,
          "power": sample.watts,
          "energy": _energy[sensorId],
        });
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
