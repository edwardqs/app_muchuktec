// lib/screens/verification_screen.dart
import 'package:app_muchik/services/auth_service.dart';
import 'package:flutter/material.dart';

class VerificationScreen extends StatefulWidget {
  final String? email;

  const VerificationScreen({Key? key, this.email}) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // --- DEFINICIÓN DE COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  final TextEditingController _tokenController = TextEditingController();
  final AuthService _authService = AuthService();
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
      final response = await _authService.verifyEmailToken(_tokenController.text);

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/loading',
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
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
    return Scaffold(
      // Fondo degradado igual que el registro
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cAzulPetroleo,
              Color.lerp(cAzulPetroleo, cVerdeMenta, 0.3)!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Botón para volver atrás (opcional, por si quieren corregir correo)
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Tarjeta Contenedora Blanca
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: cBlanco,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ícono decorativo
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cVerdeMenta.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mark_email_read_outlined,
                            size: 60,
                            color: cVerdeMenta,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '¡Revisa tu correo!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cAzulPetroleo,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.email != null
                              ? 'Hemos enviado un enlace y token a\n${widget.email}'
                              : 'Te hemos enviado un correo con el token.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: cAzulPetroleo.withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Copia el token y pégalo aquí:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cAzulPetroleo,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Input modernizado
                        TextField(
                          controller: _tokenController,
                          style: TextStyle(
                            fontSize: 18,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                            color: cAzulPetroleo,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'Ej: ABC-123',
                            hintStyle: TextStyle(
                                color: cAzulPetroleo.withOpacity(0.3),
                                letterSpacing: 1
                            ),
                            filled: true,
                            fillColor: cGrisClaro,
                            prefixIcon: Icon(Icons.paste, color: cAzulPetroleo.withOpacity(0.5)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cVerdeMenta, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          maxLines: 1,
                        ),

                        // Mensaje de Error
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: TextStyle(color: Colors.red[700], fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Botón de Acción
                        _isLoading
                            ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(cVerdeMenta))
                            : Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: cVerdeMenta,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: cVerdeMenta.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _verifyToken,
                            child: Text(
                              'Verificar y Entrar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cBlanco,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}