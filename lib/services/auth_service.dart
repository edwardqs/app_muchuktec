// lib/services/auth_service.dart

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:app_muchik/config/constants.dart';
import '../services/user_session.dart';

class AuthService {

  // --- FUNCIÓN LOGOUT (MEJORADA Y CORREGIDA) ---
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      print('No hay token para cerrar sesión.');
      UserSession().clearSession(); // <-- AÑADIDO: Limpia el UI
      return;
    }

    final url = Uri.parse('$API_BASE_URL/logout'); // <-- USANDO TU CONSTANTE

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      // ... tu lógica de print está bien
    } catch (e) {
      print('Error de conexión al intentar cerrar sesión: $e');
    } finally {
      // 1. Borra el token guardado
      await prefs.remove('accessToken');
      await prefs.remove('idCuenta'); // <-- AÑADIDO: Borra también idCuenta

      // 2. Notifica al UI que la sesión se cerró
      UserSession().clearSession(); // <-- AÑADIDO: Notifica al UI
      print('Token local eliminado y sesión del UI cerrada.');
    }
  }

  // --- FUNCIÓN DE VERIFICACIÓN (CORREGIDA) ---
  Future<Map<String, dynamic>> verifyEmailToken(String token) async {

    final response = await http.post(
      Uri.parse('$API_BASE_URL/email/verify'), // <-- USANDO TU CONSTANTE
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({'token': token}),
    );

    if (response.statusCode == 200) {
      // Éxito
      final data = json.decode(response.body);
      final String accessToken = data['access_token'];
      final String userName = data['usuario']['username'];
      final int idCuenta = data['idCuenta']; // <-- Tu backend lo envía

      // --- ¡Lógica de "auto-login" completa! ---

      // 1. Guardamos los datos en SharedPreferences (para persistencia)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', accessToken);
      await prefs.setInt('idCuenta', idCuenta); // <-- AÑADIDO: Guardamos idCuenta

      // 2. Notificamos al UI (para que cambie de pantalla)
      UserSession().setUserData(token: accessToken, name: userName);

      return data;
    } else {
      // Error
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Error al verificar el token');
    }
  }
}