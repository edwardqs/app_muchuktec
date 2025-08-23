// lib/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/services/user_session.dart';
import 'package:intl/intl.dart';

// URL base de tu API
const String apiUrl = 'http://10.0.2.2:8000/api';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos del formulario
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _dniController = TextEditingController();
  final _emailController = TextEditingController();
  final _genderController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _docTypeController = TextEditingController();

  // Controladores para el nuevo modal de contraseña
  final _currentPasswordController = TextEditingController(); // Nuevo controlador
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _docNumberMaxLength = 8; // Longitud máxima por defecto para DNI

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPasswordSaving = false; // Nuevo estado para el botón de cambio de contraseña

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _docTypeController.addListener(_updateDocNumberLength);
  }

  // --- Funciones de Lógica y Mapeo ---

  void _updateDocNumberLength() {
    setState(() {
      final docType = _docTypeController.text;
      _docNumberMaxLength = (docType == '1') ? 8 : 11;
    });
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
      return;
    }

    try {
      final url = Uri.parse('$apiUrl/getUser');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);

        _usernameController.text = userData['username'] ?? '';
        _emailController.text = userData['correo'] ?? '';
        _fullNameController.text = userData['nombres_completos'] ?? '';
        _dniController.text = userData['numerodoc'] ?? '';
        _phoneController.text = userData['telefono'] ?? '';
        _addressController.text = userData['direccion'] ?? '';
        _genderController.text = userData['genero'] ?? '';
        _birthDateController.text = userData['fecha_nacimiento'] ?? '';

        final docTypeFromBackend = userData['tipodoc']?.toString();
        _docTypeController.text = docTypeFromBackend ?? '1';

        print("Valor del backend para tipodoc: $docTypeFromBackend");

        _updateDocNumberLength();

        setState(() {
          _isLoading = false;
        });
      } else {
        _showSnackbar('Error al cargar los datos del perfil.', Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error al obtener datos del usuario: $e');
        _showSnackbar('Error de conexión. Inténtalo de nuevo.', Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
      return;
    }

    // CORRECCIÓN CLAVE: Convertir la cadena a entero antes de enviar
    final docTypeId = int.tryParse(_docTypeController.text);

    // Construir el cuerpo de la solicitud
    final requestBody = {
      'username': _usernameController.text,
      'correo': _emailController.text,
      'telefono': _phoneController.text,
      'direccion': _addressController.text,
      'genero': _genderController.text,
      'fecha_nacimiento': _birthDateController.text,
      'tipodoc_id': docTypeId,
      'numerodoc': _dniController.text,
    };

    // Imprimir el cuerpo de la solicitud para depuración
    print("Enviando al backend: ${json.encode(requestBody)}");

    try {
      final url = Uri.parse('$apiUrl/datospersonales/update');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSnackbar('¡Perfil actualizado exitosamente!', Colors.green);
        UserSession().setUserData(
          token: token,
          name: _fullNameController.text,
        );
        Navigator.of(context).pushReplacementNamed('/dashboard');

      } else {
        _showSnackbar('Error al actualizar el perfil. Código: ${response.statusCode}', Colors.red);
        print('Error response body: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        print('Error al actualizar el perfil: $e');
        _showSnackbar('Error de conexión. Inténtalo de nuevo.', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _updatePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
      return;
    }

    // Validación básica de los campos
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackbar('Todos los campos de contraseña son requeridos.', Colors.red);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackbar('Las contraseñas no coinciden.', Colors.red);
      return;
    }

    if (_newPasswordController.text.length < 8) {
      _showSnackbar('La nueva contraseña debe tener al menos 8 caracteres.', Colors.red);
      return;
    }

    setState(() {
      _isPasswordSaving = true;
    });

    // Envía los campos de forma correcta
    final requestBody = {
      'current_password': _currentPasswordController.text,
      'password': _newPasswordController.text,
      'password_confirmation': _confirmPasswordController.text,
    };

    try {
      // Usa el método PUT para coincidir con la ruta de Laravel
      final url = Uri.parse('$apiUrl/profile/password');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (mounted) {
        setState(() {
          _isPasswordSaving = false;
        });
      }

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop(); // Cierra el modal
        }
        _showSnackbar('Contraseña actualizada exitosamente.', Colors.green);
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Error desconocido';
        _showSnackbar('Error al cambiar la contraseña: $errorMessage', Colors.red);
        print('Error response body: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPasswordSaving = false;
        });
        print('Error al cambiar la contraseña: $e');
        _showSnackbar('Error de conexión. Inténtalo de nuevo.', Colors.red);
      }
    }
  }

  void _showPasswordChangeModal() {
    // Usamos showDialog para un modal en el centro de la pantalla
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Cambiar Contraseña',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A1B9A), // Púrpura oscuro
                ),
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      'Ingresa tu contraseña actual y la nueva.',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Nuevo campo para la contraseña actual
                    _buildEditableTextField(
                      controller: _currentPasswordController,
                      label: 'Contraseña Actual',
                      icon: Icons.lock_open_outlined,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu contraseña actual';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildEditableTextField(
                      controller: _newPasswordController,
                      label: 'Nueva Contraseña',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa una nueva contraseña';
                        }
                        if (value.length < 8) {
                          return 'Debe tener al menos 8 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildEditableTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar Contraseña',
                      icon: Icons.lock,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirma tu nueva contraseña';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Color(0xFF6A1B9A), // Púrpura oscuro
                    ),
                  ),
                  onPressed: () {
                    _currentPasswordController.clear();
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  onPressed: _isPasswordSaving ? null : () async {
                    setState(() {
                      _isPasswordSaving = true;
                    });
                    await _updatePassword();
                    if (mounted) {
                      setState(() {
                        _isPasswordSaving = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6A1B9A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isPasswordSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Actualizar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDateController.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd').parse(_birthDateController.text)
          : DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.purple[600],
            colorScheme: ColorScheme.light(primary: Colors.purple[600]!),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.white),
      )
          : Container(
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
          child: Column(
            children: [
              _buildCustomAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildUserAvatar(),
                        const SizedBox(height: 30),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [Colors.white, Colors.purple[100]!],
                          ).createShader(bounds),
                          child: const Text(
                            'Editar Perfil',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Actualiza tu información personal',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        _buildFormContainer(),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          // Nombres completos (no editable)
          _buildReadOnlyField(
            controller: _fullNameController,
            label: 'Nombres completos',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
          // Fila para tipo y número de documento (ambos no editables)
          Row(
            children: [
              Expanded(
                child: _buildReadOnlyField(
                  controller: _docTypeController, // Asumiendo un controlador para el tipo de documento
                  label: 'Tipo',
                  icon: Icons.description_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildReadOnlyField(
                  controller: _dniController,
                  label: 'Número de documento',
                  icon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Username (editable)
          _buildEditableTextField(
            controller: _usernameController,
            label: 'Username',
            icon: Icons.alternate_email,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu username';
              }
              if (value.length < 3) {
                return 'El username debe tener al menos 3 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          // Número de celular (editable)
          _buildEditableTextField(
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
          // Dirección completa (editable)
          _buildEditableTextField(
            controller: _addressController,
            label: 'Dirección completa',
            icon: Icons.location_on_outlined,
            keyboardType: TextInputType.streetAddress,
            maxLines: 2,
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
          // Género (no editable)
          _buildReadOnlyField(
            controller: _genderController, // Asumiendo un controlador para el género
            label: 'Género',
            icon: Icons.transgender_outlined,
          ),
          const SizedBox(height: 20),
          // Fecha de nacimiento (no editable)
          _buildReadOnlyField(
            controller: _birthDateController, // Asumiendo un controlador para la fecha de nacimiento
            label: 'Fecha de nacimiento',
            icon: Icons.cake_outlined,
          ),
          const SizedBox(height: 20),
          // Correo electrónico (editable)
          _buildEditableTextField(
            controller: _emailController,
            label: 'Correo electrónico',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu correo electrónico';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }


  Widget _buildSaveButton() {
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
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'Guardar Cambios',
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
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Spacer(),
          Text(
            'Mi Perfil',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                _showOptionsMenu();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
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
            Icons.person,
            size: 50,
            color: Colors.purple[700],
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.purple[600],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.edit,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // Se añadió el parámetro `obscureText` para ocultar la contraseña
  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        obscureText: obscureText,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          suffixIcon: Icon(
            Icons.lock_outline,
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }

  // Se añadió el parámetro `obscureText` para ocultar la contraseña
  Widget _buildEditableTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    int? maxLines,
    String? Function(String?)? validator,
    bool obscureText = false,
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
        inputFormatters: inputFormatters,
        maxLines: maxLines ?? 1,
        obscureText: obscureText,
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


  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.purple[600]),
              title: const Text('Cambiar foto de perfil'),
              onTap: () {
                Navigator.pop(context);
                // Implementar cambio de foto
              },
            ),
            ListTile(
              leading: Icon(Icons.security, color: Colors.purple[600]),
              title: const Text('Cambiar contraseña'),
              onTap: () {
                Navigator.pop(context);
                _showPasswordChangeModal();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red[600]),
              title: const Text('Eliminar cuenta'),
              onTap: () {
                Navigator.pop(context);
                // Implementar eliminación de cuenta
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _fullNameController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _genderController.dispose();
    _birthDateController.dispose();
    _docTypeController.dispose();
    // No olvides liberar los nuevos controladores
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
