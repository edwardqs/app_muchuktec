import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:app_muchik/config/constants.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- MODELO ---
class NotificationModel {
  final int id;
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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      title: json['title'] ?? 'Sin Título',
      body: json['body'] ?? 'Sin contenido.',
      date: DateTime.parse(json['created_at']),
      type: _mapStringToNotificationType(json['type']),
      isRead: json['status'] == 1,
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      date: date,
      type: type,
      isRead: isRead ?? this.isRead,
    );
  }

  // --- CAMBIO --- Agregamos el mapeo para 'commitment_due'
  static NotificationType _mapStringToNotificationType(String? type) {
    switch (type) {
      case 'budget_warning':
      case 'commitment_due': // <-- Lo tratamos igual que budget_warning
        return NotificationType.payment;
      case 'error':
        return NotificationType.alert;
      case 'success':
        return NotificationType.success;
      default: // Cualquier otro tipo será 'info'
        return NotificationType.info;
    }
  }
}

enum NotificationType {
  payment, // Para alertas de presupuesto y vencimientos de compromiso
  alert,   // Errores
  info,    // General
  success, // Éxito
}
// --- FIN DEL MODELO ---

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;
  String? _accessToken;
  int? _idcuenta;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // --- LÓGICA DE API (Sin cambios, ya era genérica) ---

  Future<void> _fetchNotifications() async {
    // ... Tu código _fetchNotifications existente ...
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('accessToken');
      _idcuenta = prefs.getInt('idCuenta');

      if (_accessToken == null || _idcuenta == null) {
        throw Exception('Usuario no autenticado o cuenta no seleccionada.');
      }

      // La URL ya pide todas las notificaciones para la cuenta
      final url = Uri.parse('$API_BASE_URL/notifications?idcuenta=$_idcuenta');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          // El 'fromJson' ya usa el mapeo actualizado
          _notifications = data
              .map((json) => NotificationModel.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar notificaciones: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    // ... Tu código _markAsRead existente ...
    // 1. Encontrar la notificación en la lista
    final notificationIndex = _notifications.indexWhere((n) => n.id == notificationId);
    if (notificationIndex == -1) return; // Si no se encuentra, salir

    final notification = _notifications[notificationIndex];


    // 2. Si ya está leída, no hacer nada
    if (notification.isRead) return;

    // Guardar el estado original por si falla la API
    final originalNotification = _notifications[notificationIndex];
    final originalNotificationsList = List<NotificationModel>.from(_notifications);


    // 3. Actualizar la UI localmente (Optimistic Update)
    setState(() {
      _notifications[notificationIndex] = notification.copyWith(isRead: true);
      // Reordenar la lista para moverla visualmente si es necesario
      _notifications.sort((a, b) {
        if (a.isRead != b.isRead) {
          return a.isRead ? 1 : -1; // No leídas primero
        }
        return b.date.compareTo(a.date); // Luego por fecha descendente
      });
    });

    // 4. Intentar actualizar en el backend
    try {
      final url = Uri.parse('$API_BASE_URL/notifications/$notificationId/read');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );

      if (response.statusCode != 200) {
        // 5. Si falla, revertir el cambio local y mostrar error
        _showErrorSnackbar('No se pudo marcar como leída. ${response.body}');
        setState(() {
          _notifications = originalNotificationsList; // Restaurar lista original
        });
      }
      // Si tiene éxito, la UI ya está actualizada
    } catch (e) {
      // 6. Revertir si hay un error de conexión
      _showErrorSnackbar('Error de red al marcar como leída.');
      setState(() {
        _notifications = originalNotificationsList; // Restaurar lista original
      });
    }
  }

  Future<void> _markAllAsRead() async {
    // ... Tu código _markAllAsRead existente ...
    // Guardar estado anterior en caso de que falle
    final originalNotifications = List<NotificationModel>.from(_notifications);

    // --- NUEVO --- Solo actualiza si hay algo que marcar
    final bool hasUnread = _notifications.any((n) => !n.isRead);
    if (!hasUnread) return;

    // Actualizar UI localmente
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });

    try {
      // ... (Tu lógica de API era correcta, sin cambios) ...
      final url = Uri.parse('$API_BASE_URL/notifications/read-all');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'idcuenta': _idcuenta}),
      );

      if (response.statusCode != 200) {
        setState(() => _notifications = originalNotifications);
        _showErrorSnackbar('No se pudo marcar todas como leídas.');
      }
    } catch (e) {
      setState(() => _notifications = originalNotifications);
      _showErrorSnackbar('Error de red. Intente de nuevo.');
    }
  }

  void _showErrorSnackbar(String message) {
    // ... Tu código _showErrorSnackbar existente ...
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- MÉTODOS DE LA VISTA ---

  // --- CAMBIO --- Aseguramos que 'payment' tenga estilo
  Map<String, dynamic> _getStyle(NotificationType type) {
    switch (type) {
      case NotificationType.payment: // <-- Este cubre 'budget_warning' Y 'commitment_due'
        return {'color': Colors.orange[700], 'icon': Icons.account_balance_wallet_rounded};
      case NotificationType.alert:
        return {'color': Colors.red[700], 'icon': Icons.error_outline_rounded};
      case NotificationType.info:
        return {'color': Colors.blue[600], 'icon': Icons.info_outline_rounded};
      case NotificationType.success:
        return {'color': Colors.green[600], 'icon': Icons.check_circle_outline_rounded};
    }
  }

  String _formatTimeAgo(DateTime date) {
    // ... Tu código _formatTimeAgo existente ...
    final Duration diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds} segundos';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} minutos';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return DateFormat('dd/MM/yy, hh:mm a').format(date);
  }

  void _showNotificationModal(BuildContext context, NotificationModel notification) {
    // ... Tu código _showNotificationModal existente (sin el _markAsRead) ...
    // 2. Obtiene el estilo (ícono y color)
    final style = _getStyle(notification.type);
    final color = style['color'] as Color?;
    final icon = style['icon'] as IconData?;

    // 3. Muestra el diálogo
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color?.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                notification.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Para que el texto largo tenga scroll si es necesario
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    notification.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _formatTimeAgo(notification.date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar', style: TextStyle(fontSize: 16)),
            )
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  Widget _buildNotificationItem(BuildContext context, NotificationModel notification) {
    // ... Tu código _buildNotificationItem existente ...
    final style = _getStyle(notification.type);
    final color = style['color'] as Color?;
    final icon = style['icon'] as IconData?;

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

        // --- Botón para marcar como leída ---
        trailing: notification.isRead
            ? Icon(Icons.check_circle, color: Colors.green[300], size: 24)
            : IconButton(
          icon: Icon(Icons.check_circle_outline, color: Colors.grey[400], size: 24),
          tooltip: 'Marcar como leída',
          onPressed: () {
            // Llama a la función de marcar como leída
            _markAsRead(notification.id);
          },
        ),

        // --- El onTap ahora muestra el modal ---
        onTap: () {
          _showNotificationModal(context, notification);
        },
      ),
    );
  }

  // --- MÉTODO BUILD (Sin cambios) ---
  @override
  Widget build(BuildContext context) {
    // ... Tu código build existente ...
    // Filtra las notificaciones leídas y no leídas
    final unread = _notifications.where((n) => !n.isRead).toList();
    final read = _notifications.where((n) => n.isRead).toList();

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
          // El botón "Marcar todas" solo es visible si hay notificaciones sin leer
          if (unread.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.blue),
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: _buildBody(unread, read), // Usamos un método auxiliar para el body
    );
  }

  Widget _buildBody(List<NotificationModel> unread, List<NotificationModel> read) {
    // ... Tu código _buildBody existente ...
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Error al cargar: $_error',
            style: const TextStyle(fontSize: 16, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_notifications.isEmpty) {
      return const Center(
        child: Text(
          'No tienes notificaciones.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    );
  }
} // Fin de _NotificationsScreenState