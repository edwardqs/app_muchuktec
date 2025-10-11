// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/report_service.dart';
import '../models/report_data.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Formateador de moneda
final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_PE', symbol: 'S/');

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();
  final int _selectedIndex = 1;
  late Future<ReportData> _reportsFuture;

  // Estado para el filtro de mes/año
  DateTime _selectedDate = DateTime.now();
  String? _fatalError;

  @override
  void initState() {
    super.initState();
    // Inicialización para evitar LateInitializationError
    _reportsFuture = Future.value(ReportData(summary: MonthlySummary(ingresos: 0, gastos: 0, balance: 0, mes: 'n/a', nombreMes: 'Cargando...'), trend: [], budgets: []));

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
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Exportar a PDF'),
                onTap: () {
                  Navigator.pop(bc);
                  _exportReport('pdf');
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
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
    // Muestra un indicador de que la descarga ha comenzado
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargando reporte en $format...')),
    );
    try {
      // Llamamos a nuestro nuevo método que guarda el archivo
      final String filePath = await _reportService.exportReports(format);

      // Si todo fue bien, mostramos un mensaje de éxito con la ubicación
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reporte guardado en la carpeta de Descargas.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
              label: 'VER RUTA',
              onPressed: () {
                // Opcional: Imprime la ruta completa en la consola para depuración
                print('Archivo guardado en: $filePath');
              }
          ),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        title: const Text(
          'Reportes',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.black87),
            onPressed: _showExportOptions,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
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
          return const Center(child: CircularProgressIndicator());
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
                    child: const Text('Reintentar', style: TextStyle(color: Colors.purple)),
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
                ),
                const SizedBox(height: 20),
                MonthlySummaryCard(summary: reportData.summary),
                const SizedBox(height: 24),
                MonthlyTrendChart(trendData: reportData.trend),
                const SizedBox(height: 24),
                BudgetComplianceCard(budgets: reportData.budgets),
              ],
            ),
          );
        } else {
          return const Center(child: Text('No hay datos de reportes disponibles.'));
        }
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.purple[700],
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Presupuestos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            activeIcon: Icon(Icons.category),
            label: 'Categorías',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

}

// -----------------------------------------------------------------------------
// WIDGETS AUXILIARES (Los he dejado igual ya que solo contienen UI/Chart Logic)
// -----------------------------------------------------------------------------

class _MonthSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onTap;

  const _MonthSelector({required this.selectedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.purple[700]),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMMM yyyy', 'es_ES').format(selectedDate),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: Colors.purple[700]),
          ],
        ),
      ),
    );
  }
}

class MonthlySummaryCard extends StatelessWidget {
  final MonthlySummary summary;

  const MonthlySummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen Mensual (${summary.nombreMes})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                color: summary.balance >= 0 ? Colors.blue[600]! : Colors.red[600]!,
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
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
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

  const MonthlyTrendChart({super.key, required this.trendData});

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    for (var data in trendData) {
      if (data.ingresos > maxY) maxY = data.ingresos;
      if (data.gastos > maxY) maxY = data.gastos;
    }

    double interval = maxY / 4;
    if (maxY == 0) {
      maxY = 100.0;
      interval = 25.0;
    } else {
      maxY = maxY * 1.1;
      interval = maxY / 4;
    }

    final List<FlSpot> ingresosSpots = trendData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.ingresos);
    }).toList();

    final List<FlSpot> gastosSpots = trendData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.gastos);
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10.0),
            child: Text(
              'Tendencia Mensual (Ingresos vs. Gastos)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(reservedSize: 0)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(reservedSize: 0)),

                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= trendData.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            trendData[value.toInt()].mesFull,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        );
                      },
                      interval: 1,
                    ),
                  ),

                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value == 0 ? '0' : currencyFormat.format(value).replaceAll('S/', '').split(',').first,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                          textAlign: TextAlign.left,
                        );
                      },
                      interval: interval,
                    ),
                  ),

                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                minX: 0,
                maxX: trendData.length.toDouble() - 1,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: ingresosSpots,
                    isCurved: true,
                    color: Colors.green.shade600,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: gastosSpots,
                    isCurved: true,
                    color: Colors.red.shade600,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Leyenda
          Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: Colors.green.shade600, text: 'Ingresos'),
                const SizedBox(width: 20),
                _LegendItem(color: Colors.red.shade600, text: 'Gastos'),
              ],
            ),
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
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class BudgetComplianceCard extends StatelessWidget {
  final List<BudgetCompliance> budgets;

  const BudgetComplianceCard({super.key, required this.budgets});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cumplimiento de Presupuestos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          if (budgets.isEmpty)
            const Center(child: Text('No hay presupuestos activos para este mes.'))
          else
            ...budgets.map((budget) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _DynamicBudgetItem(budget: budget),
            )).toList(),
        ],
      ),
    );
  }
}

class _DynamicBudgetItem extends StatelessWidget {
  final BudgetCompliance budget;

  const _DynamicBudgetItem({required this.budget});

  @override
  Widget build(BuildContext context) {
    final bool isOverBudget = budget.restante < 0;
    final Color spentColor = isOverBudget ? Colors.red.shade600! : Colors.green.shade600!;
    final Color progressColor = isOverBudget ? Colors.red.shade600! : Colors.purple.shade700!;
    final String remainingText = isOverBudget
        ? 'Excedido en ${currencyFormat.format(budget.restante.abs())}'
        : '${(budget.restante * 100 / budget.presupuestoMonto).toStringAsFixed(0)}% restante (${currencyFormat.format(budget.restante)})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              budget.categoriaNombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              currencyFormat.format(budget.gastoMonto),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: spentColor,
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
              remainingText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isOverBudget ? Colors.red.shade600 : Colors.green.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Barra de progreso
        LinearProgressIndicator(
          value: budget.porcentajeUsado / 100.0,
          backgroundColor: Colors.grey.shade200,
          color: progressColor,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}