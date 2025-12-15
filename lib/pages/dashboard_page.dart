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
  final List<EnergySample> _history = [];
  String _selectedDevice = 'Total';

  List<String> _deviceNames = [];
  bool _isLoadingDevices = true;

  @override
  void initState() {
    super.initState();

    final iot = context.read<IoTService>();

    _fetchDevices();

    iot.stream.listen((sample) {
      if (!mounted) return;

      setState(() {
        // reset quando o tempo volta de 59 -> 0
        if (_history.isNotEmpty &&
            sample.time.second < _history.last.time.second) {
          _history.clear();
        }

        _history.add(sample);

        if (_history.length > 60) {
          _history.removeAt(0);
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

    final List<EnergySample> filteredHistory = (_selectedDevice == 'Total')
        ? _history
        : _history.where((s) => s.room == _selectedDevice).toList();

    double total = 0;
    if (_selectedDevice == 'Total') {
      final latestByRoom = <String, double>{};
      for (final s in _history) {
        latestByRoom[s.room] = s.watts;
      }
      total = latestByRoom.values.fold(0, (a, b) => a + b);
    } else {
      total = filteredHistory.isNotEmpty ? filteredHistory.last.watts : 0;
    }

    final grouped = <int, double>{};
    for (final s in filteredHistory) {
      final second = s.time.second;
      if (_selectedDevice == 'Total') {
        grouped[second] = (grouped[second] ?? 0) + s.watts;
      } else {
        grouped[second] = s.watts;
      }
    }

    final ordered = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = ordered
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

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

          // CARD CONSUMO ATUAL
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
                        '${total.toStringAsFixed(0)} W',
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
                                        right:
                                            14, // 👈 mais espaço à direita (resolve o corte)
                                        bottom: 8,
                                      ),
                                      child: LineChart(
                                        LineChartData(
                                          minX: 0,
                                          maxX: 59,
                                          minY: 0,
                                          maxY: 8000,

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
                                            horizontalInterval: 1000,
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
                                                interval: 10,
                                                reservedSize: 30,
                                                getTitlesWidget: (value, meta) {
                                                  if (value % 10 == 0 ||
                                                      value == 59) {
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 2,
                                                          ),
                                                      child: Text(
                                                        value
                                                            .toInt()
                                                            .toString(),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.black87,
                                                        ),
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
                                                interval: 1000,
                                                reservedSize: 44,
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

                                    // mantém apenas o "tempo (s)" no canto
                                    const Positioned(
                                      right: 8,
                                      bottom: 2,
                                      child: Text(
                                        'tempo (s)',
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
