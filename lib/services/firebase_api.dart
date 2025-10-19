// lib/services/firebase_api.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart'; // Tu archivo de constantes

class FirebaseApi {
  // 1. Obtener la instancia de Firebase Messaging
  final _firebaseMessaging = FirebaseMessaging.instance;

  // 2. Función principal para inicializar las notificaciones
  Future<void> initNotifications() async {
    // Pedir permiso al usuario (en iOS y Android 13+)
    await _firebaseMessaging.requestPermission();

    // Obtener el Token FCM del dispositivo
    final fcmToken = await _firebaseMessaging.getToken();

    if (fcmToken == null) {
      print('🚫 Error: No se pudo obtener el FCM Token.');
      return;
    }

    print('======================');
    print('✅ FCM TOKEN: $fcmToken');
    print('======================');

    // Enviar este token a tu backend de Laravel
    await _sendTokenToBackend(fcmToken);

    // Escuchar mensajes mientras la app está abierta
    _handleForegroundMessages();
  }

  // 3. Función privada para enviar el token a Laravel
  Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      // Obtenemos el token de autenticación que guardaste en el login
      final prefs = await SharedPreferences.getInstance();
      final userToken = prefs.getString('accessToken');

      if (userToken == null) {
        print('🚫 Error: Usuario no autenticado, no se puede enviar FCM token.');
        return;
      }

      final url = Uri.parse('$API_BASE_URL/save-fcm-token');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $userToken', // Token de autenticación de Sanctum
        },
        body: jsonEncode({
          'fcm_token': fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM Token guardado en el backend exitosamente.');
      } else {
        print('❌ Error al guardar FCM Token en backend: ${response.body}');
      }
    } catch (e) {
      print('❗ Excepción al enviar FCM Token: $e');
    }
  }

  // 4. Función para manejar mensajes con la app abierta
  void _handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 ¡Notificación recibida en primer plano!');
      if (message.notification != null) {
        print('Título: ${message.notification!.title}');
        print('Cuerpo: ${message.notification!.body}');
        // Aquí puedes mostrar un SnackBar, un diálogo, o actualizar un badge
      }
    });
  }
}