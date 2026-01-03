// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/report_service.dart';
import '../models/report_data.dart';
import 'package:app_muchik/widgets/ad_banner_widget.dart';

// Formateador de moneda
final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_PE', symbol: 'S/');

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);
  final Color cRojo = const Color(0xFFE76F51);

  final ReportService _reportService = ReportService();
  final int _selectedIndex = 1;
  late Future<ReportData> _reportsFuture;

  // Estado para el filtro de mes/año
  DateTime _selectedDate = DateTime.now();
  String? _fatalError;

  @override
  void initState() {
    super.initState();

    _reportsFuture = Future.value(ReportData(
      summary: MonthlySummary(ingresos: 0, gastos: 0, balance: 0, mes: 'n/a', nombreMes: 'Cargando...'),
      trend: [],
      budgets: [],
      commitmentPayments: [],
    ));
    _checkAuthAndLoadReports();
  }

  Future<void> _checkAuthAndLoadReports() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString('accessToken');
    final int? idCuenta = prefs.getInt('idCuenta');

    if (accessToken == null) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
      return;
    }

    if (idCuenta == null) {
      if (mounted) {
        setState(() {
          _fatalError = 'ERROR: No se ha seleccionado una cuenta. Por favor, seleccione una en "Ajustes".';
        });
      }
      return;
    }

    _loadReports();
  }

  void _loadReports() {
    if (_fatalError != null) return;

    setState(() {
      _reportsFuture = _reportService.fetchReports(
        month: _selectedDate.month,
        year: _selectedDate.year,
      );
    });
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/budgets');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/categories');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('es', 'ES'),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: cVerdeMenta,
            colorScheme: ColorScheme.light(primary: cVerdeMenta, onPrimary: cBlanco),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && (picked.month != _selectedDate.month || picked.year != _selectedDate.year)) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReports();
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cBlanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: cAzulPetroleo),
                title: const Text('Exportar a PDF'),
                onTap: () {
                  Navigator.pop(bc);
                  _exportReport('pdf');
                },
              ),
              ListTile(
                leading: Icon(Icons.insert_drive_file, color: cVerdeMenta),
                title: const Text('Exportar a Hoja de Cálculo (Excel)'),
                onTap: () {
                  Navigator.pop(bc);
                  _exportReport('excel');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _exportReport(String format) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descargando reporte en $format...'),
        backgroundColor: cAzulPetroleo,
      ),
    );
    try {
      await _reportService.exportReports(
        format,
        month: _selectedDate.month,
        year: _selectedDate.year,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reporte guardado en la carpeta de Descargas.'),
          backgroundColor: cVerdeMenta,
          duration: const Duration(seconds: 4),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cGrisClaro,
      appBar: AppBar(
        backgroundColor: cGrisClaro,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cAzulPetroleo),
          onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        title: Text(
          'Reportes',
          style: TextStyle(
            color: cAzulPetroleo,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share, color: cAzulPetroleo),
            onPressed: _showExportOptions,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: cBlanco,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Center(child: AdBannerWidget()),
          ),
          _buildBottomNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_fatalError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_fatalError!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
        ),
      );
    }

    return FutureBuilder<ReportData>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: cVerdeMenta));
        } else if (snapshot.hasError) {
          final errorText = snapshot.error.toString().replaceFirst('Exception: ', '');

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar reportes: $errorText',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadReports,
                    child: Text('Reintentar', style: TextStyle(color: cVerdeMenta)),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasData) {
          final reportData = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _MonthSelector(
                  selectedDate: _selectedDate,
                  onTap: () => _selectMonth(context),
                  color: cAzulPetroleo,
                ),
                const SizedBox(height: 20),
                MonthlySummaryCard(
                  summary: reportData.summary,
                  cAzulPetroleo: cAzulPetroleo,
                ),
                const SizedBox(height: 24),

                MonthlyTrendChart(
                  trendData: reportData.trend,
                  cAzulPetroleo: cAzulPetroleo,
                  cVerdeMenta: cVerdeMenta,
                  cRojo: cRojo,
                ),

                const SizedBox(height: 24),
                BudgetComplianceCard(budgets: reportData.budgets, cAzulPetroleo: cAzulPetroleo),
                const SizedBox(height: 24),
                CommitmentPaymentsCard(payments: reportData.commitmentPayments, cAzulPetroleo: cAzulPetroleo),
              ],
            ),
          );
        } else {
          return Center(child: Text('No hay datos de reportes disponibles.', style: TextStyle(color: cAzulPetroleo)));
        }
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: cBlanco,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: cBlanco,
        selectedItemColor: cAzulPetroleo, // Color Oficial Activo
        unselectedItemColor: Colors.grey[400],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Reportes'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Presupuestos'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categorías'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGETS AUXILIARES
// -----------------------------------------------------------------------------

class _MonthSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onTap;
  final Color color;

  const _MonthSelector({required this.selectedDate, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMMM yyyy', 'es_ES').format(selectedDate).toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: color),
          ],
        ),
      ),
    );
  }
}

class MonthlySummaryCard extends StatelessWidget {
  final MonthlySummary summary;
  final Color cAzulPetroleo;

  const MonthlySummaryCard({super.key, required this.summary, required this.cAzulPetroleo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen Mensual',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cAzulPetroleo,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryItem(
                label: 'Ingresos',
                value: currencyFormat.format(summary.ingresos),
                color: Colors.green[600]!,
              ),
              _SummaryItem(
                label: 'Gastos',
                value: currencyFormat.format(summary.gastos),
                color: Colors.red[600]!,
              ),
              _SummaryItem(
                label: 'Balance',
                value: currencyFormat.format(summary.balance),
                color: summary.balance >= 0 ? cAzulPetroleo : Colors.red[600]!,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class MonthlyTrendChart extends StatelessWidget {
  final List<TrendData> trendData;
  final Color cAzulPetroleo;
  final Color cVerdeMenta;
  final Color cRojo;

  const MonthlyTrendChart({
    super.key,
    required this.trendData,
    required this.cAzulPetroleo,
    required this.cVerdeMenta,
    required this.cRojo,
  });

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: cAzulPetroleo),
              const SizedBox(width: 10),
              Text('Acerca del Gráfico', style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Este gráfico muestra la evolución de tus finanzas en los últimos 6 meses.',
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                  children: [
                    const TextSpan(text: '• '),
                    TextSpan(text: 'Ingresos: ', style: TextStyle(fontWeight: FontWeight.bold, color: cVerdeMenta)),
                    const TextSpan(text: 'Suma de todos tus ingresos registrados + préstamos recibidos.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.grey[800], fontSize: 14),
                  children: [
                    const TextSpan(text: '• '),
                    TextSpan(text: 'Gastos: ', style: TextStyle(fontWeight: FontWeight.bold, color: cRojo)),
                    const TextSpan(text: 'Suma de todos tus gastos (presupuestos) + pagos de deudas realizados.'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Entendido', style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    for (var data in trendData) {
      if (data.ingresos > maxY) maxY = data.ingresos;
      if (data.gastos > maxY) maxY = data.gastos;
    }
    maxY = maxY == 0 ? 100 : maxY * 1.2;
    double interval = maxY / 4;

    final List<FlSpot> ingresosSpots = [];
    final List<FlSpot> gastosSpots = [];

    for (int i = 0; i < trendData.length; i++) {
      ingresosSpots.add(FlSpot(i.toDouble(), trendData[i].ingresos));
      gastosSpots.add(FlSpot(i.toDouble(), trendData[i].gastos));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tendencia (Últimos 6 meses)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cAzulPetroleo,
                  ),
                ),
                InkWell(
                  onTap: () => _showInfoDialog(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.info_outline, color: Colors.grey[400], size: 22),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade100,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text('Meses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cAzulPetroleo.withOpacity(0.6))),
                    axisNameSize: 22,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < trendData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              trendData[index].mes,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text('Monto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cAzulPetroleo.withOpacity(0.6))),
                    axisNameSize: 22,
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          NumberFormat.compact(locale: 'en_US').format(value),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (trendData.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,

                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: cAzulPetroleo,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final flSpot = barSpot;
                        final bool isIncome = barSpot.barIndex == 0;
                        return LineTooltipItem(
                          '${isIncome ? "Ingreso" : "Gasto"}: \n',
                          TextStyle(
                            color: isIncome ? cVerdeMenta : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: currencyFormat.format(flSpot.y),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),

                lineBarsData: [
                  LineChartBarData(
                    spots: ingresosSpots,
                    isCurved: true,
                    color: cVerdeMenta,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: cVerdeMenta,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: cVerdeMenta.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: gastosSpots,
                    isCurved: true,
                    color: cRojo,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: cRojo,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: cRojo.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: cVerdeMenta, text: 'Ingresos'),
              const SizedBox(width: 24),
              _LegendItem(color: cRojo, text: 'Gastos'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class BudgetComplianceCard extends StatelessWidget {
  final List<BudgetCompliance> budgets;
  final Color cAzulPetroleo;

  const BudgetComplianceCard({super.key, required this.budgets, required this.cAzulPetroleo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cumplimiento de Presupuestos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cAzulPetroleo,
            ),
          ),
          const SizedBox(height: 20),

          if (budgets.isEmpty)
            Center(child: Text('No hay presupuestos activos para este mes.', style: TextStyle(color: Colors.grey[600])))
          else
            ...budgets.map((budget) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _DynamicBudgetItem(budget: budget, cAzulPetroleo: cAzulPetroleo),
            )).toList(),
        ],
      ),
    );
  }
}

class _DynamicBudgetItem extends StatelessWidget {
  final BudgetCompliance budget;
  final Color cAzulPetroleo;

  const _DynamicBudgetItem({required this.budget, required this.cAzulPetroleo});

  @override
  Widget build(BuildContext context) {
    final bool isIncome = budget.categoriaTipo == 'ingreso';

    Color amountColor;
    Color progressColor;
    String remainingLabel;
    double progressValue = budget.presupuestoMonto > 0 ? (budget.montoAlcanzado / budget.presupuestoMonto) : 0;

    if (isIncome) {
      amountColor = Colors.green.shade600;
      progressColor = Colors.green.shade600;
      if (budget.montoAlcanzado >= budget.presupuestoMonto) {
        remainingLabel = 'Meta superada en ${currencyFormat.format(budget.montoAlcanzado - budget.presupuestoMonto)}';
      } else {
        remainingLabel = '${(budget.porcentajeAlcanzado).toStringAsFixed(0)}%. Queda ${currencyFormat.format(budget.restante)}';
      }
      progressValue = (progressValue > 1.0) ? 1.0 : progressValue;

    } else {
      final bool isOverBudget = budget.restante < 0;
      amountColor = isOverBudget ? Colors.red.shade600 : cAzulPetroleo;
      progressColor = isOverBudget ? Colors.red.shade600 : const Color(0xFF2A9D8F); // Verde menta
      if (isOverBudget) {
        remainingLabel = 'Excedido en ${currencyFormat.format(budget.restante.abs())}';
      } else {
        double remainingPercentage = budget.presupuestoMonto > 0 ? (budget.restante / budget.presupuestoMonto * 100) : 0;
        remainingLabel = '${remainingPercentage.toStringAsFixed(0)}%. Queda ${currencyFormat.format(budget.restante)}';
      }
      progressValue = (progressValue > 1.0) ? 1.0 : progressValue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              budget.categoriaNombre,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              currencyFormat.format(budget.montoAlcanzado),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Presupuesto: ${currencyFormat.format(budget.presupuestoMonto)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              remainingLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: amountColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progressValue,
          backgroundColor: Colors.grey.shade200,
          color: progressColor,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class CommitmentPaymentsCard extends StatelessWidget {
  final List<CommitmentPayment> payments;
  final Color cAzulPetroleo;

  const CommitmentPaymentsCard({super.key, required this.payments, required this.cAzulPetroleo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pagos de Compromisos del Mes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cAzulPetroleo,
            ),
          ),
          const SizedBox(height: 20),
          if (payments.isEmpty)
            Center(child: Text('No se realizaron pagos de compromisos este mes.', style: TextStyle(color: Colors.grey[600])))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                return _PaymentItem(payment: payments[index]);
              },
              separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
            ),
        ],
      ),
    );
  }
}

class _PaymentItem extends StatelessWidget {
  final CommitmentPayment payment;

  const _PaymentItem({required this.payment});

  @override
  Widget build(BuildContext context) {
    final bool isIncome = payment.esIngreso;

    final Color amountColor = isIncome ? Colors.green[600]! : Colors.red[600]!;
    final String sign = isIncome ? '+' : '-';

    String subtitle;
    if (payment.cuotaNumero != null) {
      subtitle = 'Cta. N° ${payment.cuotaNumero}: ${payment.compromisoNombre}';
    } else {
      subtitle = payment.compromisoNombre;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: amountColor.withOpacity(0.1),
        child: Icon(
          isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, // <-- CORREGIDO AQUÍ
          color: amountColor,
          size: 20,
        ),
      ),
      title: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormat('dd MMM, yyyy', 'es_ES').format(payment.fechaPago),
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Text(
        '$sign${currencyFormat.format(payment.monto)}',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
    );
  }
}