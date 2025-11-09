// lib/screens/verification_screen.dart

// --- CORRECCIÓN DE IMPORTS ---
// (Usamos la ruta del paquete para ser consistentes)
import 'package:app_muchik/services/auth_service.dart';
import 'package:flutter/material.dart';
// No necesitamos importar 'dashboard_screen.dart' porque navegamos por ruta
// --- FIN DE CORRECCIÓN ---


class VerificationScreen extends StatefulWidget {
  // Opcional: pasamos el email para mostrarlo
  final String? email;

  const VerificationScreen({Key? key, this.email}) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final AuthService _authService = AuthService(); // ¡Correcto!
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _verifyToken() async {
    if (_tokenController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, pega el token de tu correo.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Llama al servicio de autenticación
      // ¡Esto está perfecto! El servicio (que corregimos antes)
      // guardará el token en SharedPreferences y actualizará UserSession.
      final response = await _authService.verifyEmailToken(_tokenController.text);

      // --- ¡CAMBIO IMPORTANTE DE NAVEGACIÓN! ---
      // 2. Si tiene éxito, navegamos a la pantalla '/loading'
      //    (igual que hace tu login_screen.dart) para que
      //    la app cargue los datos del usuario antes del dashboard.
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/loading', // <-- Esta es la ruta correcta
              (Route<dynamic> route) => false,
        );
      }
      // --- FIN DEL CAMBIO ---

    } catch (e) {
      // 3. Si hay un error (ej. token inválido), se muestra aquí
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tu UI está perfecta, no necesita cambios.
    return Scaffold(
      appBar: AppBar(
        title: Text('Verificar Cuenta'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email_outlined, size: 80, color: Colors.blueAccent),
                SizedBox(height: 20),
                Text(
                  '¡Revisa tu correo!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  widget.email != null
                      ? 'Hemos enviado un enlace a ${widget.email}.'
                      : 'Te hemos enviado un correo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: 8),
                Text(
                  'Copia el token del enlace y pégalo aquí:',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 24),
                TextField(
                  controller: _tokenController,
                  decoration: InputDecoration(
                    labelText: 'Token de Verificación',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.paste),
                  ),
                  maxLines: null, // Permite pegar tokens largos
                ),
                SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? CircularProgressIndicator()
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _verifyToken,
                    child: Text('Verificar y Entrar', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}