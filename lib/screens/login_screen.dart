// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';

// --- ¡NUEVO IMPORT! ---
// Importamos la pantalla de verificación
import '../screens/verification_screen.dart';
// --- FIN DEL NUEVO IMPORT ---

class LoginScreen extends StatefulWidget {
  // ... (tu código se queda igual)
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ... (tus controladores se quedan igual)
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _rememberMe = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String> _errorMessage = ValueNotifier<String>('');

  bool _isRedirecting = false;


  @override
  void initState() {
    // ... (tu código se queda igual)
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // ... (tu código se queda igual)
    // (Esta función usa API_BASE_URL, asegúrate que esté en tus constants.dart)
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      print('🚫 No se encontró un token de acceso en SharedPreferences. Se mantiene en la pantalla de login.');
      return;
    }

    print('🔍 Token de acceso encontrado. Validando sesión con el servidor...');
    _isLoading.value = true;
    final url = Uri.parse('$API_BASE_URL/getUser');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept' : 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      _isLoading.value = false;

      if (response.statusCode == 200) {
        print('✅ Sesión validada con éxito. Redirigiendo a /loading...');
        if (!_isRedirecting) {
          _isRedirecting = true;
          Navigator.of(context).pushReplacementNamed(
            '/loading',
            arguments: accessToken,
          );
        }
      } else {
        print('❌ El token no es válido o ha expirado. Estado: ${response.statusCode}');
        await prefs.remove('accessToken');
        await prefs.remove('idCuenta');
        _errorMessage.value = 'Tu sesión ha expirado o ya no es válida. Por favor, inicia sesión de nuevo.';
      }
    } catch (e) {
      _isLoading.value = false;
      print('❗ Error al conectar con el servidor para validar la sesión: $e');
      _errorMessage.value = 'No se pudo verificar tu sesión. Por favor, intenta de nuevo.';
      await prefs.remove('accessToken');
      await prefs.remove('idCuenta');
    }
  }

  Future<void> _performLogin() async {
    // ... (tu código se queda igual)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _isLoading.value = true;
    _errorMessage.value = '';

    final url = Uri.parse('$API_BASE_URL/login');
    final body = {
      'login': _loginController.text,
      'password': _passwordController.text,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept' : 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final accessToken = responseData['access_token'];
        final idCuenta = responseData['idCuenta'];

        if (accessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('accessToken', accessToken);
          await prefs.setInt('idCuenta', idCuenta);
          if (!_isRedirecting) {
            _isRedirecting = true;
            Navigator.of(context).pushReplacementNamed(
              '/loading',
              arguments: accessToken,
            );
          }
        } else {
          _errorMessage.value = 'Token no recibido. Por favor, intente de nuevo.';
        }
      } else {
        // Esta parte es clave, aquí le avisamos si no está verificado
        final errorData = json.decode(response.body);
        if (errorData['errors'] != null && errorData['errors']['login'] != null) {
          _errorMessage.value = errorData['errors']['login'][0];
        } else {
          _errorMessage.value = errorData['message'] ?? 'Error desconocido.';
        }
      }
    } catch (e) {
      _errorMessage.value = 'No se pudo conectar al servidor: $e';
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (tu código se queda igual)
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple[400]!,
              Colors.purple[600]!,
              Colors.indigo[600]!,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _LoginContent,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // ... (tu código se queda igual)
    _loginController.dispose();
    _passwordController.dispose();
    _isPasswordVisible.dispose();
    _rememberMe.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    super.dispose();
  }

  // --- ¡AQUÍ ESTÁ EL CAMBIO! ---
  Widget get _LoginContent {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          const _HeaderSection(),
          const SizedBox(height: 50),
          _buildLoginForm(),
          const SizedBox(height: 32),
          _buildLoginButton(),
          const SizedBox(height: 20),

          // --- ¡BOTÓN NUEVO AÑADIDO! ---
          _buildVerifyButton(context), // Botón para el "Plan B"
          // --- FIN DEL CAMBIO ---

          const SizedBox(height: 20), // Espacio extra
          const _Divider(),
          const SizedBox(height: 24),
          _buildRegisterButton(),
          const SizedBox(height: 40),
          const _FooterSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  // --- FIN DEL CAMBIO ---


  // --- ¡NUEVO WIDGET AÑADIDO! ---
  Widget _buildVerifyButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        // Navega a la pantalla de verificación manual
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VerificationScreen(),
          ),
        );
      },
      child: Text(
        '¿Aún no verificaste tu correo? Haz clic aquí',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
  // --- FIN DEL NUEVO WIDGET ---

  Widget _buildLoginForm() {
    // ... (tu código se queda igual)
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          ValueListenableBuilder<String>(
            valueListenable: _errorMessage,
            builder: (context, errorMsg, child) {
              if (errorMsg.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMsg,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildModernTextField(
            controller: _loginController,
            label: 'Correo o username',
            icon: Icons.person_outline,
            keyboardType: TextInputType.text,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu correo o username';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<bool>(
            valueListenable: _isPasswordVisible,
            builder: (context, isVisible, child) {
              return _buildModernTextField(
                controller: _passwordController,
                label: 'Contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
                isPasswordVisible: isVisible,
                onTogglePassword: () {
                  _isPasswordVisible.value = !isVisible;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu contraseña';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            // ... (tu código se queda igual)
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _rememberMe,
                builder: (context, remember, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: remember
                              ? Colors.purple[600]
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: remember
                                ? Colors.purple[600]!
                                : Colors.purple[300]!,
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            _rememberMe.value = !remember;
                          },
                          child: remember
                              ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _rememberMe.value = !remember;
                        },
                        child: Text(
                          'Recordarme',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  'Recupera tu contraseña',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    // ... (tu código se queda igual)
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, isLoading, child) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple[500]!,
                Colors.purple[700]!,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.4),
                spreadRadius: 0,
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _performLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            )
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.login,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegisterButton() {
    // ... (tu código se queda igual)
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(context, '/register');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Crear nueva cuenta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    // ... (tu código se queda igual)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.purple[600]),
            const SizedBox(width: 8),
            const Text(
              'Recuperar Contraseña',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Te enviaremos un enlace de recuperación a tu correo electrónico registrado.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Enlace de recuperación enviado'),
                  backgroundColor: Colors.green[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Enviar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    // ... (tu código se queda igual)
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword ? !(isPasswordVisible ?? false) : false,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.purple[600],
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.purple[600],
              size: 20,
            ),
          ),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              isPasswordVisible ?? false
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.purple[400],
            ),
            onPressed: onTogglePassword,
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.purple.withOpacity(0.1),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.purple[400]!,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
        ),
        validator: validator,
      ),
    );
  }
}

// Widgets Estáticos
class _HeaderSection extends StatelessWidget {
  // ... (tu código se queda igual)
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.purple[50]!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                spreadRadius: 8,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.account_balance_wallet,
            size: 70,
            color: Colors.purple[700],
          ),
        ),
        const SizedBox(height: 40),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.white, Colors.purple[100]!],
          ).createShader(bounds),
          child: const Text(
            '¡Bienvenido!',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa a tu cuenta Econo Muchik',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w300,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  // ... (tu código se queda igual)
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'O',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      ],
    );
  }
}

class _FooterSection extends StatelessWidget {
  // ... (tu código se queda igual)
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Text(
      '© 2025 Econo Muchik Finance',
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 12,
      ),
    );
  }
}