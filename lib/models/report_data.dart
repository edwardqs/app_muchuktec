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
  final String categoriaTipo; // <-- NUEVO: 'gasto' o 'ingreso'
  final double presupuestoMonto;
  final double montoAlcanzado; // <-- CAMBIO DE NOMBRE (era gastoMonto)
  final double porcentajeAlcanzado; // <-- CAMBIO DE NOMBRE (era porcentajeUsado)
  final double restante;

  BudgetCompliance({
    required this.id,
    required this.categoriaNombre,
    required this.categoriaTipo, // <-- NUEVO
    required this.presupuestoMonto,
    required this.montoAlcanzado, // <-- CAMBIO
    required this.porcentajeAlcanzado, // <-- CAMBIO
    required this.restante,
  });

  factory BudgetCompliance.fromJson(Map<String, dynamic> json) {
    return BudgetCompliance(
      id: json['id'],
      categoriaNombre: json['categoria_nombre'] ?? 'Sin Categoría',
      categoriaTipo: json['categoria_tipo'] ?? 'gasto', // <-- NUEVO (default a gasto si falta)
      presupuestoMonto: (json['presupuesto_monto'] as num?)?.toDouble() ?? 0.0,
      montoAlcanzado: (json['monto_alcanzado'] as num?)?.toDouble() ?? 0.0, // <-- CAMBIO
      porcentajeAlcanzado: (json['porcentaje_alcanzado'] as num?)?.toDouble() ?? 0.0, // <-- CAMBIO
      restante: (json['restante'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CommitmentPayment {
  final int id;
  final double monto;
  final DateTime fechaPago;
  final String tipoMovimiento; // 'pago_gasto' o 'pago_ingreso'
  final String compromisoNombre;
  final int? cuotaNumero; // Puede ser nulo

  CommitmentPayment({
    required this.id,
    required this.monto,
    required this.fechaPago,
    required this.tipoMovimiento,
    required this.compromisoNombre,
    this.cuotaNumero,
  });

  factory CommitmentPayment.fromJson(Map<String, dynamic> json) {
    // Manejo de relaciones que pueden ser nulas
    final compromiso = json['compromiso'] as Map<String, dynamic>?;
    final cuota = json['cuota_compromiso'] as Map<String, dynamic>?;

    return CommitmentPayment(
      id: json['id'] as int,
      monto: (json['monto'] as num).toDouble(),
      fechaPago: DateTime.parse(json['fecha_pago']),
      tipoMovimiento: json['tipo_movimiento'] ?? 'desconocido',
      compromisoNombre: compromiso?['nombre'] ?? 'Compromiso Eliminado',
      cuotaNumero: cuota?['numero_cuota'] as int?,
    );
  }
}
class ReportData {
  final MonthlySummary summary;
  final List<TrendData> trend;
  final List<BudgetCompliance> budgets;
  final List<CommitmentPayment> commitmentPayments; // <-- AÑADIDO

  ReportData({
    required this.summary,
    required this.trend,
    required this.budgets,
    required this.commitmentPayments, // <-- AÑADIDO
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      summary: MonthlySummary.fromJson(json['summary']),
      trend: (json['trend'] as List)
          .map((i) => TrendData.fromJson(i))
          .toList(),
      budgets: (json['budgets'] as List)
          .map((i) => BudgetCompliance.fromJson(i))
          .toList(),
      // <-- AÑADIDO
      commitmentPayments: (json['commitmentPayments'] as List)
          .map((i) => CommitmentPayment.fromJson(i))
          .toList(),
    );
  }
}