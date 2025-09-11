import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Importamos el nuevo paquete

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final String _baseUrl = 'http://10.0.2.2:8000/api';
  final String STORAGE_BASE_URL = 'http://10.0.2.2:8000/storage';

  List<dynamic> _userProfiles = [];
  bool _isLoading = true;
  String? _accessToken;
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
      _fetchUserProfiles();
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
        Uri.parse('$_baseUrl/cuentas'),
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
          title: const Text('Agregar Nuevo Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'Nombre del perfil',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                backgroundColor: Colors.blueAccent,
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
        Uri.parse('$_baseUrl/cuentas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode({'nombre': nombre}),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil agregado exitosamente.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
        }
        _fetchUserProfiles();
      } else {
        throw Exception('Failed to add profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al agregar el perfil.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteConfirmation(dynamic profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Eliminación', style: TextStyle(fontWeight: FontWeight.bold)),
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
        Uri.parse('$_baseUrl/cuentas/$id'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil eliminado exitosamente.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
        }
        _fetchUserProfiles();
      } else {
        throw Exception('Failed to delete profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar el perfil.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }

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
              title: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sección de la imagen
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
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey.shade400, width: 2),
                        ),
                        child: ClipOval(
                          child: newImage != null
                              ? Image.file(
                            newImage!,
                            fit: BoxFit.cover,
                          )
                              : (profile['ruta_imagen'] != null
                              ? CachedNetworkImage( // Usamos CachedNetworkImage aquí también
                            imageUrl: '$STORAGE_BASE_URL/${profile['ruta_imagen']}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => Icon(Icons.person, size: 50, color: Colors.grey[600]),
                          )
                              : Icon(Icons.person, size: 50, color: Colors.grey[600])),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Campo para el nombre
                    TextField(
                      controller: _editNameController,
                      decoration: InputDecoration(
                        hintText: 'Nombre del perfil',
                        labelText: 'Nombre',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Campo para la descripción
                    TextField(
                      controller: _editDescriptionController,
                      decoration: InputDecoration(
                        hintText: 'Descripción del perfil',
                        labelText: 'Descripción',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    backgroundColor: Colors.blueAccent,
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
      // Usar MultipartRequest para enviar el archivo y los datos
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/cuentas/$id'));
      request.headers['Authorization'] = 'Bearer $_accessToken';
      request.fields['nombre'] = newName.trim();
      request.fields['descripcion'] = newDescription.trim();
      request.fields['_method'] = 'PUT'; // Sobrescribir el método HTTP a PUT

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
            const SnackBar(content: Text('Perfil actualizado con éxito.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
        }
        _fetchUserProfiles();
      } else {
        throw Exception('Failed to update profile: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar el perfil.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    AuthService().logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text('Perfiles de Usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.indigo,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Quién está usando?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 32,
                  mainAxisSpacing: 32,
                  childAspectRatio: 0.8,
                ),
                itemCount: _userProfiles.length < 4
                    ? _userProfiles.length + 1
                    : _userProfiles.length,
                itemBuilder: (context, index) {
                  if (index == _userProfiles.length && _userProfiles.length < 4) {
                    return _AddProfileButton(onTap: _showAddProfileModal);
                  }
                  final profile = _userProfiles[index];
                  // Pasa `canDelete` como `false` solo para el primer perfil (índice 0)
                  return _ProfileItem(
                    name: profile['nombre'],
                    // Lógica para determinar la ruta de la imagen
                    imagePath: profile['ruta_imagen'] != null
                        ? '$STORAGE_BASE_URL/${profile['ruta_imagen']}'
                        : null,
                    onEdit: () => _showEditProfileDialog(profile),
                    onDelete: () => _showDeleteConfirmation(profile),
                    canDelete: index > 0,
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
  final bool canDelete;

  const _ProfileItem({
    required this.name,
    this.imagePath,
    required this.onEdit,
    required this.onDelete,
    this.canDelete = true, // Valor por defecto para no romper el código anterior
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: imagePath == null
                  ? LinearGradient(
                colors: [Colors.blueAccent.shade100, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: imagePath != null
                ? ClipOval(
              // Usamos CachedNetworkImage en lugar de Image.network
              child: CachedNetworkImage(
                imageUrl: imagePath!,
                fit: BoxFit.cover,
                // Muestra un indicador de carga mientras la imagen se descarga
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                // Muestra un ícono si hay un error al cargar la imagen
                errorWidget: (context, url, error) => const Icon(
                  Icons.person,
                  size: 45,
                  color: Colors.white,
                ),
              ),
            )
                : const Icon(
              Icons.person,
              size: 45,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.edit_rounded, color: Colors.blue[600]),
                onPressed: onEdit,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              if (canDelete) // Mostrar el botón de eliminar solo si `canDelete` es true
                IconButton(
                  icon: Icon(Icons.delete_rounded, color: Colors.red[600]),
                  onPressed: onDelete,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Widget para el botón de agregar perfil
class _AddProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProfileButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400, width: 2),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 45,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Agregar Perfil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
