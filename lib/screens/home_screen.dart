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

            // 2. About Us section
            _buildAboutUs(context, webPrimary, webTextDark, webTextGray, webEmerald),

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
    final double screenW = MediaQuery.sizeOf(context).width;
    final bool isHeroMobile = screenW < 600;

    return Container(
      width: double.infinity,
      height: 450,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DotPainter(color: Colors.grey.withOpacity(0.06)),
            ),
          ),
          _buildRotatingBlob(
            color: const Color(0xFFFFE5E5).withOpacity(0.4),
            size: 320, top: -40, left: -60, duration: 25.seconds,
          ),
          _buildRotatingBlob(
            color: emerald.withOpacity(0.12),
            size: 350, bottom: -80, right: -100, duration: 30.seconds,
          ),
          
          // Floating images cluster per screenshot
          Positioned(
            right: 10, top: 80,
            child: _buildCollageImage(
              url: 'https://images.unsplash.com/photo-1593113598332-cd288d649433?q=80&w=1280&auto=format&fit=crop',
              size: 130, borderRadius: 24,
            ).animate(delay: 200.ms).fadeIn(),
          ),
          Positioned(
            right: -20, top: 200,
            child: _buildCollageImage(
              url: 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?q=80&w=1280&auto=format&fit=crop',
              size: 140, borderRadius: 24,
            ).animate(delay: 400.ms).fadeIn(),
          ),
          Positioned(
            right: 120, bottom: 20,
            child: _buildCollageImage(
              url: 'https://images.unsplash.com/photo-1469571486292-0ba58a3f068b?q=80&w=1280&auto=format&fit=crop',
              size: 110, borderRadius: 24,
            ).animate(delay: 600.ms).fadeIn(),
          ),

          // Text and Actions on the left
          Positioned(
            left: 24, top: 60,
            width: MediaQuery.of(context).size.width * 0.65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: dark, height: 1.1),
                    children: isHeroMobile
                        ? [
                            const TextSpan(text: "Minh Bạch\n"),
                            TextSpan(
                              text: "Trong\n",
                              style: TextStyle(color: primary),
                            ),
                            TextSpan(
                              text: "Từng\n",
                              style: TextStyle(color: primary),
                            ),
                            const TextSpan(text: "Khoản\nQuyên Góp"),
                          ]
                        : [
                            const TextSpan(text: "Minh Bạch "),
                            TextSpan(
                              text: "Trong\nTừng",
                              style: TextStyle(color: primary),
                            ),
                            const TextSpan(text: " Khoản\nQuyên Góp"),
                          ],
                  ),
                ).animate().fadeIn(),
                SizedBox(height: isHeroMobile ? 36 : 30),
                _buildHeroActions(context, primary, dark, emerald).animate(delay: 800.ms).fadeIn(),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildCollageImage(
      {required String url, required double size, required double borderRadius}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 4),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFF3F4F6),
            child: const Icon(Icons.image_outlined, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroActions(BuildContext context, Color primary, Color dark, Color emerald) {
    final bool isMobile = MediaQuery.sizeOf(context).width < 600;
    final double btnFont = isMobile ? 15.5 : 13;
    final EdgeInsets btnPad = isMobile
        ? const EdgeInsets.symmetric(horizontal: 26, vertical: 18)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    final double btnRadius = isMobile ? 16 : 14;

    return Wrap(
      spacing: isMobile ? 14 : 12,
      runSpacing: isMobile ? 14 : 12,
      children: [
        _buildButton(
          text: "Quyên góp ngay",
          color: primary,
          textColor: Colors.white,
          padding: btnPad,
          fontSize: btnFont,
          borderRadius: btnRadius,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const CampaignsScreen()),
            );
          },
        ),
        _buildButton(
          text: "Tạo chiến dịch →",
          color: dark.withOpacity(0.08),
          textColor: dark,
          padding: btnPad,
          fontSize: btnFont,
          borderRadius: btnRadius,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const CreateCampaignScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
    EdgeInsets? padding,
    double? fontSize,
    double? borderRadius,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 14),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: fontSize ?? 13,
        ),
      ),
    );
  }

  Widget _buildAboutUs(BuildContext context, Color primary, Color dark, Color gray, Color emerald) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 24),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 2,
                color: primary,
              ),
              const SizedBox(width: 8),
              Text(
                "VỀ CHÚNG TÔI",
                style: TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ).animate().fadeIn(),
          const SizedBox(height: 12),
          Text(
            "Vì một thế giới\ntốt đẹp hơn",
            style: TextStyle(
              color: dark,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),
          Text(
            "Chúng tôi tin rằng sự minh bạch là chìa khóa để xây dựng niềm tin trong các hoạt động thiện nguyện.",
            style: TextStyle(
              color: gray.withOpacity(0.7),
              fontSize: 15,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 28),
          _buildFeatureRow(
            icon: Icons.verified_rounded,
            title: "Báo cáo minh bạch 24/7",
            color: const Color(0xFF1B5E20),
          ).animate().fadeIn(delay: 600.ms),
          const SizedBox(height: 16),
          _buildFeatureRow(
            icon: Icons.shield_rounded,
            title: "Bảo mật thông tin đóng góp",
            color: const Color(0xFF00695C),
          ).animate().fadeIn(delay: 700.ms),
          const SizedBox(height: 16),
          _buildFeatureRow(
            icon: Icons.auto_awesome_rounded,
            title: "Hỗ trợ công nghệ AI tiên tiến",
            color: const Color(0xFF37474F),
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({required IconData icon, required String title, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
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
          colorFilter: ColorFilter.mode(emerald.withOpacity(0.1), BlendMode.srcIn),
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
              shadowColor: primary.withOpacity(0.5),
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
            color: Colors.black.withOpacity(0.08),
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

