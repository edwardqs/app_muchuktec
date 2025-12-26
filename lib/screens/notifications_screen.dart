import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:app_muchik/config/constants.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// ✅ 1. Importamos el widget del anuncio
import 'package:app_muchik/widgets/ad_banner_widget.dart';

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

  static NotificationType _mapStringToNotificationType(String? type) {
    switch (type) {
      case 'budget_warning':
      case 'commitment_due':
        return NotificationType.payment;
      case 'error':
        return NotificationType.alert;
      case 'success':
        return NotificationType.success;
      default:
        return NotificationType.info;
    }
  }
}

enum NotificationType {
  payment,
  alert,
  info,
  success,
}
// --- FIN DEL MODELO ---

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

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

  // --- LÓGICA DE API (INTACTA) ---

  Future<void> _fetchNotifications() async {
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
    // 1. Encontrar la notificación en la lista
    final notificationIndex = _notifications.indexWhere((n) => n.id == notificationId);
    if (notificationIndex == -1) return;

    final notification = _notifications[notificationIndex];

    // 2. Si ya está leída, no hacer nada
    if (notification.isRead) return;

    // Guardar el estado original por si falla la API
    final originalNotificationsList = List<NotificationModel>.from(_notifications);

    // 3. Actualizar la UI localmente (Optimistic Update)
    setState(() {
      _notifications[notificationIndex] = notification.copyWith(isRead: true);
      _notifications.sort((a, b) {
        if (a.isRead != b.isRead) {
          return a.isRead ? 1 : -1;
        }
        return b.date.compareTo(a.date);
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
        _showErrorSnackbar('No se pudo marcar como leída.');
        setState(() {
          _notifications = originalNotificationsList;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error de red al marcar como leída.');
      setState(() {
        _notifications = originalNotificationsList;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final originalNotifications = List<NotificationModel>.from(_notifications);
    final bool hasUnread = _notifications.any((n) => !n.isRead);
    if (!hasUnread) return;

    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });

    try {
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- MÉTODOS DE LA VISTA CON COLORES OFICIALES ---

  Map<String, dynamic> _getStyle(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return {'color': cAzulPetroleo, 'icon': Icons.account_balance_wallet_rounded};
      case NotificationType.alert:
        return {'color': Colors.red[700], 'icon': Icons.error_outline_rounded};
      case NotificationType.info:
        return {'color': cAzulPetroleo.withOpacity(0.7), 'icon': Icons.info_outline_rounded};
      case NotificationType.success:
        return {'color': cVerdeMenta, 'icon': Icons.check_circle_outline_rounded};
    }
  }

  String _formatTimeAgo(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds} segundos';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} minutos';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return DateFormat('dd/MM/yy, hh:mm a').format(date);
  }

  void _showNotificationModal(BuildContext context, NotificationModel notification) {
    final style = _getStyle(notification.type);
    final color = style['color'] as Color?;
    final icon = style['icon'] as IconData?;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cBlanco,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cAzulPetroleo,
                ),
              ),
              const SizedBox(height: 12),
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
                      color: cAzulPetroleo.withOpacity(0.7),
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
              child: Text(
                'Cerrar',
                style: TextStyle(fontSize: 16, color: cVerdeMenta, fontWeight: FontWeight.bold),
              ),
            )
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  Widget _buildNotificationItem(BuildContext context, NotificationModel notification) {
    final style = _getStyle(notification.type);
    final color = style['color'] as Color?;
    final icon = style['icon'] as IconData?;

    // Estilo diferenciado (Leído vs No Leído) con colores oficiales
    final bgColor = notification.isRead ? cGrisClaro : cBlanco;
    final titleColor = notification.isRead ? cAzulPetroleo.withOpacity(0.6) : cAzulPetroleo;
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
            offset: const Offset(0, 2),
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
                color: cAzulPetroleo.withOpacity(0.6), // Gris azulado
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
        trailing: notification.isRead
            ? Icon(Icons.check_circle, color: cVerdeMenta.withOpacity(0.5), size: 24)
            : IconButton(
          icon: Icon(Icons.circle_outlined, color: cVerdeMenta, size: 24),
          tooltip: 'Marcar como leída',
          onPressed: () {
            _markAsRead(notification.id);
          },
        ),
        onTap: () {
          _showNotificationModal(context, notification);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).toList();
    final read = _notifications.where((n) => n.isRead).toList();

    return Scaffold(
      backgroundColor: cGrisClaro, // Fondo oficial
      appBar: AppBar(
        backgroundColor: cBlanco,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cAzulPetroleo),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notificaciones',
          style: TextStyle(
            color: cAzulPetroleo,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          if (unread.isNotEmpty)
            IconButton(
              icon: Icon(Icons.done_all, color: cVerdeMenta),
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
            ),
        ],
      ),

      // ✅ 2. Integración del Banner aquí
      bottomNavigationBar: const AdBannerWidget(),

      body: _buildBody(unread, read),
    );
  }

  Widget _buildBody(List<NotificationModel> unread, List<NotificationModel> read) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: cVerdeMenta),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: cAzulPetroleo.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No tienes notificaciones.',
              style: TextStyle(fontSize: 16, color: cAzulPetroleo.withOpacity(0.5)),
            ),
          ],
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
                color: cAzulPetroleo,
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
                color: cAzulPetroleo.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 10),
            ...read.map((n) => _buildNotificationItem(context, n)).toList(),
          ],
        ],
      ),
    );
  }
}