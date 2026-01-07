// lib/models/report_data.dart
import 'dart:convert';
double _parseDouble(dynamic value) {
  if (value == null) {
    return 0.0;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}
// --- FIN FUNCIÓN AUXILIAR ---

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
      // 👇 USA LA NUEVA FUNCIÓN AUXILIAR
      ingresos: _parseDouble(json['ingresos']),
      gastos: _parseDouble(json['gastos']),
      balance: _parseDouble(json['balance']),
      mes: json['mes'] as String,
      nombreMes: json['nombre_mes'] as String,
    );
  }
}

class TrendData {
  final String mes;      // Ejemplo: "12" o "Dic"
  final String mesFull;  // Ejemplo: "Diciembre"
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
    // Helper seguro para convertir a double
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is int) return val.toDouble();
      return val as double;
    }

    return TrendData(
      mes: json['mes'].toString(),
      mesFull: json['mes_full']?.toString() ?? json['mes'].toString(),
      year: int.parse(json['year'].toString()),
      ingresos: toDouble(json['ingresos']),
      gastos: toDouble(json['gastos']),
    );
  }
}

class BudgetCompliance {
  final int id;
  final String categoriaNombre;
  final String categoriaTipo;
  final double presupuestoMonto;
  final double montoAlcanzado;
  final double porcentajeAlcanzado;
  final double restante;

  BudgetCompliance({
    required this.id,
    required this.categoriaNombre,
    required this.categoriaTipo,
    required this.presupuestoMonto,
    required this.montoAlcanzado,
    required this.porcentajeAlcanzado,
    required this.restante,
  });

  factory BudgetCompliance.fromJson(Map<String, dynamic> json) {
    return BudgetCompliance(
      id: json['id'],
      categoriaNombre: json['categoria_nombre'] ?? 'Sin Categoría',
      categoriaTipo: json['categoria_tipo'] ?? 'gasto',
      // 👇 USA LA NUEVA FUNCIÓN AUXILIAR
      presupuestoMonto: _parseDouble(json['presupuesto_monto']),
      montoAlcanzado: _parseDouble(json['monto_alcanzado']),
      porcentajeAlcanzado: _parseDouble(json['porcentaje_alcanzado']),
      restante: _parseDouble(json['restante']),
    );
  }
}

class CommitmentPayment {
  final int id;
  final double monto;
  final DateTime fechaPago;
  final String compromisoNombre;
  final String tipoCompromiso; // 'Préstamo' o 'Deuda'
  final int? cuotaNumero;

  CommitmentPayment({
    required this.id,
    required this.monto,
    required this.fechaPago,
    required this.compromisoNombre,
    required this.tipoCompromiso,
    this.cuotaNumero,
  });

  factory CommitmentPayment.fromJson(Map<String, dynamic> json) {
    final compromiso = json['compromiso'] as Map<String, dynamic>?;
    final cuota = json['cuota_compromiso'] as Map<String, dynamic>?;

    return CommitmentPayment(
      id: json['id'] as int,
      monto: _parseDouble(json['monto']),
      fechaPago: DateTime.parse(json['fecha_pago']),
      // Extraemos el tipo directamente del compromiso padre
      tipoCompromiso: compromiso?['tipo_compromiso'] ?? 'Desconocido',
      compromisoNombre: compromiso?['nombre'] ?? 'Compromiso Eliminado',
      cuotaNumero: cuota?['numero_cuota'] as int?,
    );
  }

  // Helper para saber si es ingreso
  bool get esIngreso => tipoCompromiso == 'Préstamo';
}

class MonthlyMovement {
  final int id;
  final double monto;
  final String tipo; // 'ingreso' o 'gasto'
  final String fecha;
  final String? nota;
  final String categoriaNombre;

  MonthlyMovement({
    required this.id,
    required this.monto,
    required this.tipo,
    required this.fecha,
    this.nota,
    required this.categoriaNombre,
  });

  factory MonthlyMovement.fromJson(Map<String, dynamic> json) {
    return MonthlyMovement(
      id: json['id'] ?? 0,
      monto: double.tryParse(json['monto'].toString()) ?? 0.0,
      tipo: json['tipo'] ?? 'gasto',
      fecha: json['fecha'] ?? '',
      nota: json['nota'],
      categoriaNombre: json['categoria_nombre'] ?? 'Sin categoría',
    );
  }
}
class ReportData {
  final MonthlySummary summary;
  final List<TrendData> trend;
  final List<BudgetCompliance> budgets;
  final List<CommitmentPayment> commitmentPayments;

  // ✅ 1. Agregamos la propiedad necesaria
  final List<MonthlyMovement> movements;

  ReportData({
    required this.summary,
    required this.trend,
    required this.budgets,
    required this.commitmentPayments,
    // ✅ 2. Agregamos al constructor con valor por defecto
    this.movements = const [],
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final trendList = json['trend'] as List?;
    final budgetsList = json['budgets'] as List?;
    final commitmentPaymentsList = json['commitmentPayments'] as List?;

    // ✅ 3. Leemos la lista del JSON
    final movementsList = json['movements'] as List?;

    return ReportData(
      summary: MonthlySummary.fromJson(json['summary']),
      trend: trendList?.map((i) => TrendData.fromJson(i)).toList() ?? [],
      budgets: budgetsList?.map((i) => BudgetCompliance.fromJson(i)).toList() ?? [],
      commitmentPayments: commitmentPaymentsList?.map((i) => CommitmentPayment.fromJson(i)).toList() ?? [],

      // ✅ 4. Mapeamos usando tu clase MonthlyMovement
      movements: movementsList?.map((i) => MonthlyMovement.fromJson(i)).toList() ?? [],
    );
  }
}