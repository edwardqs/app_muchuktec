import 'package:flutter/material.dart';
import 'package:app_muchik/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final int _selectedIndex = 4;
  String? _profileImageUrl;
  String? _accessToken;
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndFetchPhoto();
  }

  // Método para cargar el token y luego la foto de perfil
  Future<void> _loadAccessTokenAndFetchPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');

    if (_accessToken != null) {
      _loadSelectedAccountAndFetchImage();
    }
  }

  Future<void> _loadSelectedAccountAndFetchImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      // **CAMBIO 1: Usar la clave correcta ('idCuenta') y el tipo de dato correcto (int)**
      final int? selectedAccountId = prefs.getInt('idCuenta');

      if (token == null) {
        if (mounted) {
          print('Token no encontrado, redirigiendo al login...');
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }

      if (selectedAccountId == null) {
        if (mounted) {
          print('No se ha seleccionado una cuenta, mostrando imagen por defecto.');
          setState(() {
            _profileImageUrl = null;
            _isLoading = false;
          });
        }
        return;
      }

      // **CAMBIO 2: Convertir el ID de int a String para la URL de la API**
      final url = Uri.parse('$API_BASE_URL/accounts/${selectedAccountId.toString()}');
      print('Fetching account details from URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accountData = data['cuenta'];
        final relativePath = accountData['ruta_imagen'] as String?;

        setState(() {
          if (relativePath != null) {
            _profileImageUrl = '$STORAGE_BASE_URL/$relativePath';
            print('URL de la imagen construida: $_profileImageUrl');
          } else {
            _profileImageUrl = null;
          }
          _isLoading = false;
        });
      } else {
        print('Error al obtener los detalles de la cuenta. Status Code: ${response.statusCode}');
        print('Body de la respuesta de error: ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print('Excepción al obtener los detalles de la cuenta: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/reports');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/budgets');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/categories');
        break;
      case 4:
        break;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) { // Usamos 'dialogContext' aquí
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                // Navegar inmediatamente DESPUÉS de cerrar el diálogo
                // El pop y la navegación deben estar en una sola operación.
                await AuthService().logout();
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                        (Route<dynamic> route) => false,
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Acerca de Econo Muchik Finance'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versión: 1.0.0',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                'Tu asistente financiero personal para gestionar ingresos, gastos y presupuestos de manera inteligente.',
              ),
              SizedBox(height: 16),
              Text(
                'Desarrollado con ❤️ para ayudarte a alcanzar tus metas financieras.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        title: const Text(
          'Ajustes',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          InkWell(
            onTap: () {
              print('Navigating to accounts_screen');
              Navigator.pushNamed(context, '/accounts');
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.purple[100],
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? Icon(
                  Icons.person,
                  size: 20,
                  color: Colors.purple[700],
                )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuenta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingsItem(
                    icon: Icons.edit_outlined,
                    title: 'Editar datos personales',
                    onTap: () {
                      // NAVEGACIÓN ACTUALIZADA A EDITAR PERFIL
                      Navigator.pushNamed(context, '/edit-profile');
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsItem(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notificaciones',
                    onTap: () {
                      Navigator.pushNamed(context, '/notifications');
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsItem(
                    icon: Icons.group_outlined,
                    title: 'Ver perfiles',
                    onTap: () {
                      print('Navigating to accounts_screen');
                      Navigator.pushNamed(context, '/accounts');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'General',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingsItem(
                    icon: Icons.info_outline,
                    title: 'Acerca de ...',
                    onTap: _showAboutDialog,
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsItem(
                    icon: Icons.logout,
                    title: 'Cerrar sesión',
                    titleColor: Colors.red,
                    trailing: Icon(
                      Icons.power_settings_new,
                      color: Colors.red[600],
                      size: 20,
                    ),
                    onTap: _showLogoutDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.purple[700],
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Reportes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Presupuestos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category_outlined),
              activeIcon: Icon(Icons.category),
              label: 'Categorías',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.titleColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: titleColor ?? Colors.grey[700],
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor ?? Colors.black87,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
            size: 20,
          ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
    );
  }
}
