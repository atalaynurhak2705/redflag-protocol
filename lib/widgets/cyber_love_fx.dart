import 'dart:math';
import 'package:flutter/material.dart';

// Bu widget'ı Dashboard'un en üstüne (Stack içine) koyacağız.
// GlobalKey kullanarak dışarıdan tetikleyeceğiz.
class CyberLoveFX extends StatefulWidget {
  final Widget child;

  const CyberLoveFX({Key? key, required this.child}) : super(key: key);

  @override
  CyberLoveFXState createState() => CyberLoveFXState();
}

class CyberLoveFXState extends State<CyberLoveFX> with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<HeartParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        setState(() {
          // Animasyon bittiğinde particle listesini temizle
          if (_controller.status == AnimationStatus.completed) {
            _particles.clear();
            _controller.reset();
          }
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Dışarıdan çağrılacak metot: Ekrana aşk parçacıkları saçar
  void triggerLoveBurst() {
    _particles.clear();
    // 15-20 arası kalp oluştur
    for (int i = 0; i < 20; i++) {
      _particles.add(HeartParticle(random: _random));
    }
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Alttaki ana ekran (Dashboard)
        widget.child,
        
        // Animasyon Katmanı
        if (_controller.isAnimating)
          Positioned.fill(
            child: IgnorePointer( // Dokunmayı engelleme, arkaya geçir
              child: CustomPaint(
                painter: HeartExplosionPainter(
                  particles: _particles,
                  progress: _controller.value,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --- PARTICLE SİSTEMİ ---

class HeartParticle {
  late double x;
  late double y;
  late double size;
  late double speed;
  late double angle;
  late Color color;

  HeartParticle({required Random random}) {
    // Ekranın ortasından biraz aşağıdan başlasın
    x = 0.5; 
    y = 0.6; 
    
    // Rastgele saçılma açısı
    angle = (random.nextDouble() * 360) * (pi / 180);
    
    speed = 0.3 + random.nextDouble() * 0.4; // Hız
    size = 10.0 + random.nextDouble() * 20.0; // Boyut
    
    // Renkler: Aşk Kırmızısı ve Tech Cyan karışımı
    color = random.nextBool() 
        ? const Color(0xFFFF2000) // Neon Red
        : const Color(0xFF00E5FF); // Neon Cyan
  }
}

class HeartExplosionPainter extends CustomPainter {
  final List<HeartParticle> particles;
  final double progress;

  HeartExplosionPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      // Hareket mantığı: Yukarı ve yanlara doğru yayılma
      final double dx = (cos(particle.angle) * particle.speed * progress);
      final double dy = (-1 * particle.speed * progress) - (progress * 0.5); // Yukarı daha hızlı
      
      final double posX = (particle.x * size.width) + (dx * size.width);
      final double posY = (particle.y * size.height) + (dy * size.height);

      // Opaklık zamanla azalır
      final double opacity = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = particle.color.withOpacity(opacity);

      // Gölge efekti (Neon Glow)
      final shadowPaint = Paint()
        ..color = particle.color.withOpacity(opacity * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.save();
      canvas.translate(posX, posY);
      
      // Cyberpunk Kalp Çizimi (Tech Heart)
      Path heartPath = Path();
      // Biraz daha köşeli, "Tech" görünümlü bir kalp
      double s = particle.size * (1 - progress * 0.2); // Giderek hafif küçülür
      
      heartPath.moveTo(0, s * 0.3);
      heartPath.cubicTo(-s * 0.5, -s * 0.2, -s * 0.5, s * 0.6, 0, s); // Sol taraf
      heartPath.cubicTo(s * 0.5, s * 0.6, s * 0.5, -s * 0.2, 0, s * 0.3); // Sağ taraf
      
      canvas.drawPath(heartPath, shadowPaint); // Glow çiz
      canvas.drawPath(heartPath, paint); // Ana kalp çiz
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}