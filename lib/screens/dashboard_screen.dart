import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/balance_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_movements.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_muchik/config/constants.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final int _selectedIndex = 0;
  String? _profileImageUrl;
  bool _isLoading = true;

  // --- NUEVAS VARIABLES ---
  bool _isUserVerified = true;
  bool _isLoadingVerificationStatus = true;
  bool _isSendingVerification = false;
  String? _userEmail;
  String? _accessToken;
  // --- FIN NUEVAS VARIABLES ---

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // <-- Add this
    super.dispose();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When the app comes back into view
    if (state == AppLifecycleState.resumed) {
      print("App resumed. Refreshing user data...");
      _refreshUserData(); // Check the verification status again
    }
  }

  Future<void> _refreshUserData() async {
    // Only refresh if we have a token
    if (_accessToken == null) {
      // Maybe try reloading initial data just in case
      _loadInitialData();
      return;
    }

    final url = Uri.parse('$API_BASE_URL/getUser');
    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10)); // Add a timeout

      if (mounted && response.statusCode == 200) {
        final userData = json.decode(response.body);
        final String? emailVerifiedAt = userData['email_verified_at'] as String?;
        final bool isVerifiedNow = emailVerifiedAt != null;

        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isUserVerified', isVerifiedNow);

        // Update the screen state ONLY if the verification status changed
        if (_isUserVerified != isVerifiedNow) {
          print("Verification status changed to: $isVerifiedNow. Hiding prompt.");
          setState(() {
            _isUserVerified = isVerifiedNow;
            // Optionally update other user details like name if needed
          });
        } else {
          print("Verification status remains: $_isUserVerified.");
        }
      } else if (mounted) {
        print("Could not refresh user data from API: ${response.statusCode}. Using local data.");
        // Fallback: Reload from SharedPreferences if API fails
        _loadInitialData();
      }
    } catch (e) {
      print("Network error refreshing user data: $e. Using local data.");
      if (mounted) _loadInitialData(); // Fallback to local data on error
    }
  }

  // NUEVA FUNCIÓN PARA CARGAR
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true; // Carga imagen
      _isLoadingVerificationStatus = true;
    });

    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');

    // Leemos el estado de verificación guardado por LoadingScreen
    _isUserVerified = prefs.getBool('isUserVerified') ?? false;
    // Opcional: leer email si lo guardaste
    // _userEmail = prefs.getString('userEmail');

    // Marcamos que ya leímos el estado
    setState(() { _isLoadingVerificationStatus = false; });

    // Continuamos cargando la imagen (tu lógica existente)
    await _loadSelectedAccountAndFetchImage();

    // Ya no necesitas _isLoading para la imagen aquí si _loadSelected... lo maneja
    // setState(() { _isLoading = false; }); // _loadSelected... ya pone _isLoading = false
  }

  Future<void> _resendVerificationEmail() async {
    print("🚀 Botón Reenviar Correo presionado."); // <-- PRINT 1
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    _accessToken = token;

    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: No autenticado.'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isSendingVerification = true; });

    final url = Uri.parse('$API_BASE_URL/email/verification-notification');
    print("📡 Llamando a API: $url con Token: Bearer $_accessToken");
    try {
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      ).timeout(const Duration(seconds: 15));
      print("🚦 Respuesta API recibida: ${response.statusCode}");

      if (!mounted) return;

      if (response.statusCode == 202 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo de verificación enviado. Revisa tu bandeja de entrada y spam.'), backgroundColor: Colors.green),
        );
      } else if (response.statusCode == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demasiados intentos. Intenta más tarde.'), backgroundColor: Colors.orange),
        );
      } else {
        print("Error reenviando email: ${response.statusCode} ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar correo: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("🔥 Excepción en llamada API: $e");
      if (!mounted) return;
      print("Excepción reenviando email: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() { _isSendingVerification = false; });
    }
  }

  void _onItemTapped(int index) {
    // Solo navega si el índice es diferente al actual
    if (index == _selectedIndex) {
      return;
    }

    switch (index) {
      case 0: // Inicio
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 1: // Reportes
        Navigator.pushReplacementNamed(context, '/reports');
        break;
      case 2: // Presupuestos
        Navigator.pushReplacementNamed(context, '/budgets');
        break;
      case 3: // Categorías
        Navigator.pushReplacementNamed(context, '/categories');
        break;
      case 4: // Ajustes
        Navigator.pushReplacementNamed(context, '/settings');
        break;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: const Text(
          'Menu',
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.purple[100],
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.purple,
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
                    print('Error al cargar la imagen de red: $error');
                    return Icon(Icons.person, size: 24, color: Colors.purple[700]);
                  },
                ),
              )
                  : Icon(Icons.person, size: 24, color: Colors.purple[700]),
            ),
          ),
        ],
      ),
      body: _isLoadingVerificationStatus // Primero espera a saber si está verificado
          ? const Center(child: CircularProgressIndicator())
          :SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isUserVerified)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0), // Espacio debajo del aviso
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
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hemos enviado un enlace a tu correo. Por favor, haz clic en él para activar tu cuenta completamente.',
                          // O usa _userEmail si lo guardaste: 'Revisa tu bandeja de entrada ($_userEmail)...'
                          style: TextStyle(color: Colors.orange[700], fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _isSendingVerification ? null : _resendVerificationEmail,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: _isSendingVerification
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Reenviar Correo', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // --- FIN AVISO ---
            const BalanceCard(),
            const SizedBox(height: 24),
            const QuickActions(),
            const SizedBox(height: 24),
            const RecentMovements(),
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
