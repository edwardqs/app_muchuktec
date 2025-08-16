import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  // Reemplaza esto con la URL de tu API de Laravel
  final String _baseUrl = 'http://tu-api-laravel.com/api';
  // Simula el ID del usuario, en un escenario real se obtendría del token de autenticación
  final int _userId = 1;
  // Simula el token de autenticación del usuario
  final String _authToken = 'Bearer 1|f345hdsjkhf34kjh5kjh4k';

  List<Map<String, dynamic>> _userProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfiles();
  }

  // Método para obtener los perfiles del usuario desde la API de Laravel
  Future<void> _fetchUserProfiles() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profiles?user_id=$_userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['profiles'];
        setState(() {
          _userProfiles = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load profiles');
      }
    } catch (e) {
      print("Error al obtener perfiles: $e");
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar los perfiles.')),
        );
      }
    }
  }

  // Método para mostrar el modal de agregar nuevo perfil
  void _showAddProfileModal() {
    if (_userProfiles.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No puedes tener más de 4 perfiles.')),
        );
      }
      return;
    }

    final TextEditingController _nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Agregar Nuevo Perfil'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Nombre del perfil',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  _addProfile(_nameController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  // Método para agregar un nuevo perfil a la API de Laravel
  Future<void> _addProfile(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/profiles'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authToken,
        },
        body: json.encode({
          'user_id': _userId,
          'name': name,
        }),
      );

      if (response.statusCode == 201) {
        // Asumiendo que la API devuelve el nuevo perfil creado
        final newProfile = json.decode(response.body);
        setState(() {
          _userProfiles.add(newProfile);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil agregado exitosamente.')),
          );
        }
      } else {
        throw Exception('Failed to add profile');
      }
    } catch (e) {
      print('Error al agregar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al agregar el perfil.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Cuentas'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Quién está usando?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
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
                  if (index == _userProfiles.length && _userProfiles.length < 4) {
                    return _AddProfileButton(onTap: _showAddProfileModal);
                  }
                  final profile = _userProfiles[index];
                  return _ProfileItem(
                    name: profile['name'],
                    icon: Icons.person,
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
  final IconData icon;

  const _ProfileItem({
    required this.name,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seleccionaste a $name')),
        );
        // Aquí podrías agregar la lógica para cambiar al perfil seleccionado
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 50,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.add,
              size: 50,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
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
    );
  }
}
