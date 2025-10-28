import 'dart:async';
import 'dart:math';
import '../models/energy_sample.dart';

class IoTService {
  final _controller = StreamController<EnergySample>.broadcast();
  Stream<EnergySample> get stream => _controller.stream;

  final _rnd = Random();
  final List<String> rooms;
  IoTService._(this.rooms);

  factory IoTService.demo() => IoTService._(['Sala', 'Cozinha', 'Quarto', 'Garagem']);

  Timer? _timer;

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      for (final r in rooms) {
        var base = switch (r) {
          'Cozinha' => 220 + _rnd.nextDouble() * 150,
          'Sala' => 140 + _rnd.nextDouble() * 90,
          'Quarto' => 90 + _rnd.nextDouble() * 50,
          _ => 70 + _rnd.nextDouble() * 40,
        };
        if (_rnd.nextDouble() < 0.05) base += 400 + _rnd.nextDouble() * 300;
        _controller.add(EnergySample(now, r, base));
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
