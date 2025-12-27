// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/services/user_session.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_muchik/config/constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _dniController = TextEditingController();
  final _emailController = TextEditingController();
  final _genderController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _docTypeController = TextEditingController();

  // Controladores Password
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;
  bool _isUploadingImage = false;
  int _docNumberMaxLength = 8;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPasswordSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _docTypeController.addListener(_updateDocNumberLength);
  }

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
      final url = Uri.parse('$API_BASE_URL/getUser');
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

        String relativePath = userData['ruta_imagen'] ?? '';
        if (relativePath.startsWith('/')) {
          relativePath = relativePath.substring(1);
        }
        _usernameController.text = userData['username'] ?? '';
        _emailController.text = userData['correo'] ?? '';
        _fullNameController.text = userData['nombres_completos'] ?? '';
        _dniController.text = userData['numerodoc'] ?? '';
        _phoneController.text = userData['telefono'] ?? '';
        _addressController.text = userData['direccion'] ?? '';
        _genderController.text = userData['genero'] ?? '';
        _birthDateController.text = userData['fecha_nacimiento'] ?? '';

        _profileImageUrl = relativePath.isNotEmpty ? '$STORAGE_BASE_URL/$relativePath' : null;

        final genderFromBackend = userData['genero']?.toString();
        _genderController.text = (genderFromBackend == 'M') ? 'Masculino' : 'Femenino';

        final docTypeFromBackend = userData['tipodoc']?.toString();
        _docTypeController.text = (docTypeFromBackend == '1') ? 'DNI' : 'RUC';

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

    // Convertir texto visual a ID para el backend
    int docTypeId = _docTypeController.text == 'DNI' ? 1 : 2;
    // Ajustar lógica según tu backend si es necesario,
    // pero idealmente deberías guardar el ID real en una variable aparte si '1'/'2' no es directo.
    // Como en loadData lo conviertes a texto, aquí asumimos simple reversión o envío tal cual si el backend acepta string.
    // Si el backend espera '1' o '2':
    // int tipodocId = (_docTypeController.text == 'DNI') ? 1 : 2;

    // Asumiendo que guardaste el valor real o usas la lógica inversa:
    final requestBody = {
      'username': _usernameController.text,
      'correo': _emailController.text,
      'telefono': _phoneController.text,
      'direccion': _addressController.text,
      'genero': _genderController.text == 'Masculino' ? 'M' : 'F', // Ajuste para backend
      'fecha_nacimiento': _birthDateController.text,
      'tipodoc_id': (_docTypeController.text == 'DNI') ? 1 : 2,
      'numerodoc': _dniController.text,
    };

    try {
      final url = Uri.parse('$API_BASE_URL/datospersonales/update');
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
        _showSnackbar('¡Perfil actualizado exitosamente!', cVerdeMenta);
        UserSession().setUserData(
          token: token,
          name: _fullNameController.text,
        );
        Navigator.of(context).pushReplacementNamed('/dashboard');

      } else {
        _showSnackbar('Error al actualizar: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error de conexión.', Colors.red);
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
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackbar('Todos los campos son requeridos.', Colors.red);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackbar('Las contraseñas no coinciden.', Colors.red);
      return;
    }

    if (_newPasswordController.text.length < 8) {
      _showSnackbar('Mínimo 8 caracteres.', Colors.red);
      return;
    }

    setState(() {
      _isPasswordSaving = true;
    });

    final requestBody = {
      'current_password': _currentPasswordController.text,
      'password': _newPasswordController.text,
      'password_confirmation': _confirmPasswordController.text,
    };

    try {
      final url = Uri.parse('$API_BASE_URL/profile/password');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (mounted) setState(() { _isPasswordSaving = false; });

      if (response.statusCode == 200) {
        if (mounted) Navigator.of(context).pop();
        _showSnackbar('Contraseña actualizada.', cVerdeMenta);
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        final errorData = json.decode(response.body);
        _showSnackbar(errorData['message'] ?? 'Error desconocido', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isPasswordSaving = false; });
        _showSnackbar('Error de conexión.', Colors.red);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;
      await _uploadImageToBackend(File(image.path));
    } catch (e) {
      _showSnackbar('No se pudo seleccionar la imagen.', Colors.red);
    }
  }

  Future<void> _uploadImageToBackend(File imageFile) async {
    setState(() {
      _isUploadingImage = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    final url = Uri.parse('$API_BASE_URL/usuario/upload-photo');
    final request = http.MultipartRequest('POST', url);

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('profile_photo', imageFile.path),
    );

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        setState(() {
          _profileImageUrl = jsonResponse['profile_photo_url'];
        });
        _showSnackbar('Foto actualizada.', cVerdeMenta);
      } else {
        _showSnackbar('Error al subir la imagen.', Colors.red);
      }
    } catch (e) {
      _showSnackbar('Error de conexión.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _showPasswordChangeModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: cBlanco,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Cambiar Contraseña',
                style: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo),
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('Ingresa tu contraseña actual y la nueva.', style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(height: 20),
                    // Usamos los inputs con estilo nuevo dentro del modal también
                    _buildModalInput(_currentPasswordController, 'Contraseña Actual', Icons.lock_open_outlined, true),
                    const SizedBox(height: 16),
                    _buildModalInput(_newPasswordController, 'Nueva Contraseña', Icons.lock_outline, true),
                    const SizedBox(height: 16),
                    _buildModalInput(_confirmPasswordController, 'Confirmar Contraseña', Icons.lock, true),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancelar', style: TextStyle(color: cAzulPetroleo)),
                  onPressed: () {
                    _currentPasswordController.clear();
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  onPressed: _isPasswordSaving ? null : () async {
                    setState(() { _isPasswordSaving = true; });
                    await _updatePassword();
                    if (mounted) setState(() { _isPasswordSaving = false; });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cAzulPetroleo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isPasswordSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Actualizar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Input simple para el modal (para no usar el estilo full del form principal que tiene label blanco)
  Widget _buildModalInput(TextEditingController controller, String hint, IconData icon, bool obscure) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: cAzulPetroleo),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cVerdeMenta, width: 2), borderRadius: BorderRadius.circular(12)),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cAzulPetroleo))
          : Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cAzulPetroleo, // Fondo oscuro superior
              const Color(0xFF1D3540), // Tono más oscuro abajo
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
                        const Text(
                          'Editar Perfil',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Actualiza tu información personal',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // CONTENEDOR TRANSPARENTE DEL FORMULARIO
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
        color: Colors.white.withOpacity(0.1), // Glassmorphism sutil
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Campos NO editables
          _buildReadOnlyField(
            controller: _fullNameController,
            label: 'Nombres completos',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildReadOnlyField(
                  controller: _docTypeController,
                  label: 'Tipo',
                  icon: Icons.description_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildReadOnlyField(
                  controller: _dniController,
                  label: 'Número',
                  icon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Campos Editables con Estilo Login (Label arriba)
          _buildEditableTextField(
            controller: _usernameController,
            label: 'Username',
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: 20),
          _buildEditableTextField(
            controller: _phoneController,
            label: 'Número de celular',
            icon: Icons.phone_android,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
          ),
          const SizedBox(height: 20),
          _buildEditableTextField(
            controller: _addressController,
            label: 'Dirección completa',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 20),

          // Más campos no editables
          _buildReadOnlyField(
            controller: _genderController,
            label: 'Género',
            icon: Icons.transgender_outlined,
          ),
          const SizedBox(height: 20),
          _buildReadOnlyField(
            controller: _birthDateController,
            label: 'Fecha de nacimiento',
            icon: Icons.cake_outlined,
          ),
          const SizedBox(height: 20),
          _buildEditableTextField(
            controller: _emailController,
            label: 'Correo electrónico',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }

  // --- ESTILO BASADO EN LA IMAGEN LOGIN ---
  Widget _buildEditableTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label arriba, fuera del input
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        // Input Box Blanco/Gris Claro
        Container(
          decoration: BoxDecoration(
            color: cGrisClaro, // Fondo claro
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines ?? 1,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cAzulPetroleo, // Texto oscuro
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: cAzulPetroleo.withOpacity(0.7)),
              border: InputBorder.none, // Sin borde visible por defecto
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Ingresa tu $label',
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Campo requerido';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7), // Label un poco más apagado para read-only
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), // Fondo semi-transparente para read-only
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white, // Texto blanco para contraste
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white70),
              suffixIcon: const Icon(Icons.lock_outline, color: Colors.white54, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: cVerdeMenta, // Botón Verde Menta
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: _isSaving
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.save_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Guardar Cambios',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Planifiko',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showOptionsMenu,
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
            color: cBlanco,
            border: Border.all(color: cVerdeMenta, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 10,
              )
            ],
          ),
          child: _isUploadingImage
              ? Center(child: CircularProgressIndicator(color: cVerdeMenta))
              : ClipOval(
            child: _profileImageUrl != null
                ? Image.network(_profileImageUrl!, fit: BoxFit.cover)
                : Icon(Icons.person, size: 60, color: cAzulPetroleo),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadImage,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cVerdeMenta,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cBlanco,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.security, color: cAzulPetroleo),
              title: Text('Cambiar contraseña', style: TextStyle(color: cAzulPetroleo)),
              onTap: () {
                Navigator.pop(context);
                _showPasswordChangeModal();
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}