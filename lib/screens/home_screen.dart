import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Colors matching the design system
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
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: webTextDark),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: webTextDark),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: webPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, color: webPrimary, size: 14),
                        SizedBox(width: 4),
                        Text(
                          "TrustFundMe Impact",
                          style: TextStyle(
                            color: webPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Radical Transparency\nin Every Donation",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: webTextDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Track your impact in real-time with Vietnam's first AI-powered charity management platform.",
                    style: TextStyle(
                      fontSize: 14,
                      color: webTextGray,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: webPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text("Donate Now", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: webEmerald,
                          side: const BorderSide(color: webEmerald, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Campaigns", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Section Header: Our Impact
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Latest Fundraisers",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: webTextDark,
                        ),
                      ),
                      Text(
                        "Inspired by what you care about",
                        style: TextStyle(
                          fontSize: 14,
                          color: webTextGray,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text("See All", style: TextStyle(color: webEmerald)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // horizontal list of projects
            SizedBox(
              height: 320,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                   _buildProjectCard(
                    context,
                    "Education for All",
                    "Building Schools in Rural Areas",
                    0.625,
                    "125k raised",
                    "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?fit=crop&w=400&h=300",
                  ),
                  _buildProjectCard(
                    context,
                    "Clean Water Initiative",
                    "Wells for Communities",
                    0.785,
                    "78.5k raised",
                    "https://images.unsplash.com/photo-1532629345422-7515f3d16bb6?fit=crop&w=400&h=300",
                  ),
                  _buildProjectCard(
                    context,
                    "Healthcare Access",
                    "Mobile Clinics Outreach",
                    0.45,
                    "95k raised",
                    "https://images.unsplash.com/photo-1593113598332-cd288d649433?fit=crop&w=400&h=300",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // CTA Section
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: webEmerald,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text(
                    "Ready to make a difference?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Join thousands of donors who trust our AI-powered transparency.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: webEmerald,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Get Started Now", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, String title, String subtitle, double progress, String raisedText, String imageUrl) {
    const Color webPrimary = Color(0xFFF84D43);
    const Color webTextDark = Color(0xFF1F2937);
    const Color webTextGray = Color(0xFF4B5563);

    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.network(
              imageUrl,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: webTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: webTextGray,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(webPrimary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      raisedText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: webTextDark,
                      ),
                    ),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: webPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
