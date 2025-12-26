import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/balance_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_movements.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';
// ✅ 1. Importamos el widget del anuncio
import 'package:app_muchik/widgets/ad_banner_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final int _selectedIndex = 0;
  String? _profileImageUrl;
  bool _isLoading = true;

  // --- COLORES OFICIALES ---
  final Color cPetrolBlue = const Color(0xFF264653);
  final Color cMintGreen = const Color(0xFF2A9D8F);
  final Color cLightGrey = const Color(0xFFF4F4F4);
  final Color cWhite = const Color(0xFFFFFFFF);

  // --- VARIABLES ---
  bool _isUserVerified = true;
  bool _isLoadingVerificationStatus = true;
  bool _isSendingVerification = false;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print("App resumed. Refreshing user data...");
      _refreshUserData();
    }
  }

  Future<void> _refreshUserData() async {
    if (_accessToken == null) {
      _loadInitialData();
      return;
    }

    final url = Uri.parse('$API_BASE_URL/getUser');
    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      if (mounted && response.statusCode == 200) {
        final userData = json.decode(response.body);
        final String? emailVerifiedAt = userData['email_verified_at'] as String?;
        final bool isVerifiedNow = emailVerifiedAt != null;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isUserVerified', isVerifiedNow);

        if (_isUserVerified != isVerifiedNow) {
          setState(() {
            _isUserVerified = isVerifiedNow;
          });
        }
      } else if (mounted) {
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _isLoadingVerificationStatus = true;
    });

    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _isUserVerified = prefs.getBool('isUserVerified') ?? false;

    setState(() { _isLoadingVerificationStatus = false; });

    await _loadSelectedAccountAndFetchImage();
  }

  Future<void> _resendVerificationEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    _accessToken = token;

    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: No autenticado.'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isSendingVerification = true; });

    final url = Uri.parse('$API_BASE_URL/email/verification-notification');
    try {
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 202 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo de verificación enviado.'), backgroundColor: Colors.green),
        );
      } else if (response.statusCode == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demasiados intentos. Intenta más tarde.'), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar correo: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() { _isSendingVerification = false; });
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0: Navigator.pushReplacementNamed(context, '/dashboard'); break;
      case 1: Navigator.pushReplacementNamed(context, '/reports'); break;
      case 2: Navigator.pushReplacementNamed(context, '/budgets'); break;
      case 3: Navigator.pushReplacementNamed(context, '/categories'); break;
      case 4: Navigator.pushReplacementNamed(context, '/settings'); break;
    }
  }

  Future<void> _loadSelectedAccountAndFetchImage() async {
    setState(() { _isLoading = true; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final int? selectedAccountId = prefs.getInt('idCuenta');

      if (token == null) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
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
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cLightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // ✅ Evita que aparezca flecha de volver por defecto
        // ✅ Botón de hamburguesa ELIMINADO de aquí
        title: Text(
          'Menu',
          style: TextStyle(
            color: cPetrolBlue,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: cPetrolBlue),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cMintGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Center(
                  child: CircularProgressIndicator(
                    color: cMintGreen,
                    strokeWidth: 2,
                  ))
                  : _profileImageUrl != null
                  ? ClipOval(
                child: Image.network(
                  _profileImageUrl!,
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.person, size: 24, color: cPetrolBlue);
                  },
                ),
              )
                  : Icon(Icons.person, size: 24, color: cPetrolBlue),
            ),
          ),
        ],
      ),
      body: _isLoadingVerificationStatus
          ? Center(child: CircularProgressIndicator(color: cMintGreen))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isUserVerified)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Card(
                  color: Colors.orange[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.orange[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Verifica tu correo electrónico',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hemos enviado un enlace a tu correo. Por favor, haz clic en él para activar tu cuenta completamente.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _isSendingVerification ? null : _resendVerificationEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            textStyle: const TextStyle(fontFamily: 'Poppins'),
                          ),
                          child: _isSendingVerification
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Reenviar Correo', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const BalanceCard(),
            const SizedBox(height: 24),
            const QuickActions(),
            const SizedBox(height: 24),
            const RecentMovements(),
          ],
        ),
      ),

      // ✅ 2. Aquí integramos el Anuncio dentro del BottomNavigationBar
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Importante para que no ocupe toda la pantalla
        children: [
          // Anuncio Banner
          const AdBannerWidget(),

          // Tu Barra de Navegación Original
          Container(
            decoration: BoxDecoration(
              color: cWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: cMintGreen,
              unselectedItemColor: cPetrolBlue.withOpacity(0.5),
              selectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
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