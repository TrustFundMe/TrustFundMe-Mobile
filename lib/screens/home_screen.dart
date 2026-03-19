import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'create_campaign_screen.dart';

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
            // 1. Hero Section (Updated to match FE design)
            _buildHero(context, webPrimary, webTextDark, webTextGray, webEmerald),

            // 2. About Section
            _buildAbout(webTextDark, webTextGray, webPrimary),

            // 3. Counter Section
            _buildCounter(webEmerald),

            // 4. Projects Section
            _buildProjects(webTextDark, webTextGray, webEmerald, webPrimary),

            // 5. Featured Section
            _buildFeatures(webPrimary, webTextDark),

            // 6. CTA Section
            _buildCTA(context, webEmerald, webPrimary),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, Color primary, Color dark, Color gray, Color emerald) {
    return Container(
      width: double.infinity,
      height: 400, // Reduced from 450 to reduce white space
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
          ),
          _buildRotatingBlob(
            color: emerald.withValues(alpha: 0.12),
            size: 300,
            bottom: -80,
            right: -80,
            duration: 15.seconds,
            isClockwise: false,
          ),

          // Text Content (Column)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 30, // Reduced from 34
                      fontWeight: FontWeight.w900, 
                      color: dark, 
                      height: 1.2,
                      fontFamily: 'Inter',
                    ),
                    children: [
                      const TextSpan(text: "Minh Bạch "),
                      TextSpan(text: "Trong\nTừng", style: TextStyle(color: primary)),
                      const TextSpan(text: " Khoản\nQuyên Góp"),
                    ],
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
                
                const SizedBox(height: 32),
                
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text("Quyên góp ngay", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        "Xem cộng đồng",
                        style: TextStyle(color: emerald, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                
                const SizedBox(height: 12),
                
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CreateCampaignScreen()),
                    );
                  },
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                  child: Text(
                    "Tạo chiến dịch của bạn →",
                    style: TextStyle(color: emerald.withValues(alpha: 0.8), fontWeight: FontWeight.w600, fontSize: 14, decoration: TextDecoration.underline),
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          ),

          // Floating Images (Adjusted for mobile spacing)
          _buildFloatingImage(
            "https://images.unsplash.com/photo-1593113598332-cd288d649433?w=500", // Volunteers
            size: 130, // Reduced from 150
            top: 60,
            right: 15, // Pushed more to the right
            delay: 200.ms,
          ),
          _buildFloatingImage(
            "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=500", // Kids
            size: 100, // Reduced from 110
            top: 180,
            right: 10,
            delay: 400.ms,
          ),
          _buildFloatingImage(
            "https://images.unsplash.com/photo-1532629345422-7515f3d16bb6?w=500", // Giving/Charity (Fixed irrelevant image)
            size: 105, // Slightly smaller
            top: 260, // Positioned where the red box was
            right: 130, // Adjusted leftwards
            delay: 600.ms,
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
          return Transform.rotate(
            angle: angle,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size * 0.4),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 40, spreadRadius: 20),
                ],
              ),
            ),
          );
        },
      ).animate().scale(duration: 2.seconds, curve: Curves.easeInOut).fadeIn(),
    );
  }

  Widget _buildFloatingImage(String url, {required double size, double? top, double? right, double? bottom, required Duration delay}) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 10)),
          ],
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[100],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(delay: delay)
          .scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack, duration: 800.ms)
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .slideY(begin: 0, end: 0.05, duration: 3.seconds, curve: Curves.easeInOut),
    );
  }

  Widget _buildAbout(Color dark, Color gray, Color primary) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "VỀ CHÚNG TÔI",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: primary, letterSpacing: 2.0),
          ).animate().shimmer(duration: 2.seconds, color: primary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            "Vì một thế giới tốt đẹp hơn",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: dark),
          ),
          const SizedBox(height: 16),
          const Text(
            "Chúng tôi tin rằng sự minh bạch là chìa khóa để xây dựng niềm tin trong các hoạt động thiện nguyện. TrustFundMe cam kết 100% số tiền của bạn được chuyển đến đúng nơi cần thiết.",
            style: TextStyle(color: Colors.grey, height: 1.6, fontSize: 16),
          ),
          const SizedBox(height: 24),
          _buildAboutItem(Icons.verified_user_rounded, "Báo cáo minh bạch 24/7", 800.ms),
          _buildAboutItem(Icons.security_rounded, "Bảo mật thông tin đóng góp", 1000.ms),
          _buildAboutItem(Icons.auto_awesome_rounded, "Hỗ trợ công nghệ AI tiên tiến", 1200.ms),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 400.ms);
  }

  Widget _buildAboutItem(IconData icon, String text, Duration animDelay) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A685B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1A685B)),
          ),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    ).animate().fadeIn(delay: animDelay).slideX(begin: -0.1);
  }

  Widget _buildCounter(Color emerald) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [emerald, emerald.withBlue(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: emerald.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _AnimatedCounterItem("1.2", "K+", "Chiến dịch"),
          _AnimatedCounterItem("50", "B+", "Đã quyên góp"),
          _AnimatedCounterItem("100", "K+", "Nhà hảo tâm"),
        ],
      ),
    ).animate().scale(delay: 500.ms, duration: 600.ms, curve: Curves.easeOutBack);
  }

  Widget _buildProjects(Color dark, Color gray, Color emerald, Color primary) {
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
                onPressed: () {},
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
          height: 320,
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
                "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=500",
              ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2),
              _ProjectCard(
                "Cứu trợ thiên tai",
                "Hỗ trợ khẩn cấp cho các gia đình bị ảnh hưởng bão.",
                0.40,
                primary,
                "https://images.unsplash.com/photo-1593113598332-cd288d649433?w=500",
              ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures(Color primary, Color dark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "TẠI SAO CHỌN CHÚNG TÔI",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 2.0),
          ),
          const SizedBox(height: 20),
          _FeatureTile(Icons.remove_red_eye_outlined, "Minh bạch hóa", "Mọi giao dịch đều được ghi lại công khai.", 200.ms),
          _FeatureTile(Icons.bolt_rounded, "Phản hồi nhanh", "Hỗ trợ khẩn cấp ngay khi có thiên tai xảy ra.", 400.ms),
          _FeatureTile(Icons.groups_rounded, "Cộng đồng mạnh", "Kết nối hàng nghìn tình nguyện viên trên toàn quốc.", 600.ms),
        ],
      ),
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
          ).animate(onPlay: (controller) => controller.repeat())
           .shimmer(duration: 3.seconds, color: Colors.white24),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 10,
              shadowColor: primary.withValues(alpha: 0.5),
            ),
            child: const Text("Bắt đầu ngay", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.05, 1.05)),
        ],
      ),
    ).animate().fadeIn(delay: 1.seconds).slideY(begin: 0.2);
  }
}

class _AnimatedCounterItem extends StatefulWidget {
  final String value;
  final String suffix;
  final String label;
  const _AnimatedCounterItem(this.value, this.suffix, this.label);

  @override
  State<_AnimatedCounterItem> createState() => _AnimatedCounterItemState();
}

class _AnimatedCounterItemState extends State<_AnimatedCounterItem> {
  @override
  Widget build(BuildContext context) {
    double targetValue = double.tryParse(widget.value) ?? 0;
    
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Animate().custom(
              duration: 2.seconds,
              curve: Curves.easeOutExpo,
              builder: (context, value, child) {
                double current = value * targetValue;
                return Text(
                  widget.value.contains('.') ? current.toStringAsFixed(1) : current.toInt().toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                );
              },
            ),
            Text(widget.suffix, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(widget.label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
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
                Image.network(imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
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
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 2),
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

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Duration delay;
  const _FeatureTile(this.icon, this.title, this.desc, this.delay);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFF84D43), size: 26),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    ).animate().fadeIn(delay: delay).slideX(begin: 0.1);
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

