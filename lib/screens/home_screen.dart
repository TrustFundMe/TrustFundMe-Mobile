import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'campaigns_screen.dart';
import 'create_campaign_screen.dart';
import '../core/providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color webPrimary = Color(0xFFF84D43);
    const Color webBgGray = Color(0xFFF9FAFB);
    const Color webTextDark = Color(0xFF1F2937);
    const Color webTextGray = Color(0xFF4B5563);
    const Color webEmerald = Color(0xFF1A685B);

    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Image.asset(
          'assets/images/black-logo.png',
          height: 32,
          fit: BoxFit.contain,
        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: webTextDark),
            onPressed: () {},
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 1. Hero section
            _buildHero(context, webPrimary, webTextDark, webTextGray, webEmerald),

            // 3. Projects section
            _buildProjects(
              context,
              webTextDark,
              webTextGray,
              webEmerald,
              webPrimary,
            ),

            // 4. CTA section
            _buildCTA(context, webEmerald, webPrimary),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(
      BuildContext context, Color primary, Color dark, Color gray, Color emerald) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double heroHeight = math.max(320, math.min(screenHeight * 0.58, 460));
    return Container(
      width: double.infinity,
      height: heroHeight,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Background Dots Pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _DotPainter(color: Colors.grey.withValues(alpha: 0.1)),
            ),
          ),

          // Rotating Blobs (Background Animations)
          _buildRotatingBlob(
            color: primary.withValues(alpha: 0.15),
            size: 250,
            top: -50,
            left: -50,
            duration: 10.seconds,
            driftX: 14,
            driftY: 10,
          ),
          _buildRotatingBlob(
            color: emerald.withValues(alpha: 0.12),
            size: 300,
            bottom: -80,
            right: -80,
            duration: 15.seconds,
            isClockwise: false,
            driftX: 16,
            driftY: 12,
          ),
          _buildRotatingBlob(
            color: primary.withValues(alpha: 0.08),
            size: 170,
            top: 120,
            right: 60,
            duration: 12.seconds,
            driftX: 10,
            driftY: 8,
          ),

          // Text + actions occupy ~70% hero height
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight * 0.92,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: dark,
                                height: 0.98,
                              ),
                              children: [
                                const TextSpan(text: "Minh Bạch "),
                                TextSpan(text: "Trong\nTừng", style: TextStyle(color: primary)),
                                const TextSpan(text: " Khoản\nQuyên Góp"),
                              ],
                            ),
                          ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
                          const SizedBox(height: 10),
                          Text(
                            "Theo dõi dòng tiền theo từng hạng mục, từng chiến dịch.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: gray.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ).animate().fadeIn(delay: 120.ms, duration: 450.ms),
                          const Spacer(),
                          _buildHeroActions(context, primary, emerald)
                              .animate()
                              .fadeIn(delay: 300.ms)
                              .slideY(begin: 0.2),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  Widget _buildRotatingBlob({
    required Color color,
    required double size,
    double? top,
    double? left,
    double? right,
    double? bottom,
    required Duration duration,
    bool isClockwise = true,
    double driftX = 0,
    double driftY = 0,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Animate(
        onPlay: (controller) => controller.repeat(),
      ).custom(
        duration: duration,
        builder: (context, value, child) {
          final angle = isClockwise ? value * 2 * math.pi : -value * 2 * math.pi;
          final double dx = math.sin(value * 2 * math.pi) * driftX;
          final double dy = math.cos(value * 2 * math.pi) * driftY;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: angle,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(size * 0.4),
                ),
              ),
            ),
          );
        },
      ).animate().fadeIn(),
    );
  }

  Widget _buildHeroActions(BuildContext context, Color primary, Color emerald) {
    final auth = context.read<AuthProvider>();
    final bool isFundOwner = auth.user?.role.toUpperCase() == 'FUND_OWNER';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CampaignsScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: primary.withValues(alpha: 0.28),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_outline, size: 18),
              SizedBox(width: 8),
              Text(
                "Quyên góp ngay",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CampaignsScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: 0.45)),
                backgroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_2_outlined, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "Cộng đồng",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => isFundOwner
                        ? const CampaignsScreen()
                        : const CreateCampaignScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: 0.45)),
                backgroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isFundOwner ? "Chiến dịch của tôi" : "Tạo chiến dịch",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjects(
    BuildContext context,
    Color dark,
    Color gray,
    Color emerald,
    Color primary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Chiến dịch nổi bật", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dark)),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CampaignsScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text("Tất cả", style: TextStyle(color: emerald, fontWeight: FontWeight.bold)),
                    const Icon(Icons.arrow_forward_ios, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 340,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ProjectCard(
                "Quỹ Trẻ em vùng cao",
                "Hỗ trợ sách vở và trường học cho các bé vùng núi.",
                0.75,
                primary,
                "https://placehold.co/800x500.png?text=Tre+em+vung+cao&bg=DBEAFE&color=0F172A",
              ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2),
              _ProjectCard(
                "Cứu trợ thiên tai",
                "Hỗ trợ khẩn cấp cho các gia đình bị ảnh hưởng bão.",
                0.40,
                primary,
                "https://placehold.co/800x500.png?text=Cuu+tro+thien+tai&bg=E2E8F0&color=0F172A",
              ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCTA(BuildContext context, Color emerald, Color primary) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(32),
        image: DecorationImage(
          image: const NetworkImage("https://www.transparenttextures.com/patterns/carbon-fibre.png"),
          opacity: 0.1,
          colorFilter: ColorFilter.mode(emerald.withValues(alpha: 0.1), BlendMode.srcIn),
        ),
      ),
      child: Column(
        children: [
          const Text(
            "Bạn đã sẵn sàng để\ntạo ra sự khác biệt?",
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateCampaignScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 10,
              shadowColor: primary.withValues(alpha: 0.5),
            ),
            child: const Text("Bắt đầu ngay", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ).animate().fadeIn(delay: 120.ms),
        ],
      ),
    ).animate().fadeIn(delay: 1.seconds).slideY(begin: 0.2);
  }
}

class _ProjectCard extends StatelessWidget {
  final String title;
  final String desc;
  final double progress;
  final Color primary;
  final String imageUrl;
  const _ProjectCard(this.title, this.desc, this.progress, this.primary, this.imageUrl);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 20, bottom: 10, top: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    color: const Color(0xFFE5E7EB),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFF9CA3AF),
                      size: 30,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.favorite_border, size: 18, color: primary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress, 
                    backgroundColor: Colors.grey[100], 
                    color: primary, 
                    minHeight: 8,
                  ),
                ).animate().shimmer(delay: 1.seconds, duration: 2.seconds),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${(progress * 100).toInt()}%", style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text("Đã quyên góp", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Custom Painter for Dot Pattern Background
class _DotPainter extends CustomPainter {
  final Color color;
  _DotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const double spacing = 20.0;
    const double dotSize = 1.5;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

