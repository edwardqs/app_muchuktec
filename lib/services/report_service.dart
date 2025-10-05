// lib/services/report_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Importante para la sesión
import '../models/report_data.dart';

const String STORAGE_BASE_URL = 'http://10.0.2.2:8000/storage';
const String API_BASE_URL = 'http://10.0.2.2:8000/api';
class ReportService {

  // Función auxiliar para obtener el token y el ID de cuenta
  Future<Map<String, dynamic>> _getAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString('accessToken');
    final int? idCuenta = prefs.getInt('idCuenta');

    if (accessToken == null) {
      throw Exception('No se encontró el token de acceso. Sesión expirada.');
    }
    if (idCuenta == null) {
      throw Exception('No se ha seleccionado una cuenta.');
    }

    return {
      'accessToken': accessToken,
      'idCuenta': idCuenta.toString(),
    };
  }

  Future<ReportData> fetchReports({required int month, required int year}) async {
    final authData = await _getAuthData();
    final accessToken = authData['accessToken'];
    final idCuenta = authData['idCuenta']; // String del idCuenta

    final Map<String, dynamic> queryParams = {
      'month': month.toString(),
      'year': year.toString(),
      'idcuenta': idCuenta, // <--- Enviamos el idCuenta en los parámetros de la URL
    };

    final uri = Uri.parse('$API_BASE_URL/reports').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json', // Laravel a veces necesita el Accept header
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ReportData.fromJson(data);
    }

    // Manejo de errores para token inválido o problemas en Laravel
    if (response.statusCode == 401) {
      throw Exception('Sesión expirada o no autorizada. Por favor, inicie sesión de nuevo.');
    }

    // Si la respuesta es HTML (como en tu error), la decodificamos como texto
    if (response.headers['content-type']?.contains('text/html') == true) {
      throw Exception('Error del servidor (HTML devuelto). Verifique el backend: ${response.statusCode}');
    }

    // Intenta decodificar el error si es JSON
    try {
      final errorData = json.decode(response.body);
      throw Exception('Fallo al cargar los reportes: ${errorData['message'] ?? response.statusCode}');
    } catch (_) {
      throw Exception('Fallo al cargar los reportes: Código ${response.statusCode}');
    }
  }

  Future<void> exportReports(String format) async {
    final authData = await _getAuthData();
    final accessToken = authData['accessToken'];
    final idCuenta = authData['idCuenta']; // Obtener el idCuenta
    final Map<String, dynamic> queryParams = {
      'idcuenta': idCuenta,
    };
    final uri = Uri.parse('$API_BASE_URL/reports/export/$format')
        .replace(queryParameters: queryParams); // <-- AGREGADO

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      // Éxito: En una app real, aquí manejarías la descarga binaria.
      return;
    } else {
      // Manejo de errores
      if (response.headers['content-type']?.contains('text/html') == true) {
        throw Exception('Error en el servidor de exportación (HTML devuelto).');
      }
      try {
        final errorData = json.decode(response.body);
        throw Exception('Fallo al exportar: ${errorData['error'] ?? response.statusCode}');
      } catch (_) {
        throw Exception('Fallo al exportar: Código ${response.statusCode}');
      }
    }
  }
}