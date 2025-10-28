import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/iot_service.dart';
import '../models/energy_sample.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<EnergySample> _history = [];

  @override
  void initState() {
    super.initState();
    final iot = context.read<IoTService>();
    iot.stream.listen((s) {
      setState(() {
        _history.add(s);
        if (_history.length > 180) _history.removeAt(0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final latestByRoom = <String, double>{};
    for (final s in _history) {
      latestByRoom[s.room] = s.watts;
    }
    final total = latestByRoom.values.fold<double>(0, (a, b) => a + b);

    final groups = <int, double>{};
    for (final s in _history) {
      final idx = s.time.second;
      groups[idx] = (groups[idx] ?? 0) + s.watts;
    }
    final lineSpots = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spots =
        lineSpots.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGED - Dashboard'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Consumo Atual'),
                        Text('${total.toStringAsFixed(0)} W',
                            style:
                                Theme.of(context).textTheme.headlineMedium),
                      ]),
                  const Icon(Icons.bolt, size: 48),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Consumo em Tempo Real (~últimos 3 min)'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: LineChart(LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          dotData: const FlDotData(show: false)),
                    ],
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                  )),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
