// lib/models/pago_compromiso_model.dart
import 'package:intl/intl.dart';

class PagoCompromisoModel {
  final int id;
  final double monto;
  final String fechaPago;
  final String? nota;
  final DateTime createdAt;
  final String? numeroCuotaDisplay;

  PagoCompromisoModel({
    required this.id,
    required this.monto,
    required this.fechaPago,
    this.nota,
    required this.createdAt,
    this.numeroCuotaDisplay,
  });

  factory PagoCompromisoModel.fromJson(Map<String, dynamic> json) {
    return PagoCompromisoModel(
      id: json['id'] as int? ?? 0,
      monto: double.tryParse(json['monto'].toString()) ?? 0.0,
      fechaPago: json['fecha_pago'] as String? ?? '',
      nota: json['nota'] as String?,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      numeroCuotaDisplay: json['numero_cuota']?.toString(),
    );
  }

  // Helper para mostrar fecha formateada
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