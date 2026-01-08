import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Colores oficiales de Planifiko
  final Color cAzulPetroleo = const Color(0xFF264653);
  final Color cVerdeMenta = const Color(0xFF2A9D8F);
  final Color cBlanco = const Color(0xFFFFFFFF);
  final Color cGrisFondo = const Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cGrisFondo,
      body: CustomScrollView(
        slivers: [
          // Header con Gradiente y Estilo Moderno
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: cAzulPetroleo,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                'Planifiko Premium',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cAzulPetroleo, cAzulPetroleo.withOpacity(0.8)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome, size: 60, color: cVerdeMenta),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Lista de Beneficios con diseño de Tarjetas
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Desbloquea tu potencial financiero',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cAzulPetroleo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Únete a la comunidad de Planifiko y toma el control total.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  ),
                  const SizedBox(height: 24),

                  // Beneficios
                  _buildPremiumCard(Icons.app_blocking, 'Cero Anuncios', 'Navega por la app sin distracciones publicitarias.'),
                  _buildPremiumCard(Icons.group_add_rounded, 'Multiperfiles', 'Crea hasta 10 perfiles para toda tu familia.'),
                  _buildPremiumCard(Icons.file_download_rounded, 'Exportar Reportes', 'Descarga tus informes detallados en formato PDF y Excel.'),
                  _buildPremiumCard(Icons.security_rounded, 'Soporte VIP', 'Atención prioritaria para cualquier consulta.'),
                ],
              ),
            ),
          ),

          // Espacio para que el botón no tape el contenido
          const SliverToBoxAdapter(child: SizedBox(height: 180)),
        ],
      ),

      // Botón Flotante de Compra (CTA)
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cBlanco,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Suscripción Anual', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text(
                  'S/ 4.90',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cAzulPetroleo),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => _startPurchase(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cVerdeMenta,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: cVerdeMenta.withOpacity(0.4),
                ),
                child: const Text(
                  'OBTENER PREMIUM',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Prueba de 7 días gratis • Cancela cuando quieras',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cBlanco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cVerdeMenta.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cVerdeMenta, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: cVerdeMenta.withOpacity(0.3), size: 20),
        ],
      ),
    );
  }

  Future<void> _startPurchase() async {
    // 1. Mostramos un pequeño loader para que parezca real
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 2. Simulamos un retraso de red de 2 segundos
    await Future.delayed(const Duration(seconds: 2));

    // 3. Guardamos en SharedPreferences que el usuario YA ES PREMIUM
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', true);

    // 4. Cerramos el loader y mostramos el éxito
    if (!mounted) return;
    Navigator.pop(context); // Cierra el loader

    _showSuccessDialog(); // Llamamos a la animación de éxito
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF2A9D8F), size: 80), // cVerdeMenta
            const SizedBox(height: 16),
            const Text(
              '¡Bienvenido a Premium!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ahora tienes acceso a todos los beneficios de Planifiko.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF264653)), // cAzulPetroleo
                onPressed: () {
                  Navigator.pop(context); // Cierra el diálogo
                  Navigator.pushReplacementNamed(context, '/settings'); // Refresca los ajustes
                },
                child: const Text('EMPEZAR', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}