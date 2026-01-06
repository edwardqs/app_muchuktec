import 'package:flutter/material.dart';
import 'package:app_muchik/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';
import 'package:app_muchik/screens/subscription_screen.dart';
import 'package:app_muchik/widgets/ad_banner_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- COLORES OFICIALES ---
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cGrisClaro = const Color(0xFFF4F4F4);
  final Color cBlanco = const Color(0xFFFFFFFF);

  final int _selectedIndex = 4;
  String? _profileImageUrl;
  String? _accessToken;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndFetchPhoto();
  }

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
      final int? selectedAccountId = prefs.getInt('idCuenta');

      if (token == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }

      if (selectedAccountId == null) {
        if (mounted) {
          setState(() {
            _profileImageUrl = null;
            _isLoading = false;
          });
        }
        return;
      }

      final url = Uri.parse('$API_BASE_URL/accounts/${selectedAccountId.toString()}');
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
          } else {
            _profileImageUrl = null;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
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
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: cBlanco,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Cerrar sesión',
            style: TextStyle(
              color: cAzulPetroleo,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Estás seguro de que quieres cerrar sesión?',
            style: TextStyle(color: cAzulPetroleo.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: cAzulPetroleo, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
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
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
              ),
              child: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
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
          backgroundColor: cBlanco,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Acerca de Planifiko',
            style: TextStyle(
              color: cAzulPetroleo,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versión: 1.0.0',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cVerdeMenta,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu asistente financiero personal para gestionar ingresos, gastos y presupuestos de manera inteligente.',
                style: TextStyle(color: cAzulPetroleo.withOpacity(0.8)),
              ),
              const SizedBox(height: 16),
              Text(
                'Desarrollado con ❤️ para ayudarte a alcanzar tus metas financieras.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: cAzulPetroleo.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cerrar',
                style: TextStyle(color: cVerdeMenta, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cGrisClaro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cAzulPetroleo),
          onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        title: Text(
          'Ajustes',
          style: TextStyle(
            color: cAzulPetroleo,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: cAzulPetroleo),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/accounts');
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: cVerdeMenta,
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? Icon(
                  Icons.person,
                  size: 20,
                  color: cBlanco,
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
            Text(
              'Cuenta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cAzulPetroleo,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cBlanco,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: cAzulPetroleo.withOpacity(0.08),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingsItem(
                    icon: Icons.star_rounded,
                    title: 'Plan Premium',
                    iconColor: Colors.orange[700],
                    textColor: cAzulPetroleo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 56, color: cGrisClaro), // Divisor
                  _SettingsItem(
                    icon: Icons.edit_outlined,
                    title: 'Editar datos personales',
                    iconColor: cVerdeMenta,
                    textColor: cAzulPetroleo,
                    onTap: () {
                      Navigator.pushNamed(context, '/edit-profile');
                    },
                  ),
                  Divider(height: 1, indent: 56, color: cGrisClaro),
                  _SettingsItem(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notificaciones',
                    iconColor: cVerdeMenta,
                    textColor: cAzulPetroleo,
                    onTap: () {
                      Navigator.pushNamed(context, '/notifications');
                    },
                  ),
                  Divider(height: 1, indent: 56, color: cGrisClaro),
                  _SettingsItem(
                    icon: Icons.group_outlined,
                    title: 'Ver perfiles',
                    iconColor: cVerdeMenta,
                    textColor: cAzulPetroleo,
                    onTap: () {
                      Navigator.pushNamed(context, '/accounts');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'General',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cAzulPetroleo,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cBlanco,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: cAzulPetroleo.withOpacity(0.08),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingsItem(
                    icon: Icons.info_outline,
                    title: 'Acerca de ...',
                    iconColor: cVerdeMenta,
                    textColor: cAzulPetroleo,
                    onTap: _showAboutDialog,
                  ),
                  Divider(height: 1, indent: 56, color: cGrisClaro),
                  _SettingsItem(
                    icon: Icons.logout,
                    title: 'Cerrar sesión',
                    iconColor: Colors.red[400]!,
                    textColor: Colors.red[700]!,
                    trailing: Icon(
                      Icons.power_settings_new,
                      color: Colors.red[400],
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

      // ✅ 2. Integración del Banner y la Barra de Navegación
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Vital para que no ocupe toda la pantalla
        children: [
          // Banner de Publicidad
          const AdBannerWidget(),

          // Barra de navegación original
          Container(
            decoration: BoxDecoration(
              color: cBlanco,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 10,
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
              selectedItemColor: cAzulPetroleo, // Azul Petróleo para activo
              unselectedItemColor: Colors.grey[400],
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
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.iconColor,
    this.textColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? Colors.grey).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor ?? Colors.grey[700],
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor ?? Colors.black87,
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
        vertical: 8,
      ),
    );
  }
}