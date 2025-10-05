// lib/models/report_data.dart

class MonthlySummary {
  final double ingresos;
  final double gastos;
  final double balance;
  final String mes;
  final String nombreMes;

  MonthlySummary({
    required this.ingresos,
    required this.gastos,
    required this.balance,
    required this.mes,
    required this.nombreMes,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      ingresos: (json['ingresos'] as num).toDouble(),
      gastos: (json['gastos'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      mes: json['mes'] as String,
      nombreMes: json['nombre_mes'] as String,
    );
  }
}

class TrendData {
  final String mes;
  final String mesFull;
  final int year;
  final double ingresos;
  final double gastos;

  TrendData({
    required this.mes,
    required this.mesFull,
    required this.year,
    required this.ingresos,
    required this.gastos,
  });

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      mes: json['mes'] as String,
      mesFull: json['mes_full'] as String,
      year: json['year'] as int,
      ingresos: (json['ingresos'] as num).toDouble(),
      gastos: (json['gastos'] as num).toDouble(),
    );
  }
}

class BudgetCompliance {
  final int id;
  final String categoriaNombre;
  final double presupuestoMonto;
  final double gastoMonto;
  final double restante;
  final double porcentajeUsado;

  BudgetCompliance({
    required this.id,
    required this.categoriaNombre,
    required this.presupuestoMonto,
    required this.gastoMonto,
    required this.restante,
    required this.porcentajeUsado,
  });

  factory BudgetCompliance.fromJson(Map<String, dynamic> json) {
    return BudgetCompliance(
      id: json['id'] as int,
      categoriaNombre: json['categoria_nombre'] as String,
      presupuestoMonto: (json['presupuesto_monto'] as num).toDouble(),
      gastoMonto: (json['gasto_monto'] as num).toDouble(),
      restante: (json['restante'] as num).toDouble(),
      porcentajeUsado: (json['porcentaje_usado'] as num).toDouble(),
    );
  }
}

class ReportData {
  final MonthlySummary summary;
  final List<TrendData> trend;
  final List<BudgetCompliance> budgets;

  ReportData({
    required this.summary,
    required this.trend,
    required this.budgets,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      summary: MonthlySummary.fromJson(json['summary']),
      trend: (json['trend'] as List).map((i) => TrendData.fromJson(i)).toList(),
      budgets: (json['budgets'] as List).map((i) => BudgetCompliance.fromJson(i)).toList(),
    );
  }
}