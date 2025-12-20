// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';
import '../screens/verification_screen.dart';

// --- DEFINICIÓN DE COLORES OFICIALES ---
final Color cPetrolBlue = const Color(0xFF264653);
final Color cMintGreen = const Color(0xFF2A9D8F);
final Color cLightGrey = const Color(0xFFF4F4F4);
final Color cWhite = const Color(0xFFFFFFFF);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String> _errorMessage = ValueNotifier<String>('');

  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) return;

    _isLoading.value = true;
    final url = Uri.parse('$API_BASE_URL/getUser');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      _isLoading.value = false;

      if (response.statusCode == 200) {
        if (!_isRedirecting) {
          _isRedirecting = true;
          Navigator.of(context).pushReplacementNamed(
            '/loading',
            arguments: accessToken,
          );
        }
      } else {
        await prefs.remove('accessToken');
        await prefs.remove('idCuenta');
        _errorMessage.value = 'Tu sesión ha expirado.';
      }
    } catch (e) {
      _isLoading.value = false;
      await prefs.remove('accessToken');
      await prefs.remove('idCuenta');
    }
  }

  Future<void> _performLogin() async {
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
          'Accept': 'application/json',
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
          _errorMessage.value = 'Error de token.';
        }
      } else {
        final errorData = json.decode(response.body);
        if (errorData['errors'] != null && errorData['errors']['login'] != null) {
          _errorMessage.value = errorData['errors']['login'][0];
        } else {
          _errorMessage.value = errorData['message'] ?? 'Credenciales incorrectas.';
        }
      }
    } catch (e) {
      _errorMessage.value = 'Error de conexión.';
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cPetrolBlue, cMintGreen],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _LoginContent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _isPasswordVisible.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    super.dispose();
  }

  Widget get _LoginContent {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const _HeaderSection(),
          const SizedBox(height: 30),
          _buildLoginForm(),
          const SizedBox(height: 24),
          _buildLoginButton(),
          const SizedBox(height: 10),
          _buildVerifyButton(context),
          const SizedBox(height: 16),
          const _Divider(),
          const SizedBox(height: 16),
          _buildRegisterButton(),
          const SizedBox(height: 20),
          const _FooterSection(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildVerifyButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => VerificationScreen()),
        );
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        '¿Aún no verificaste tu correo? Haz clic aquí',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cPetrolBlue.withOpacity(0.3),
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
              if (errorMsg.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMsg,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
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
            validator: (value) => (value == null || value.isEmpty)
                ? 'Ingresa tu usuario'
                : null,
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: _isPasswordVisible,
            builder: (context, isVisible, child) {
              return _buildModernTextField(
                controller: _passwordController,
                label: 'Contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
                isPasswordVisible: isVisible,
                onTogglePassword: () => _isPasswordVisible.value = !isVisible,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Ingresa tu contraseña'
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, isLoading, child) {
        return Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [cMintGreen, cPetrolBlue]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cPetrolBlue.withOpacity(0.4),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: isLoading
                ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            )
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Poppins',
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
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, '/register'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Crear nueva cuenta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SOLUCIÓN: Agregado AutovalidateMode ---
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            // ¡ESTA LÍNEA ES LA MAGIA! 👇
            // Hace que el error desaparezca apenas el usuario interactúa con el campo
            autovalidateMode: AutovalidateMode.onUserInteraction,

            controller: controller,
            keyboardType: keyboardType,
            obscureText: isPassword ? !(isPasswordVisible ?? false) : false,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cPetrolBlue,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              hintText: 'Ingresa tu $label'.toLowerCase(),
              hintStyle: TextStyle(
                color: cPetrolBlue.withOpacity(0.5),
                fontWeight: FontWeight.w400,
                fontFamily: 'Poppins',
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: cPetrolBlue, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                icon: Icon(
                  isPasswordVisible ?? false
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: cPetrolBlue.withOpacity(0.6),
                  size: 20,
                ),
                onPressed: onTogglePassword,
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: cPetrolBlue.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/logo4.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '¡Bienvenido!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
            shadows: [
              Shadow(
                offset: const Offset(0, 2),
                blurRadius: 4,
                color: Colors.black.withOpacity(0.2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ingresa a tu cuenta Planifiko',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w300,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'O',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.3))),
      ],
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Text(
      '© 2025 Planifiko Finance',
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 11,
        fontFamily: 'Poppins',
      ),
    );
  }
}