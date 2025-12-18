// Martim Santos - 22309746
// Sérgio Dias - 22304791

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/iot_service.dart';
import '../models/energy_sample.dart';

class DashboardPage extends StatefulWidget {
  final String userId;

  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- VARIÁVEIS DE ESTADO ---

  final List<EnergySample> _rawHistory = [];
  final List<double> _totalHistory = [];

  final Map<String, double> _latestReadings = {};
  DateTime? _lastTotalUpdate;

  String _selectedDevice = 'Total';
  List<String> _deviceNames = [];
  bool _isLoadingDevices = true;

  // --- CONFIGURAÇÃO DA JANELA DE TEMPO ---
  final double _windowDuration = 60.0;
  final int _secondsPerSample = 5;

  // Adicionamos +1 para garantir que o gráfico vai até à linha dos 60s.
  int get _pointsNeeded => (_windowDuration / _secondsPerSample).ceil() + 1;

  @override
  void initState() {
    super.initState();

    final iot = context.read<IoTService>();
    _fetchDevices();

    iot.stream.listen((sample) {
      if (!mounted) return;

      setState(() {
        final now = DateTime.now();

        // 1. Atualizar mapa
        _latestReadings[sample.room] = sample.watts;

        // 2. Calcular TOTAL
        double currentTotalSum = _latestReadings.values.fold(
          0,
          (a, b) => a + b,
        );

        // 3. Lógica Total (Debounce para 5s)
        if (_totalHistory.isNotEmpty &&
            _lastTotalUpdate != null &&
            now.difference(_lastTotalUpdate!).inMilliseconds < 2000) {
          _totalHistory.last = currentTotalSum;
        } else {
          _totalHistory.add(currentTotalSum);
          _lastTotalUpdate = now;

          // Mantém apenas os pontos necessários (13)
          if (_totalHistory.length > _pointsNeeded) {
            _totalHistory.removeAt(0);
          }
        }

        // 4. Adicionar ao histórico RAW
        _rawHistory.add(sample);
        // Buffer maior para segurança
        if (_rawHistory.length > 200) {
          _rawHistory.removeAt(0);
        }
      });
    });
  }

  Future<void> _fetchDevices() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('sensors')
          .get();

      final List<String> loadedDevices = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedDevices.add(data['description'] ?? doc.id);
      }

      if (mounted) {
        setState(() {
          _deviceNames = loadedDevices;
          _isLoadingDevices = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dispositivos: $e');
      if (mounted) {
        setState(() => _isLoadingDevices = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    List<FlSpot> spots = [];
    double currentDisplayWatts = 0;

    if (_selectedDevice == 'Total') {
      // --- MODO TOTAL ---
      currentDisplayWatts = _totalHistory.isNotEmpty ? _totalHistory.last : 0;

      for (int i = 0; i < _totalHistory.length; i++) {
        double xPosition = (i * _secondsPerSample).toDouble();
        spots.add(FlSpot(xPosition, _totalHistory[i]));
      }
    } else {
      // --- MODO INDIVIDUAL ---
      final roomHistory = _rawHistory
          .where((s) => s.room == _selectedDevice)
          .toList();
      currentDisplayWatts = roomHistory.isNotEmpty ? roomHistory.last.watts : 0;

      // Isso garante que mostramos pontos suficientes para chegar aos 60s.
      int startIndex = 0;
      if (roomHistory.length > _pointsNeeded) {
        startIndex = roomHistory.length - _pointsNeeded;
      }

      int pointCounter = 0;
      for (int i = startIndex; i < roomHistory.length; i++) {
        double xPosition = (pointCounter * _secondsPerSample).toDouble();
        spots.add(FlSpot(xPosition, roomHistory[i].watts));
        pointCounter++;
      }
    }

    // Y Máximo
    double maxVal = 0;
    for (var spot in spots) {
      if (spot.y > maxVal) maxVal = spot.y;
    }
    double maxY = (maxVal < 100) ? 100 : (maxVal * 1.2);
    maxY = (maxY / 10).ceil() * 10;

    final hasData = spots.isNotEmpty;
    final underlineWidth = (_selectedDevice.length * 9.0) + 30.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1F6036),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SELETOR
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PopupMenuButton<String>(
                color: const Color(0xFFEBEFE7),
                onSelected: (value) => setState(() => _selectedDevice = value),
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[
                    const PopupMenuItem(value: 'Total', child: Text('Total')),
                  ];
                  if (_deviceNames.isNotEmpty) {
                    for (final d in _deviceNames) {
                      items.add(PopupMenuItem(value: d, child: Text(d)));
                    }
                  } else if (_isLoadingDevices) {
                    items.add(
                      const PopupMenuItem(
                        enabled: false,
                        child: Text('A carregar...'),
                      ),
                    );
                  }
                  return items;
                },
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
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 1.4,
                width: underlineWidth,
                color: Colors.black,
              ),
              const SizedBox(height: 16),
            ],
          ),

          // CARD CONSUMO
          Card(
            color: const Color(0xFFEBEFE7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consumo Atual ($_selectedDevice)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${currentDisplayWatts.toStringAsFixed(0)} W',
                        style: const TextStyle(fontSize: 34),
                      ),
                      const Icon(Icons.bolt, size: 50),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // CARD GRÁFICO
          Card(
            color: const Color(0xFFEBEFE7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consumo em Tempo Real ($_selectedDevice)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: hasData
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'watts (W)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        left: 4,
                                        right: 14,
                                        bottom: 8,
                                      ),
                                      child: LineChart(
                                        LineChartData(
                                          minX: 0,
                                          maxX: _windowDuration,
                                          minY: 0,
                                          maxY: maxY,

                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: spots,
                                              isCurved: false,
                                              barWidth: 3,
                                              color: cs.primary,
                                              dotData: const FlDotData(
                                                show: false,
                                              ),
                                            ),
                                          ],

                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: false,
                                            horizontalInterval: maxY / 5,
                                            getDrawingHorizontalLine: (value) =>
                                                FlLine(
                                                  color: Colors.black
                                                      .withOpacity(0.12),
                                                  strokeWidth: 1,
                                                ),
                                          ),

                                          extraLinesData: ExtraLinesData(
                                            horizontalLines: [
                                              HorizontalLine(
                                                y: 0,
                                                color: Colors.black.withOpacity(
                                                  0.18,
                                                ),
                                                strokeWidth: 1,
                                                dashArray: [6, 4],
                                              ),
                                            ],
                                          ),

                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                interval: 5,
                                                reservedSize: 30,
                                                getTitlesWidget: (value, meta) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      '${value.toInt()}s',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                interval: maxY / 5,
                                                reservedSize: 40,
                                                getTitlesWidget: (value, meta) {
                                                  if (value == 0)
                                                    return const SizedBox.shrink();
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.black54,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: false,
                                              ),
                                            ),
                                            rightTitles: const AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: false,
                                              ),
                                            ),
                                          ),
                                          borderData: FlBorderData(show: false),
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Text(
                                        'janela de tempo (ultimos 60s)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Text(
                              'A aguardar dados...',
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
