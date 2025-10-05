// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // <-- ¡IMPORTANTE!
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/assign_budget_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/compromises_screen.dart';
import 'screens/compromises_create_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/compromises_tiers_screen.dart';
import 'screens/movements_screen.dart';
import 'screens/compromises_detail_screen.dart';
import 'screens/notifications_screen.dart';

// DEBES CAMBIAR main() a async para usar await en la inicialización
void main() async {
  // 1. Inicializar los Widgets de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializar la localización para español ('es').
  // Esto resuelve la LocaleDataException.
  // Usamos 'es' para cargar todos los datos de sus dialectos (como 'es_PE').
  await initializeDateFormatting('es');

  runApp(const EconoMuchikApp());
}

class EconoMuchikApp extends StatelessWidget {
  const EconoMuchikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Econo Muchik Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: 'Roboto',
      ),

      locale: const Locale('es', 'ES'), // Forzar el locale a Español España (un dialecto conocido)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      supportedLocales: const [
        Locale('en', 'US'), // Inglés
        Locale('es', 'ES'), // Español estándar
        Locale('es', 'PE'), // Español Perú (para tu formato de moneda es_PE)
      ],

      home: const LoginScreen(),
      onGenerateRoute: (settings) {
        // ... (Tu onGenerateRoute se mantiene igual)
        print('onGenerateRoute called with: ${settings.name}');
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (context) => const RegisterScreen());
          case '/settings':
            return MaterialPageRoute(builder: (context) => const SettingsScreen());
          case '/loading':
            return MaterialPageRoute(builder: (context) => const LoadingScreen());
          case '/dashboard':
            return MaterialPageRoute(builder: (context) => const DashboardScreen());
          case '/reports':
            return MaterialPageRoute(builder: (context) => const ReportsScreen());
          case '/categories':
            return MaterialPageRoute(builder: (context) => const CategoriesScreen());
          case '/edit-profile':
            return MaterialPageRoute(builder: (context) => const EditProfileScreen());
          case '/budgets':
            return MaterialPageRoute(builder: (context) => const BudgetsScreen());
          case '/assign-budget':
            return MaterialPageRoute(builder: (context) => const AssignBudgetScreen());
          case '/compromises':
            return MaterialPageRoute(builder: (context) => const CompromisesScreen());
          case '/compromises_create':
            return MaterialPageRoute(builder: (context) => const CompromisesCreateScreen());
          case '/accounts':
            return MaterialPageRoute(builder: (context) => const AccountsScreen());
          case '/compromises_tiers':
          // Asegúrate de usar el nombre de la clase correcto, que parece ser 'TercerosScreen'
            return MaterialPageRoute(builder: (context) => const TercerosScreen());
          case '/movements':
            return MaterialPageRoute(builder: (context) => const MovementsScreen());
          case '/compromises_detail':
            return MaterialPageRoute(builder: (context) => const CompromisesDetailScreen());
          case '/notifications':
            return MaterialPageRoute(builder: (context) => const NotificationsScreen());
          default:
            return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
      },
    );
  }
}