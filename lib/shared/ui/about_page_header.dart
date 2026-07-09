import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../engine/localization_engine.dart';
import 'app_text_styles.dart';

/// About page header card with detailed book illustration and metadata.
/// 
/// Displays a centered, modern 3D book illustration with floating icons,
/// app title, subtitle, and version information on a light blue gradient background.
class AboutPageHeader extends StatelessWidget {
  const AboutPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoColors.secondarySystemBackground.resolveFrom(context);
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Main illustration area with book and floating icons
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft light blue background glow
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.8,
                        colors: [
                          primaryColor.withOpacity(0.08),
                          primaryColor.withOpacity(0.02),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                )  ,
                // Micro-particles and geometric shapes (background layer)
                Positioned(
                  top: 15,
                  left: 20,
                  child: _MicroParticle(
                    color: primaryColor.withOpacity(0.3),
                    size: 3,
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 30,
                  child: _MicroParticle(
                    color: const Color.fromARGB(255, 76, 175, 80).withOpacity(0.3),
                    size: 2,
                  ),
                ),
                Positioned(
                  top: 30,
                  right: 40,
                  child: Transform.rotate(
                    angle: 0.785, // 45 degrees
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 152, 0).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 25,
                  left: 25,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                
                // Central book illustration (simplified 3D representation)
                _BookIllustration(primaryColor: primaryColor, size: 70),
                
                // Floating icon 1: Clock (Time)
                Positioned(
                  top: 20,
                  left: 20,
                  child: _FloatingIcon(
                    icon: CupertinoIcons.clock_solid,
                    color: primaryColor,
                    backgroundColor: primaryColor.withOpacity(0.15),
                    size: 36,
                  ),
                ),
                
                // Floating icon 2: Bar chart (Statistics)
                Positioned(
                  top: 40,
                  right: 20,
                  child: _FloatingIcon(
                    icon: CupertinoIcons.chart_bar_fill,
                    color: const Color.fromARGB(255, 76, 175, 80),
                    backgroundColor: const Color.fromARGB(255, 76, 175, 80).withOpacity(0.15),
                    size: 36,
                  ),
                ),
                
                // Floating icon 3: Open book (Content)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: _FloatingIcon(
                    icon: CupertinoIcons.book_fill,
                    color: const Color.fromARGB(255, 255, 152, 0),
                    backgroundColor: const Color.fromARGB(255, 255, 152, 0).withOpacity(0.15),
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Title: BookReader
          Text(
            'BookReader',
            style: AppTextStyles.pageTitle(context).copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 6),
          
          // Subtitle: Chinese mission statement
          Text(
            LocalizationEngine.text('about_app_mission') ?? '专注阅读，让每一次打开都值得',
            style: AppTextStyles.secondary(context).copyWith(
              fontSize: 12,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Version 1.0.0',
              style: AppTextStyles.secondary(context).copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3D-style book illustration positioned in the center of the header.
class _BookIllustration extends StatelessWidget {
  final Color primaryColor;
  final double size;

  const _BookIllustration({
    required this.primaryColor,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BookPainter(primaryColor: primaryColor),
        size: Size(size, size),
      ),
    );
  }
}

/// Custom painter to render a simplified 3D book illustration.
class _BookPainter extends CustomPainter {
  final Color primaryColor;

  _BookPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintBlue = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    
    final paintDarkBlue = Paint()
      ..color = primaryColor.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    final paintWhite = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    
    final paintGrey = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Book spine (dark blue back)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(8, 0),
          width: 30,
          height: 110,
        ),
        const Radius.circular(4),
      ),
      paintDarkBlue,
    );

    // Left page (white)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(-20, 0),
          width: 55,
          height: 100,
        ),
        const Radius.circular(3),
      ),
      paintWhite,
    );

    // Right page (white)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(20, 0),
          width: 55,
          height: 100,
        ),
        const Radius.circular(3),
      ),
      paintWhite,
    );

    // Book cover (blue)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: 120,
          height: 100,
        ),
        const Radius.circular(6),
      ),
      paintBlue,
    );

    // Text lines on left page (subtle)
    final leftPageLeft = center.dx - 38;
    const lineSpacing = 12;
    const lineHeight = 2;
    const lineWidth = 30;
    
    for (int i = 0; i < 5; i++) {
      final y = center.dy - 35 + (i * lineSpacing);
      canvas.drawLine(
        Offset(leftPageLeft, y),
        Offset(leftPageLeft + lineWidth, y),
        paintGrey,
      );
    }

    // Text lines on right page (subtle)
    final rightPageLeft = center.dx + 8;
    for (int i = 0; i < 5; i++) {
      final y = center.dy - 35 + (i * lineSpacing);
      canvas.drawLine(
        Offset(rightPageLeft, y),
        Offset(rightPageLeft + lineWidth, y),
        paintGrey,
      );
    }
  }

  @override
  bool shouldRepaint(_BookPainter oldDelegate) => false;
}

/// Floating rounded-corner icon badge.
class _FloatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double size;

  const _FloatingIcon({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.size = 48,
  });

  @override
  State<_FloatingIcon> createState() => _FloatingIconState();
}

class _FloatingIconState extends State<_FloatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.size / 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          size: widget.size * 0.5,
          color: widget.color,
        ),
      ),
    );
  }
}

/// Simple micro-particle shape for visual detail.
class _MicroParticle extends StatelessWidget {
  final Color color;
  final double size;

  const _MicroParticle({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
