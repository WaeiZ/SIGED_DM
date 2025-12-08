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

  IoTService({required this.userId});

  // energia acumulada por sensor
  final Map<String, double> _energy = {
    "Sensor1": 0,
    "Sensor2": 0,
    "Sensor3": 0,
  };

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _emit("Sensor1");
      _emit("Sensor2");
      _emit("Sensor3");
    });
  }

  Future<void> _emit(String room) async {
    final voltage = 215 + _rand.nextDouble() * 15;
    final current = _rand.nextDouble() * 10;
    final watts = voltage * current;

    // energia acumulada (kWh)
    _energy[room] = _energy[room]! + (watts / 1000 / 3600);

    final sample = EnergySample(DateTime.now(), room, watts);

    //Envia para o Dashboard (stream)
    _controller.add(sample);

    //Envia para Firebase
    await _db
        .collection("users")
        .doc(userId)
        .collection("sensors")
        .doc(room)
        .collection("readings")
        .add({
          "timestamp": sample.time.millisecondsSinceEpoch,
          "power": sample.watts,
          "energy": _energy[room],
        });
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
