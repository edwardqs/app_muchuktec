import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// CompromiseModel (Asumo que esta clase está correctamente definida y accesible)
class CompromiseModel {
  final String id;
  final String name;
  final double amount;
  final String date;
  final String? tipoCompromiso;
  final int? idusuario;
  final int? idcuenta;
  final int? idtercero;
  final int? idfrecuencia;
  final double? montoTotal;
  final int? cantidadCuotas;
  final double? montoCuota;
  final int? cuotasPagadas;
  final double? tasaInteres;
  final String? tipoInteres;
  final String? fechaTermino;
  final String? estado;
  final int? estadoEliminar;

  CompromiseModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    this.tipoCompromiso,
    this.idusuario,
    this.idcuenta,
    this.idtercero,
    this.idfrecuencia,
    this.montoTotal,
    this.cantidadCuotas,
    this.montoCuota,
    this.cuotasPagadas,
    this.tasaInteres,
    this.tipoInteres,
    this.fechaTermino,
    this.estado,
    this.estadoEliminar,
  });
}

// ----------------------------------------------------------------------------------

class CompromisesDetailScreen extends StatelessWidget {
  const CompromisesDetailScreen({super.key});

  // Funciones auxiliares (omito código por brevedad, el tuyo es correcto)
  String _formatCurrency(double? value) {
    if (value == null) return 'N/A';
    return 'S/ ${value.toStringAsFixed(2)}';
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return date;
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.purple[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const Divider(color: Colors.grey),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Intentar recuperar el argumento de la ruta. El '?' evita el error si es null.
    final CompromiseModel? receivedCompromise = ModalRoute.of(context)?.settings.arguments as CompromiseModel?;

    // 2. Si es nulo, usar un objeto de ejemplo.
    final CompromiseModel compromise = receivedCompromise ?? CompromiseModel(
      id: 'DUMMY_ID',
      name: 'Compromiso de Prueba (SIN DATOS REALES)',
      amount: 50.0,
      date: '2025-01-15',
      tipoCompromiso: 'PRÉSTAMO',
      montoTotal: 500.0,
      cantidadCuotas: 10,
      montoCuota: 50.0,
      cuotasPagadas: 3,
      tasaInteres: 8.5,
      tipoInteres: 'FIJO',
      fechaTermino: '2025-10-15',
      estado: 'ACTIVO',
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detalle: ${compromise.name}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              // TODO: Implementar navegación a la pantalla de edición
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicador visual de que son datos de prueba
            if (receivedCompromise == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Mostrando datos de ejemplo. No se recibió el Compromiso real.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Sección de Resumen Principal
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    compromise.tipoCompromiso ?? 'COMPROMISO REGISTRADO',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                  const Divider(height: 20, color: Colors.purple),
                  _buildDetailRow(
                      'Monto Total',
                      _formatCurrency(compromise.montoTotal),
                      Icons.money),
                  _buildDetailRow(
                      'Monto por Cuota',
                      _formatCurrency(compromise.montoCuota),
                      Icons.payment),
                ],
              ),
            ),

            // Resto de las secciones...
            _buildSectionHeader('Cuotas y Pagos'),
            _buildDetailRow('Total de Cuotas', (compromise.cantidadCuotas ?? 0).toString(), Icons.format_list_numbered),
            _buildDetailRow('Cuotas Pagadas', (compromise.cuotasPagadas ?? 0).toString(), Icons.check_circle_outline),

            _buildSectionHeader('Fechas y Frecuencia'),
            _buildDetailRow('Fecha de Inicio', _formatDate(compromise.date), Icons.calendar_today),
            _buildDetailRow('Fecha de Término', _formatDate(compromise.fechaTermino), Icons.event_available),
            _buildDetailRow('Frecuencia (ID)', (compromise.idfrecuencia ?? 'N/A').toString(), Icons.repeat),

            _buildSectionHeader('Intereses'),
            _buildDetailRow('Tasa de Interés', '${compromise.tasaInteres?.toStringAsFixed(2) ?? '0.00'}%', Icons.percent),
            _buildDetailRow('Tipo de Interés', compromise.tipoInteres ?? 'N/A', Icons.functions),

            _buildSectionHeader('Otros Datos'),
            _buildDetailRow('Estado Actual', compromise.estado ?? 'N/A', Icons.info),
            _buildDetailRow('ID del Tercero', (compromise.idtercero ?? 'N/A').toString(), Icons.people_alt),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}