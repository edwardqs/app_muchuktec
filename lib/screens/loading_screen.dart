// screens/loading_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:app_muchik/services/user_session.dart';

//rene
const String apiUrl = 'http://10.0.2.2:8000/api';
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

  @override
  void initState() {
    super.initState();

    // Logo Animation Controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Progress Animation Controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Text Animation Controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Logo Animations
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

    // Progress Animation
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    // Text Animations
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


    _startAnimations();
    _checkLoginStatus();
  }

  void _startAnimations() async {
    // Start logo animation
    _logoController.forward();

    // Wait a bit, then start text animation
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();

    // Start progress animation
    await Future.delayed(const Duration(milliseconds: 400));
    _progressController.forward();

    // Navigate to dashboard after all animations
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final animationFuture = Future.delayed(const Duration(milliseconds: 2500));

    if (token != null) {
      // Si existe un token, intentamos obtener los datos del usuario
      await _fetchUserData(token);
    } else {
      // Si no hay token, esperamos a que las animaciones terminen y navegamos al login.
      await animationFuture;
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  Future<void> _fetchUserData(String token) async {
    final url = Uri.parse('$apiUrl/user');
    final animationFuture = Future.delayed(const Duration(milliseconds: 2500));

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Esperamos a que la animación termine, si la API responde antes.
      await animationFuture;

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        // Accedemos directamente a la instancia singleton
        final userSession = UserSession();

        userSession.setUserData(
          token: token,
          name: userData['nombres_completos'] ?? 'Usuario',
        );
        print('✅ Datos del usuario obtenidos y guardados: ${userData['nombres_completos']}');

        if (mounted) {
          // Navegamos al dashboard
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      } else {
        // El token no es válido o ha expirado, cerramos la sesión y vamos al login
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accessToken');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (e) {
      // Error de conexión o servidor, lo enviamos al login
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accessToken');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
      print('Error al obtener los datos del usuario: $e');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _textController.dispose();
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
              Colors.purple[400]!,
              Colors.purple[700]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo Animation
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: Opacity(
                      opacity: _logoOpacityAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
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
                        child: Icon(
                          Icons.account_balance_wallet,
                          size: 60,
                          color: Colors.purple[700],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Text Animation
              SlideTransition(
                position: _textSlideAnimation,
                child: FadeTransition(
                  opacity: _textOpacityAnimation,
                  child: Column(
                    children: [
                      const Text(
                        'Econo Muchik Finance',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tu asistente financiero personal',
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

              // Loading Animation
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

                    // Custom Progress Bar
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

                    // Loading Dots
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

// Loading Dots Animation Widget
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
        if (mounted) {
          _controllers[i].forward();
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      await Future.delayed(const Duration(milliseconds: 400));
      for (var controller in _controllers) {
        if (mounted) {
          controller.reverse();
        }
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