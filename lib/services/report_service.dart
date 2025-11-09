// lib/services/report_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_data.dart';
import 'dart:async';
import 'dart:typed_data'; // Necesario para los bytes
import 'package:app_muchik/config/constants.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart'; // <-- 1. IMPORTA EL NUEVO PAQUETE
class ReportService {

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
    final idCuenta = authData['idCuenta'];

    final Map<String, dynamic> queryParams = {
      'month': month.toString(),
      'year': year.toString(),
      'idcuenta': idCuenta,
    };

    final uri = Uri.parse('$API_BASE_URL/reports').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ReportData.fromJson(data);
    }

    if (response.statusCode == 401) {
      throw Exception('Sesión expirada o no autorizada. Por favor, inicie sesión de nuevo.');
    }

    if (response.headers['content-type']?.contains('text/html') == true) {
      throw Exception('Error del servidor (HTML devuelto). Verifique el backend: ${response.statusCode}');
    }

    try {
      final errorData = json.decode(response.body);
      throw Exception('Fallo al cargar los reportes: ${errorData['message'] ?? response.statusCode}');
    } catch (_) {
      throw Exception('Fallo al cargar los reportes: Código ${response.statusCode}');
    }
  }

  Future<String> exportReports(String format, {int? month, int? year}) async {
    final authData = await _getAuthData();
    final accessToken = authData['accessToken'];
    final idCuenta = authData['idCuenta'];

    final queryParams = {
      'idcuenta': idCuenta,
    };
    if (month != null) {
      queryParams['month'] = month.toString();
    }
    if (year != null) {
      queryParams['year'] = year.toString();
    }

    final uri = Uri.parse('$API_BASE_URL/reports/export/$format')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException('El servidor tardó demasiado en responder.'),
    );

    if (response.statusCode == 200) {
      Uint8List fileBytes = response.bodyBytes;

      String extension = format == 'excel' ? 'xlsx' : 'pdf';
      String baseFileName = 'reporte_financiero_${DateTime.now().toIso8601String()}.$extension';

      final params = SaveFileDialogParams(
        data: fileBytes,
        fileName: baseFileName,
      );

      final String? filePath = await FlutterFileDialog.saveFile(params: params);

      if (filePath != null) {
        return filePath;
      } else {
        throw Exception('Guardado cancelado por el usuario.');
      }

    } else {
      try {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error'] ?? 'Error desconocido del servidor';
        throw Exception('Error del Servidor (${response.statusCode}): $errorMessage');
      } catch (e) {
        throw Exception('Fallo al descargar el reporte. Código: ${response.statusCode}');
      }
    }
  }
}