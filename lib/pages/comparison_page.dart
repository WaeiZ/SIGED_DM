import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/iot_service.dart';
import '../models/energy_sample.dart';

class ComparisonPage extends StatefulWidget {
  const ComparisonPage({super.key});

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  final List<EnergySample> _history = [];
  String _selectedMode = 'Média'; // Opções: Média, Mediana, Média Móvel

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

  double _calculateAverage(List<double> list) {
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  double _calculateMedian(List<double> list) {
    if (list.isEmpty) return 0;
    final sorted = [...list]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double _calculateMovingAverage(List<double> list, {int window = 10}) {
    if (list.isEmpty) return 0;
    final lastValues = list.sublist(max(0, list.length - window));
    return _calculateAverage(lastValues);
  }

  Future<void> _exportPdf(Map<String, double> results) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Relatório de Consumo por Divisão',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Tipo de cálculo: $_selectedMode',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: ['Divisão', 'Valor (W)'],
                  data: results.entries
                      .map((e) => [e.key, e.value.toStringAsFixed(2)])
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/relatorio_consumo.pdf');
    await file.writeAsBytes(await pdf.save());

    // Notifica o utilizador
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF exportado com sucesso!'),
        duration: Duration(seconds: 2),
      ),
    );

    // 🔹 Abre o ficheiro diretamente
    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final byRoom = <String, List<double>>{};
    for (final s in _history) {
      byRoom.putIfAbsent(s.room, () => []).add(s.watts);
    }

    final rooms = byRoom.keys.toList();
    final values = rooms.map((r) {
      final list = byRoom[r]!;
      switch (_selectedMode) {
        case 'Mediana':
          return _calculateMedian(list);
        case 'Média Móvel':
          return _calculateMovingAverage(list);
        default:
          return _calculateAverage(list);
      }
    }).toList();

    final bars = <BarChartGroupData>[
      for (var i = 0; i < rooms.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: values[i], width: 20, color: const Color(0xFF2F80ED)),
          ],
        ),
    ];

    final resultMap = {
      for (var i = 0; i < rooms.length; i++) rooms[i]: values[i],
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Comparação')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Média de Consumo por Divisão (recente)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: DropdownButton<String>(
                value: _selectedMode,
                items: const [
                  DropdownMenuItem(value: 'Média', child: Text('Média')),
                  DropdownMenuItem(value: 'Mediana', child: Text('Mediana')),
                  DropdownMenuItem(
                      value: 'Média Móvel', child: Text('Média Móvel')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedMode = v);
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  barGroups: bars,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              i >= 0 && i < rooms.length ? rooms[i] : '',
                              style: const TextStyle(fontSize: 12), 
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 Botão Exportar PDF
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _exportPdf(resultMap),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Exportar PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F80ED),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
