import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String apiUrl = 'http://10.0.2.2:8000/api';

class TercerosScreen extends StatefulWidget {
  const TercerosScreen({super.key});

  @override
  State<TercerosScreen> createState() => _TercerosScreenState();
}

class _TercerosScreenState extends State<TercerosScreen> {
  final _nombreController = TextEditingController();
  String? _tipoSeleccionado;

  final List<String> _tipos = ['Banco', 'Prestamista', 'Persona', 'Servicio'];

  List<Map<String, dynamic>> tercerosList = [];
  bool isLoading = false;
  String? errorMessage;
  String? _accessToken;
  int? _idCuenta;

  @override
  void initState() {
    super.initState();
    _loadAccessTokenAndFetchTerceros();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _loadAccessTokenAndFetchTerceros() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _idCuenta = prefs.getInt('idCuenta');

    if (_accessToken != null) {
      _fetchTerceros();
    } else {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se encontró un token de sesión. Por favor, inicie sesión.';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchTerceros() async {
    if (!mounted || _accessToken == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/terceros'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          tercerosList = data.map((e) => e as Map<String, dynamic>).toList();
        });
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accessToken');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Su sesión ha expirado. Por favor, inicie sesión de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        setState(() {
          errorMessage = 'Error al cargar terceros. Intente de nuevo.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No se pudo conectar al servidor. Revise su conexión.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _registrarTercero() async {
    if (_nombreController.text.isEmpty || _tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_accessToken == null || _idCuenta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el token de acceso. Por favor, reinicie la aplicación.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final body = {
      'nombre': _nombreController.text.trim(),
      'tipo': _tipoSeleccionado,
    };

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/terceros'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final newTercero = json.decode(response.body);
        setState(() {
          tercerosList.add(newTercero);
          _nombreController.clear();
          _tipoSeleccionado = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tercero registrado con éxito'), backgroundColor: Colors.green),
        );
      } else {
        String errorMessage = 'Error al registrar el tercero: Código ${response.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor. Intente de nuevo.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _actualizarTercero(int id, String nuevoNombre, String? nuevoTipo) async {
    if (_accessToken == null) return;

    final body = {
      'nombre': nuevoNombre.trim(),
      'tipo': nuevoTipo,
    };

    try {
      final response = await http.put(
        Uri.parse('$apiUrl/terceros/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final updatedTercero = json.decode(response.body);
        setState(() {
          final index = tercerosList.indexWhere((t) => t['id'] == id);
          if (index != -1) tercerosList[index] = updatedTercero;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tercero actualizado'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _eliminarTercero(int id) async {
    if (_accessToken == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiUrl/terceros/$id'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          tercerosList.removeWhere((t) => t['id'] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tercero eliminado'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor'), backgroundColor: Colors.red),
      );
    }
  }

  void _mostrarConfirmacionEliminar(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Eliminar Tercero', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        content: const Text('¿Estás seguro de que quieres eliminar este tercero?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: Colors.grey[600]))),
          TextButton(onPressed: () { Navigator.pop(context); _eliminarTercero(id); }, child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _mostrarModalEditar(Map<String, dynamic> tercero) {
    final TextEditingController editNombreController = TextEditingController(text: tercero['nombre']);
    String? editTipoSeleccionado = tercero['tipo'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Editar Tercero', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editNombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Tercero',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: editTipoSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Tipo de Tercero',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _tipos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (newValue) => editTipoSeleccionado = newValue,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _actualizarTercero(tercero['id'], editNombreController.text, editTipoSeleccionado); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Gestión de Terceros', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.black), onPressed: () {}),
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/accounts'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: Colors.purple[100], shape: BoxShape.circle),
              child: Icon(Icons.person, size: 20, color: Colors.purple[700]),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección Registro
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registrar Nuevo Tercero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  TextField(controller: _nombreController, decoration: InputDecoration(labelText: 'Nombre del Tercero', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _tipoSeleccionado,
                    decoration: InputDecoration(labelText: 'Tipo de Tercero', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    items: _tipos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (newValue) => setState(() { _tipoSeleccionado = newValue; }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _registrarTercero,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                      child: const Text('Registrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Lista de Terceros Registrados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : tercerosList.isEmpty
                ? Text(errorMessage ?? 'No hay terceros registrados', style: const TextStyle(color: Colors.grey))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tercerosList.length,
              itemBuilder: (context, index) => _buildTerceroItem(tercerosList[index]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTerceroItem(Map<String, dynamic> tercero) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tercero['nombre'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
              const SizedBox(height: 4),
              Text(tercero['tipo'], style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ]),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _mostrarModalEditar(tercero), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _mostrarConfirmacionEliminar(tercero['id']), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -2))]),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        currentIndex: 3,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Reportes'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Presupuestos'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categorías'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
        onTap: (index) {
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
              Navigator.pushReplacementNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }
}
