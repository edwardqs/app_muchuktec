import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _isPremium = false; // ✅ Nuevo estado para controlar el bloqueo

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus(); // ✅ Verificamos apenas inicia el widget
  }

  // Función para verificar si el usuario es Premium
  Future<void> _checkPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool premiumStatus = prefs.getBool('isPremium') ?? false;

    if (mounted) {
      setState(() {
        _isPremium = premiumStatus;
      });
    }

    // Solo si NO es premium, iniciamos la carga del anuncio
    if (!premiumStatus) {
      _loadAd();
    } else {
      print('✨ [AdBanner] Usuario Premium detectado. No se cargará publicidad.');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ya no llamamos a _loadAd aquí directamente para evitar doble carga
  }

  Future<void> _loadAd() async {
    // Si ya es premium o está cargando, no hacer nada
    if (_isPremium || _isLoading || _isLoaded) return;

    _isLoading = true;
    try {
      if (!mounted) return;

      final size = MediaQuery.of(context).size;
      final double screenWidth = size.width;

      final AnchoredAdaptiveBannerAdSize? adSize =
      await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          screenWidth.truncate());

      if (!mounted || adSize == null) {
        _isLoading = false;
        return;
      }

      _bannerAd = BannerAd(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        size: adSize,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                _isLoaded = true;
                _isLoading = false;
              });
            }
          },
          onAdFailedToLoad: (ad, err) {
            _isLoading = false;
            ad.dispose();
          },
        ),
      );

      await _bannerAd!.load();

    } catch (e) {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🚫 REGLA DE ORO: Si es premium, el widget no ocupa espacio (0x0)
    if (_isPremium) {
      return const SizedBox.shrink();
    }

    if (_bannerAd != null && _isLoaded) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return _isLoading
        ? const SizedBox(
        height: 50,
        child: Center(child: Text('Cargando Ads...', style: TextStyle(fontSize: 10, color: Colors.grey)))
    )
        : const SizedBox.shrink();
  }
}