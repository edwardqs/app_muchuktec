// lib/screens/assign_budget_screen.dart
import 'package:flutter/material.dart';

class AssignBudgetScreen extends StatefulWidget {
  const AssignBudgetScreen({super.key});

  @override
  State<AssignBudgetScreen> createState() => _AssignBudgetScreenState();
}

class _AssignBudgetScreenState extends State<AssignBudgetScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedCategory = 'Categoría';
  String _selectedMonth = 'Mes - Año';

  // Lista de categorías disponibles
  final List<String> categories = [
    'Categoría',
    'Alimentación',
    'Transporte',
    'Entretenimiento',
    'Servicios',
    'Salud',
    'Educación',
    'Compras',
  ];

  // Lista de meses disponibles
  final List<String> months = [
    'Mes - Año',
    'Enero 2025',
    'Febrero 2025',
    'Marzo 2025',
    'Abril 2025',
    'Mayo 2025',
    'Junio 2025',
    'Julio 2025',
    'Agosto 2025',
    'Septiembre 2025',
    'Octubre 2025',
    'Noviembre 2025',
    'Diciembre 2025',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Asignar Presupuesto',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {},
          ),
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.purple[100],
              child: Icon(Icons.person, color: Colors.purple, size: 20),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título principal
            Text(
              'Seleccionar categoría',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 12),

            // Dropdown de categorías
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                underline: SizedBox(),
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                items: categories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: value == 'Categoría' ? Colors.grey[400] : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
              ),
            ),
            SizedBox(height: 24),

            // Título mes
            Text(
              'Mes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 12),

            // Dropdown de mes
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedMonth,
                isExpanded: true,
                underline: SizedBox(),
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                items: months.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: value == 'Mes - Año' ? Colors.grey[400] : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedMonth = newValue;
                    });
                  }
                },
              ),
            ),
            SizedBox(height: 24),

            // Título monto
            Text(
              'Monto del presupuesto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 12),

            // Campo de monto
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'S/.',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            SizedBox(height: 40),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _assignBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Asignar Presupuesto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _assignBudget() {
    // Validaciones
    if (_selectedCategory == 'Categoría') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor selecciona una categoría'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedMonth == 'Mes - Año') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor selecciona un mes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor ingresa el monto del presupuesto'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar que el monto sea un número válido
    double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor ingresa un monto válido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Aquí guardarías el presupuesto en tu base de datos o estado
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Presupuesto asignado: $_selectedCategory - $_selectedMonth - S/.${amount.toStringAsFixed(2)}'
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    // Limpiar formulario
    setState(() {
      _selectedCategory = 'Categoría';
      _selectedMonth = 'Mes - Año';
      _amountController.clear();
    });

    // Volver al dashboard después de asignar
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}