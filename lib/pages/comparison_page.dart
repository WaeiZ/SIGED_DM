//Martim Santos - 22309746
//Sérgio Dias - 22304791

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
  String medidaSelecionada = 'energia'; // energia, potencia
  DateTime dataInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime dataFim = DateTime.now();

  List<String> dispositivos = [];
  Map<String, String> dispositivoMap = {};
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
          .collection('users')
          .doc(widget.userId)
          .collection('sensors')
          .get();

      // Cria um Map com description → id
      final Map<String, String> sensorMap = {};
      for (var doc in sensoresSnapshot.docs) {
        final data = doc.data();
        final description = data['description'] ?? doc.id;
        sensorMap[description] = doc.id; // "Sala" → "Sensor1"
      }

      setState(() {
        dispositivoMap = sensorMap;
        dispositivos = sensorMap.keys.toList();
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

      // Converte description → id real
      final sensorId = dispositivoMap[dispositivoSelecionado]!;

      // Buscar dados de consumo do dispositivo no intervalo de datas
      final readingsSnapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('sensors')
          .doc(sensorId)
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

      // Agrupar dados por dia e calcular média
      final Map<String, List<double>> dadosPorDia = {};

      for (var doc in readingsSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as num).toInt();
        final timestampDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dataKey = DateFormat('dd/MM').format(timestampDate);

        double valor = 0;
        switch (medidaSelecionada) {
          case 'energia':
            valor = (data['energy'] as num?)?.toDouble() ?? 0;
            break;
          case 'potencia':
            valor = (data['power'] as num?)?.toDouble() ?? 0;
            break;
        }

        dadosPorDia.putIfAbsent(dataKey, () => []);
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

  // ------------------ FUNÇÕES DE ESTATÍSTICA ------------------

  double? _calcularMedia(List<double> valores) {
    if (valores.isEmpty) return null;
    final soma = valores.reduce((a, b) => a + b);
    return soma / valores.length;
  }

  double? _calcularMediana(List<double> valores) {
    if (valores.isEmpty) return null;
    final lista = List<double>.from(valores)..sort();
    final meio = lista.length ~/ 2;

    if (lista.length.isOdd) {
      return lista[meio];
    } else {
      return (lista[meio - 1] + lista[meio]) / 2;
    }
  }

  double? _calcularModa(List<double> valores) {
    if (valores.isEmpty) return null;

    final frequencias = <double, int>{};

    for (final v in valores) {
      // arredondar para evitar diferenças mínimas de casas decimais
      final chave = double.parse(v.toStringAsFixed(2));
      frequencias[chave] = (frequencias[chave] ?? 0) + 1;
    }

    double moda = frequencias.keys.first;
    int maxFreq = frequencias[moda]!;

    frequencias.forEach((valor, freq) {
      if (freq > maxFreq) {
        maxFreq = freq;
        moda = valor;
      }
    });

    return moda;
  }

  /// Média móvel simples: devolve só a ÚLTIMA média móvel
  double? _ultimaMediaMovel(List<double> valores, int janela) {
    if (valores.isEmpty) return null;
    if (janela <= 0) return null;

    if (valores.length < janela) {
      janela = valores.length;
    }

    double soma = 0;
    for (int i = valores.length - janela; i < valores.length; i++) {
      soma += valores[i];
    }

    return soma / janela;
  }

  // ------------------------------------------------------------

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
        backgroundColor: const Color(0xFF1F6036),
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
              // IMPORTANTE: aqui o label tem de bater certo com os "items"
              label: medidaSelecionada,
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
                  backgroundColor: const Color(0xFF1F6036),
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
        child: CircularProgressIndicator(color: Color(0xFF1F6036)),
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
        barTouchData: BarTouchData(enabled: false),
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
        hint: Text(itemLabels?[label] ?? label),
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

      final sensorId = dispositivoMap[dispositivoSelecionado]!;

      // 1) Buscar todos os readings
      final readingsSnapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('sensors')
          .doc(sensorId)
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

      // 2) Preparar dados
      final List<String> headers = [
        'Data/Hora',
        'Potência (W)',
        'Energia (kWh)',
      ];

      final List<List<String>> dadosTabela = [];
      final List<double> valoresPotencia = [];
      final List<double> valoresEnergia = [];

      for (var doc in readingsSnapshot.docs) {
        final data = doc.data();
        final ts = (data['timestamp'] as num).toInt();
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        final power = (data['power'] as num?)?.toDouble() ?? 0;
        final energy = (data['energy'] as num?)?.toDouble() ?? 0;

        dadosTabela.add([
          DateFormat('dd/MM/yyyy HH:mm').format(dt),
          power.toStringAsFixed(2),
          energy.toStringAsFixed(4),
        ]);

        valoresPotencia.add(power);
        valoresEnergia.add(energy);
      }

      // TOTAL DE ENERGIA (kWh) NO PERÍODO
      // Robusto a resets: soma apenas incrementos positivos (energy cumulativo)
      double totalEnergiaKWh = 0;

      if (valoresEnergia.length >= 2) {
        for (int i = 1; i < valoresEnergia.length; i++) {
          final diff = valoresEnergia[i] - valoresEnergia[i - 1];
          if (diff > 0) totalEnergiaKWh += diff;
        }
      }

      // -----------------------------------------------------------

      const int maxLinhasPDF = 500;
      final bool dadosForamCortados = dadosTabela.length > maxLinhasPDF;

      final List<List<String>> dadosParaImprimir = dadosForamCortados
          ? dadosTabela.take(maxLinhasPDF).toList()
          : dadosTabela;

      // 2.1) Calcular estatísticas
      const janelaMediaMovel = 5;
      final mediaPot = _calcularMedia(valoresPotencia);
      final medianaPot = _calcularMediana(valoresPotencia);
      final modaPot = _calcularModa(valoresPotencia);
      final mediaMovelPot = _ultimaMediaMovel(
        valoresPotencia,
        janelaMediaMovel,
      );

      final mediaEner = _calcularMedia(valoresEnergia);
      final medianaEner = _calcularMediana(valoresEnergia);
      final modaEner = _calcularModa(valoresEnergia);
      final mediaMovelEner = _ultimaMediaMovel(
        valoresEnergia,
        janelaMediaMovel,
      );

      String formatNum(double? v, int decimals) {
        if (v == null) return '-';
        return v.toStringAsFixed(decimals);
      }

      // 3) Criar o documento PDF
      final pdf = pw.Document();
      final medidaLabel = _getMedidaLabel(medidaSelecionada);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Relatório de Consumo',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Paragraph(
              text:
                  'Dispositivo: $dispositivoSelecionado\n'
                  'Medida selecionada: $medidaLabel\n'
                  'Período: ${_formatDate(dataInicio)} a ${_formatDate(dataFim)}\n'
                  'Total de registos encontrados: ${dadosTabela.length}\n'
                  'Total de energia no período: ${totalEnergiaKWh.toStringAsFixed(4)} kWh',
            ),
            pw.SizedBox(height: 16),

            // Tabela Limitada
            pw.Table.fromTextArray(
              headers: headers,
              data: dadosParaImprimir,
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

            if (dadosForamCortados)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10),
                child: pw.Text(
                  "ATENÇÃO: Devido ao grande volume de dados, apenas as primeiras $maxLinhasPDF linhas foram listadas acima para permitir a exportação do PDF. As estatísticas abaixo consideram TODOS os registos.",
                  style: const pw.TextStyle(color: PdfColors.red, fontSize: 10),
                ),
              ),

            pw.SizedBox(height: 24),

            // Estatísticas
            pw.Text(
              'Estatísticas (Baseadas em todos os ${dadosTabela.length} registos)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Potência (W)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Média: ${formatNum(mediaPot, 2)}'),
                      pw.Text('Mediana: ${formatNum(medianaPot, 2)}'),
                      pw.Text('Moda: ${formatNum(modaPot, 2)}'),
                      pw.Text(
                        'Média móvel (5): ${formatNum(mediaMovelPot, 2)}',
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Energia (kWh)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Média: ${formatNum(mediaEner, 4)}'),
                      pw.Text('Mediana: ${formatNum(medianaEner, 4)}'),
                      pw.Text('Moda: ${formatNum(modaEner, 4)}'),
                      pw.Text(
                        'Média móvel (5): ${formatNum(mediaMovelEner, 4)}',
                      ),
                      pw.SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

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
