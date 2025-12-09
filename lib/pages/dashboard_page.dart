//Martim Santos - 22309746
//Sérgio Dias - 22304791

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
  // 1. Variável de estado para a opção selecionada
  String _selectedDevice = 'Total';

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

    // --- FILTRAR HISTÓRICO ---
    // Filtra o histórico apenas se um sensor específico for selecionado.
    final List<EnergySample> filteredHistory = (_selectedDevice == 'Total')
        ? _history
        : _history.where((s) => s.room == _selectedDevice).toList();

    // ------------------------------
    // CALCULAR CONSUMO ATUAL (USANDO DADOS FILTRADOS)
    // ------------------------------
    double total = 0;
    if (_selectedDevice == 'Total') {
      // Se for "Total", usamos a lógica original para somar o último valor de cada sensor.
      final latestByRoom = <String, double>{};
      for (final s in _history) {
        // Usamos o histórico COMPLETO aqui.
        latestByRoom[s.room] = s.watts;
      }
      total = latestByRoom.values.fold<double>(0, (a, b) => a + b);
    } else {
      // Se for um Sensor específico, o consumo atual é apenas o último valor desse sensor.
      total = filteredHistory.isNotEmpty ? filteredHistory.last.watts : 0;
    }

    // ------------------------------
    // PREPARAR GRÁFICO (USANDO DADOS FILTRADOS)
    // ------------------------------
    final grouped = <int, double>{};
    for (final s in filteredHistory) {
      // Usamos o histórico FILTRADO aqui.
      final second = s.time.second;
      // Se 'Total' estiver selecionado, a amostra já foi filtrada para ser o histórico completo,
      // mas precisamos agrupá-los por segundo (somando os valores dos diferentes sensores).
      // Se for um sensor específico, a amostra já está filtrada.
      if (_selectedDevice == 'Total') {
        grouped[second] = (grouped[second] ?? 0) + s.watts;
      } else {
        // Se for um sensor específico, o valor já é a leitura daquele sensor no momento.
        grouped[second] = s.watts;
      }
    }

    final ordered = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = ordered
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    // Caso não haja dados ainda
    final hasData = spots.isNotEmpty;

    // Calcula a largura do sublinhado baseada no texto do botão
    double underlineWidth = (_selectedDevice.length * 9.0) + 30.0;

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
                // 2. Atualiza o estado
                onSelected: (String value) {
                  setState(() {
                    _selectedDevice = value;
                  });
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'Total', child: Text('Total')),
                  PopupMenuItem(value: 'Sensor1', child: Text('Sensor1')),
                  PopupMenuItem(value: 'Sensor2', child: Text('Sensor2')),
                  PopupMenuItem(value: 'Sensor3', child: Text('Sensor3')),
                ],
                // 3. O child mostra o valor selecionado
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedDevice, // Usa a variável de estado aqui
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
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
                width: underlineWidth, // Largura dinâmica
                color: Colors.black,
              ),

              const SizedBox(height: 16),
            ],
          ),

          // CARD 1 — CONSUMO ATUAL (usa a variável `total` já calculada)
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
                  Text(
                    'Consumo Atual (${_selectedDevice})', // Título mais descritivo
                    style: const TextStyle(
                      color: Colors.black,
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

          // CARD 2 — GRÁFICO EM TEMPO REAL (usa a variável `spots` já calculada)
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
                  Text(
                    'Consumo em Tempo Real (${_selectedDevice})', // Título mais descritivo
                    style: const TextStyle(
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
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots, // Usa spots filtrados
                                  isCurved: true,
                                  barWidth: 3,
                                  color: cs.primary,
                                  dotData: const FlDotData(show: false),
                                ),
                              ],
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) =>
                                    const FlLine(
                                      color: Colors.black26,
                                      strokeWidth: 0.4,
                                    ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 10,
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
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 200,
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
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
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
