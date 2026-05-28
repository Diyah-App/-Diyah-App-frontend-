import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class StaticSplashScreen extends StatefulWidget {
  final bool needsUpdate;
  final String updateUrl;

  const StaticSplashScreen({Key? key, this.needsUpdate = false, this.updateUrl = ""}) : super(key: key);

  @override
  _StaticSplashScreenState createState() => _StaticSplashScreenState();
}

class _StaticSplashScreenState extends State<StaticSplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for 3 seconds to show the splash screen
    await Future.delayed(Duration(seconds: 3));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => HomeScreen(needsUpdate: widget.needsUpdate, updateUrl: widget.updateUrl),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161412), // Dark fallback color
      body: Stack(
        children: [
          // 1. Background Pattern Layer
          // We zoom into the top-left corner of the image to extract just the pattern/texture
          Positioned.fill(
            child: Transform.scale(
              scale: 3.0, // Zoom in heavily so we only see the texture, not the sword/text
              alignment: Alignment.topLeft,
              child: Image.asset(
                'assets/images/splash_image.jpg',
                fit: BoxFit.cover,
                // Darken it slightly so the foreground stands out clearly
                color: Colors.black.withOpacity(0.4),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
          
          // 2. Foreground Image Layer
          // The full image centered perfectly without ANY cropping on any screen
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) {
                // A soft vignette effect (RadialGradient) to seamlessly blend 
                // the edges of the square image into the patterned background!
                return const RadialGradient(
                  center: Alignment.center,
                  radius: 0.65, // Controls how far the fade reaches
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0.0, 0.7, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/images/splash_image.jpg',
                // It will naturally shrink to fit the screen without cropping
              ),
            ),
          ),
        ],
      ),
    );
  }
}
