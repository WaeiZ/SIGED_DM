import 'dart:async';

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
  /// Histórico recente de amostras (até 180 valores)
  final List<EnergySample> _history = [];

  /// Subscrição da stream de dados IoT
  StreamSubscription<EnergySample>? _sub;

  /// Dispositivo selecionado no filtro
  String _selectedDevice = 'Total';

  // =========================
  // CICLO DE VIDA
  // =========================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final iot = context.read<IoTService>();

      _sub = iot.stream.listen((sample) {
        setState(() {
          _history.add(sample);
          if (_history.length > 180) {
            _history.removeAt(0);
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // =========================
  // LÓGICA / CÁLCULOS
  // =========================

  /// Retorna a lista de amostras filtradas pelo dispositivo selecionado.
  List<EnergySample> get _filteredHistory {
    if (_selectedDevice == 'Total') return _history;
    return _history.where((s) => s.room == _selectedDevice).toList();
  }

  /// Calcula o consumo total atual (somando último valor de cada room).
  double get _currentTotalWatts {
    final latestByRoom = <String, double>{};

    for (final s in _filteredHistory) {
      latestByRoom[s.room] = s.watts;
    }

    return latestByRoom.values.fold<double>(0, (a, b) => a + b);
  }

  /// Agrupa por segundo (0–59) e soma Watts.
  Map<int, double> get _groupedBySecond {
    final grouped = <int, double>{};

    for (final s in _filteredHistory) {
      final sec = s.time.second;
      grouped[sec] = (grouped[sec] ?? 0) + s.watts;
    }

    return grouped;
  }

  /// Constrói os pontos para o gráfico em função dos segundos.
  List<FlSpot> get _spots {
    final grouped = _groupedBySecond;

    final ordered = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = ordered
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    // Evita problemas do gráfico com menos de 2 pontos
    if (spots.length < 2) {
      return [const FlSpot(0, 0), if (spots.isNotEmpty) spots.first];
    }

    return spots;
  }

  bool get _hasData {
    return _filteredHistory.isNotEmpty && _spots.any((s) => s.y > 0);
  }

  double get _maxY {
    if (!_hasData) return 100;
    final values = _spots.map((e) => e.y).toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    return max + max * 0.1; // +10% de margem
  }

  // =========================
  // UI HELPERS
  // =========================

  Widget _buildDeviceSelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() => _selectedDevice = value);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'Total', child: Text('Total')),
            PopupMenuItem(value: 'Sensor1', child: Text('Sensor1')),
            PopupMenuItem(value: 'Sensor2', child: Text('Sensor2')),
            PopupMenuItem(value: 'Sensor3', child: Text('Sensor3')),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedDevice,
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

        // Sublinhado
        Container(
          margin: const EdgeInsets.only(top: 2),
          height: 1.4,
          width: 90,
          color: Colors.black,
        ),

        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildCurrentConsumptionCard(ColorScheme cs) {
    return Card(
      color: cs.surface,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consumo Atual',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDevice == 'Total'
                  ? 'Todos os Sensores'
                  : 'Dispositivo: $_selectedDevice',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentTotalWatts.toStringAsFixed(0)} W',
                  style: const TextStyle(
                    fontSize: 34,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(Icons.bolt, size: 50, color: Colors.black),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeChartCard(ColorScheme cs) {
    return Card(
      color: cs.surface,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consumo em Tempo Real',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedDevice == 'Total'
                  ? 'Últimos segundos — Total'
                  : 'Últimos segundos — $_selectedDevice',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: _hasData
                  ? LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: 59,
                        minY: 0,
                        maxY: _maxY,

                        // Linha principal
                        lineBarsData: [
                          LineChartBarData(
                            spots: _spots,
                            isCurved: true,
                            barWidth: 3,
                            color: cs.primary,
                            dotData: const FlDotData(show: false),
                          ),
                        ],

                        // Grelha
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => const FlLine(
                            color: Colors.black26,
                            strokeWidth: 0.4,
                          ),
                        ),

                        // Eixos / Títulos
                        titlesData: FlTitlesData(
                          show: true,

                          // Eixo X (segundos)
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

                          // Eixo Y (Watts)
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 200, // ajusta conforme o teu consumo
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

                        // Sem borda
                        borderData: FlBorderData(show: false),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'A recolher dados...',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
          _buildRealtimeChartCard(cs),
        ],
      ),
    );
  }
}
