import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'shared_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize auth service
  final auth = AuthService();
  await auth.init();
  
  runApp(const LegoApp());
}

class LegoApp extends StatelessWidget {
  const LegoApp({super.key});

  static const Color legoRed     = Color(0xFFC91A09);
  static const Color legoYellow  = Color(0xFFFFD700);
  static const Color legoDark    = Color(0xFF1A1F2E);
  static const Color legoBlue    = Color(0xFF006DB7);
  static const Color legoSurface = Color(0xFFFFFFFF);
  static const Color legoBg      = Color(0xFFF5F5F5);
  static const Color legoMuted   = Color(0xFF888888);
  static const Color legoBorder  = Color(0xFFEEEEEE);

  static const double radiusCard  = 16;
  static const double radiusBtn   = 12;
  static const double radiusBadge = 8;
  static const double pagePadding = 16;
  static const double cardPadding = 16;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'LEGO Brick Detection & Inventory',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: legoRed,
          brightness: Brightness.light,
          scaffoldBackgroundColor: legoBg,
          textTheme: GoogleFonts.outfitTextTheme(),
          appBarTheme: AppBarTheme(
            backgroundColor: legoDark,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.outfit(
              fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: legoBorder),
            ),
            surfaceTintColor: Colors.white,
            color: legoSurface,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: legoRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: legoBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: legoRed, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          }),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth Gate (uses Provider instead of ValueListenable)
// ---------------------------------------------------------------------------

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return Scaffold(
            backgroundColor: LegoApp.legoBg,
            body: Center(
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                  const SizedBox(height: 24),
                  Container(width: 200, height: 20, color: Colors.white),
                  const SizedBox(height: 12),
                  Container(width: 140, height: 14, color: Colors.white),
                ]),
              ),
            ),
          );
        }
        return auth.isLoggedIn ? const HomeScreen() : const AuthPage();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Auth Page (updated to use AuthService)
// ---------------------------------------------------------------------------

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool _isLoading = false;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _username = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!isLogin && _pass.text.trim() != _confirm.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    Map<String, dynamic> result;

    if (isLogin) {
      result = await auth.login(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
    } else {
      result = await auth.register(
        email: _email.text.trim(),
        password: _pass.text.trim(),
        username: _username.text.isNotEmpty ? _username.text.trim() : null,
      );
    }

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Success!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Authentication failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LegoApp.legoBg,
      body: Column(
        children: [
          // ── RED HERO HEADER with stud-dot pattern ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 32,
              bottom: 40,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC91A09), Color(0xFF8B1207)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Stack(
              children: [
                // Stud dot pattern overlay
                Positioned.fill(
                  child: CustomPaint(painter: _StudPatternPainter()),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.view_in_ar, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'LEGO Brick Counter',
                      style: GoogleFonts.outfit(
                        fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLogin ? 'Sign in to continue' : 'Join the LEGO community',
                      style: GoogleFonts.outfit(
                        fontSize: 14, color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── WHITE FORM CARD ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  decoration: BoxDecoration(
                    color: LegoApp.legoSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LegoApp.legoBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLogin ? 'Welcome Back!' : 'Create Account',
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: LegoApp.legoDark),
                      ),
                      const SizedBox(height: 24),
                      if (!isLogin) ...[
                        TextField(
                          controller: _username,
                          decoration: const InputDecoration(
                            labelText: 'Username (optional)',
                            prefixIcon: Icon(Icons.person_outline, color: LegoApp.legoRed),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: LegoApp.legoRed),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: LegoApp.legoRed),
                        ),
                      ),
                      if (!isLogin) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirm,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_outline, color: LegoApp.legoRed),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isLoading
                            ? Shimmer.fromColors(
                                key: const ValueKey('loading'),
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade100,
                                child: Container(width: double.infinity, height: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                              )
                            : SizedBox(
                                key: const ValueKey('button'),
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _submit();
                                  },
                                  child: Text(isLogin ? 'Login' : 'Register'),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          if (!_isLoading) setState(() => isLogin = !isLogin);
                        },
                        child: Text(
                          isLogin ? 'New here? Create an account' : 'Already have an account? Login',
                          style: const TextStyle(color: LegoApp.legoRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stud-dot pattern painter for the hero header
class _StudPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    const spacing = 32.0;
    const radius = 6.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Home Screen (unchanged)
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        onScanTap: () => setState(() => _idx = 1),
        onInventoryTap: () => setState(() => _idx = 3),
      ),
      const ScanScreen(),
      const ScanHistoryScreen(),
      const InventoryScreen(),
      const RecommendationsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LEGO Brick Detection'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(key: ValueKey(_idx), child: _screens[_idx]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black26,
        indicatorColor: LegoApp.legoYellow.withValues(alpha: 0.3),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: LegoApp.legoRed), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt, color: LegoApp.legoRed), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history, color: LegoApp.legoRed), label: 'History'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2, color: LegoApp.legoRed), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.construction_outlined), selectedIcon: Icon(Icons.construction, color: LegoApp.legoRed), label: 'Builds'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: LegoApp.legoRed), label: 'Profile'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard Screen
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onScanTap;
  final VoidCallback? onInventoryTap;
  
  const DashboardScreen({super.key, this.onScanTap, this.onInventoryTap});
  
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _data = {};
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }
  
  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final data = await ApiService.getDashboardData();
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final username = auth.user?['username'] ?? 'Builder';

    return Scaffold(
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Could not load dashboard'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loadDashboard,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // ── DARK HERO HEADER ──
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 20,
                      right: 20,
                      bottom: 24,
                    ),
                    decoration: const BoxDecoration(
                      color: LegoApp.legoDark,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, $username!',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'What will you build today?',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white70),
                              onPressed: _loadDashboard,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // ── STAT CHIPS ──
                        Row(
                          children: [
                            _heroStatChip(Icons.widgets, '${_data['totalBricks'] ?? 0}', 'Bricks'),
                            const SizedBox(width: 8),
                            _heroStatChip(Icons.category_outlined, '${_data['uniqueTypes'] ?? 0}', 'Types'),
                            const SizedBox(width: 8),
                            _heroStatChip(Icons.document_scanner_outlined, '${_data['totalScans'] ?? 0}', 'Scans'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── BODY ──
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── SCAN CTA BANNER ──
                      GestureDetector(
                        onTap: widget.onScanTap,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ready to scan?',
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: LegoApp.legoDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Identify bricks instantly with AI',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: LegoApp.legoDark.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: LegoApp.legoDark.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.camera_alt, color: LegoApp.legoDark, size: 28),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                      // D) Recent Scan
                      _sectionHeader('LAST SCAN'),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: LegoApp.legoSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: LegoApp.legoBorder),
                        ),
                        child: _isLoading
                            ? Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              )
                            : _data['lastScanDate'] == null
                                ? Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      const Text('No scans yet — try scanning some bricks!'),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      const Icon(Icons.access_time, color: LegoApp.legoYellow),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Most Recent Scan',
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                                            ),
                                            Text(
                                              _formatDate(_data['lastScanDate']),
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        label: Text('${_data['totalScans']} total'),
                                        backgroundColor: LegoApp.legoYellow.withValues(alpha: 0.2),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ),
                      ),
                      
                      // E) Buildable Sets
                      _sectionHeader('SETS YOU CAN BUILD'),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: LegoApp.legoSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: LegoApp.legoBorder),
                        ),
                        child: _isLoading
                            ? Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              )
                            : (_data['buildableSets'] == 0 && _data['topSet'] == null)
                                ? Text(
                                    'Add more bricks to your inventory to see buildable sets',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${_data['buildableSets']}',
                                            style: const TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.w700,
                                              color: LegoApp.legoYellow,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'sets are 50%+\ncomplete',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                                                ),
                                                Text(
                                                  'based on your inventory',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_data['topSet'] != null) ...[
                                        const Divider(height: 24),
                                        Text(
                                          'TOP MATCH',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey.shade600,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _data['topSet']['name'] ?? 'Unknown Set',
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15),
                                              ),
                                            ),
                                            Text(
                                              '${_data['topSet']['completion_percentage'] ?? 0}%',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: LegoApp.legoYellow,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (_data['topSet']['completion_percentage'] ?? 0) / 100,
                                            backgroundColor: Colors.grey[200],
                                            color: LegoApp.legoYellow,
                                            minHeight: 8,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                      ),
                      
                      // F) Quick Actions
                      _sectionHeader('QUICK ACTIONS'),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.onScanTap,
                              icon: const Icon(Icons.camera_alt, color: Colors.black),
                              label: const Text('Scan Now', style: TextStyle(color: Colors.black)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LegoApp.legoYellow,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onInventoryTap,
                              icon: const Icon(Icons.inventory_2, color: LegoApp.legoYellow),
                              label: const Text('Inventory', style: TextStyle(color: LegoApp.legoYellow)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: LegoApp.legoYellow),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _heroStatChip(IconData icon, String value, String label) {
    return StatChip(label: label, value: value);
  }
  
  Widget _buildStatCard(IconData icon, int value, String label) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 28, color: const Color(0xFFFFD700)),
            const SizedBox(height: 8),
            _isLoading
                ? Container(
                    height: 22,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value.toDouble()),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, animValue, child) {
                      return Text(
                        animValue.toInt().toString(),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 22),
                      );
                    },
                  ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month]} ${dt.day}, ${dt.year} • $hour:$minute $period';
    } catch (e) {
      return dateStr;
    }
  }
}

// ---------------------------------------------------------------------------
// Live Detection Screen
// ---------------------------------------------------------------------------

class LiveDetectionScreen extends StatefulWidget {
  const LiveDetectionScreen({super.key});
  
  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  CameraController? _controller;
  bool _isDetecting = false;
  List<dynamic> _detections = [];
  Timer? _detectionTimer;
  String? _error;
  Size? _imageSize;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera available');
        return;
      }
      
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      if (!mounted) return;
      
      setState(() {});
      
      // Start detection loop
      _detectionTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) => _detectFrame());
    } catch (e) {
      setState(() => _error = 'Camera permission required for live detection');
    }
  }
  
  Future<void> _detectFrame() async {
    if (_isDetecting || _controller == null || !_controller!.value.isInitialized) return;
    
    setState(() => _isDetecting = true);
    
    try {
      final image = await _controller!.takePicture();
      final bytes = await File(image.path).readAsBytes();
      
      // Store image size for bbox scaling
      final decodedImage = await decodeImageFromList(bytes);
      _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
      
      final result = await ApiService.detectWithYolo(bytes);
      
      if (mounted && result['success'] == true) {
        setState(() {
          _detections = result['detections'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Detection error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetecting = false);
      }
    }
  }
  
  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 60, color: Colors.white54),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }
    
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate brick counts
    final brickCounts = <String, int>{};
    for (var detection in _detections) {
      final name = detection['class_name'] ?? 'Unknown';
      brickCounts[name] = (brickCounts[name] ?? 0) + 1;
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          
          // Bounding Boxes Overlay
          if (_imageSize != null)
            CustomPaint(
              size: Size.infinite,
              painter: _BoundingBoxPainter(
                detections: _detections,
                imageSize: _imageSize!,
                screenSize: screenSize,
              ),
            ),
          
          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom Detection Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_detections.length} bricks detected',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: brickCounts.isEmpty
                        ? const Center(
                            child: Text(
                              'Point camera at LEGO bricks',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            children: brickCounts.entries.map((entry) {
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFFFD700)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFD700),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${entry.value}',
                                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
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

// Custom Painter for Bounding Boxes
class _BoundingBoxPainter extends CustomPainter {
  final List<dynamic> detections;
  final Size imageSize;
  final Size screenSize;
  
  _BoundingBoxPainter({
    required this.detections,
    required this.imageSize,
    required this.screenSize,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );
    
    for (var detection in detections) {
      final bbox = detection['bbox'];
      if (bbox == null) continue;
      
      // Scale bbox from image coordinates to screen coordinates
      final scaleX = screenSize.width / imageSize.width;
      final scaleY = screenSize.height / imageSize.height;
      
      final x1 = (bbox['x1'] ?? 0) * scaleX;
      final y1 = (bbox['y1'] ?? 0) * scaleY;
      final x2 = (bbox['x2'] ?? 0) * scaleX;
      final y2 = (bbox['y2'] ?? 0) * scaleY;
      
      // Draw rectangle
      canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), paint);
      
      // Draw label
      final className = detection['class_name'] ?? 'Unknown';
      final confidence = ((detection['confidence'] ?? 0) * 100).toStringAsFixed(0);
      final label = '$className $confidence%';
      
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.green,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(x1, y1 - 20));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Scan Screen (unchanged, but will now use authenticated API calls)
// ---------------------------------------------------------------------------

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<LegoBrick> _scannedBricks = [];
  bool _isDetecting = false;
  String? _errorMessage;
  XFile? _selectedImage;
  List<dynamic> _detectionResults = [];
  String _selectedDetector = 'azure'; // 'azure' | 'onnx'
  
  // ONNX detection state
  List<dynamic> _onnxResults = [];
  bool _isDetectingOnnx = false;
  String? _onnxError;

  // ---- actions ----

  void _clearSelection() => setState(() {
        _selectedImage = null;
        _errorMessage = null;
        _scannedBricks = [];
        _detectionResults = [];
        _isDetecting = false;
        _onnxResults = [];
        _onnxError = null;
        _isDetectingOnnx = false;
      });

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _detectionResults = [];
      _isDetecting = false;
    });
    try {
      final img = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (img != null) {
        setState(() {
          _selectedImage = img;
          _scannedBricks = [];
        });
      }
    } catch (e) {
      setState(() => _errorMessage = '${source == ImageSource.camera ? "Camera" : "Gallery"} error: $e');
    }
  }

  Future<void> _detectBricks() async {
    if (_selectedImage == null) return;
    
    print('🔍 DEBUG: Starting detection...');
    setState(() {
      _isDetecting = true;
      _errorMessage = null;
      _detectionResults = [];
    });

    try {
      print('📤 DEBUG: Calling ApiService.uploadImage...');
      final result = await ApiService.uploadImage(_selectedImage!);
      print('📥 DEBUG: API Response: $result');
      print('📊 DEBUG: Success field: ${result['success']}');
      print('📊 DEBUG: Results field: ${result['results']}');

      if (result['success'] == true) {
        final results = (result['results'] as List?) ?? [];
        print('✅ DEBUG: Found ${results.length} results');
        print('📋 DEBUG: Results data: $results');
        
        setState(() {
          _detectionResults = results;
          print('🔄 DEBUG: Set _detectionResults to ${_detectionResults.length} items');
          
          _scannedBricks = results
              .map((d) {
                print('🧱 DEBUG: Processing brick: $d');
                final colorName = d['color'] ?? 'Unknown';
                return LegoBrick(
                  id: d['id'] ?? d['brick_id'] ?? '0000',
                  name: d['name'] ?? d['brick_name'] ?? d['class'] ?? 'Unknown',
                  color: _parseColor(colorName),
                  colorName: colorName,
                  quantity: d['quantity'] ?? d['count'] ?? 1,
                  confidence: (d['confidence'] as num?)?.toDouble(),
                );
              })
              .toList();
          _errorMessage = null;
          print('✅ DEBUG: Created ${_scannedBricks.length} LegoBrick objects');
        });

        if (mounted && _scannedBricks.isNotEmpty) {
          print('🎉 DEBUG: Showing success snackbar');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Found ${_scannedBricks.length} brick(s)!'),
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        } else {
          print('⚠️ DEBUG: No bricks to show or not mounted');
        }
      } else {
        print('❌ DEBUG: API returned success=false');
        setState(() => _errorMessage = result['error'] ?? 'Detection failed.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e, stackTrace) {
      print('💥 DEBUG: Exception caught: $e');
      print('📍 DEBUG: Stack trace: $stackTrace');
      setState(() => _errorMessage = 'Network error. Check your connection.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      setState(() => _isDetecting = false);
      print('🏁 DEBUG: Detection complete. _isDetecting = false');
      print('📊 DEBUG: Final state - _scannedBricks: ${_scannedBricks.length}, _detectionResults: ${_detectionResults.length}');
    }
  }
  
  Future<void> _detectWithOnnx() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _isDetectingOnnx = true;
      _onnxError = null;
      _onnxResults = [];
    });

    try {
      final result = await ApiService.detectWithOnnx(_selectedImage!);
      
      if (result['success'] == true) {
        setState(() {
          _onnxResults = result['results'] ?? [];
          _isDetectingOnnx = false;
        });
        
        if (mounted && _onnxResults.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('ONNX found ${_onnxResults.length} brick(s)!'),
            ]),
            backgroundColor: const Color(0xFF1A1A2E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        }
      } else {
        setState(() {
          _onnxError = result['error'] ?? 'ONNX detection failed.';
          _isDetectingOnnx = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_onnxError!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      setState(() {
        _isDetectingOnnx = false;
        _onnxError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ONNX Detection failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
  
  Future<void> _addOnnxToInventory() async {
    if (_onnxResults.isEmpty) return;
    
    final bricks = _onnxResults.map((brick) => {
      'id': brick['brick_id'] ?? brick['id'] ?? '0000',
      'name': brick['brick_name'] ?? brick['name'] ?? 'Unknown',
      'color': brick['color'] ?? 'Unknown',
      'quantity': brick['count'] ?? brick['quantity'] ?? 1,
    }).toList();
    
    final result = await ApiService.addToInventory(bricks);
    if (result['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Text('✓ ONNX bricks added to inventory'),
        ]),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }
  
  Future<void> _addAllToInventory() async {
    if (_scannedBricks.isEmpty) return;
    
    final bricks = _scannedBricks.map((b) => {
      'id': b.id,
      'name': b.name,
      'color': b.colorName ?? 'Unknown',
      'quantity': b.quantity,
    }).toList();
    
    final result = await ApiService.addToInventory(bricks);
    if (result['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Text('✓ Bricks added to inventory'),
        ]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  Color _parseColor(String name) {
    switch (name.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      case 'green':
        return Colors.green;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'brown':
        return Colors.brown;
      case 'gray':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildScanCard(),
          const SizedBox(height: 16),
          _buildResultsSection(),
          if (_onnxResults.isNotEmpty || _onnxError != null) ...[
            const SizedBox(height: 16),
            _buildOnnxResultsSection(),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildScanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Scan LEGO Bricks', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
              if (_selectedImage != null && !_isDetecting)
                IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _clearSelection,
                    tooltip: 'Clear'),
            ],
          ),
          const SizedBox(height: 16),
          _imagePreviewArea(),
          const SizedBox(height: 16),
          if (_selectedImage != null) _detectorSelectorCard(),
          if (_selectedImage == null) ...[
            _actionButtons(),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text('— or try live detection —', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LiveDetectionScreen()),
                  );
                },
                icon: const Icon(Icons.videocam),
                label: const Text('Live Detection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD01012),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _imagePreviewArea() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 200,
        maxHeight: 300,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _selectedImage == null ? const Color(0xFFF0F0F0) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade400,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: _selectedImage == null
            ? _emptyPreview()
            : _isDetecting
                ? _detectingOverlay()
                : _imagePreview(),
      ),
    );
  }

  Widget _emptyPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Upload a photo to detect bricks',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _detectingOverlay() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: FutureBuilder<Uint8List>(
            future: _selectedImage!.readAsBytes(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox(height: 220);
              return Opacity(
                opacity: 0.3,
                child: Image.memory(
                  snap.data!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              );
            },
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: LegoApp.legoYellow),
                const SizedBox(height: 12),
                Text(
                  'Analyzing with Azure Vision...',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FutureBuilder<Uint8List>(
        future: _selectedImage!.readAsBytes(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return SizedBox(
              height: 220,
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(color: Colors.white),
              ),
            );
          }
          if (!snap.hasData) {
            return const SizedBox(
              height: 220,
              child: Center(child: Icon(Icons.error, color: LegoApp.legoRed)),
            );
          }
          return Image.memory(
            snap.data!,
            fit: BoxFit.contain,
            width: double.infinity,
          );
        },
      ),
    );
  }

  Widget _detectorSelectorCard() {
    final isRunning = _isDetecting || _isDetectingOnnx;
    return Column(
      children: [
        // Vertical method selector
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LegoApp.legoBorder),
          ),
          child: Column(children: [
            _MethodTile(
              icon: Icons.cloud_outlined,
              label: 'Azure API',
              desc: 'Fast cloud-based detection',
              selected: _selectedDetector == 'azure',
              onTap: () => setState(() => _selectedDetector = 'azure'),
            ),
            Divider(height: 1, thickness: 1, color: LegoApp.legoBorder),
            _MethodTile(
              icon: Icons.memory_outlined,
              label: 'ONNX',
              desc: 'Local & private',
              selected: _selectedDetector == 'onnx',
              onTap: () => setState(() => _selectedDetector = 'onnx'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // Single unified detect button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_selectedImage != null && !isRunning) ? () {
              HapticFeedback.lightImpact();
              switch (_selectedDetector) {
                case 'azure': _detectBricks(); break;
                case 'onnx': _detectWithOnnx(); break;
              }
            } : null,
            icon: isRunning
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.search),
            label: Text(isRunning
                ? 'Detecting...'
                : 'Detect with ${_selectedDetector == 'azure' ? 'Azure' : 'ONNX'}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LegoApp.legoRed,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LegoApp.radiusBtn)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButtons() {
    return Row(
      key: const ValueKey('action_btns'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionBtn(Icons.camera_alt, 'Take Photo',
            () { HapticFeedback.lightImpact(); _pickImage(ImageSource.camera); }),
        _actionBtn(Icons.photo_library, 'Upload Image',
            () { HapticFeedback.lightImpact(); _pickImage(ImageSource.gallery); }),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Detection Results', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
                if (_scannedBricks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: LegoApp.legoRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${_scannedBricks.length} found',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: LegoApp.legoRed)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_detectionResults.isEmpty && _scannedBricks.isEmpty)
              _emptyResults()
            else if (_detectionResults.isNotEmpty && _scannedBricks.isEmpty)
              _noDetectionMessage()
            else
              ..._scannedBricks.asMap().entries.map((entry) {
                final i = entry.key;
                final brick = entry.value;
                return _brickResultCard(brick, _detectionResults.length > i ? _detectionResults[i] : null);
              }),
            if (_scannedBricks.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _addAllToInventory,
                  style: FilledButton.styleFrom(
                    backgroundColor: LegoApp.legoRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LegoApp.radiusBtn)),
                  ),
                  child: Text('Add All to Inventory', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyResults() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_in_ar_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No bricks detected yet',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Upload an image and click\n"Detect Bricks" to start',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _noDetectionMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 64, color: Colors.amber[700]),
          const SizedBox(height: 16),
          Text('No bricks detected',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.amber[800])),
          const SizedBox(height: 8),
          Text('Try a clearer photo with better lighting',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _brickResultCard(LegoBrick brick, dynamic rawData) {
    final conf = brick.confidence ?? 0;
    final confPct = conf * 100;
    final quantity = rawData != null ? (rawData['count'] ?? rawData['quantity'] ?? brick.quantity) : brick.quantity;
    final colorName = brick.colorName ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(LegoApp.radiusCard),
        border: Border.all(color: LegoApp.legoBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(brick.name,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
                Text('ID: ${brick.id}',
                  style: const TextStyle(fontSize: 12, color: LegoApp.legoMuted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${confPct.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2a8a00))),
            ),
            if (quantity > 1) ...[
              const SizedBox(width: 6),
              LegoBadge('×$quantity'),
            ],
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brick.color,
                border: Border.all(color: LegoApp.legoBorder),
              ),
            ),
            const SizedBox(width: 8),
            Text(colorName, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: conf,
              minHeight: 4,
              backgroundColor: LegoApp.legoBorder,
              valueColor: const AlwaysStoppedAnimation(LegoApp.legoYellow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnnxResultsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.memory, color: Color(0xFFFFD700), size: 20),
                const SizedBox(width: 8),
                Text(
                  'ONNX YOLOv8 Results',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LegoApp.legoDark,
                  ),
                ),
                const Spacer(),
                if (_onnxResults.isNotEmpty)
                  Chip(
                    label: Text('${_onnxResults.length} bricks'),
                    backgroundColor: const Color(0xFFFFD700),
                    labelStyle: const TextStyle(color: Colors.black, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_onnxError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_onnxError!, style: const TextStyle(color: Colors.red)),
              ),
            if (_onnxResults.isEmpty && _onnxError == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No bricks detected by ONNX model.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ..._onnxResults.map((brick) => _detectionResultCard(brick)).toList(),
            if (_onnxResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add ONNX Results to Inventory'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LegoApp.legoRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LegoApp.radiusBtn)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _addOnnxToInventory,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detectionResultCard(Map<String, dynamic> brick) {
    final name = brick['brick_name'] ?? brick['name'] ?? brick['class'] ?? 'Unknown Brick';
    final brickId = brick['brick_id'] ?? brick['id'] ?? '—';
    final colorName = brick['color'] ?? 'Unknown';
    final brickColor = _colorFromName(colorName);
    final conf = ((brick['confidence'] ?? 0) as num).toDouble();
    final qty = brick['count'] ?? brick['quantity'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(LegoApp.radiusCard),
        border: Border.all(color: LegoApp.legoBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
              Text('ID: $brickId', style: const TextStyle(fontSize: 12, color: LegoApp.legoMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFF0FFF0), borderRadius: BorderRadius.circular(6)),
            child: Text('${(conf * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2a8a00))),
          ),
          if (qty != null) ...[
            const SizedBox(width: 6),
            LegoBadge('×$qty'),
          ],
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: brickColor,
              border: Border.all(color: LegoApp.legoBorder),
            ),
          ),
          const SizedBox(width: 8),
          Text(colorName, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: conf,
            minHeight: 4,
            backgroundColor: LegoApp.legoBorder,
            valueColor: const AlwaysStoppedAnimation(LegoApp.legoYellow),
          ),
        ),
      ]),
    );
  }

  Color _colorFromName(String? name) {
    switch (name?.toLowerCase().trim()) {
      case 'red':
        return const Color(0xFFC42822);
      case 'dark red':
        return const Color(0xFF720E0E);
      case 'orange':
        return const Color(0xFFDA8541);
      case 'yellow':
        return const Color(0xFFF0CD61);
      case 'lime green':
        return const Color(0xFF00AF4D);
      case 'green':
        return const Color(0xFF008F41);
      case 'dark green':
        return const Color(0xFF00451A);
      case 'light blue':
        return const Color(0xFF68C3E2);
      case 'medium blue':
        return const Color(0xFF7396C8);
      case 'blue':
        return const Color(0xFF0D69AB);
      case 'dark blue':
        return const Color(0xFF002060);
      case 'sand blue':
        return const Color(0xFF5A7184);
      case 'purple':
        return const Color(0xFF6B327C);
      case 'magenta':
        return const Color(0xFFA3005B);
      case 'white':
        return const Color(0xFFF2F3F2);
      case 'light gray':
      case 'light grey':
        return const Color(0xFFA3A2A4);
      case 'dark gray':
      case 'dark grey':
        return const Color(0xFF635F61);
      case 'black':
        return const Color(0xFF1B2A34);
      case 'brown':
        return const Color(0xFF583927);
      case 'dark tan':
        return const Color(0xFF8F7956);
      case 'tan':
        return const Color(0xFFDEC69C);
      case 'unknown':
      default:
        return Colors.grey.shade400;
    }
  }

}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.label,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: selected ? const Color(0xFFFFF8F8) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: selected ? LegoApp.legoRed : LegoApp.legoBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: selected ? Colors.white : LegoApp.legoMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: selected ? LegoApp.legoRed : const Color(0xFF1a1a1a),
              )),
              Text(desc, style: const TextStyle(fontSize: 12, color: LegoApp.legoMuted)),
            ],
          ),
        ),
        if (selected) const Icon(Icons.circle, size: 8, color: LegoApp.legoRed),
      ]),
    ),
  );
}

// ---------------------------------------------------------------------------
// Inventory Screen (updated to use authenticated API)
// ---------------------------------------------------------------------------

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<LegoBrick> _inventory = [];
  bool _loading = true;
  String? _error;
  bool _isGridView = false;
  Set<String> _selectedColors = {};

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.getInventory();
      if (res.containsKey('error')) {
        setState(() => _error = res['error']);
      } else {
        final items = (res['inventory'] as List?) ?? [];
        setState(() {
          _inventory = items
              .map((d) => LegoBrick(
                    id: d['id'] ?? d['brick_id'] ?? '0000',
                    name: d['name'] ?? 'Unknown',
                    color: _colorFromName(d['color'] ?? ''),
                    colorName: d['color'] ?? 'Unknown',
                    quantity: d['quantity'] ?? 1,
                  ))
              .toList();
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to load inventory');
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _colorFromName(String name) {
    switch (name.toLowerCase().trim()) {
      case 'red':
        return const Color(0xFFC42822);
      case 'dark red':
        return const Color(0xFF720E0E);
      case 'orange':
        return const Color(0xFFDA8541);
      case 'yellow':
        return const Color(0xFFF0CD61);
      case 'lime green':
        return const Color(0xFF00AF4D);
      case 'green':
        return const Color(0xFF008F41);
      case 'dark green':
        return const Color(0xFF00451A);
      case 'light blue':
        return const Color(0xFF68C3E2);
      case 'medium blue':
        return const Color(0xFF7396C8);
      case 'blue':
        return const Color(0xFF0D69AB);
      case 'dark blue':
        return const Color(0xFF002060);
      case 'sand blue':
        return const Color(0xFF5A7184);
      case 'purple':
        return const Color(0xFF6B327C);
      case 'magenta':
        return const Color(0xFFA3005B);
      case 'white':
        return const Color(0xFFF2F3F2);
      case 'light gray':
      case 'light grey':
        return const Color(0xFFA3A2A4);
      case 'dark gray':
      case 'dark grey':
        return const Color(0xFF635F61);
      case 'black':
        return const Color(0xFF1B2A34);
      case 'brown':
        return const Color(0xFF583927);
      case 'dark tan':
        return const Color(0xFF8F7956);
      case 'tan':
        return const Color(0xFFDEC69C);
      case 'unknown':
      default:
        return Colors.grey.shade400;
    }
  }

  List<LegoBrick> get _filtered {
    if (_selectedColors.isEmpty) return _inventory;
    return _inventory.where((b) => _selectedColors.contains(b.colorName?.toLowerCase())).toList();
  }

  Future<void> _updateQty(LegoBrick b, int delta) async {
    final newQty = b.quantity + delta;
    if (newQty < 0) return;
    if (newQty == 0) {
      await ApiService.deleteInventoryItem(b.id, color: b.colorName ?? 'Unknown');
    } else {
      await ApiService.updateInventoryItem(b.id, quantity: newQty);
    }
    _loadInventory();
  }

  @override
  Widget build(BuildContext context) {
    final totalBricks = _inventory.fold<int>(0, (s, b) => s + b.quantity);
    final colorSet = _inventory.map((b) => b.colorName?.toLowerCase() ?? 'unknown').toSet().toList();
    final filtered = _filtered;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Total Bricks', '$totalBricks', Icons.view_in_ar),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                _stat('Unique Types', '${_inventory.length}', Icons.category),
              ],
            ),
          ),
        ),
        if (colorSet.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: colorSet.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c[0].toUpperCase() + c.substring(1)),
                  selected: _selectedColors.contains(c),
                  onSelected: (v) => setState(() => v ? _selectedColors.add(c) : _selectedColors.remove(c)),
                  selectedColor: LegoApp.legoYellow.withValues(alpha: 0.3),
                  avatar: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _colorFromName(c),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('My Inventory', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
                    Row(children: [
                      IconButton(
                        icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: LegoApp.legoBlue),
                        onPressed: () => setState(() => _isGridView = !_isGridView),
                        tooltip: _isGridView ? 'List view' : 'Grid view',
                      ),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInventory),
                      IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => showSearch(context: context, delegate: _BrickSearchDelegate(_inventory))),
                    ]),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _loading
                        ? _shimmerList()
                        : _error != null
                            ? Center(child: Text(_error!, style: const TextStyle(color: LegoApp.legoRed)))
                            : filtered.isEmpty
                                ? _emptyState()
                                : _isGridView ? _gridBody(filtered) : _listBody(filtered),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('Your inventory is empty', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Text('Scan some LEGO bricks to get started!', style: TextStyle(color: Colors.grey[400])),
      ]),
    );
  }

  Widget _shimmerList() {
    return Shimmer.fromColors(
      key: const ValueKey('shimmer'),
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: double.infinity, height: 14, color: Colors.white),
              const SizedBox(height: 6),
              Container(width: 100, height: 10, color: Colors.white),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _listBody(List<LegoBrick> items) {
    return ListView.builder(
      key: const ValueKey('list'),
      itemCount: items.length,
      itemBuilder: (_, i) => _inventoryItem(items[i]),
    );
  }

  Widget _gridBody(List<LegoBrick> items) {
    return GridView.builder(
      key: const ValueKey('grid'),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.3),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b = items[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 20, backgroundColor: b.color,
                child: b.color == Colors.white || b.color == Colors.yellow
                    ? Icon(Icons.view_in_ar, size: 18, color: Colors.grey[700])
                    : const Icon(Icons.view_in_ar, size: 18, color: Colors.white)),
              const SizedBox(height: 8),
              Text(b.name, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('ID: ${b.id}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                InkWell(onTap: () => _updateQty(b, -1), child: const Icon(Icons.remove_circle_outline, size: 20, color: LegoApp.legoRed)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${b.quantity}', style: GoogleFonts.outfit(fontWeight: FontWeight.w800))),
                InkWell(onTap: () => _updateQty(b, 1), child: const Icon(Icons.add_circle_outline, size: 20, color: LegoApp.legoBlue)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _inventoryItem(LegoBrick b) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LegoApp.legoSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LegoApp.legoBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: b.color,
            child: b.color == Colors.white || b.color == Colors.yellow
                ? Icon(Icons.view_in_ar, size: 18, color: Colors.grey[700])
                : const Icon(Icons.view_in_ar, size: 18, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                Text('ID: ${b.id}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20, color: LegoApp.legoRed), onPressed: () => _updateQty(b, -1)),
            Text('${b.quantity}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)),
            IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: LegoApp.legoRed), onPressed: () => _updateQty(b, 1)),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Column(children: [
        Icon(icon, color: LegoApp.legoBlue, size: 24),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ]);
}

// ---------------------------------------------------------------------------
// Recommendations Screen (unchanged)
// ---------------------------------------------------------------------------

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});
  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<LegoSet> _sets = [];
  bool _loading = true;
  int _inventorySize = -1; // -1 = not yet loaded

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getRecommendations();
      final recs = (res['recommendations'] as List?) ?? [];
      final invSize = res['inventory_size'] as int? ?? -1;
      setState(() {
        _inventorySize = invSize;
        _sets = recs.map((d) {
          final rawMissing = d['missing_pieces'];
          final List<Map<String, dynamic>> missingList = rawMissing is List
              ? rawMissing.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
          return LegoSet(
            name:               d['name'] ?? '',
            theme:              d['theme'] ?? '',
            completion:         ((d['completion_percentage'] ?? 0) as num).toInt(),
            ownedPieces:        ((d['owned_pieces'] ?? 0) as num).toInt(),
            totalPieces:        ((d['total_pieces'] ?? 0) as num).toInt(),
            missingPieces:      ((d['missing_pieces_count'] ?? 0) as num).toInt(),
            difficulty:         d['difficulty'] ?? 'intermediate',
            estimatedBuildTime: d['estimated_build_time'] ?? '',
            missingPiecesList:  missingList,
            imageUrl:           d['image_url'] ?? '',
          );
        }).toList();
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Buildable Sets',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        Text('Based on your current inventory', style: TextStyle(color: Colors.grey[500])),
        // Banner shown when user has no inventory yet
        if (!_loading && _inventorySize == 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: LegoApp.legoYellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LegoApp.legoYellow.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: LegoApp.legoDark),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Scan bricks to see your real completion %',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: LegoApp.legoDark),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _loading
                ? Shimmer.fromColors(
                    key: const ValueKey('rec_shimmer'),
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: ListView.builder(
                      itemCount: 3,
                      itemBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(height: 140,
                          decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                  )
                : _sets.isEmpty
                    ? Center(
                        key: const ValueKey('no_recs'),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.construction, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No recommendations yet',
                            style: GoogleFonts.outfit(fontSize: 18,
                              fontWeight: FontWeight.w700, color: Colors.grey[500])),
                        ]),
                      )
                    : ListView.builder(
                            key: const ValueKey('rec_list'),
                            itemCount: _sets.length,
                            itemBuilder: (_, i) => _setCard(_sets[i]),
                          ),
          ),
        ),
      ]),
    );
  }

  Widget _setCard(LegoSet s) {
    final pct = s.completion / 100;
    final diffColor = s.difficulty == 'beginner'
        ? Colors.green
        : s.difficulty == 'intermediate'
            ? Colors.orange
            : LegoApp.legoRed;
    final diffLabel = s.difficulty == 'beginner'
        ? 'Beginner'
        : s.difficulty == 'intermediate'
            ? 'Intermediate'
            : 'Advanced';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row: progress ring + name/theme ──
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 60, height: 60,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: pct, strokeWidth: 5,
                  backgroundColor: Colors.grey.shade200,
                  color: diffColor,
                ),
                Text('${s.completion}%',
                  style: GoogleFonts.outfit(fontSize: 11,
                    fontWeight: FontWeight.w800, color: diffColor)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s.name,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700))),
                  Chip(
                    label: Text(diffLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w600)),
                    backgroundColor: diffColor,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]),
                if (s.theme.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(s.theme,
                    style: const TextStyle(fontSize: 12, color: LegoApp.legoMuted)),
                ],
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          // ── Progress bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, backgroundColor: Colors.grey[200],
              color: diffColor, minHeight: 6),
          ),
          const SizedBox(height: 8),
          // ── Piece count row ──
          Row(children: [
            Text('${s.completion}% complete',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: diffColor)),
            const Spacer(),
            Text('${s.ownedPieces} of ${s.totalPieces} pieces',
              style: const TextStyle(fontSize: 12, color: LegoApp.legoMuted)),
          ]),
          if (s.estimatedBuildTime.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.schedule, size: 12, color: LegoApp.legoMuted),
              const SizedBox(width: 4),
              Text(s.estimatedBuildTime,
                style: const TextStyle(fontSize: 11, color: LegoApp.legoMuted)),
            ]),
          ],
          const SizedBox(height: 8),
          // ── Missing pieces section ──
          if (s.missingPiecesList.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: const [
                Icon(Icons.check_circle, size: 16, color: Color(0xFF2a8a00)),
                SizedBox(width: 6),
                Text('You can build this set!',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF2a8a00))),
              ]),
            )
          else
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Row(children: [
                  const Icon(Icons.warning_amber, size: 14, color: LegoApp.legoRed),
                  const SizedBox(width: 6),
                  Text('${s.missingPieces} missing piece${s.missingPieces == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: LegoApp.legoRed)),
                ]),
                children: s.missingPiecesList.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: LegoApp.legoBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text('${p['brick_id']} · ${p['color']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Text('need ${p['needed']}  (have ${p['have']})',
                      style: const TextStyle(fontSize: 11, color: LegoApp.legoMuted)),
                  ]),
                )).toList(),
              ),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Screen (updated with logout and user info)
// ---------------------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _backendStatus = 'checking…';
  String _pineconeStatus = 'checking…';
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadProfile();
  }

  Future<void> _checkStatus() async {
    final health = await ApiService.getHealth();
    setState(() {
      _backendStatus = health['status'] ?? health['error'] ?? 'unknown';
      _pineconeStatus = health['pinecone_status'] ?? 'unknown';
    });
  }

  Future<void> _loadProfile() async {
    final profile = await ApiService.getProfile();
    if (profile['success'] == true) {
      setState(() {
        _userProfile = profile['user'];
      });
    }
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.logout();
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'L';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final username = _userProfile?['username'] ?? auth.user?['username'] ?? 'Lego Enthusiast';
    final email = _userProfile?['email'] ?? auth.user?['email'] ?? '';
    final stats = _userProfile?['stats'] ?? {};
    final totalScans = (stats['total_scans'] ?? 0) as int;
    final totalInv = (stats['total_inventory_items'] ?? 0) as int;
    final totalFav = (stats['favorite_sets'] ?? 0) as int;
    final backendOk = _backendStatus.toLowerCase().contains('healthy') || _backendStatus.toLowerCase() == 'ok';
    final pineconeOk = _pineconeStatus.toLowerCase().contains('connected') || _pineconeStatus.toLowerCase() == 'ok' || _pineconeStatus.toLowerCase().contains('healthy');

    return Column(children: [
        // ── DARK PROFILE HEADER ──
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 24,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: LegoApp.legoDark,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: LegoApp.legoYellow,
              child: Text(_initials(username), style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
            ),
            const SizedBox(height: 14),
            Text(username, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            if (email.isNotEmpty) Text(email, style: const TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 20),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _animatedStatCard('Scans', totalScans, Icons.qr_code_scanner),
                _animatedStatCard('Bricks', totalInv, Icons.view_in_ar),
                _animatedStatCard('Favorites', totalFav, Icons.favorite),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              Chip(
                avatar: Icon(Icons.dns, size: 16, color: backendOk ? Colors.green : LegoApp.legoRed),
                label: Text('Backend: ${backendOk ? "Connected" : _backendStatus}', style: TextStyle(fontSize: 11, color: backendOk ? Colors.green.shade800 : LegoApp.legoRed)),
                backgroundColor: backendOk ? Colors.green.shade50 : Colors.red.shade50,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Chip(
                avatar: Icon(Icons.cloud, size: 16, color: pineconeOk ? Colors.green : LegoApp.legoRed),
                label: Text('Pinecone: ${pineconeOk ? "Connected" : _pineconeStatus}', style: TextStyle(fontSize: 11, color: pineconeOk ? Colors.green.shade800 : LegoApp.legoRed)),
                backgroundColor: pineconeOk ? Colors.green.shade50 : Colors.red.shade50,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _profileTile(Icons.history, 'Scan History', () {}),
              _profileTile(Icons.favorite, 'Favorite Sets', () {}),
              _profileTile(Icons.settings, 'Settings', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }),
              _profileTile(Icons.help, 'Help & Support', () {}),
              _profileTile(Icons.info, 'About', () {}),
              _profileTile(Icons.logout, 'Logout', _logout, color: LegoApp.legoRed),
            ],
          ),
        ),
      ]);
  }

  Widget _animatedStatCard(String label, int value, IconData icon) {
    return SizedBox(
      width: 100,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: LegoApp.legoYellow, size: 22),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, v, __) => Text(
              '${v.toInt()}',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: LegoApp.legoSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LegoApp.legoBorder),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? LegoApp.legoRed).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color ?? LegoApp.legoRed, size: 20),
        ),
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: color)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Screen
// ---------------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _backendOnline = false;
  
  @override
  void initState() {
    super.initState();
    _checkBackendStatus();
  }
  
  Future<void> _checkBackendStatus() async {
    try {
      final result = await ApiService.getHealth();
      setState(() {
        _backendOnline = result['status'] == 'healthy' || result['status'] == 'degraded';
      });
    } catch (e) {
      setState(() {
        _backendOnline = false;
      });
    }
  }
  
  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _ChangePasswordSheet(),
    );
  }
  
  Future<void> _exportInventory() async {
    try {
      final jsonString = await ApiService.exportInventory();
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Inventory Data'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(jsonString),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Copied to clipboard'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
              child: const Text('Copy All', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _clearScanHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Scan History?'),
        content: const Text('All your scan history will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      try {
        await ApiService.clearScanHistory();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Scan history cleared'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ACCOUNT Section
          Text('ACCOUNT', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline, color: Color(0xFFFFD700)),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showChangePasswordSheet,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // DATA & PRIVACY Section
          Text('DATA & PRIVACY', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_outlined, color: Color(0xFFFFD700)),
                  title: const Text('Export Inventory'),
                  subtitle: const Text('Download your inventory as JSON'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportInventory,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Clear Scan History', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('This cannot be undone'),
                  onTap: _clearScanHistory,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // ABOUT Section
          Text('ABOUT', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Color(0xFFFFD700)),
                  title: const Text('App Version'),
                  trailing: Text('2.0.0', style: TextStyle(color: Colors.grey.shade600)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.group_outlined, color: Color(0xFFFFD700)),
                  title: const Text('Team'),
                  trailing: Text('NextGen Solutions', style: TextStyle(color: Colors.grey.shade600)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined, color: Color(0xFFFFD700)),
                  title: const Text('Backend'),
                  trailing: Chip(
                    label: Text(_backendOnline ? 'Connected' : 'Offline'),
                    backgroundColor: _backendOnline ? Colors.green.shade100 : Colors.red.shade100,
                    labelStyle: TextStyle(
                      color: _backendOnline ? Colors.green.shade800 : Colors.red.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Change Password Bottom Sheet
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();
  
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _updatePassword() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    
    // Validation
    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required'), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiService.changePassword(
        currentPassword: oldPassword,
        newPassword: newPassword,
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Password updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to update password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Change Password', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _oldPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm New Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isLoading ? null : _updatePassword,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('Update Password', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan History Screen
// ---------------------------------------------------------------------------

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});
  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final history = await ApiService.getScanHistory();
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load scan history: $e';
        _isLoading = false;
      });
    }
  }

  Color _colorFromName(String? colorName) {
    switch (colorName?.toLowerCase().trim()) {
      case 'red':
        return const Color(0xFFC42822);
      case 'dark red':
        return const Color(0xFF720E0E);
      case 'orange':
        return const Color(0xFFDA8541);
      case 'yellow':
        return const Color(0xFFF0CD61);
      case 'lime green':
        return const Color(0xFF00AF4D);
      case 'green':
        return const Color(0xFF008F41);
      case 'dark green':
        return const Color(0xFF00451A);
      case 'light blue':
        return const Color(0xFF68C3E2);
      case 'medium blue':
        return const Color(0xFF7396C8);
      case 'blue':
        return const Color(0xFF0D69AB);
      case 'dark blue':
        return const Color(0xFF002060);
      case 'sand blue':
        return const Color(0xFF5A7184);
      case 'purple':
        return const Color(0xFF6B327C);
      case 'magenta':
        return const Color(0xFFA3005B);
      case 'white':
        return const Color(0xFFF2F3F2);
      case 'light gray':
      case 'light grey':
        return const Color(0xFFA3A2A4);
      case 'dark gray':
      case 'dark grey':
        return const Color(0xFF635F61);
      case 'black':
        return const Color(0xFF1B2A34);
      case 'brown':
        return const Color(0xFF583927);
      case 'dark tan':
        return const Color(0xFF8F7956);
      case 'tan':
        return const Color(0xFFDEC69C);
      case 'unknown':
      default:
        return Colors.grey.shade400;
    }
  }

  Future<void> _addScanToInventory(List<dynamic> scanResults) async {
    if (scanResults.isEmpty) return;

    final bricks = scanResults.map((brick) => {
      'id': brick['brick_id'] ?? brick['id'] ?? '0000',
      'name': brick['brick_name'] ?? brick['name'] ?? brick['class'] ?? 'Unknown',
      'color': brick['color'] ?? 'Unknown',
      'quantity': brick['count'] ?? brick['quantity'] ?? 1,
    }).toList();

    try {
      final result = await ApiService.updateInventory(bricks);
      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('✓ Bricks added to inventory'),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to add to inventory: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan History', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LegoApp.legoYellow))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadHistory,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No scans yet.\nGo detect some bricks!', style: TextStyle(color: Colors.grey.shade600, fontSize: 16), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: LegoApp.legoYellow,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final scan = _history[index];
                          final scanDate = scan['scan_date'] ?? scan['date'] ?? '';
                          final totalBricks = scan['total_bricks'] ?? 0;
                          final uniqueTypes = scan['unique_types'] ?? 0;
                          
                          List<dynamic> scanResults = [];
                          try {
                            final results = scan['scan_results'] ?? scan['results'];
                            if (results is String) {
                              scanResults = jsonDecode(results);
                            } else if (results is List) {
                              scanResults = results;
                            }
                          } catch (e) {
                            scanResults = [];
                          }

                          String formattedDate = scanDate;
                          try {
                            final dt = DateTime.parse(scanDate);
                            final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                            final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                            final minute = dt.minute.toString().padLeft(2, '0');
                            final period = dt.hour >= 12 ? 'PM' : 'AM';
                            formattedDate = '${months[dt.month]} ${dt.day}, ${dt.year} • $hour:$minute $period';
                          } catch (e) {
                            formattedDate = scanDate.toString().substring(0, scanDate.length > 16 ? 16 : scanDate.length);
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: LegoApp.legoYellow,
                                child: const Icon(Icons.document_scanner, color: Colors.black),
                              ),
                              title: Text(formattedDate, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                              subtitle: Text('$totalBricks bricks • $uniqueTypes types', style: TextStyle(color: Colors.grey.shade600)),
                              trailing: Chip(
                                label: Text('$totalBricks bricks', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                backgroundColor: LegoApp.legoYellow.withValues(alpha: 0.2),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              children: [
                                if (scanResults.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text('No result details available', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                                  )
                                else
                                  ...scanResults.map((brick) {
                                    final brickName = brick['brick_name'] ?? brick['name'] ?? brick['class'] ?? 'Unknown';
                                    final confidence = (brick['confidence'] ?? 0) as num;
                                    final count = brick['count'] ?? brick['quantity'] ?? 1;
                                    final color = brick['color'] ?? 'Unknown';
                                    final brickColor = _colorFromName(color);

                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: LegoApp.legoBorder),
                                      ),
                                      child: Row(children: [
                                        Container(
                                          width: 32, height: 32,
                                          decoration: BoxDecoration(
                                            color: brickColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(child: Container(
                                            width: 16, height: 16,
                                            decoration: BoxDecoration(
                                              color: brickColor,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          )),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(brickName, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                                            Text('${(confidence * 100).toStringAsFixed(1)}% confidence',
                                              style: const TextStyle(fontSize: 11, color: LegoApp.legoMuted)),
                                          ],
                                        )),
                                        LegoBadge('×$count'),
                                      ]),
                                    );
                                  }),
                                if (scanResults.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: TextButton.icon(
                                        onPressed: () => _addScanToInventory(scanResults),
                                        icon: const Icon(Icons.add_circle_outline),
                                        label: const Text('Add All to Inventory'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: LegoApp.legoBlue,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class LegoBrick {
  final String id;
  final String name;
  final Color color;
  final String? colorName;
  final int quantity;
  final double? confidence;

  LegoBrick({
    required this.id,
    required this.name,
    required this.color,
    this.colorName,
    required this.quantity,
    this.confidence,
  });
}

class LegoSet {
  final String name;
  final String theme;
  final int completion;
  final int ownedPieces;
  final int totalPieces;
  final int missingPieces;
  final String difficulty;
  final String estimatedBuildTime;
  final List<Map<String, dynamic>> missingPiecesList;
  final String imageUrl;

  LegoSet({
    required this.name,
    required this.theme,
    required this.completion,
    required this.ownedPieces,
    required this.totalPieces,
    required this.missingPieces,
    required this.difficulty,
    required this.estimatedBuildTime,
    required this.missingPiecesList,
    required this.imageUrl,
  });
}

// ---------------------------------------------------------------------------
// Search Delegate
// ---------------------------------------------------------------------------

class _BrickSearchDelegate extends SearchDelegate {
  final List<LegoBrick> bricks;
  _BrickSearchDelegate(this.bricks);

  @override
  List<Widget> buildActions(BuildContext ctx) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext ctx) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(ctx, null));

  @override
  Widget buildResults(BuildContext ctx) => _list();

  @override
  Widget buildSuggestions(BuildContext ctx) => _list();

  Widget _list() {
    final r = bricks
        .where((b) =>
            b.name.toLowerCase().contains(query.toLowerCase()) ||
            b.id.contains(query))
        .toList();
    return ListView.builder(
      itemCount: r.length,
      itemBuilder: (_, i) {
        final b = r[i];
        return ListTile(
          leading: CircleAvatar(radius: 20, backgroundColor: b.color,
            child: b.color == Colors.white || b.color == Colors.yellow
                ? Icon(Icons.view_in_ar, size: 16, color: Colors.grey[700])
                : const Icon(Icons.view_in_ar, size: 16, color: Colors.white)),
          title: Text(b.name),
          subtitle: Text('ID: ${b.id}'),
          trailing: Text('Qty: ${b.quantity}'),
        );
      },
    );
  }
}

