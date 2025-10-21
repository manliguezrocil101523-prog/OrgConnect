import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color mintBg = Color(0xFFEAF6F0);
  static const Color tealHeader = Color(0xFF79CFC4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mintBg,
      appBar: AppBar(
        backgroundColor: tealHeader,
        elevation: 0,
        title: const Text(
          'Home',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/signin');
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double circleSize =
              (constraints.maxWidth * 0.40).clamp(120.0, 180.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFF1B5E20), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Icon(
                          Icons.person,
                          size: circleSize * 0.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    _actionButton(
                      context: context,
                      label: 'Profile',
                      icon: Icons.groups_outlined,
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                    ),

                    const SizedBox(height: 12),

                    _actionButton(
                      context: context,
                      label: 'Organizations',
                      icon: Icons.groups_outlined,
                      onTap: () => Navigator.pushNamed(context, '/orglist'),
                    ),

                    const SizedBox(height: 12),
                    // Removed Dashboard button as per user request
                    // _actionButton(
                    //   context: context,
                    //   label: 'Dashboard',
                    //   icon: Icons.dashboard_outlined,
                    //   onTap: () => Navigator.push(
                    //     context,
                    //     MaterialPageRoute(
                    //         builder: (_) => const StudentDashboard()),
                    //   ),
                    // ),

                    _actionButton(
                      context: context,
                      label: 'Notifications',
                      icon: Icons.notifications_outlined,
                      onTap: () =>
                          Navigator.pushNamed(context, '/notifications'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: tealHeader,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 2,
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
