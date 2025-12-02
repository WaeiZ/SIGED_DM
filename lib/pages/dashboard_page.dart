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

    // Ouvir stream
    iot.stream.listen((sample) {
      setState(() {
        _history.add(sample);
        if (_history.length > 180) _history.removeAt(0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ------------------------------
    // CALCULAR CONSUMO ATUAL
    // ------------------------------
    final latestByRoom = <String, double>{};
    for (final s in _history) {
      latestByRoom[s.room] = s.watts;
    }
    final total = latestByRoom.values.fold<double>(0, (a, b) => a + b);

    // ------------------------------
    // PREPARAR GRÁFICO
    // ------------------------------
    final grouped = <int, double>{};
    for (final s in _history) {
      final second = s.time.second;
      grouped[second] = (grouped[second] ?? 0) + s.watts;
    }

    final ordered = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = ordered
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    // Caso não haja dados ainda
    final hasData = spots.isNotEmpty;

    // ------------------------------
    // UI
    // ------------------------------
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGED - Dashboard'),
        centerTitle: true,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BOTÃO DE OPÇÕES (DISPOSITIVO)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PopupMenuButton<String>(
                onSelected: (value) {},
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'Total', child: Text('Total')),
                  PopupMenuItem(value: 'Sensor1', child: Text('Sensor1')),
                  PopupMenuItem(value: 'Sensor2', child: Text('Sensor2')),
                  PopupMenuItem(value: 'Sensor3', child: Text('Sensor3')),
                ],
                // Este child é o botão que aparece na UI
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Dispositivo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),

              // SUBLINHADO
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 1.4,
                width: 105, // ajusta para o tamanho desejado
                color: Colors.black,
              ),

              const SizedBox(height: 16),
            ],
          ),

          //=====================================
          // CARD 1 — CONSUMO ATUAL
          //=====================================
          Card(
            color: cs.surface,
            elevation: 1,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Consumo Atual',
                    style: TextStyle(
                      color: Colors.black, // força para evitar opacidade
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${total.toStringAsFixed(0)} W',
                        style: const TextStyle(
                          fontSize: 34,
                          color: Colors.black,
                        ),
                      ),
                      const Icon(Icons.bolt, size: 50, color: Colors.black),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          //=====================================
          // CARD 2 — GRÁFICO EM TEMPO REAL
          //=====================================
          Card(
            color: cs.surface,
            elevation: 1,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TÍTULO
                  const Text(
                    'Consumo em Tempo Real',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 240,
                    child: hasData
                        ? LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: 59,

                              // -------------------------------
                              // LINHA PRINCIPAL DO GRÁFICO
                              // -------------------------------
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  barWidth: 3,
                                  color: cs.primary,
                                  dotData: const FlDotData(show: false),
                                ),
                              ],

                              // -------------------------------
                              // GRELHA
                              // -------------------------------
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) =>
                                    const FlLine(
                                      color: Colors.black26,
                                      strokeWidth: 0.4,
                                    ),
                              ),

                              // -------------------------------
                              // EIXOS / COORDENADAS
                              // -------------------------------
                              titlesData: FlTitlesData(
                                show: true,

                                // EIXO X (segundos)
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 10, // mostra 0, 10, 20...
                                    reservedSize: 24,
                                    getTitlesWidget: (value, meta) {
                                      if (value % 10 == 0) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black87,
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),

                                // EIXO Y (Watts)
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval:
                                        200, // ajusta conforme o teu consumo
                                    reservedSize: 36,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black87,
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // Desativa topo e direita
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),

                              // -------------------------------
                              // SEM BORDA
                              // -------------------------------
                              borderData: FlBorderData(show: false),
                            ),
                          )
                        : const Center(
                            child: Text(
                              'A recolher dados...',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
