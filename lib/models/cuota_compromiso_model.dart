// lib/models/cuota_compromiso_model.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class CuotaCompromisoModel {
  final int id;
  final int numeroCuota;
  final String fechaPagoProgramada;
  final double monto; // Monto total original de la cuota
  final bool pagado;
  final double montoPagado; // <-- ✅ Nuevo: Cuánto se ha pagado
  final double saldoRestante; // <-- ✅ Nuevo: Cuánto falta por pagar

  CuotaCompromisoModel({
    required this.id,
    required this.numeroCuota,
    required this.fechaPagoProgramada,
    required this.monto,
    required this.pagado,
    required this.montoPagado, // <-- Añadido
    required this.saldoRestante, // <-- Añadido
  });

  factory CuotaCompromisoModel.fromJson(Map<String, dynamic> json) {
    double montoTotal = double.tryParse(json['monto'].toString()) ?? 0.0;

    // ✅ Leer la suma de pagos enviada por el backend
    double montoYaPagado = double.tryParse(json['pagos_sum_monto'].toString()) ?? 0.0;

    // Calcular saldo restante
    double saldoRestanteCalc = montoTotal - montoYaPagado;
    // Asegurar que no sea negativo (por si acaso)
    if (saldoRestanteCalc < 0) saldoRestanteCalc = 0.0;

    // El backend también envía 'pagado' (true/false)
    bool isPagado = json['pagado'] == true || json['pagado'] == 1;

    return CuotaCompromisoModel(
      id: json['id'] as int? ?? 0,
      numeroCuota: json['numero_cuota'] as int? ?? 0,
      fechaPagoProgramada: json['fecha_pago_programada'] as String? ?? '',
      monto: montoTotal,
      pagado: isPagado,
      montoPagado: montoYaPagado, // <-- Guardamos el monto pagado
      saldoRestante: saldoRestanteCalc, // <-- Guardamos el saldo restante
    );
  }

  // --- Helpers (Actualizados) ---

  // Texto de estado (ahora más preciso)
  String get statusText {
    if (pagado) return 'Pagada'; // Si el backend dice 'pagado = true'
    if (montoPagado > 0) return 'Parcial'; // Si se ha pagado algo pero no todo
    return 'Pendiente'; // Si no se ha pagado nada
  }

  // Color de estado (para la UI)
  Color get statusColor {
    if (pagado) return Colors.green.shade700;
    if (montoPagado > 0) return Colors.blue.shade700;
    return Colors.orange.shade700;
  }

  // Helper para el dropdown (ahora muestra saldo restante)
  String get displayText {
    final dateFormatted = DateFormat('dd/MM/yy').format(DateTime.parse(fechaPagoProgramada));
    final amountFormatted = NumberFormat.currency(locale: 'es_PE', symbol: 'S/', decimalDigits: 2).format(saldoRestante);
    return 'Cuota $numeroCuota ($dateFormatted) - Restan $amountFormatted';
  }

  // Formateador para el monto TOTAL (columna "Monto")
  String get montoTotalFormateado {
    final numberFormatter = NumberFormat("#,##0.00", "es_PE");
    String numeroFormateado = numberFormatter.format(monto);
    return 'S/ $numeroFormateado';
  }

  // ✅ NUEVO: Formateador para el SALDO (columna "Por Pagar")
  String get saldoRestanteFormateado {
    final numberFormatter = NumberFormat("#,##0.00", "es_PE");
    String numeroFormateado = numberFormatter.format(saldoRestante);
    return 'S/ $numeroFormateado';
  }
}