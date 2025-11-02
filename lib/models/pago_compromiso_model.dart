import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class PagoCompromisoModel {
  final int id;
  final double monto;
  final String fechaPago;
  final String? nota;
  final DateTime createdAt;
  final int? numeroCuota;
  final String? fechaPagoProgramada;

  PagoCompromisoModel({
    required this.id,
    required this.monto,
    required this.fechaPago,
    this.nota,
    required this.createdAt,
    this.numeroCuota,
    this.fechaPagoProgramada,
  });

  factory PagoCompromisoModel.fromJson(Map<String, dynamic> json) {
    int? parsedNumeroCuota;
    String? parsedFechaProgramada;

    if (json['cuota_compromiso'] != null && json['cuota_compromiso'] is Map) {
      parsedNumeroCuota = json['cuota_compromiso']['numero_cuota'] as int?;
      parsedFechaProgramada = json['cuota_compromiso']['fecha_pago_programada'] as String?;
    }

    return PagoCompromisoModel(
      id: json['id'] as int? ?? 0,
      monto: double.tryParse(json['monto'].toString()) ?? 0.0,
      fechaPago: json['fecha_pago'] as String? ?? '',
      nota: json['nota'] as String?,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      numeroCuota: parsedNumeroCuota,
      fechaPagoProgramada: parsedFechaProgramada,
    );
  }

  // Helper para mostrar fecha formateada
  String get cuotaDisplayText {
    if (numeroCuota == null || fechaPagoProgramada == null) {
      return 'Flexible';
    }

    try {
      // Caso 2: Hay cuota. Comparamos fechas.
      final dtPago = DateTime.parse(fechaPago);
      final dtProgramada = DateTime.parse(fechaPagoProgramada!);

      // Comparamos solo la parte de la fecha (ignorando la hora)
      final dateOnlyPago = DateTime(dtPago.year, dtPago.month, dtPago.day);
      final dateOnlyProgramada = DateTime(dtProgramada.year, dtProgramada.month, dtProgramada.day);

      if (dateOnlyPago.isBefore(dateOnlyProgramada)) {
        return 'Anticipado (C. $numeroCuota)'; // Ej: "Anticipado (C. 1)"
      } else {
        return 'Cuota $numeroCuota'; // Ej: "Cuota 1"
      }
    } catch (e) {
      // Fallback si las fechas son inválidas
      return 'Cuota $numeroCuota';
    }
  }

  String get fechaFormateada {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(fechaPago));
    } catch (e) {
      return fechaPago; // Fallback
    }
  }
  // Helper para mostrar monto formateado
  String get montoFormateado {
    final numberFormatter = NumberFormat("#,##0.00", "es_PE");
    String numeroFormateado = numberFormatter.format(monto);
    return 'S/ $numeroFormateado';
  }
}