//Martim Santos - 22309746
//Sérgio Dias - 22304791

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import necessário

import '../services/iot_service.dart';
import '../models/energy_sample.dart';

class DashboardPage extends StatefulWidget {
  // Adicionado userId para podermos buscar os sensores deste utilizador
  final String userId;

  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<EnergySample> _history = [];
  String _selectedDevice = 'Total';

  // Lista para armazenar os nomes dos dispositivos vindos do Firebase
  List<String> _deviceNames = [];
  bool _isLoadingDevices = true;

  @override
  void initState() {
    super.initState();

    final iot = context.read<IoTService>();

    // 1. Carregar dispositivos do Firestore ao iniciar
    _fetchDevices();

    // 2. Ouvir stream IoT
    iot.stream.listen((sample) {
      if (mounted) {
        setState(() {
          _history.add(sample);
          if (_history.length > 180) _history.removeAt(0);
        });
      }
    });
  }

  // Lógica adaptada da ComparisonPage para buscar descrições
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
        // Tenta pegar a descrição, se não existir usa o ID do documento
        final description = data['description'] ?? doc.id;
        loadedDevices.add(description);
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
        setState(() {
          _isLoadingDevices = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // --- FILTRAR HISTÓRICO ---
    final List<EnergySample> filteredHistory = (_selectedDevice == 'Total')
        ? _history
        : _history.where((s) => s.room == _selectedDevice).toList();

    // --- CALCULAR CONSUMO ATUAL ---
    double total = 0;
    if (_selectedDevice == 'Total') {
      final latestByRoom = <String, double>{};
      for (final s in _history) {
        latestByRoom[s.room] = s.watts;
      }
      total = latestByRoom.values.fold<double>(0, (a, b) => a + b);
    } else {
      total = filteredHistory.isNotEmpty ? filteredHistory.last.watts : 0;
    }

    // --- PREPARAR GRÁFICO ---
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
    double underlineWidth = (_selectedDevice.length * 9.0) + 30.0;

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
        elevation: 0,
        centerTitle: true,
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BOTÃO DE OPÇÕES (DISPOSITIVO)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PopupMenuButton<String>(
                color: const Color(0xFFEBEFE7),
                onSelected: (String value) {
                  setState(() {
                    _selectedDevice = value;
                  });
                },
                // AQUI ESTÁ A LÓGICA DINÂMICA
                itemBuilder: (context) {
                  // Opção fixa 'Total'
                  final List<PopupMenuEntry<String>> menuItems = [
                    const PopupMenuItem(value: 'Total', child: Text('Total')),
                  ];

                  // Adiciona os dispositivos carregados do Firebase
                  if (_deviceNames.isNotEmpty) {
                    for (var device in _deviceNames) {
                      menuItems.add(
                        PopupMenuItem(value: device, child: Text(device)),
                      );
                    }
                  } else if (_isLoadingDevices) {
                    // Mostra um item de loading se ainda estiver a carregar
                    menuItems.add(
                      const PopupMenuItem(
                        enabled: false,
                        child: Text('A carregar...'),
                      ),
                    );
                  }

                  return menuItems;
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
                width: underlineWidth,
                color: Colors.black,
              ),

              const SizedBox(height: 16),
            ],
          ),

          // CARD 1 — CONSUMO ATUAL
          Card(
            color: const Color(0xFFEBEFE7),
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
                    'Consumo Atual ($_selectedDevice)',
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

          // CARD 2 — GRÁFICO EM TEMPO REAL
          Card(
            color: const Color(0xFFEBEFE7),
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
                    'Consumo em Tempo Real ($_selectedDevice)',
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
                                  spots: spots,
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
