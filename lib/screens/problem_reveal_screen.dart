import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import 'problem_detail_screen.dart';

class ProblemRevealScreen extends StatefulWidget {
  final Problem problem;

  const ProblemRevealScreen({super.key, required this.problem});

  @override
  State<ProblemRevealScreen> createState() => _ProblemRevealScreenState();
}

class _ProblemRevealScreenState extends State<ProblemRevealScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleInAnimation;
  late Animation<double> _rotateInAnimation;
  late Animation<double> _zoomOutAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: const Duration(milliseconds: 3500), vsync: this);

    // 1. Entrance: Spin & Drop (0 - 1200ms)
    // Scale 0.0 -> 1.0 (with bounce)
    _scaleInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // Rotate 4pi -> 0 (Spinning in)
    _rotateInAnimation = Tween<double>(begin: 4.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Read Phase (Idle from 0.35 to 0.8)

    // 3. Exit: Zoom In (Expand newspaper) (0.8 - 1.0)
    // Scale 1.0 -> 15.0 (Zoom into the paper)
    _zoomOutAnimation = Tween<double>(begin: 1.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeInExpo),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.9, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) _enterExam();
    });
  }

  void _enterExam() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProblemDetailScreen(problem: widget.problem),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Authentic newspaper color
    final paperColor = const Color(0xFFEBE6D8);

    return Scaffold(
      backgroundColor: Colors.black, // Cinematic dark background
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Combine scale in and zoom out (scale out)
            double currentScale = _scaleInAnimation.value;
            if (_controller.value > 0.8) {
              currentScale = _zoomOutAnimation.value;
            }

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // 3D perspective
                ..rotateZ(_rotateInAnimation.value * math.pi) // Spin
                ..scale(currentScale), // Scale In/Out
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: FittedBox( // Scale down on small screens
                  fit: BoxFit.contain,
                  child: _buildNewspaper(paperColor),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNewspaper(Color paperColor) {
    return Container(
      width: 360,
      height: 600,
      decoration: BoxDecoration(
        color: paperColor,
        image: const DecorationImage(
          image: AssetImage('assets/images/vintage_newspaper_texture.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.white, BlendMode.multiply),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content Layer
          Padding(
             padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
             child: Column(
              children: [
              // --- HEADLINE SECTION ---
              Column(
                children: [
                    // Brand
                    Text(
                      "THE WORLD MATH",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        color: Colors.black87,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Divider Info Line
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: Colors.black87, width: 2.0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "VOL. ${widget.problem.date.year}",
                            style: _metaStyle(),
                          ),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy')
                                .format(widget.problem.date)
                                .toUpperCase(),
                            style: _metaStyle(),
                          ),
                          Text(
                            "PRICE: 100 PTS", // Simplified
                            style: _metaStyle(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // --- MAIN CONTENT SECTION ---
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Headline
                      Text(
                        widget.problem.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 0.95,
                          color: Colors.black,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Columns
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Text)
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                       Container(
                                        color: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Text(
                                          'BREAKING NEWS', 
                                          style: GoogleFonts.oswald(
                                            color: Colors.white, 
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10
                                          )
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Fake Article text
                                  Expanded(
                                    child: Text(
                                      _getTeaserText(),
                                      textAlign: TextAlign.justify,
                                      overflow: TextOverflow.fade,
                                      style: GoogleFonts.merriweather(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Right Column (Chart/Ad)
                            Expanded(
                              flex: 2,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  AspectRatio(
                                    aspectRatio: 1.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.black),
                                        color: Colors.grey.withOpacity(0.1),
                                      ),
                                      child: CustomPaint(painter: StockChartPainter()),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text("MARKET TREND", style: GoogleFonts.oswald(fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  
                                  // Divider
                                  const Divider(color: Colors.black, height: 16),

                                  // Weather Box
                                  Column(
                                    children: [
                                      const Icon(Icons.wb_sunny, size: 28),
                                      const SizedBox(height: 4),
                                      Text("HIGH 24°C", style: GoogleFonts.oswald(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ),
              
              const SizedBox(height: 12),
              
              // Footer
              Container(
                height: 4,
                color: Colors.black,
              ),
              const SizedBox(height: 2),
              Container(
                height: 1,
                color: Colors.black,
              ),
            ],
          ),
          ),

          // Grunge Overlay Layer (GenAI Asset)
          Positioned.fill(
            child: Image.asset(
              'assets/images/old_paper_overlay.png',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.2), // Subtle blend
              colorBlendMode: BlendMode.dstIn,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _metaStyle({double fontSize = 10, Color color = Colors.black}) {
    return GoogleFonts.courierPrime(
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      color: color,
    );
  }

  String _getTeaserText() {
    // Generate some dummy lorem ipsum based on the content or generic math chatter
    if (widget.problem.content.isNotEmpty) {
      String clean = widget.problem.content.replaceAll(RegExp(r'[*#\[\]]'), '');
      if (clean.length > 500) return "${clean.substring(0, 500)}..."; // Increased length
      return clean;
    }
    return "Global markets are shaking as a new mathematical paradox emerges from the World Math Institute. Analysts predict a surge in cognitive activity. Experts advise citizens to stay calm and calculate derivatives. The volatility index has reached an all-time high as students across the globe attempt to solve this week's problem...";
  }
}

// Simple Painter for a "Stock Chart" look
class StockChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    
    // Draw jagged line
    double x = 0;
    double y = size.height * 0.7;
    final r = math.Random(12345); // Fixed seed for consistency
    
    while (x < size.width) {
      x += size.width / 10;
      y = (size.height / 2) + (r.nextDouble() - 0.5) * (size.height * 0.8);
      path.lineTo(x, y);
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
