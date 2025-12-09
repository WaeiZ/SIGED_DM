import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ComparisonPage extends StatefulWidget {
  final String userId;

  const ComparisonPage({super.key, required this.userId});

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? dispositivoSelecionado;
  String medidaSelecionada = 'energia'; // energia, potencia, corrente
  DateTime dataInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime dataFim = DateTime.now();

  List<String> dispositivos = [];
  List<ChartData> dadosGrafico = [];
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _carregarDispositivos();
  }

  Future<void> _carregarDispositivos() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      // Buscar dispositivos do utilizador
      final sensoresSnapshot = await _firestore
          .collection('users') // Mudou de 'utilizadores' para 'users'
          .doc(widget.userId)
          .collection('sensors') // Mudou de 'dispositivos' para 'sensors'
          .get();

      final listaSensores = sensoresSnapshot.docs
          .map((doc) => doc.id) // Usa o ID do documento
          .toList();

      setState(() {
        dispositivos = listaSensores;
        if (dispositivos.isNotEmpty) {
          dispositivoSelecionado = dispositivos.first;
          _carregarDadosHistorico();
        } else {
          isLoading = false;
        }
      });
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
      _mostrarErro('Erro ao carregar dispositivos: $e');
    }
  }

  Future<void> _carregarDadosHistorico() async {
    if (dispositivoSelecionado == null) return;

    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      // Buscar dados de consumo do dispositivo no intervalo de datas
      final readingsSnapshot = await _firestore
          .collection('users') // Mudou para 'users'
          .doc(widget.userId)
          .collection('sensors') // Mudou para 'sensors'
          .doc(dispositivoSelecionado)
          .collection('readings') // Mudou de 'historico' para 'readings'
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: dataInicio.millisecondsSinceEpoch,
          )
          .where(
            'timestamp',
            isLessThanOrEqualTo: dataFim.millisecondsSinceEpoch,
          )
          .orderBy('timestamp')
          .get();

      // Agrupar dados por dia e calcular média/soma
      final Map<String, List<double>> dadosPorDia = {};

      for (var doc in readingsSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as num)
            .toInt(); // Nota: é number, não Timestamp
        final timestampDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dataKey = DateFormat('dd/MM').format(timestampDate);

        double valor = 0;
        switch (medidaSelecionada) {
          case 'energia':
            valor =
                (data['energy'] as num?)?.toDouble() ??
                0; // Mudou para 'energy'
            break;
          case 'potencia':
            valor =
                (data['power'] as num?)?.toDouble() ?? 0; // Mudou para 'power'
            break;
        }

        if (!dadosPorDia.containsKey(dataKey)) {
          dadosPorDia[dataKey] = [];
        }
        dadosPorDia[dataKey]!.add(valor);
      }

      // Calcular média por dia
      final List<ChartData> novosdados = [];
      dadosPorDia.forEach((data, valores) {
        final media = valores.reduce((a, b) => a + b) / valores.length;
        novosdados.add(ChartData(data: data, valor: media));
      });

      setState(() {
        dadosGrafico = novosdados;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
      _mostrarErro('Erro ao carregar histórico: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Histórico',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown Dispositivo
            _buildDropdown(
              label: dispositivoSelecionado ?? 'Selecione um dispositivo',
              items: dispositivos,
              onChanged: (value) {
                setState(() {
                  dispositivoSelecionado = value;
                });
                _carregarDadosHistorico();
              },
            ),
            const SizedBox(height: 16),
            // Selecionar Medida
            const Text(
              'Selecionar Medida',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildDropdown(
              label: _getMedidaLabel(medidaSelecionada),
              items: const ['energia', 'potencia'],
              itemLabels: const {
                'energia': 'Energia (kWh)',
                'potencia': 'Potência (W)',
              },
              onChanged: (value) {
                setState(() {
                  medidaSelecionada = value!;
                });
                _carregarDadosHistorico();
              },
            ),
            const SizedBox(height: 24),
            // Seleção de datas
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    label: _formatDate(dataInicio),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dataInicio,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          dataInicio = picked;
                        });
                        _carregarDadosHistorico();
                      }
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('-', style: TextStyle(fontSize: 18)),
                ),
                Expanded(
                  child: _buildDatePicker(
                    label: _formatDate(dataFim),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dataFim,
                        firstDate: dataInicio,
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          dataFim = picked;
                        });
                        _carregarDadosHistorico();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Gráfico
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(height: 250, child: _buildChartWidget()),
            ),
            const SizedBox(height: 32),
            // Botão Exportar PDF
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _exportarPDF,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text(
                  'Exportar PDF',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartWidget() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      );
    }

    if (hasError || dadosGrafico.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              hasError
                  ? 'Erro ao carregar dados'
                  : 'Sem dados para o período selecionado',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (hasError)
              TextButton(
                onPressed: _carregarDadosHistorico,
                child: const Text('Tentar novamente'),
              ),
          ],
        ),
      );
    }

    return _buildChart();
  }

  Widget _buildChart() {
    if (dadosGrafico.isEmpty) {
      return const Center(child: Text('Sem dados'));
    }

    final maxY =
        dadosGrafico.map((e) => e.valor).reduce((a, b) => a > b ? a : b) * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: false,
        ), // Desativa o tooltip temporariamente
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < dadosGrafico.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      dadosGrafico[value.toInt()].data,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
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
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: dadosGrafico.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.valor,
                color: const Color(0xFF1F6036),
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required List<String> items,
    Map<String, String>? itemLabels,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: items.contains(label) ? label : null,
        hint: Text(label),
        isExpanded: true,
        underline: const SizedBox(),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(itemLabels?[value] ?? value),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'DD/MM/YYYY',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getMedidaLabel(String medida) {
    switch (medida) {
      case 'energia':
        return 'Energia (kWh)';
      case 'potencia':
        return 'Potência (W)';
      case 'corrente':
        return 'Corrente (A)';
      default:
        return 'Selecione uma medida';
    }
  }

  // ignore: unused_element
  String _getUnidade() {
    switch (medidaSelecionada) {
      case 'energia':
        return 'kWh';
      case 'potencia':
        return 'W';
      case 'corrente':
        return 'A';
      default:
        return '';
    }
  }

  Future<void> _exportarPDF() async {
    if (dispositivoSelecionado == null) {
      _mostrarErro('Selecione um dispositivo primeiro');
      return;
    }

    try {
      setState(() => isLoading = true);

      // 1) Buscar os readings do Firestore (mesmo filtro de datas)
      final readingsSnapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('sensors')
          .doc(dispositivoSelecionado)
          .collection('readings')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: dataInicio.millisecondsSinceEpoch,
          )
          .where(
            'timestamp',
            isLessThanOrEqualTo: dataFim.millisecondsSinceEpoch,
          )
          .orderBy('timestamp')
          .get();

      if (readingsSnapshot.docs.isEmpty) {
        setState(() => isLoading = false);
        _mostrarErro('Não há dados para exportar neste período.');
        return;
      }

      // 2) Converter para uma lista de linhas (timestamp, power, energy)
      final List<List<String>> linhas = [
        ['Data/Hora', 'Potência (W)', 'Energia (kWh)'],
      ];

      for (var doc in readingsSnapshot.docs) {
        final data = doc.data();
        final ts = (data['timestamp'] as num).toInt();
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        final power = (data['power'] as num?)?.toDouble() ?? 0;
        final energy = (data['energy'] as num?)?.toDouble() ?? 0;

        linhas.add([
          DateFormat('dd/MM/yyyy HH:mm').format(dt),
          power.toStringAsFixed(2),
          energy.toStringAsFixed(4),
        ]);
      }

      // 3) Criar o documento PDF
      final pdf = pw.Document();

      final medidaLabel = _getMedidaLabel(medidaSelecionada);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Relatório de Consumo',
                style: const pw.TextStyle(fontSize: 22),
              ),
            ),
            pw.Paragraph(
              text:
                  'Dispositivo: $dispositivoSelecionado\nMedida selecionada: $medidaLabel\nPeríodo: ${_formatDate(dataInicio)} a ${_formatDate(dataFim)}',
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: linhas.first,
              data: linhas.sublist(1),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              cellAlignment: pw.Alignment.centerRight,
            ),
          ],
        ),
      );

      // 4) Mostrar diálogo de impressão / guardar ficheiro
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      _mostrarErro('Erro ao exportar PDF: $e');
    }
  }
}

class ChartData {
  final String data;
  final double valor;

  ChartData({required this.data, required this.valor});
}
