import 'package:intl/intl.dart'; // For formatting

class CuotaCompromisoModel {
  final int id;
  final int numeroCuota;
  final String fechaPagoProgramada;
  final double monto;
  final bool pagado;

  CuotaCompromisoModel({
    required this.id,
    required this.numeroCuota,
    required this.fechaPagoProgramada,
    required this.monto,
    required this.pagado,
  });

  factory CuotaCompromisoModel.fromJson(Map<String, dynamic> json) {
    return CuotaCompromisoModel(
      id: json['id'] as int? ?? 0,
      numeroCuota: json['numero_cuota'] as int? ?? 0,
      fechaPagoProgramada: json['fecha_pago_programada'] as String? ?? '',
      monto: double.tryParse(json['monto'].toString()) ?? 0.0,
      pagado: json['pagado'] == true || json['pagado'] == 1,
    );
  }

  String get statusText => pagado ? 'Pagada' : 'Pendiente';

  // Helper for display in Dropdown
  String get displayText {
    try {
      final dateFormatted = DateFormat('dd/MM/yy').format(DateTime.parse(fechaPagoProgramada));
      final amountFormatted = NumberFormat.currency(locale: 'es_PE', symbol: 'S/', decimalDigits: 2).format(monto);
      return 'Cuota $numeroCuota ($dateFormatted) - $amountFormatted';
    } catch (e) {
      // Fallback if date parsing fails
      return 'Cuota $numeroCuota - S/${monto.toStringAsFixed(2)}';
    }
  }
}