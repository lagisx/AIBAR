import 'package:flutter/material.dart';

import '../../../shared_widgets/scissors_logo.dart';
import '../../auth/widgets/staggered_title.dart';

class SplashScreen extends StatefulWidget {
  final WidgetBuilder nextBuilder;

  const SplashScreen({super.key, required this.nextBuilder});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showNext = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showNext = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _showNext
          ? Builder(builder: widget.nextBuilder)
          : const _SplashContent(),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.35),
              radius: 1.3,
              colors: [Color(0xFF1C2648), Color(0xFF0A101F)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                const ScissorsLogo(size: 116),
                const SizedBox(height: 32),
                const StaggeredTitle(
                  text: 'VEGAS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Твой барбершоп в кармане',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(flex: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: SizedBox(
                    width: 88,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7C8CF8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
