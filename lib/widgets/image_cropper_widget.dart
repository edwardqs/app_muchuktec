import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

class ImageCropperWidget extends StatelessWidget {
  final Uint8List imageBytes;
  final Function(Uint8List) onCropped;

  const ImageCropperWidget({
    super.key,
    required this.imageBytes,
    required this.onCropped,
  });

  @override
  Widget build(BuildContext context) {
    final controller = CropController();

    // Colores de tu App
    const Color cAzulPetroleo = Color(0xFF264653);
    const Color cVerdeMenta = Color(0xFF2A9D8F);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Ajustar Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: cAzulPetroleo,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 30, color: cVerdeMenta),
            onPressed: () => controller.crop(),
            tooltip: 'Confirmar recorte',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: imageBytes,
              controller: controller,
              onCropped: (result) {
                // ▼ CAMBIO DEFINITIVO AQUÍ ▼
                if (result is CropSuccess) {
                  // En la v3.0+, se usa 'croppedImage' en lugar de 'data'
                  onCropped(result.croppedImage);
                  Navigator.pop(context);
                } else if (result is CropFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al recortar la imagen')),
                  );
                }
              },
              aspectRatio: 1 / 1,
              withCircleUi: true,
              baseColor: Colors.black,
              maskColor: Colors.black.withOpacity(0.8),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            color: cAzulPetroleo,
            child: const SafeArea(
              top: false,
              child: Text(
                'Mueve y ajusta la imagen dentro del círculo',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}