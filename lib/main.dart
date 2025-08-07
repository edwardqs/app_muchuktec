// lib/main.dart
import 'package:flutter/material.dart';
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

void main() {
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
      home: const LoginScreen(),
      onGenerateRoute: (settings) {
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
          default:
            return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
      },
    );
  }
}