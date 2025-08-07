// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _documentController = TextEditingController();
  final _phoneController = TextEditingController(); // Nuevo controlador para celular
  final _addressController = TextEditingController(); // Nuevo controlador para dirección

  String _selectedDocumentType = 'DNI';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Hero Logo
                  Container(
                    width: 120,
                    height: 120,
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
                          spreadRadius: 5,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_add_alt_1,
                      size: 60,
                      color: Colors.purple[700],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Title con estilo moderno
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, Colors.purple[100]!],
                    ).createShader(bounds),
                    child: const Text(
                      '¡Únete a nosotros!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu cuenta y comienza tu viaje financiero',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Formulario con glassmorphism
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        // Name Field
                        _buildModernTextField(
                          controller: _nameController,
                          label: 'Nombres y apellidos',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu nombre completo';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Username Field
                        _buildModernTextField(
                          controller: _usernameController,
                          label: 'Username',
                          icon: Icons.alternate_email,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu username';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Tipo de documento con estilo moderno
                        _buildDocumentTypeSelector(),

                        const SizedBox(height: 20),

                        // Campo DNI/RUC
                        _buildDocumentField(),

                        const SizedBox(height: 20),

                        // Celular Field - NUEVO
                        _buildModernTextField(
                          controller: _phoneController,
                          label: 'Número de celular',
                          icon: Icons.phone_android,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          suffixText: '9 dígitos',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu número de celular';
                            }
                            if (value.length != 9) {
                              return 'El celular debe tener 9 dígitos';
                            }
                            if (!value.startsWith('9')) {
                              return 'El celular debe empezar con 9';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Dirección Field - NUEVO
                        _buildModernTextField(
                          controller: _addressController,
                          label: 'Dirección completa',
                          icon: Icons.location_on_outlined,
                          keyboardType: TextInputType.streetAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu dirección';
                            }
                            if (value.length < 10) {
                              return 'Por favor ingresa una dirección completa';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Email Field
                        _buildModernTextField(
                          controller: _emailController,
                          label: 'Correo electrónico',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu email';
                            }
                            if (!value.contains('@')) {
                              return 'Por favor ingresa un email válido';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Password Field
                        _buildModernTextField(
                          controller: _passwordController,
                          label: 'Contraseña',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          isPasswordVisible: _isPasswordVisible,
                          onTogglePassword: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu contraseña';
                            }
                            if (value.length < 6) {
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Confirm Password Field
                        _buildModernTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar contraseña',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          isPasswordVisible: _isConfirmPasswordVisible,
                          onTogglePassword: () {
                            setState(() {
                              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor confirma tu contraseña';
                            }
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Register Button con estilo llamativo
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green[400]!,
                          Colors.green[600]!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          spreadRadius: 0,
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _handleRegister,
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
                            Icons.rocket_launch,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Crear mi cuenta',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Back to Login con estilo
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 16),
                          children: [
                            TextSpan(
                              text: '¿Ya tienes cuenta? ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            const TextSpan(
                              text: 'Iniciar sesión',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
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
        inputFormatters: inputFormatters,
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
          suffixText: suffixText,
          suffixStyle: TextStyle(
            color: Colors.purple[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
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

  Widget _buildDocumentTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.credit_card,
                  color: Colors.purple[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Tipo de documento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDocumentOption('DNI', Icons.badge),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDocumentOption('RUC', Icons.business),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentOption(String type, IconData icon) {
    bool isSelected = _selectedDocumentType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDocumentType = type;
          _documentController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple[500] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.purple[300]! : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentField() {
    int expectedLength = _selectedDocumentType == 'DNI' ? 8 : 11;
    return _buildModernTextField(
      controller: _documentController,
      label: 'Número de $_selectedDocumentType',
      icon: _selectedDocumentType == 'DNI' ? Icons.person : Icons.business,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(expectedLength),
      ],
      suffixText: '$expectedLength dígitos',
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingresa tu $_selectedDocumentType';
        }
        if (value.length != expectedLength) {
          return '$_selectedDocumentType debe tener $expectedLength dígitos';
        }
        if (_selectedDocumentType == 'RUC') {
          if (!value.startsWith('10') && !value.startsWith('20')) {
            return 'RUC debe empezar con 10 o 20';
          }
        }
        return null;
      },
    );
  }

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¡Cuenta creada exitosamente!\n$_selectedDocumentType: ${_documentController.text}\nCelular: ${_phoneController.text}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pushReplacementNamed(context, '/loading');
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _documentController.dispose();
    _phoneController.dispose(); // Nuevo dispose
    _addressController.dispose(); // Nuevo dispose
    super.dispose();
  }
}