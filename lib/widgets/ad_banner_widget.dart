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
  bool _isLoading = false;

  // ID REAL DE BRUNO (AdMob)
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111' // <--- TU ID REAL
      : 'ca-app-pub-3940256099942544/2934735716'; // ID iOS Test

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Log inicial
    if (!_isLoaded && _bannerAd == null && !_isLoading) {
      print('🟢 [AdBanner] didChangeDependencies: Iniciando solicitud de carga...');
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    _isLoading = true;

    try {
      if (!mounted) {
        print('🔴 [AdBanner] Widget no montado al inicio.');
        return;
      }

      // 1. Obtener tamaño de pantalla
      final size = MediaQuery.of(context).size;
      final double screenWidth = size.width;
      print('🔵 [AdBanner] Ancho de pantalla detectado: $screenWidth');

      // 2. Calcular tamaño adaptativo
      print('🔵 [AdBanner] Calculando tamaño adaptativo...');

      // NOTA: Si esto falla, el error suele ser aquí.
      final AnchoredAdaptiveBannerAdSize? adSize =
      await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          screenWidth.truncate());

      if (!mounted) {
        print('🔴 [AdBanner] Widget desmontado durante el cálculo del tamaño.');
        _isLoading = false;
        return;
      }

      if (adSize == null) {
        print('🔴 [AdBanner] Error: El tamaño del banner adaptativo retornó NULL.');
        _isLoading = false;
        return;
      }

      print('🟢 [AdBanner] Tamaño calculado: ${adSize.width}x${adSize.height}');
      print('🔵 [AdBanner] Instanciando BannerAd con ID: $_adUnitId');

      // 3. Crear la instancia del anuncio
      _bannerAd = BannerAd(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        size: adSize, // <--- Si falla aquí, probaremos cambiar esto por AdSize.banner
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('✅ [AdBanner] ¡EXITO! Banner cargado. ID: ${ad.responseInfo?.responseId}');
            if (mounted) {
              setState(() {
                _isLoaded = true;
                _isLoading = false;
              });
            }
          },
          onAdFailedToLoad: (ad, err) {
            print('❌ [AdBanner] FALLÓ LA CARGA.');
            print('   -> Código: ${err.code}');
            print('   -> Mensaje: ${err.message}');
            print('   -> Dominio: ${err.domain}');

            // Log extra para ver si hay info de mediación o respuesta
            if (ad.responseInfo != null) {
              print('   -> Response Info: ${ad.responseInfo}');
            }

            _isLoading = false;
            ad.dispose();
          },
          onAdOpened: (Ad ad) => print('bf [AdBanner] Anuncio abierto.'),
          onAdClosed: (Ad ad) => print('bf [AdBanner] Anuncio cerrado.'),
          onAdImpression: (Ad ad) => print('bf [AdBanner] Impresión registrada.'),
        ),
      );

      // 4. Cargar
      print('🚀 [AdBanner] Ejecutando .load()...');
      await _bannerAd!.load();

    } catch (e, stackTrace) {
      print('🔥 [AdBanner] EXCEPCIÓN FATAL en _loadAd:');
      print(e);
      print(stackTrace);
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    print('🗑️ [AdBanner] Dispose llamado. Liberando recursos.');
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
        // Pinta el fondo rojo temporalmente para ver si el contenedor ocupa espacio
        // color: Colors.red.withOpacity(0.2),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // Mientras carga o si falló, mostramos un espacio vacío (o un texto debug)
    return _isLoading
        ? const SizedBox(
        height: 50,
        child: Center(child: Text('Cargando Ads...', style: TextStyle(fontSize: 10, color: Colors.grey)))
    )
        : const SizedBox.shrink();
  }
}