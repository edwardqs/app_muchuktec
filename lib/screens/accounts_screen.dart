import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app_muchik/config/constants.dart';
// ✅ 1. Importar el widget del anuncio
import 'package:app_muchik/widgets/ad_banner_widget.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  List<dynamic> _userProfiles = [];
  bool _isLoading = true;
  String? _accessToken;
  int? _selectedAccountId;
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndFetchProfiles();
  }

  Future<void> _loadAccessTokenAndFetchProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');

    if (_accessToken != null) {
      await _fetchUserProfiles();
      _loadSelectedAccount();
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró un token de sesión. Por favor, inicie sesión.')),
      );
    }
  }

  Future<void> _loadSelectedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final int? savedId = prefs.getInt('idCuenta');
    setState(() {
      _selectedAccountId = savedId;
    });
  }

  Future<void> _saveSelectedAccount(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('idCuenta', id);
    setState(() {
      _selectedAccountId = id;
    });
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
            (route) => false,
      );
    }
  }

  Future<void> _fetchUserProfiles() async {
    if (_accessToken == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/cuentas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _userProfiles = data;
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar los perfiles.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print("Error al obtener perfiles: $e");
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al conectar con el servidor.')),
      );
    }
  }

  // --- MODAL AGREGAR ---
  void _showAddProfileModal() {
    if (_userProfiles.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No puedes tener más de 4 perfiles.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Agregar Nuevo Perfil', style: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo)),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'Nombre del perfil',
              filled: true,
              fillColor: cGrisClaro,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _addProfile(nameController.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cVerdeMenta,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Agregar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addProfile(String nombre) async {
    if (_accessToken == null) return;

    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/cuentas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode({'nombre': nombre}),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Perfil agregado exitosamente.'), backgroundColor: cVerdeMenta),
          );
        }
        _fetchUserProfiles();
      } else {
        throw Exception('Failed to add profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al agregar el perfil.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- MODAL ELIMINAR ---
  void _showDeleteConfirmation(dynamic profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirmar Eliminación', style: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo)),
        content: Text('¿Estás seguro de que deseas eliminar el perfil "${profile['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteProfile(profile['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProfile(int id) async {
    if (_accessToken == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$API_BASE_URL/cuentas/$id'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Perfil eliminado exitosamente.'), backgroundColor: cVerdeMenta),
          );
        }
        _fetchUserProfiles();
      } else {
        throw Exception('Failed to delete profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar el perfil.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- MODAL EDITAR ---
  void _showEditProfileDialog(dynamic profile) {
    _editNameController.text = profile['nombre'];
    _editDescriptionController.text = profile['descripcion'] ?? '';
    File? newImage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          setState(() {
                            newImage = File(pickedFile.path);
                          });
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cGrisClaro,
                          border: Border.all(color: cVerdeMenta, width: 2),
                        ),
                        child: ClipOval(
                          child: newImage != null
                              ? Image.file(newImage!, fit: BoxFit.cover)
                              : (profile['ruta_imagen'] != null
                              ? CachedNetworkImage(
                            imageUrl: '$STORAGE_BASE_URL/${profile['ruta_imagen']}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => CircularProgressIndicator(color: cVerdeMenta),
                            errorWidget: (context, url, error) => Icon(Icons.person, size: 50, color: Colors.grey[400]),
                          )
                              : Icon(Icons.person, size: 50, color: Colors.grey[400])),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _editNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        filled: true,
                        fillColor: cGrisClaro,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _editDescriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        filled: true,
                        fillColor: cGrisClaro,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _editNameController.clear();
                    _editDescriptionController.clear();
                  },
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateProfile(
                      profile['id'],
                      _editNameController.text,
                      _editDescriptionController.text,
                      newImage,
                    );
                    _editNameController.clear();
                    _editDescriptionController.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cVerdeMenta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateProfile(int id, String newName, String newDescription, File? newImage) async {
    if (_accessToken == null) return;

    if (newName.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El nombre no puede estar vacío.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$API_BASE_URL/cuentas/$id'));
      request.headers['Authorization'] = 'Bearer $_accessToken';
      request.fields['nombre'] = newName.trim();
      request.fields['descripcion'] = newDescription.trim();
      request.fields['_method'] = 'PUT';

      if (newImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('imagen', newImage.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Perfil actualizado con éxito.'), backgroundColor: cVerdeMenta),
          );
        }
        _fetchUserProfiles();
      } else {
        throw Exception('Failed to update profile: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar el perfil.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('idCuenta');
    AuthService().logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (Route<dynamic> route) => false,
      );
    }
  }

  void _showSelectionConfirmation(dynamic profile) {
    String displayName = profile['nombre'];
    if (_userProfiles.isNotEmpty && profile == _userProfiles[0]) {
      if (displayName.length > 2 && displayName.endsWith('-1')) {
        displayName = displayName.substring(0, displayName.length - 2);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirmar Selección', style: TextStyle(fontWeight: FontWeight.bold, color: cAzulPetroleo)),
        content: Text('¿Quieres usar el perfil "$displayName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveSelectedAccount(profile['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cVerdeMenta,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Seleccionar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cGrisClaro, // Fondo oficial #F4F4F4
      appBar: AppBar(
        title: const Text('Perfiles de Usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: cAzulPetroleo, // Fondo oficial #264653
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),

      // ✅ 2. Aquí integramos el Banner en el BottomSheet
      bottomSheet: Container(
        color: cGrisClaro, // Para que el fondo coincida
        width: double.infinity,
        child: const AdBannerWidget(), // El anuncio se muestra aquí
      ),

      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cVerdeMenta))
          : Padding(
        padding: const EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: 80.0 // ✅ IMPORTANTE: Espacio extra abajo para que el banner no tape los perfiles
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Quién está usando?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: cAzulPetroleo,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.8,
                ),
                itemCount: _userProfiles.length < 4
                    ? _userProfiles.length + 1
                    : _userProfiles.length,
                itemBuilder: (context, index) {
                  // Botón de agregar
                  if (index == _userProfiles.length && _userProfiles.length < 4) {
                    return _AddProfileButton(
                      onTap: _showAddProfileModal,
                      cVerdeMenta: cVerdeMenta,
                      cAzulPetroleo: cAzulPetroleo,
                    );
                  }

                  final profile = _userProfiles[index];
                  bool isSelected = _selectedAccountId == profile['id'];
                  String rawName = profile['nombre'];
                  String displayName = rawName;

                  if (index == 0 && rawName.length > 2 && rawName.endsWith('-1')) {
                    displayName = rawName.substring(0, rawName.length - 2);
                  }

                  return _ProfileItem(
                    name: displayName,
                    imagePath: profile['ruta_imagen'] != null
                        ? '$STORAGE_BASE_URL/${profile['ruta_imagen']}'
                        : null,
                    onEdit: () => _showEditProfileDialog(profile),
                    onDelete: () => _showDeleteConfirmation(profile),
                    onTap: () => _showSelectionConfirmation(profile),
                    canDelete: index > 0,
                    isSelected: isSelected,
                    cAzulPetroleo: cAzulPetroleo,
                    cVerdeMenta: cVerdeMenta,
                    cBlanco: cBlanco,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para un ítem de perfil
class _ProfileItem extends StatelessWidget {
  final String name;
  final String? imagePath;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final bool canDelete;
  final bool isSelected;
  final Color cAzulPetroleo;
  final Color cVerdeMenta;
  final Color cBlanco;

  const _ProfileItem({
    required this.name,
    this.imagePath,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    this.canDelete = true,
    this.isSelected = false,
    required this.cAzulPetroleo,
    required this.cVerdeMenta,
    required this.cBlanco,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: cVerdeMenta, width: 3) : null,
          boxShadow: [
            BoxShadow(
              color: cAzulPetroleo.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: imagePath == null
                        ? LinearGradient(
                      colors: [cVerdeMenta.withOpacity(0.4), cVerdeMenta],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: imagePath != null
                      ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: imagePath!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(child: CircularProgressIndicator(color: cVerdeMenta)),
                      errorWidget: (context, url, error) => Icon(
                        Icons.person,
                        size: 45,
                        color: cBlanco,
                      ),
                    ),
                  )
                      : Icon(
                    Icons.person,
                    size: 45,
                    color: cBlanco,
                  ),
                ),
                const SizedBox(height: 12),
                // Nombre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cAzulPetroleo,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_rounded, color: cVerdeMenta),
                      onPressed: onEdit,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    if (canDelete)
                      IconButton(
                        icon: Icon(Icons.delete_rounded, color: Colors.red[400]),
                        onPressed: onDelete,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ],
            ),
            // Check de seleccionado
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.check_circle,
                  color: cVerdeMenta,
                  size: 28,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Widget para el botón de agregar perfil
class _AddProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color cVerdeMenta;
  final Color cAzulPetroleo;

  const _AddProfileButton({
    required this.onTap,
    required this.cVerdeMenta,
    required this.cAzulPetroleo,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cVerdeMenta.withOpacity(0.5), width: 2, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: cVerdeMenta.withOpacity(0.5), width: 2),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 40,
                color: cVerdeMenta,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Agregar Perfil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cAzulPetroleo.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}