import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:app_muchik/services/user_session.dart';
import 'package:app_muchik/config/constants.dart';
import 'package:app_muchik/services/firebase_api.dart';

import 'package:app_links/app_links.dart';
import '../services/auth_service.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late AnimationController _textController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final AuthService _authService = AuthService();

  // Definimos tu color principal aquí para usarlo fácilmente
  final Color mainColor = const Color(0xFF008989);

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6),
    ));
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600),
            () => _textController.forward());
    Future.delayed(const Duration(milliseconds: 1000),
            () => _progressController.forward());

    final animationFuture = Future.delayed(const Duration(milliseconds: 2500));

    bool isLoggedIn = await _handleInitialLink();

    if (!isLoggedIn) {
      isLoggedIn = await _checkSessionAndSetup();
    }

    await animationFuture;

    if (mounted) {
      if (isLoggedIn) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<bool> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();

      if (initialUri == null) {
        print('No hay enlace inicial. Escuchando futuros enlaces...');
        _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
          _handleDeepLink(uri);
        });
        return false;
      }

      print('Enlace inicial encontrado: $initialUri');
      return await _handleDeepLink(initialUri);
    } catch (e) {
      print('Error al obtener el enlace inicial (app_links): $e');
      return false;
    }
  }

  Future<bool> _handleDeepLink(Uri uri) async {
    if (uri.scheme == 'com.economuchik.app_muchik' && uri.host == 'verify') {
      final String? token = uri.queryParameters['token'];

      if (token != null && token.isNotEmpty) {
        print('✅ Token capturado del Deep Link: $token');
        try {
          await _authService.verifyEmailToken(token);
          print('🎉 ¡Auto-login por Deep Link exitoso!');
          return true;
        } catch (e) {
          print('❌ Error al verificar el token del Deep Link: $e');
          return false;
        }
      }
    }
    return false;
  }

  Future<bool> _checkSessionAndSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      print('🚫 No hay token, se redirige a login.');
      return false;
    }

    final url = Uri.parse('$API_BASE_URL/getUser');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        final String? emailVerifiedAt =
        userData['email_verified_at'] as String?;
        final bool isVerified = emailVerifiedAt != null;

        await prefs.setBool('isUserVerified', isVerified);
        final userSession = UserSession();
        userSession.setUserData(
          token: token,
          name: userData['nombres_completos'] ?? 'Usuario',
        );
        await prefs.setInt('idUsuario', userData['id'] as int? ?? 0);

        print('🔄 Registrando dispositivo para notificaciones...');
        await FirebaseApi().initNotifications();

        return true;
      } else {
        print('❌ Token no válido, limpiando sesión.');
        await prefs.remove('accessToken');
        await prefs.remove('idCuenta');
        await prefs.remove('isUserVerified');
        return false;
      }
    } catch (e) {
      print('❗ Error de red al validar sesión: $e');
      await prefs.remove('accessToken');
      await prefs.remove('idCuenta');
      await prefs.remove('isUserVerified');
      return false;
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _textController.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              mainColor.withOpacity(0.8),
              mainColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: Opacity(
                      opacity: _logoOpacityAnimation.value,
                      // --- INICIO DE CAMBIOS IMPORTANTES ---
                      child: Container(
                        // 1. Aumentamos un poco el tamaño del círculo contenedor
                        width: 150,
                        height: 150,

                        // 2. ESTA LÍNEA ES MÁGICA: Recorta todo lo que se salga del círculo
                        clipBehavior: Clip.antiAlias,

                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        // 3. Quitamos el Padding para que la imagen toque los bordes
                        child: Image.asset(
                          'assets/icon/logo4.jpg',
                          // 4. Usamos 'cover' para que haga zoom y llene todo el espacio
                          fit: BoxFit.cover,
                        ),
                      ),
                      // --- FIN DE CAMBIOS ---
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              SlideTransition(
                position: _textSlideAnimation,
                child: FadeTransition(
                  opacity: _textOpacityAnimation,
                  child: Column(
                    children: [
                      const Text(
                        'Planifiko',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tu dinero, bajo control',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Column(
                  children: [
                    FadeTransition(
                      opacity: _textOpacityAnimation,
                      child: Text(
                        'Cargando tu información...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _progressAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    FadeTransition(
                      opacity: _textOpacityAnimation,
                      child: const LoadingDots(),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    _startAnimation();
  }

  void _startAnimation() async {
    while (mounted) {
      for (int i = 0; i < _controllers.length; i++) {
        if (!mounted) return;
        _controllers[i].forward();
        await Future.delayed(const Duration(milliseconds: 200));
      }
      await Future.delayed(const Duration(milliseconds: 400));
      for (var controller in _controllers) {
        if (!mounted) return;
        controller.reverse();
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: 0.4 + (_animations[index].value * 0.6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}