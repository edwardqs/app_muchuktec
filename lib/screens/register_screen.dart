// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:app_muchik/config/constants.dart';

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
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthDateController = TextEditingController(); // Aquí se agregó la declaración

  // Gestión de estado con ValueNotifier para optimización
  final ValueNotifier<String> _selectedDocumentType =
  ValueNotifier<String>('DNI');
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isConfirmPasswordVisible =
  ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _selectedGender = ValueNotifier<String?>(null);
  final ValueNotifier<DateTime?> _selectedDate = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String> _errorMessage = ValueNotifier<String>('');

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _documentController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthDateController.dispose(); // Asegúrate de que se libere correctamente
    _selectedDocumentType.dispose();
    _isPasswordVisible.dispose();
    _isConfirmPasswordVisible.dispose();
    _isLoading.dispose();
    _selectedGender.dispose();
    _selectedDate.dispose();
    _errorMessage.dispose();
    super.dispose();
  }

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
            // Llamamos al getter para construir el contenido
            child: _RegisterContent,
          ),
        ),
      ),
    );
  }

  // Getter que devuelve el contenido completo del formulario
  Widget get _RegisterContent {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 40),
          const _HeaderSection(),
          const SizedBox(height: 40),
          _buildFormContainer(),
          const SizedBox(height: 32),
          _buildRegisterButton(),
          const SizedBox(height: 24),
          _buildLoginButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFormContainer() {
    return Container(
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
          // Mensaje de error centralizado
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
          _buildDocumentTypeSelector(),
          const SizedBox(height: 20),
          ValueListenableBuilder<String>(
            valueListenable: _selectedDocumentType,
            builder: (context, type, child) {
              return _buildDocumentField(type);
            },
          ),
          const SizedBox(height: 20),
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
          ValueListenableBuilder<String?>(
            valueListenable: _selectedGender,
            builder: (context, gender, child) {
              return _buildGenderSelector(gender);
            },
          ),
          const SizedBox(height: 20),
          _buildBirthDateField(),
          const SizedBox(height: 20),
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
                  if (value.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<bool>(
            valueListenable: _isConfirmPasswordVisible,
            builder: (context, isVisible, child) {
              return _buildModernTextField(
                controller: _confirmPasswordController,
                label: 'Confirmar contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
                isPasswordVisible: isVisible,
                onTogglePassword: () {
                  _isConfirmPasswordVisible.value = !isVisible;
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, isLoading, child) {
        return Container(
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
            onPressed: isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            )
                : const Row(
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
        );
      },
    );
  }

  Widget _buildLoginButton() {
    return Container(
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
    bool readOnly = false,
    VoidCallback? onTap,
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
        readOnly: readOnly,
        onTap: onTap,
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
    return ValueListenableBuilder<String>(
      valueListenable: _selectedDocumentType,
      builder: (context, type, child) {
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
      },
    );
  }

  Widget _buildDocumentOption(String type, IconData icon) {
    bool isSelected = _selectedDocumentType.value == type;
    return GestureDetector(
      onTap: () {
        _selectedDocumentType.value = type;
        _documentController.clear();
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

  Widget _buildDocumentField(String type) {
    int expectedLength = type == 'DNI' ? 8 : 11;
    return _buildModernTextField(
      controller: _documentController,
      label: 'Número de $type',
      icon: type == 'DNI' ? Icons.person : Icons.business,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(expectedLength),
      ],
      suffixText: '$expectedLength dígitos',
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingresa tu $type';
        }
        if (value.length != expectedLength) {
          return '$type debe tener $expectedLength dígitos';
        }
        if (type == 'RUC') {
          if (!value.startsWith('10') && !value.startsWith('20')) {
            return 'RUC debe empezar con 10 o 20';
          }
        }
        return null;
      },
    );
  }

  Widget _buildGenderSelector(String? gender) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.wc_outlined,
              color: Colors.purple[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: gender,
              decoration: InputDecoration(
                labelText: 'Género',
                labelStyle: TextStyle(
                  color: Colors.purple[600],
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
              items: ['Masculino', 'Femenino'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                _selectedGender.value = newValue;
              },
              validator: (value) {
                if (value == null) {
                  return 'Por favor selecciona tu género';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthDateField() {
    return _buildModernTextField(
      controller: _birthDateController,
      label: 'Fecha de nacimiento',
      icon: Icons.calendar_today,
      readOnly: true,
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate.value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.purple[600]!,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black87,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.purple[600],
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && picked != _selectedDate.value) {
          _selectedDate.value = picked;
          _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingresa tu fecha de nacimiento';
        }
        return null;
      },
    );
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      _isLoading.value = true;
      _errorMessage.value = '';

      int tipoDocumento = _selectedDocumentType.value == 'DNI' ? 1 : 2;

      String? generoParaEnvio;
      if (_selectedGender.value == 'Masculino') {
        generoParaEnvio = 'M';
      } else if (_selectedGender.value == 'Femenino') {
        generoParaEnvio = 'F';
      }

      final Map<String, dynamic> requestBody = {
        'username': _usernameController.text,
        'correo': _emailController.text,
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
        'nombres_completos': _nameController.text,
        'tipodoc': tipoDocumento,
        'numerodoc': _documentController.text,
        'direccion': _addressController.text,
        'telefono': _phoneController.text,
        'genero': generoParaEnvio,
        'fecha_nacimiento': _birthDateController.text,
      };

      try {
        final response = await http.post(
          Uri.parse('$API_BASE_URL/register'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(requestBody),
        );

        if (response.statusCode == 201) {
          _showSnackBar(
              '✅ Registro exitoso. Ahora puedes iniciar sesión.', Colors.green[600]!);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        } else {
          final responseData = json.decode(response.body);
          if (responseData['errors'] != null) {
            final firstError = responseData['errors'].values.first[0];
            _errorMessage.value = firstError;
          } else {
            _errorMessage.value =
                responseData['message'] ?? 'Error desconocido al registrar.';
          }
        }
      } catch (e) {
        _errorMessage.value = 'No se pudo conectar al servidor: $e';
        print('Error en el registro: $e');
      } finally {
        _isLoading.value = false;
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// Widgets Estáticos para reusar y mejorar el rendimiento
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
      ],
    );
  }
}
