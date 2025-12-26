import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // ID de prueba oficial de Google (ÚSALO PARA DESARROLLO)
  // Cuando vayas a producción, cambia esto por tu Ad Unit ID real
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cargamos el anuncio aquí para tener acceso al tamaño de la pantalla (context)
    if (!_isLoaded && _bannerAd == null) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    // 1. Obtenemos el ancho de la pantalla del dispositivo
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;

    // 2. Calculamos el tamaño adaptativo (Ancho completo)
    // Esto le dice a Google: "Dame un anuncio que quepa en este ancho"
    final AnchoredAdaptiveBannerAdSize? adSize =
    await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        screenWidth.truncate());

    if (adSize == null) {
      print('No se pudo obtener el tamaño del banner adaptativo');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: adSize, // ✅ USAMOS EL TAMAÑO ADAPTATIVO
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
          print('Banner adaptativo cargado: ${ad.responseInfo}');
        },
        onAdFailedToLoad: (ad, err) {
          print('Error al cargar el banner: ${err.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerAd != null && _isLoaded) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    // Espacio reservado mientras carga (opcional, evita saltos bruscos)
    return const SizedBox.shrink();
  }
}