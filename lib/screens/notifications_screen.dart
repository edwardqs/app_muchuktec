import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_muchik/config/constants.dart';

// Modelo de datos simple para las notificaciones de prueba
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final NotificationType type;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.type,
    this.isRead = false,
  });
}

// Tipos de notificación para asignar íconos y colores
enum NotificationType {
  payment,   // Pagos, vencimientos
  alert,     // Errores, fallos de conexión
  info,      // Actualizaciones generales, recordatorios
  success,   // Registro exitoso, operación completada
}

// Datos de prueba
final List<NotificationModel> dummyNotifications = [
  NotificationModel(
    id: '1',
    title: '¡Pago Pendiente! 🔔',
    body: 'El compromiso "Préstamo Hipotecario" vence en 3 días. Monto: S/ 1,250.00',
    date: DateTime.now().subtract(const Duration(minutes: 15)),
    type: NotificationType.payment,
  ),
  NotificationModel(
    id: '2',
    title: 'Operación Exitosa ✅',
    body: 'Tu registro de gasto en "Comida" por S/ 45.00 fue completado.',
    date: DateTime.now().subtract(const Duration(hours: 2)),
    type: NotificationType.success,
    isRead: true,
  ),
  NotificationModel(
    id: '3',
    title: 'Actualización de Sistema',
    body: 'Hemos lanzado nuevas funciones de reporte. ¡Echa un vistazo!',
    date: DateTime.now().subtract(const Duration(days: 1)),
    type: NotificationType.info,
    isRead: true,
  ),
  NotificationModel(
    id: '4',
    title: 'Error de Sincronización ⚠️',
    body: 'Fallo al conectar con la base de datos remota. Intenta recargar la aplicación.',
    date: DateTime.now().subtract(const Duration(days: 3)),
    type: NotificationType.alert,
  ),
  NotificationModel(
    id: '5',
    title: 'Vencimiento de Tarjeta',
    body: 'La cuota de tu tarjeta "Visa Platinum" está programada para mañana.',
    date: DateTime.now().subtract(const Duration(days: 5)),
    type: NotificationType.payment,
  ),
];


class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // Método para obtener el color y el ícono basado en el tipo de notificación
  Map<String, dynamic> _getStyle(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return {'color': Colors.orange[700], 'icon': Icons.account_balance_wallet_rounded};
      case NotificationType.alert:
        return {'color': Colors.red[700], 'icon': Icons.error_outline_rounded};
      case NotificationType.info:
        return {'color': Colors.blue[600], 'icon': Icons.info_outline_rounded};
      case NotificationType.success:
        return {'color': Colors.green[600], 'icon': Icons.check_circle_outline_rounded};
    }
  }

  // Método para formatear la fecha a un formato amigable (ej: "Hace 15 minutos")
  String _formatTimeAgo(DateTime date) {
    final Duration diff = DateTime.now().difference(date);

    if (diff.inSeconds < 60) {
      return 'Hace ${diff.inSeconds} segundos';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} minutos';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours} horas';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return DateFormat('dd/MM/yy, hh:mm a').format(date);
    }
  }

  // Widget para construir cada ítem de notificación
  Widget _buildNotificationItem(BuildContext context, NotificationModel notification) {
    final style = _getStyle(notification.type);
    final color = style['color'] as Color?;
    final icon = style['icon'] as IconData?;

    // El color de fondo y del texto depende de si fue leída
    final bgColor = notification.isRead ? Colors.white : Colors.blueGrey[50];
    final titleColor = notification.isRead ? Colors.grey[700] : Colors.black;
    final fontWeight = notification.isRead ? FontWeight.w400 : FontWeight.w600;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color?.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: fontWeight,
            fontSize: 16,
            color: titleColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimeAgo(notification.date),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: Implementar navegación al detalle de la notificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Abriendo detalle de: ${notification.title}')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Primero, separamos las notificaciones leídas de las no leídas para mostrarlas ordenadas.
    final unread = dummyNotifications.where((n) => !n.isRead).toList();
    final read = dummyNotifications.where((n) => n.isRead).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.blue),
            onPressed: () {
              // TODO: Implementar marcar todas como leídas
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Función "Marcar todas como leídas" ejecutada.')),
              );
            },
          ),
        ],
      ),
      body: dummyNotifications.isEmpty
          ? const Center(
        child: Text(
          'No tienes notificaciones.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección NO LEÍDAS
            if (unread.isNotEmpty) ...[
              Text(
                'Sin leer (${unread.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              ...unread.map((n) => _buildNotificationItem(context, n)).toList(),
              const SizedBox(height: 20),
            ],

            // Sección LEÍDAS
            if (read.isNotEmpty) ...[
              Text(
                'Leídas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 10),
              ...read.map((n) => _buildNotificationItem(context, n)).toList(),
            ],
          ],
        ),
      ),
    );
  }
}