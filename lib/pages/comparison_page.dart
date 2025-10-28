import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/iot_service.dart';
import '../models/energy_sample.dart';

class ComparisonPage extends StatefulWidget {
  const ComparisonPage({super.key});

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  final List<EnergySample> _history = [];

  @override
  void initState() {
    super.initState();
    context.read<IoTService>().stream.listen((s) {
      setState(() {
        _history.add(s);
        if (_history.length > 300) _history.removeAt(0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final byRoom = <String, List<double>>{};
    for (final s in _history) {
      byRoom.putIfAbsent(s.room, () => []).add(s.watts);
    }
    final rooms = byRoom.keys.toList();
    final avgs = rooms.map((r) {
      final list = byRoom[r]!;
      return list.isEmpty ? 0.0 : list.reduce((a,b)=>a+b)/list.length;
    }).toList();

    final bars = <BarChartGroupData>[];
    for (var i=0;i<rooms.length;i++) {
      bars.add(BarChartGroupData(x: i, barRods: [BarChartRodData(toY: avgs[i])]));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Comparação')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Média de Consumo por Divisão (recente)'),
            const SizedBox(height: 12),
            Expanded(
              child: BarChart(BarChartData(
                barGroups: bars,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(i>=0 && i<rooms.length ? rooms[i] : ''),
                      );
                    }),
                  ),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
