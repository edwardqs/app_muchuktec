// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:app_muchik/config/constants.dart';
import 'package:app_muchik/screens/verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // --- DEFINICIÓN DE COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _documentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthDateController = TextEditingController();

  // Gestión de estado con ValueNotifier
  final ValueNotifier<String> _selectedDocumentType = ValueNotifier<String>('DNI');
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isConfirmPasswordVisible = ValueNotifier<bool>(false);
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
    _birthDateController.dispose();
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
      backgroundColor: cAzulPetroleo, // Fondo base por si falla el gradiente
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cAzulPetroleo, // #264653
              Color.lerp(cAzulPetroleo, cVerdeMenta, 0.3)!, // Transición suave
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _RegisterContent,
          ),
        ),
      ),
    );
  }

  Widget get _RegisterContent {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          // Header simplificado (sin logo, solo texto limpio)
          const _HeaderSection(),
          const SizedBox(height: 30),
          _buildFormContainer(),
          const SizedBox(height: 30),
          _buildRegisterButton(),
          const SizedBox(height: 16),
          _buildLoginButton(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFormContainer() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cBlanco, // Fondo blanco para el formulario
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
        children: [
          // Mensaje de error
          ValueListenableBuilder<String>(
            valueListenable: _errorMessage,
            builder: (context, errorMsg, child) {
              if (errorMsg.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
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
            validator: (value) => (value == null || value.isEmpty)
                ? 'Ingresa tu nombre completo'
                : null,
          ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _usernameController,
            label: 'Username',
            icon: Icons.alternate_email,
            validator: (value) => (value == null || value.isEmpty)
                ? 'Ingresa tu username'
                : null,
          ),
          const SizedBox(height: 20),
          _buildDocumentTypeSelector(),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: _selectedDocumentType,
            builder: (context, type, child) {
              return _buildDocumentField(type);
            },
          ),
          const SizedBox(height: 16),
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
              if (value == null || value.isEmpty) return 'Ingresa tu celular';
              if (value.length != 9) return 'Debe tener 9 dígitos';
              if (!value.startsWith('9')) return 'Debe empezar con 9';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _addressController,
            label: 'Dirección completa',
            icon: Icons.location_on_outlined,
            keyboardType: TextInputType.streetAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa tu dirección';
              if (value.length < 10) return 'Dirección muy corta';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _emailController,
            label: 'Correo electrónico',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa tu email';
              if (!value.contains('@')) return 'Email inválido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<String?>(
            valueListenable: _selectedGender,
            builder: (context, gender, child) {
              return _buildGenderSelector(gender);
            },
          ),
          const SizedBox(height: 16),
          _buildBirthDateField(),
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
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa contraseña';
                  if (value.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: _isConfirmPasswordVisible,
            builder: (context, isVisible, child) {
              return _buildModernTextField(
                controller: _confirmPasswordController,
                label: 'Confirmar contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
                isPasswordVisible: isVisible,
                onTogglePassword: () => _isConfirmPasswordVisible.value = !isVisible,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Confirma contraseña';
                  if (value != _passwordController.text) return 'No coinciden';
                  return null;
                },
              );
            },
          ),
        ],
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
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      obscureText: isPassword ? !(isPasswordVisible ?? false) : false,
      inputFormatters: inputFormatters,
      // ESTO HACE QUE EL ERROR SE QUITE AL ESCRIBIR
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: cAzulPetroleo,
      ),
      decoration: InputDecoration(
        labelText: label,
        // Configuración para que el label se vea bien
        alignLabelWithHint: true,
        floatingLabelStyle: TextStyle(
            color: cVerdeMenta,
            fontWeight: FontWeight.bold
        ),
        labelStyle: TextStyle(
          color: cAzulPetroleo.withOpacity(0.6),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          color: cAzulPetroleo.withOpacity(0.7),
          size: 22,
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            isPasswordVisible ?? false
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: cVerdeMenta,
          ),
          onPressed: onTogglePassword,
        )
            : null,
        suffixText: suffixText,
        suffixStyle: TextStyle(
          color: cAzulPetroleo.withOpacity(0.5),
          fontSize: 12,
        ),
        // Bordes y Rellenos limpios
        filled: true,
        fillColor: cGrisClaro, // #F4F4F4
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: cVerdeMenta,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red.shade400,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red.shade400,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDocumentTypeSelector() {
    return ValueListenableBuilder<String>(
      valueListenable: _selectedDocumentType,
      builder: (context, type, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo de documento',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cAzulPetroleo,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDocumentOption('DNI', Icons.badge),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDocumentOption('RUC', Icons.business),
                ),
              ],
            ),
          ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? cVerdeMenta : cGrisClaro,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cVerdeMenta : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? cBlanco : cAzulPetroleo.withOpacity(0.6),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? cBlanco : cAzulPetroleo.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                fontSize: 15,
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
        if (value == null || value.isEmpty) return 'Ingresa tu $type';
        if (value.length != expectedLength) {
          return '$type debe tener $expectedLength dígitos';
        }
        if (type == 'RUC') {
          if (!value.startsWith('10') && !value.startsWith('20')) {
            return 'RUC inválido (10 o 20)';
          }
        }
        return null;
      },
    );
  }

  Widget _buildGenderSelector(String? gender) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cGrisClaro,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.wc, color: cAzulPetroleo.withOpacity(0.7), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: gender,
              icon: Icon(Icons.keyboard_arrow_down, color: cAzulPetroleo),
              decoration: InputDecoration(
                labelText: 'Género',
                labelStyle: TextStyle(
                  color: cAzulPetroleo.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              dropdownColor: cBlanco,
              items: ['Masculino', 'Femenino'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(color: cAzulPetroleo),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                _selectedGender.value = newValue;
              },
              validator: (value) => (value == null) ? 'Selecciona género' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
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
                primaryColor: cVerdeMenta,
                colorScheme: ColorScheme.light(
                  primary: cVerdeMenta,
                  onPrimary: cBlanco,
                  surface: cBlanco,
                  onSurface: cAzulPetroleo,
                ),
                dialogBackgroundColor: cBlanco,
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
      validator: (value) => (value == null || value.isEmpty) ? 'Ingresa fecha' : null,
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
            color: cVerdeMenta, // Verde Menta oficial
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cVerdeMenta.withOpacity(0.4),
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
                ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cBlanco),
                strokeWidth: 2,
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rocket_launch, color: cBlanco, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Crear mi cuenta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cBlanco,
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
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16),
          children: [
            TextSpan(
              text: '¿Ya tienes cuenta? ',
              style: TextStyle(color: cBlanco.withOpacity(0.9)),
            ),
            TextSpan(
              text: 'Iniciar sesión',
              style: TextStyle(
                color: cBlanco,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: cBlanco,
              ),
            ),
          ],
        ),
      ),
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
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => VerificationScreen(
                  email: _emailController.text,
                ),
              ),
            );
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
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    // Logo eliminado, solo textos limpios y modernos
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¡Únete a nosotros!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Completa tus datos para comenzar.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}