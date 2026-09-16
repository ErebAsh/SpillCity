import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _orbitProgress;
  
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  
  late Animation<double> _subtitleOpacity;
  late Animation<Offset> _subtitleSlide;
  
  late Animation<double> _buttonsOpacity;
  late Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();
    
    // Total animation timeline runs for 7.5 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7500),
    );


    // 2. Main Logo Scale & Rotation (0.5s - 3.0s -> Interval 0.067 to 0.4)
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.067, 0.4, curve: Curves.easeOutBack),
      ),
    );
    
    // Rotate counter-clockwise (~540 degrees = -3 * pi radians)
    _logoRotation = Tween<double>(begin: 0.0, end: -3 * math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.067, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Orbiting Particles Swarm (2.5s - 5.5s -> Interval 0.33 to 0.73)
    _orbitProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.33, 0.73, curve: Curves.easeInOutCubic),
      ),
    );

    // 4. Header Text Entrance (4.5s - 6.5s)
    // Title "Welcome" (4.5s - 6.0s -> Interval 0.6 to 0.8)
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.8, curve: Curves.easeOutQuad),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.8, curve: Curves.easeOutQuad),
      ),
    );

    // Subtitle "Discover your creativity" (4.8s - 6.3s -> Interval 0.64 to 0.84)
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.64, 0.84, curve: Curves.easeOutQuad),
      ),
    );
    _subtitleSlide = Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.64, 0.84, curve: Curves.easeOutQuad),
      ),
    );

    // 5. Action Buttons Entrance (6.0s - 7.5s -> Interval 0.8 to 1.0)
    _buttonsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _buttonsSlide = Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Start the animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
        
    return Scaffold(
      body: Stack(
        children: [
          // 1. Radial Dark Metallic Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Color(0xFF1E2226), // Center charcoal grey
                  Color(0xFF0D0F11), // Edge deep dark
                ],
              ),
            ),
          ),
          
          // Subtle circular brushed texture overlay using custom painter
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: CustomPaint(
                painter: _BrushedMetalPainter(),
              ),
            ),
          ),


          // 3. Central Animated Flower Logo & Orbiting Particles
          Align(
            alignment: const Alignment(0, -0.25),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: Transform.rotate(
                    angle: _logoRotation.value,
                    child: CustomPaint(
                      size: const Size(220, 220),
                      painter: _FlowerLogoPainter(
                        orbitProgress: _orbitProgress.value,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. Header Titles and Action Buttons at the Bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title: "Welcome"
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: const Text(
                        'Welcome',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtitle: "Discover your creativity"
                  FadeTransition(
                    opacity: _subtitleOpacity,
                    child: SlideTransition(
                      position: _subtitleSlide,
                      child: const Text(
                        'Discover your creativity',
                        style: TextStyle(
                          color: Color(0xFFA0A5AB),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Actions Buttons Row
                  FadeTransition(
                    opacity: _buttonsOpacity,
                    child: SlideTransition(
                      position: _buttonsSlide,
                      child: Row(
                        children: [
                          // "Get Started" (Sign Up) Button
                          Expanded(
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE91E63), // Pink
                                    Color(0xFFFF9800), // Orange
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () => context.push('/signup'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: const Text(
                                  'Get Started',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // "Log In" Button
                          Expanded(
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                color: const Color(0xFF1C2023).withValues(alpha: 0.5),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: () => context.push('/login'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: const Text(
                                  'Log In',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws circular brushed metal overlay lines
class _BrushedMetalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw concentric circles to mimic circular brushing
    for (double r = 50; r < size.width * 0.8; r += 20) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Custom painter to draw the 8-petal overlapping translucent logo and the spiraling orbit dots.
class _FlowerLogoPainter extends CustomPainter {
  final double orbitProgress;

  _FlowerLogoPainter({required this.orbitProgress});

  // Clockwise starting from 3 o'clock:
  // 0: 3:00 -> Teal
  // 1: 4:30 -> Cyan Blue
  // 2: 6:00 -> Warm Orange
  // 3: 7:30 -> Golden Yellow
  // 4: 9:00 -> Bright Green
  // 5: 10:30 -> Lime Green
  // 6: 12:00 -> Vibrant Magenta / Purple
  // 7: 1:30 -> Soft Pink
  final List<Color> petalColors = [
    const Color(0xFF00BCB4), // 3:00 -> Teal
    const Color(0xFF2196F3), // 4:30 -> Cyan Blue
    const Color(0xFFFF9800), // 6:00 -> Warm Orange
    const Color(0xFFFFD54F), // 7:30 -> Golden Yellow
    const Color(0xFF4CAF50), // 9:00 -> Bright Green
    const Color(0xFF8BC34A), // 10:30 -> Lime Green
    const Color(0xFF9C27B0), // 12:00 -> Vibrant Magenta / Purple
    const Color(0xFFE91E63), // 1:30 -> Soft Pink
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.22; // 48.4 when size is 220x220

    // Draw the 8 translucent overlapping petals
    for (int i = 0; i < 8; i++) {
      // 0 radians points right (3:00).
      // We rotate clockwise by i * 45 degrees (i * 2 * pi / 8).
      final angle = i * (2 * math.pi / 8);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      
      final paint = Paint()
        ..color = petalColors[i].withValues(alpha: 0.60) // semi-translucent overlay
        ..style = PaintingStyle.fill;

      // Draw the asymmetric pinwheel petal path.
      // In local coordinates (after translation and rotation), pointing UP is negative Y.
      final path = Path();
      path.moveTo(0, 0);
      path.cubicTo(
        baseRadius * 0.675,  -baseRadius * 0.225, // cp1 (outer bulge)
        baseRadius * 0.825,  -baseRadius * 0.975, // cp2 (outer bulge)
        -baseRadius * 0.33,  -baseRadius * 1.35,  // tip
      );
      path.cubicTo(
        -baseRadius * 0.525, -baseRadius * 0.975, // cp1 (inner bulge)
        -baseRadius * 0.225, -baseRadius * 0.45,  // cp2 (inner bulge)
        0, 0,                                     // end back at center
      );
      path.close();

      canvas.drawPath(path, paint);
      canvas.restore();
    }

    // Draw the central focal point core
    // 1. Crisp small dark circle (outer black core)
    final corePaint = Paint()
      ..color = const Color(0xFF121517) // dark charcoal grey / black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * 0.45, corePaint);

    // 2. Yellow concentric ring (thin) - Fades in with orbitProgress
    final ringPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: orbitProgress) // Golden Yellow fading in
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, baseRadius * 0.26, ringPaint);

    // 3. Center solid yellow dot - Lerps from white to yellow with orbitProgress
    final centerDotColor = Color.lerp(
      const Color(0xFFF5F5F7), // Initial off-white dot
      const Color(0xFFFFD54F), // Target Golden Yellow
      orbitProgress,
    ) ?? const Color(0xFFFFD54F);

    final dotPaint = Paint()
      ..color = centerDotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * 0.12, dotPaint);

    // Draw the 4 cardinal points dots (Top, Right, Bottom, Left)
    // Aligned with the petals at 12:00, 3:00, 6:00, 9:00 (indices 6, 0, 2, 4)
    if (orbitProgress > 0) {
      final List<int> cardinalIndices = [0, 2, 4, 6];
      for (int i in cardinalIndices) {
        final double finalAngle = i * (2 * math.pi / 8);
        
        // Spiraling/orbiting physics logic matching the intro animation timeline:
        final double currentAngle = finalAngle - (3 * math.pi * (1.0 - orbitProgress));
        final double targetRadius = baseRadius * 1.52;
        final double currentRadius = targetRadius * orbitProgress;

        final double x = center.dx + currentRadius * math.cos(currentAngle);
        final double y = center.dy + currentRadius * math.sin(currentAngle);

        final dotColor = petalColors[i];
        final particlePaint = Paint()
          ..color = dotColor.withValues(alpha: math.min(1.0, orbitProgress * 1.2))
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(x, y),
          (baseRadius * 0.11) * math.min(1.0, orbitProgress * 1.2),
          particlePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowerLogoPainter oldDelegate) {
    return oldDelegate.orbitProgress != orbitProgress;
  }
}
