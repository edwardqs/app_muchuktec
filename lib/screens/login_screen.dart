// screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Importa el paquete http
import 'dart:convert'; // Importa para codificar/decodificar JSON
import 'package:shared_preferences/shared_preferences.dart';
const String apiUrl = 'http://127.0.0.1:8000/api';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false; // Nuevo estado para el indicador de carga
  String errorMessage = ''; // Nuevo estado para mostrar mensajes de error de la API

  // Metodo para manejar el inicio de sesión
  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) {
      return; // No proceder si la validación del formulario falla
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    final url = Uri.parse('$apiUrl/login');
    final body = {
      'correo': _emailController.text,
      'password': _passwordController.text,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body), // Codificar el cuerpo a JSON
      );
      if (response.statusCode == 200) {
        // Login exitoso
        final responseData = json.decode(response.body);
        final accessToken = responseData['access_token'];

        if (accessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('accessToken', accessToken);
          print('Inicio de sesión exitoso. Token: $accessToken');
          Navigator.of(context).pushReplacementNamed(
            '/loading', // La ruta nombrada de tu HomeScreen
            arguments: accessToken, // Pasar el token como argumento
          );
        } else {
          setState(() {
            errorMessage = 'Token no recibido. Por favor, intente de nuevo.';
          });
        }
      } else {
        final errorData = json.decode(response.body);
        if (errorData['errors'] != null) {
          final firstError = errorData['errors'].values.first[0];
          setState(() {
            errorMessage = firstError;
          });
        } else {
          setState(() {
            errorMessage = errorData['message'] ?? 'Error desconocido al iniciar sesión.';
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'No se pudo conectar al servidor: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('SettingsScreen build method called'); // Debug
    print('SettingsScreen context: $context'); // Debug
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo/Avatar
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 60,
                    color: Colors.purple[700],
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                const Text(
                  'Econo Muchik Finance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 40),

                // Email Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'Correo Electrónico',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu email';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Password Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Contraseña',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu contraseña';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // Llama a _performLogin cuando se presiona el botón
                    // El botón se deshabilita si isLoading es true
                    onPressed: isLoading ? null : _performLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading // Muestra un CircularProgressIndicator si está cargando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Iniciar Sesión',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'No tengo una cuenta, registrarme',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}