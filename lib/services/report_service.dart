// lib/services/report_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_data.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart'; // Necesario para la carpeta pública

const String STORAGE_BASE_URL = 'http://10.0.2.2:8000/storage';
const String API_BASE_URL = 'http://10.0.2.2:8000/api';

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

  // 🚨 NUEVO MÉTODO: Obtener la ruta de descarga pública y solicitar permisos
  Future<String> _getDownloadPath(String fileName) async {

    var status = await Permission.storage.status;

    if (status.isDenied) {
      // 1. Si está denegado, solicitarlo
      status = await Permission.storage.request();
    }

    // 🚨 ÚLTIMO INTENTO: Si el permiso sigue sin concederse, forzar la apertura de Ajustes
    if (status.isDenied || status.isPermanentlyDenied) {
      openAppSettings();

      throw Exception('Permiso de almacenamiento denegado. Conceda el permiso y reintente.');
    }

    Directory? directory;

    if (Platform.isAndroid) {

      final externalDir = await getExternalStorageDirectory();

      if (externalDir != null) {
        final externalRoot = externalDir.path.split('/Android').first;
        final downloadPath = '$externalRoot/Download';
        directory = Directory(downloadPath);

        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
    } else if (Platform.isIOS) {
      // En iOS, el directorio de documentos es el mejor lugar accesible.
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory == null) {
      throw Exception('No se pudo determinar la ruta de descarga.');
    }

    return '${directory.path}/$fileName';
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

  Future<String> exportReports(String format) async {
    final authData = await _getAuthData();
    final accessToken = authData['accessToken'];
    final idCuenta = authData['idCuenta'];

    final uri = Uri.parse('$API_BASE_URL/reports/export/$format')
        .replace(queryParameters: {'idcuenta': idCuenta});

    final Future<http.Response> responseFuture = http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException('El servidor tardó demasiado en enviar el reporte. Intente de nuevo.'),
    );

    final response = await responseFuture;

    if (response.statusCode == 200) {
      String extension = format == 'excel' ? 'xlsx' : 'pdf';
      String fileName = 'reporte_financiero_${DateTime.now().year}${DateTime.now().month}.$extension';

      // 🚨 USAR EL MÉTODO DE RUTA PÚBLICA
      final filePath = await _getDownloadPath(fileName);

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      return filePath;
    } else {

      try {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error'] ?? 'Error desconocido del servidor';
        throw Exception('Error del Servidor (${response.statusCode}): $errorMessage');
      } catch (e) {

        if (response.statusCode == 501) {
          throw Exception('La exportación a PDF no está implementada en el servidor (Código 501).');
        }

        // Error de conexión o lectura del archivo.
        throw Exception('Fallo de conexión o lectura del archivo. Código: ${response.statusCode}');
      }
    }
  }


}