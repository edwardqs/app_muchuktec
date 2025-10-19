import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:app_muchik/config/constants.dart';

class AuthService {

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      print('No hay token para cerrar sesión, el usuario ya ha cerrado sesión.');
      return;
    }

    final url = Uri.parse('$API_BASE_URL/logout');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        print('Cierre de sesión exitoso en el backend.');
      } else {
        print('Error en el cierre de sesión en el backend: ${response.body}');
      }
    } catch (e) {
      print('Error de conexión al intentar cerrar sesión: $e');
    } finally {
      await prefs.remove('accessToken');
      print('Token local eliminado. Sesión del cliente cerrada.');
    }
  }
}