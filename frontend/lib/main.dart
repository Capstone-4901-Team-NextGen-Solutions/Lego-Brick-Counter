import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'camera_screen.dart';

import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthService();
  await auth.init();
  runApp(const LegoApp());
}

class LegoApp extends StatelessWidget {
  const LegoApp({super.key});

  static const Color legoYellow = Color(0xFFFFD700);
  static const Color legoRed = Color(0xFFD01012);
  static const Color legoBlue = Color(0xFF006DB7);
  static const Color legoBg = Color(0xFFF5F5F5);
  static const Color legoDark = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return ChangeNotifierProvider(
          create: (_) => AuthService(),
          child: MaterialApp(
            title: 'LEGO Brick Detection & Inventory',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: legoYellow,
              brightness: Brightness.light,
              scaffoldBackgroundColor: legoBg,
              textTheme: GoogleFonts.nunitoTextTheme(),
              appBarTheme: AppBarTheme(
                backgroundColor: legoDark,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 3,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                surfaceTintColor: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: legoRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: legoBlue, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              pageTransitionsTheme: const PageTransitionsTheme(builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
              }),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: legoYellow,
              brightness: Brightness.dark,
              textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
            ),
            home: const AuthGate(),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Auth Gate
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
// Auth Page
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
    _email.dispose(); _pass.dispose(); _confirm.dispose(); _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!isLogin && _pass.text.trim() != _confirm.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    Map<String, dynamic> result;
    if (isLogin) {
      result = await auth.login(email: _email.text.trim(), password: _pass.text.trim());
    } else {
      result = await auth.register(
        email: _email.text.trim(),
        password: _pass.text.trim(),
        username: _username.text.isNotEmpty ? _username.text.trim() : null,
      );
    }
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['success'] ? (result['message'] ?? 'Success!') : (result['error'] ?? 'Authentication failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LegoApp.legoBg,
      body: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LegoApp.legoYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.view_in_ar, size: 48, color: LegoApp.legoRed),
                    ),
                    const SizedBox(height: 20),
                    Text(isLogin ? 'Welcome Back!' : 'Create Account',
                        style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
                    const SizedBox(height: 6),
                    Text(isLogin ? 'Sign in to continue' : 'Join the LEGO community',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                    const SizedBox(height: 28),
                    if (!isLogin) ...[
                      TextField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'Username (optional)',
                          prefixIcon: Icon(Icons.person_outline, color: LegoApp.legoBlue),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, color: LegoApp.legoBlue),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pass,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline, color: LegoApp.legoBlue),
                      ),
                    ),
                    if (!isLogin) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline, color: LegoApp.legoBlue),
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
                                onPressed: () { HapticFeedback.lightImpact(); _submit(); },
                                child: Text(isLogin ? 'Login' : 'Register'),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () { if (!_isLoading) setState(() => isLogin = !isLogin); },
                      child: Text(
                        isLogin ? 'New here? Create an account' : 'Already have an account? Login',
                        style: const TextStyle(color: LegoApp.legoBlue, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home Screen
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
      appBar: AppBar(title: const Text('LEGO Brick Detection')),
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
  void initState() { super.initState(); _loadDashboard(); }

  Future<void> _loadDashboard() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getDashboardData();
      setState(() { _data = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.2)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.widgets, color: Color(0xFFFFD700), size: 24),
          Text(' LEGO Inventory', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        ]),
        backgroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboard)],
      ),
      body: _error != null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Could not load dashboard'),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadDashboard, child: const Text('Retry')),
            ]))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    height: 100,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Welcome back!', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
                        const SizedBox(height: 4),
                        const Text('Ready to scan some bricks?', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ])),
                      Icon(Icons.construction, size: 48, color: Colors.white.withOpacity(0.8)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _buildStatCard(Icons.widgets, _data['totalBricks'] ?? 0, 'Total Bricks')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(Icons.category_outlined, _data['uniqueTypes'] ?? 0, 'Brick Types')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(Icons.document_scanner_outlined, _data['totalScans'] ?? 0, 'Scans Done')),
                  ]),
                  _sectionHeader('LAST SCAN'),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _isLoading
                          ? Container(height: 50, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)))
                          : _data['lastScanDate'] == null
                              ? Row(children: [Icon(Icons.info_outline, color: Colors.grey.shade600), const SizedBox(width: 8), const Text('No scans yet — try scanning some bricks!')])
                              : Row(children: [
                                  const Icon(Icons.access_time, color: Color(0xFFFFD700)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Most Recent Scan', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
                                    Text(_formatDate(_data['lastScanDate']), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ])),
                                  Chip(label: Text('${_data['totalScans']} total'), backgroundColor: const Color(0xFFFFD700).withOpacity(0.2), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                ]),
                    ),
                  ),
                  _sectionHeader('SETS YOU CAN BUILD'),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _isLoading
                          ? Container(height: 100, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)))
                          : (_data['buildableSets'] == 0 && _data['topSet'] == null)
                              ? Text('Add more bricks to your inventory to see buildable sets', style: TextStyle(color: Colors.grey.shade600))
                              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Text('${_data['buildableSets']}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Color(0xFFFFD700))),
                                    const SizedBox(width: 16),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('sets are 50%+\ncomplete', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
                                      Text('based on your inventory', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ])),
                                  ]),
                                  if (_data['topSet'] != null) ...[
                                    const Divider(height: 24),
                                    Text('TOP MATCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 1.2)),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(child: Text(_data['topSet']['name'] ?? 'Unknown Set', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15))),
                                      Text('${_data['topSet']['completion_percentage'] ?? 0}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFFFFD700))),
                                    ]),
                                    const SizedBox(height: 6),
                                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (_data['topSet']['completion_percentage'] ?? 0) / 100, backgroundColor: Colors.grey[200], color: const Color(0xFFFFD700), minHeight: 8)),
                                  ],
                                ]),
                    ),
                  ),
                  _sectionHeader('QUICK ACTIONS'),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(
                      onPressed: widget.onScanTap,
                      icon: const Icon(Icons.camera_alt, color: Colors.black),
                      label: const Text('Scan Now', style: TextStyle(color: Colors.black)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), padding: const EdgeInsets.symmetric(vertical: 12)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: widget.onInventoryTap,
                      icon: const Icon(Icons.inventory_2, color: Color(0xFFFFD700)),
                      label: const Text('Inventory', style: TextStyle(color: Color(0xFFFFD700))),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFFD700)), padding: const EdgeInsets.symmetric(vertical: 12)),
                    )),
                  ]),
                ]),
              ),
            ),
    );
  }

  Widget _buildStatCard(IconData icon, int value, String label) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Icon(icon, size: 28, color: const Color(0xFFFFD700)),
          const SizedBox(height: 8),
          _isLoading
              ? Container(height: 22, width: 40, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)))
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.toDouble()),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, animValue, child) => Text(animValue.toInt().toString(), style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 22)),
                ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11), textAlign: TextAlign.center),
        ]),
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
    } catch (e) { return dateStr; }
  }
}

// ---------------------------------------------------------------------------
// Scan Screen
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

  void _clearSelection() => setState(() {
    _selectedImage = null; _errorMessage = null;
    _scannedBricks = []; _detectionResults = []; _isDetecting = false;
  });

  Future<void> _pickImage(ImageSource source) async {
  setState(() {
    _errorMessage = null;
    _detectionResults = [];
    _isDetecting = false;
  });
 
  try {
    XFile? img;
 
    if (source == ImageSource.camera) {
      //Uses the real camera screen instead of ImagePicker.camera,
      //which doesn't work on desktop and silently falls back to file picker.
      img = await CameraCapture.capture(context);
    } else {
      img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
    }
 
    if (img != null) {
      setState(() {
        _selectedImage = img;
        _scannedBricks = [];
      });
    }
  } catch (e) {
    setState(() => _errorMessage =
        '${source == ImageSource.camera ? "Camera" : "Gallery"} error: $e');
  }
}

  Future<void> _detectBricks() async {
    if (_selectedImage == null) return;
    setState(() { _isDetecting = true; _errorMessage = null; _detectionResults = []; });
    try {
      final result = await ApiService.uploadImage(_selectedImage!);
      if (result['success'] == true) {
        final results = (result['results'] as List?) ?? [];
        setState(() {
          _detectionResults = results;
          _scannedBricks = results.map((d) {
            final colorName = d['color'] ?? 'Unknown';
            return LegoBrick(
              id: d['id'] ?? d['brick_id'] ?? '0000',
              name: d['name'] ?? d['brick_name'] ?? d['class'] ?? 'Unknown',
              color: _parseColor(colorName),
              colorName: colorName,
              quantity: d['quantity'] ?? d['count'] ?? 1,
              confidence: (d['confidence'] as num?)?.toDouble(),
            );
          }).toList();
          _errorMessage = null;
        });
        if (mounted && _scannedBricks.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 12), Text('Found ${_scannedBricks.length} brick(s)!')]),
            backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        }
      } else {
        setState(() => _errorMessage = result['error'] ?? 'Detection failed.');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error. Check your connection.');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      setState(() => _isDetecting = false);
    }
  }

  Future<void> _addAllToInventory() async {
    if (_scannedBricks.isEmpty) return;
    final bricks = _scannedBricks.map((b) => {'id': b.id, 'name': b.name, 'color': b.colorName ?? 'Unknown', 'quantity': b.quantity}).toList();
    final result = await ApiService.addToInventory(bricks);
    if (result['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('✓ Bricks added to inventory')]),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  Color _parseColor(String name) {
    switch (name.toLowerCase()) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'yellow': return Colors.yellow;
      case 'green': return Colors.green;
      case 'black': return Colors.black;
      case 'white': return Colors.white;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'brown': return Colors.brown;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildScanCard(), const SizedBox(height: 16), _buildResultsSection(), const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildScanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Scan LEGO Bricks', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
            if (_selectedImage != null && !_isDetecting)
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: _clearSelection),
          ]),
          const SizedBox(height: 16),
          _imagePreviewArea(),
          const SizedBox(height: 16),
          if (_selectedImage != null) _detectButton(),
          if (_selectedImage == null) _actionButtons(),
        ]),
      ),
    );
  }

  Widget _imagePreviewArea() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 300),
      child: Container(
        decoration: BoxDecoration(
          color: _selectedImage == null ? const Color(0xFFF0F0F0) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade400, width: 2, strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: _selectedImage == null ? _emptyPreview() : _isDetecting ? _detectingOverlay() : _imagePreview(),
      ),
    );
  }

  Widget _emptyPreview() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.image_outlined, size: 60, color: Colors.grey[400]),
    const SizedBox(height: 12),
    Text('Upload a photo to detect bricks', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
  ]));

  Widget _detectingOverlay() => Stack(children: [
    ClipRRect(borderRadius: BorderRadius.circular(14), child: FutureBuilder<Uint8List>(
      future: _selectedImage!.readAsBytes(),
      builder: (ctx, snap) => snap.hasData ? Opacity(opacity: 0.3, child: Image.memory(snap.data!, fit: BoxFit.contain, width: double.infinity)) : const SizedBox(height: 220),
    )),
    Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: LegoApp.legoYellow),
        const SizedBox(height: 12),
        Text('Analyzing with Azure Vision...', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    )),
  ]);

  Widget _imagePreview() => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: FutureBuilder<Uint8List>(
      future: _selectedImage!.readAsBytes(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return SizedBox(height: 220, child: Shimmer.fromColors(baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100, child: Container(color: Colors.white)));
        if (!snap.hasData) return const SizedBox(height: 220, child: Center(child: Icon(Icons.error, color: LegoApp.legoRed)));
        return Image.memory(snap.data!, fit: BoxFit.contain, width: double.infinity);
      },
    ),
  );

  Widget _detectButton() {
    final isEnabled = _selectedImage != null && !_isDetecting;
    return SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
      onPressed: isEnabled ? () { HapticFeedback.lightImpact(); _detectBricks(); } : null,
      icon: Icon(_isDetecting ? Icons.hourglass_empty : Icons.search),
      label: Text(_isDetecting ? 'Detecting...' : 'Detect Bricks'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? const Color(0xFFFFD700) : Colors.grey,
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ));
  }

  Widget _actionButtons() {
  return Row(
    key: const ValueKey('action_btns'),
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _actionBtn(
        Icons.camera_alt,
        'Take Photo',
        () {
          HapticFeedback.lightImpact();
          _pickImage(ImageSource.camera);
        },
      ),
      _actionBtn(
        Icons.photo_library,
        'Upload Image',
        () {
          HapticFeedback.lightImpact();
          _pickImage(ImageSource.gallery);
        },
      ),
    ],
  );
}

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 32), const SizedBox(height: 8),
          Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );

  Widget _buildResultsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Detection Results', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
            if (_scannedBricks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: LegoApp.legoRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${_scannedBricks.length} found', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: LegoApp.legoRed)),
              ),
          ]),
          const SizedBox(height: 12),
          if (_detectionResults.isEmpty && _scannedBricks.isEmpty) _emptyResults()
          else if (_detectionResults.isNotEmpty && _scannedBricks.isEmpty) _noDetectionMessage()
          else ..._scannedBricks.asMap().entries.map((entry) => _brickResultCard(entry.value, _detectionResults.length > entry.key ? _detectionResults[entry.key] : null)),
          if (_scannedBricks.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48, child: FilledButton(
              onPressed: _addAllToInventory,
              style: FilledButton.styleFrom(backgroundColor: LegoApp.legoBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Add All to Inventory', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
            )),
          ],
        ]),
      ),
    );
  }

  Widget _emptyResults() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.view_in_ar_outlined, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('No bricks detected yet', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[500])),
      const SizedBox(height: 8),
      Text('Upload an image and click\n"Detect Bricks" to start', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
    ]),
  );

  Widget _noDetectionMessage() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.warning_amber_rounded, size: 64, color: Colors.amber[700]),
      const SizedBox(height: 16),
      Text('No bricks detected', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.amber[800])),
      const SizedBox(height: 8),
      Text('Try a clearer photo with better lighting', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
    ]),
  );

  Widget _brickResultCard(LegoBrick brick, dynamic rawData) {
    final conf = brick.confidence ?? 0;
    final quantity = rawData != null ? (rawData['count'] ?? rawData['quantity'] ?? brick.quantity) : brick.quantity;
    final colorName = brick.colorName ?? 'Unknown';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: brick.color, width: 3)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(brick.name, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: LegoApp.legoDark)),
              const SizedBox(height: 6),
              Row(children: [CircleAvatar(radius: 8, backgroundColor: brick.color), const SizedBox(width: 6), Text(colorName, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500))]),
              const SizedBox(height: 4),
              Text('Confidence: ${(conf * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ])),
            if (quantity > 1) Chip(label: Text('Qty: $quantity', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), backgroundColor: LegoApp.legoYellow.withValues(alpha: 0.2), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: conf, backgroundColor: Colors.grey.shade200, color: const Color(0xFFFFD700), minHeight: 8)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inventory Screen
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
  void initState() { super.initState(); _loadInventory(); }

  Future<void> _loadInventory() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getInventory();
      if (res.containsKey('error')) {
        setState(() => _error = res['error']);
      } else {
        final items = (res['inventory'] as List?) ?? [];
        setState(() {
          _inventory = items.map((d) => LegoBrick(
            id: d['id'] ?? d['brick_id'] ?? '0000',
            name: d['name'] ?? 'Unknown',
            color: _colorFromName(d['color'] ?? ''),
            colorName: d['color'] ?? 'Unknown',
            quantity: d['quantity'] ?? 1,
          )).toList();
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to load inventory');
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _colorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'yellow': return Colors.yellow;
      case 'green': return Colors.green;
      case 'black': return Colors.black;
      case 'white': return Colors.white;
      default: return Colors.grey;
    }
  }

  List<LegoBrick> get _filtered {
    if (_selectedColors.isEmpty) return _inventory;
    return _inventory.where((b) => _selectedColors.contains(b.colorName?.toLowerCase())).toList();
  }

  Future<void> _updateQty(LegoBrick b, int delta) async {
    final newQty = b.quantity + delta;
    if (newQty < 0) return;
    if (newQty == 0) await ApiService.deleteInventoryItem(b.id, color: b.colorName ?? 'Unknown');
    else await ApiService.updateInventoryItem(b.id, quantity: newQty);
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
        Card(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('Total Bricks', '$totalBricks', Icons.view_in_ar),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            _stat('Unique Types', '${_inventory.length}', Icons.category),
          ]),
        )),
        if (colorSet.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: colorSet.map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(c[0].toUpperCase() + c.substring(1)),
              selected: _selectedColors.contains(c),
              onSelected: (v) => setState(() => v ? _selectedColors.add(c) : _selectedColors.remove(c)),
              selectedColor: LegoApp.legoYellow.withValues(alpha: 0.3),
              avatar: CircleAvatar(radius: 8, backgroundColor: _colorFromName(c)),
            ),
          )).toList())),
        ],
        const SizedBox(height: 12),
        Expanded(child: Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('My Inventory', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
              Row(children: [
                IconButton(icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: LegoApp.legoBlue), onPressed: () => setState(() => _isGridView = !_isGridView)),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInventory),
                IconButton(icon: const Icon(Icons.search), onPressed: () => showSearch(context: context, delegate: _BrickSearchDelegate(_inventory))),
              ]),
            ]),
            const SizedBox(height: 8),
            Expanded(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _loading ? _shimmerList() : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: LegoApp.legoRed)))
                  : filtered.isEmpty ? _emptyState() : _isGridView ? _gridBody(filtered) : _listBody(filtered),
            )),
          ]),
        ))),
      ]),
    );
  }

  Widget _emptyState() => Center(key: const ValueKey('empty'), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.inventory_2, size: 80, color: Colors.grey[300]),
    const SizedBox(height: 16),
    Text('Your inventory is empty', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[500])),
    const SizedBox(height: 8),
    Text('Scan some LEGO bricks to get started!', style: TextStyle(color: Colors.grey[400])),
  ]));

  Widget _shimmerList() => Shimmer.fromColors(
    key: const ValueKey('shimmer'),
    baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
    child: ListView.builder(itemCount: 5, itemBuilder: (_, __) => Padding(
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
    )),
  );

  Widget _listBody(List<LegoBrick> items) => ListView.builder(key: const ValueKey('list'), itemCount: items.length, itemBuilder: (_, i) => _inventoryItem(items[i]));

  Widget _gridBody(List<LegoBrick> items) => GridView.builder(
    key: const ValueKey('grid'),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.3),
    itemCount: items.length,
    itemBuilder: (_, i) {
      final b = items[i];
      return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircleAvatar(radius: 20, backgroundColor: b.color, child: b.color == Colors.white || b.color == Colors.yellow ? Icon(Icons.view_in_ar, size: 18, color: Colors.grey[700]) : const Icon(Icons.view_in_ar, size: 18, color: Colors.white)),
        const SizedBox(height: 8),
        Text(b.name, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('ID: ${b.id}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(onTap: () => _updateQty(b, -1), child: const Icon(Icons.remove_circle_outline, size: 20, color: LegoApp.legoRed)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${b.quantity}', style: GoogleFonts.nunito(fontWeight: FontWeight.w800))),
          InkWell(onTap: () => _updateQty(b, 1), child: const Icon(Icons.add_circle_outline, size: 20, color: LegoApp.legoBlue)),
        ]),
      ])));
    },
  );

  Widget _inventoryItem(LegoBrick b) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      leading: CircleAvatar(radius: 20, backgroundColor: b.color, child: b.color == Colors.white || b.color == Colors.yellow ? Icon(Icons.view_in_ar, size: 18, color: Colors.grey[700]) : const Icon(Icons.view_in_ar, size: 18, color: Colors.white)),
      title: Text(b.name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      subtitle: Text('ID: ${b.id}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20, color: LegoApp.legoRed), onPressed: () => _updateQty(b, -1)),
        Text('${b.quantity}', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
        IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: LegoApp.legoBlue), onPressed: () => _updateQty(b, 1)),
      ]),
    ),
  );

  Widget _stat(String label, String value, IconData icon) => Column(children: [
    Icon(icon, color: LegoApp.legoBlue, size: 24), const SizedBox(height: 4),
    Text(value, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
  ]);
}

// ---------------------------------------------------------------------------
// Recommendations Screen
// ---------------------------------------------------------------------------
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});
  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<LegoSet> _sets = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getRecommendations();
      final recs = (res['recommendations'] as List?) ?? [];
      setState(() => _sets = recs.map((d) => LegoSet(name: d['name'] ?? '', completion: d['completion_percentage'] ?? 0, missingPieces: d['missing_pieces'] ?? 0, imageUrl: d['image_url'] ?? '')).toList());
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Buildable Sets', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ]),
        Text('Based on your current inventory', style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 16),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _loading
              ? Shimmer.fromColors(key: const ValueKey('rec_shimmer'), baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
                  child: ListView.builder(itemCount: 3, itemBuilder: (_, __) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))))))
              : _sets.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.construction, size: 80, color: Colors.grey[300]), const SizedBox(height: 16), Text('No recommendations yet', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[500]))]))
                  : ListView.builder(key: const ValueKey('rec_list'), itemCount: _sets.length, itemBuilder: (_, i) => _setCard(_sets[i])),
        )),
      ]),
    );
  }

  Widget _setCard(LegoSet s) {
    final pct = s.completion / 100;
    final diffColor = s.completion > 70 ? Colors.green : s.completion > 40 ? Colors.orange : LegoApp.legoRed;
    final diffLabel = s.completion > 70 ? 'Easy' : s.completion > 40 ? 'Medium' : 'Hard';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 56, height: 56, child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(value: pct, strokeWidth: 5, backgroundColor: Colors.grey.shade200, color: diffColor),
          Text('${s.completion}%', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: diffColor)),
        ])),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(s.name, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700))),
            Chip(label: Text(diffLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)), backgroundColor: diffColor, padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey[200], color: diffColor, minHeight: 6)),
          const SizedBox(height: 8),
          if (s.missingPieces > 0) Chip(avatar: const Icon(Icons.warning_amber, size: 14, color: LegoApp.legoRed), label: Text('${s.missingPieces} missing', style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ])),
      ])),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Screen
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
  void initState() { super.initState(); _checkStatus(); _loadProfile(); }

  Future<void> _checkStatus() async {
    final health = await ApiService.getHealth();
    setState(() {
      _backendStatus = health['status'] ?? health['error'] ?? 'unknown';
      _pineconeStatus = health['pinecone_status'] ?? 'unknown';
    });
  }

  Future<void> _loadProfile() async {
    final profile = await ApiService.getProfile();
    if (profile['success'] == true) setState(() => _userProfile = profile['user']);
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(children: [
            CircleAvatar(radius: 40, backgroundColor: LegoApp.legoYellow, child: Text(_initials(username), style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: LegoApp.legoDark))),
            const SizedBox(height: 14),
            Text(username, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
            if (email.isNotEmpty) Text(email, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _animatedStatCard('Scans', totalScans, Icons.qr_code_scanner),
              _animatedStatCard('Bricks', totalInv, Icons.view_in_ar),
              _animatedStatCard('Favorites', totalFav, Icons.favorite),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              Chip(
                avatar: Icon(Icons.dns, size: 16, color: backendOk ? Colors.green : LegoApp.legoRed),
                label: Text('Backend: ${backendOk ? "Connected" : _backendStatus}', style: TextStyle(fontSize: 11, color: backendOk ? Colors.green.shade800 : LegoApp.legoRed)),
                backgroundColor: backendOk ? Colors.green.shade50 : Colors.red.shade50,
                padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Chip(
                avatar: Icon(Icons.cloud, size: 16, color: pineconeOk ? Colors.green : LegoApp.legoRed),
                label: Text('Pinecone: ${pineconeOk ? "Connected" : _pineconeStatus}', style: TextStyle(fontSize: 11, color: pineconeOk ? Colors.green.shade800 : LegoApp.legoRed)),
                backgroundColor: pineconeOk ? Colors.green.shade50 : Colors.red.shade50,
                padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
          ]),
        )),
        const SizedBox(height: 16),
        Expanded(child: ListView(children: [
          _profileTile(Icons.history, 'Scan History', () {}),
          _profileTile(Icons.favorite, 'Favorite Sets', () {}),
          _profileTile(Icons.settings, 'Settings', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
          _profileTile(Icons.help, 'Help & Support', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
          }),
          _profileTile(Icons.info, 'About', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
          }),
          _profileTile(Icons.logout, 'Logout', _logout, color: LegoApp.legoRed),
        ])),
      ]),
    );
  }

  Widget _animatedStatCard(String label, int value, IconData icon) => SizedBox(
    width: 100,
    child: Card(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(children: [
        Icon(icon, color: LegoApp.legoBlue, size: 22), const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (_, v, __) => Text('${v.toInt()}', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ]),
    )),
  );

  Widget _profileTile(IconData icon, String title, VoidCallback onTap, {Color? color}) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (color ?? LegoApp.legoBlue).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color ?? LegoApp.legoBlue, size: 20),
      ),
      title: Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: color)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    ),
  );
}

// ---------------------------------------------------------------------------
// Settings Screen — 10 features
// ---------------------------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _saveScanHistory = true;
  bool _autoAddToInventory = false;
  double _confidenceThreshold = 0.60;
  String _imageQuality = 'High';
  bool _backendOnline = false;
  bool _checkingBackend = false;

  @override
  void initState() {
    super.initState();
    _darkMode = themeNotifier.value == ThemeMode.dark;
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    setState(() => _checkingBackend = true);
    try {
      final res = await ApiService.getHealth();
      setState(() => _backendOnline = res['status'] == 'healthy' || res['status'] == 'degraded');
    } catch (_) {
      setState(() => _backendOnline = false);
    } finally {
      setState(() => _checkingBackend = false);
    }
  }

  void _showChangePassword() => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => const _ChangePasswordSheet(),
  );

  void _showEditProfile() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Display Name', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'New display name', prefixIcon: Icon(Icons.person_outline))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); _snack('✓ Display name updated', Colors.green); },
            style: FilledButton.styleFrom(backgroundColor: LegoApp.legoYellow, foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportInventory() async {
    try {
      final json = await ApiService.exportInventory();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [const Icon(Icons.download_outlined, color: LegoApp.legoYellow), const SizedBox(width: 8), Text('Inventory Export', style: GoogleFonts.nunito(fontWeight: FontWeight.w700))]),
          content: SizedBox(width: double.maxFinite, height: 200, child: SingleChildScrollView(child: SelectableText(json, style: const TextStyle(fontSize: 12)))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton.icon(
              onPressed: () { Clipboard.setData(ClipboardData(text: json)); Navigator.pop(ctx); _snack('✓ Copied to clipboard', Colors.green); },
              icon: const Icon(Icons.copy, size: 16), label: const Text('Copy JSON'),
              style: FilledButton.styleFrom(backgroundColor: LegoApp.legoYellow, foregroundColor: Colors.black),
            ),
          ],
        ),
      );
    } catch (e) { _snack('Export failed: $e', Colors.red); }
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red.shade400), const SizedBox(width: 8), Text('Clear History?', style: GoogleFonts.nunito(fontWeight: FontWeight.w700))]),
        content: const Text('All scan history will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete All')),
        ],
      ),
    );
    if (ok == true && mounted) {
      try { await ApiService.clearScanHistory(); _snack('✓ Scan history cleared', Colors.green); }
      catch (e) { _snack('Failed: $e', Colors.red); }
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 20)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _sectionLabel('APPEARANCE'),
          _card([
            _switchTile(icon: _darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, iconBg: const Color(0xFF1A1A2E), iconColor: Colors.white, title: 'Dark Mode', subtitle: _darkMode ? 'Dark theme is on' : 'Light theme is on', value: _darkMode,
              onChanged: (v) { setState(() => _darkMode = v); themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light; }),
          ]),
          _sectionLabel('ACCOUNT'),
          _card([
            _navTile(icon: Icons.person_outline, iconBg: LegoApp.legoBlue.withOpacity(0.12), iconColor: LegoApp.legoBlue, title: 'Edit Display Name', subtitle: 'Update your profile name', onTap: _showEditProfile),
            _divider(),
            _navTile(icon: Icons.lock_outline, iconBg: Colors.orange.withOpacity(0.12), iconColor: Colors.orange, title: 'Change Password', subtitle: 'Update your login password', onTap: _showChangePassword),
          ]),
          _sectionLabel('SCANNING'),
          _card([
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                _iconBox(Icons.tune, Colors.purple.withOpacity(0.12), Colors.purple),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Confidence Threshold', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('Min: ${(_confidenceThreshold * 100).toInt()}%  —  lower = more detections', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ])),
              ]),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(activeTrackColor: LegoApp.legoYellow, thumbColor: LegoApp.legoYellow, overlayColor: LegoApp.legoYellow.withOpacity(0.15), inactiveTrackColor: Colors.grey.shade300, trackHeight: 4),
              child: Slider(value: _confidenceThreshold, min: 0.30, max: 0.95, divisions: 13, onChanged: (v) => setState(() => _confidenceThreshold = v)),
            ),
            _divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                _iconBox(Icons.high_quality_outlined, Colors.teal.withOpacity(0.12), Colors.teal),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Image Quality', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('Higher = more accurate, slower upload', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ])),
                SegmentedButton<String>(
                  segments: ['Low', 'Medium', 'High'].map((q) => ButtonSegment(value: q, label: Text(q, style: const TextStyle(fontSize: 11)))).toList(),
                  selected: {_imageQuality},
                  onSelectionChanged: (s) => setState(() => _imageQuality = s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? LegoApp.legoYellow : null),
                    foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.black : null),
                  ),
                ),
              ]),
            ),
            _divider(),
            _switchTile(icon: Icons.inventory_2_outlined, iconBg: Colors.green.withOpacity(0.12), iconColor: Colors.green, title: 'Auto-Add to Inventory', subtitle: 'Automatically save detected bricks', value: _autoAddToInventory, onChanged: (v) => setState(() => _autoAddToInventory = v)),
            _divider(),
            _switchTile(icon: Icons.notifications_outlined, iconBg: Colors.amber.withOpacity(0.12), iconColor: Colors.amber.shade800, title: 'Scan Notifications', subtitle: 'Get notified when scan completes', value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v)),
            _divider(),
            _switchTile(icon: Icons.history, iconBg: Colors.indigo.withOpacity(0.12), iconColor: Colors.indigo, title: 'Save Scan History', subtitle: 'Store results in your history', value: _saveScanHistory, onChanged: (v) => setState(() => _saveScanHistory = v)),
          ]),
          _sectionLabel('DATA & PRIVACY'),
          _card([
            _navTile(icon: Icons.download_outlined, iconBg: Colors.green.withOpacity(0.12), iconColor: Colors.green, title: 'Export Inventory', subtitle: 'Download your data as JSON', onTap: _exportInventory),
            _divider(),
            _navTile(icon: Icons.delete_sweep_outlined, iconBg: Colors.red.withOpacity(0.10), iconColor: Colors.red, title: 'Clear Scan History', subtitle: 'Permanently delete all scan records', titleColor: Colors.red, onTap: _clearHistory),
          ]),
          _sectionLabel('SYSTEM'),
          _card([
            ListTile(
              leading: _iconBox(Icons.dns_outlined, LegoApp.legoYellow.withOpacity(0.15), LegoApp.legoYellow),
              title: Text('Backend Status', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Text(_checkingBackend ? 'Checking...' : (_backendOnline ? 'Connected & running' : 'Offline'),
                  style: TextStyle(fontSize: 12, color: _checkingBackend ? Colors.grey : (_backendOnline ? Colors.green.shade700 : Colors.red))),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _checkingBackend ? Colors.grey : (_backendOnline ? Colors.green : Colors.red))),
                const SizedBox(width: 6),
                IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _checkBackend, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
              ]),
            ),
            _divider(),
            ListTile(
              leading: _iconBox(Icons.info_outline, Colors.grey.shade200, Colors.grey.shade600),
              title: Text('App Version', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: LegoApp.legoYellow.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('v2.0.0', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.brown.shade700)),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8, left: 4),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.5)),
  );

  Widget _card(List<Widget> children) => Card(margin: const EdgeInsets.only(bottom: 2), elevation: 2, shadowColor: Colors.black12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Column(children: children));

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _iconBox(IconData icon, Color bg, Color color) => Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20));

  Widget _navTile({required IconData icon, required Color iconBg, required Color iconColor, required String title, required String subtitle, Color? titleColor, required VoidCallback onTap}) => ListTile(
    leading: _iconBox(icon, iconBg, iconColor),
    title: Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15, color: titleColor)),
    subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
    onTap: onTap,
  );

  Widget _switchTile({required IconData icon, required Color iconBg, required Color iconColor, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) => ListTile(
    leading: _iconBox(icon, iconBg, iconColor),
    title: Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
    subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    trailing: Switch.adaptive(value: value, onChanged: onChanged, activeColor: LegoApp.legoYellow),
  );
}

// ---------------------------------------------------------------------------
// Change Password Sheet
// ---------------------------------------------------------------------------
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _oldVis = false, _newVis = false, _confirmVis = false;

  @override
  void dispose() { _old.dispose(); _new.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_old.text.isEmpty || _new.text.isEmpty || _confirm.text.isEmpty) { _snack('All fields are required', Colors.red); return; }
    if (_new.text != _confirm.text) { _snack('Passwords do not match', Colors.red); return; }
    if (_new.text.length < 6) { _snack('Minimum 6 characters required', Colors.red); return; }
    setState(() => _loading = true);
    try {
      final res = await ApiService.changePassword(currentPassword: _old.text, newPassword: _new.text);
      if (!mounted) return;
      if (res['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Password updated'), backgroundColor: Colors.green));
      } else {
        setState(() => _loading = false);
        _snack(res['error'] ?? 'Failed to update password', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Error: $e', Colors.red);
    }
  }

  void _snack(String msg, Color bg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('Change Password', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        _pf(_old, 'Current Password', _oldVis, (v) => setState(() => _oldVis = v)),
        const SizedBox(height: 12),
        _pf(_new, 'New Password', _newVis, (v) => setState(() => _newVis = v)),
        const SizedBox(height: 12),
        _pf(_confirm, 'Confirm New Password', _confirmVis, (v) => setState(() => _confirmVis = v)),
        const SizedBox(height: 20),
        SizedBox(height: 52, child: FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: LegoApp.legoYellow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text('Update Password', style: GoogleFonts.nunito(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
        )),
      ]),
    );
  }

  Widget _pf(TextEditingController c, String label, bool vis, ValueChanged<bool> toggle) => TextField(
    controller: c, obscureText: !vis,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(icon: Icon(vis ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), onPressed: () => toggle(!vis)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
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
  void initState() { super.initState(); _loadHistory(); }

  Future<void> _loadHistory() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final result = await ApiService.getScanHistory();
      if (result['success'] == true && result['scans'] != null) {
        final scans = result['scans'];
        setState(() { _history = scans is List ? scans : []; _isLoading = false; });
      } else {
        setState(() { _history = []; _isLoading = false; _errorMessage = result['error'] ?? 'Failed to load scan history'; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Failed to load scan history: $e'; _isLoading = false; _history = []; });
    }
  }

  Color _colorFromName(String? colorName) {
    switch (colorName?.toLowerCase()) {
      case 'red': return Colors.red;
      case 'orange': return Colors.orange;
      case 'yellow': return Colors.yellow;
      case 'green': return Colors.green;
      case 'blue': return Colors.blue;
      case 'purple': return Colors.purple;
      case 'white': return Colors.white;
      case 'black': return Colors.black;
      case 'brown': return const Color(0xFF795548);
      default: return Colors.grey;
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
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('✓ Bricks added to inventory')]),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan History', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LegoApp.legoYellow))
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red), const SizedBox(height: 16),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center), const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _loadHistory, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ])))
              : _history.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.history, size: 80, color: Colors.grey.shade400), const SizedBox(height: 16),
                      Text('No scans yet.\nGo detect some bricks!', style: TextStyle(color: Colors.grey.shade600, fontSize: 16), textAlign: TextAlign.center),
                    ]))
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
                            if (results is String) scanResults = jsonDecode(results);
                            else if (results is List) scanResults = results;
                          } catch (_) {}
                          String formattedDate = scanDate;
                          try {
                            final dt = DateTime.parse(scanDate);
                            final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                            final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                            final minute = dt.minute.toString().padLeft(2, '0');
                            final period = dt.hour >= 12 ? 'PM' : 'AM';
                            formattedDate = '${months[dt.month]} ${dt.day}, ${dt.year} • $hour:$minute $period';
                          } catch (_) {}
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              leading: CircleAvatar(backgroundColor: LegoApp.legoYellow, child: const Icon(Icons.document_scanner, color: Colors.black)),
                              title: Text(formattedDate, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 16)),
                              subtitle: Text('$totalBricks bricks • $uniqueTypes types', style: TextStyle(color: Colors.grey.shade600)),
                              trailing: Chip(label: Text('$totalBricks bricks', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), backgroundColor: LegoApp.legoYellow.withValues(alpha: 0.2), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              children: [
                                if (scanResults.isEmpty)
                                  Padding(padding: const EdgeInsets.all(16), child: Text('No result details available', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600)))
                                else
                                  ...scanResults.map((brick) {
                                    final brickName = brick['brick_name'] ?? brick['name'] ?? brick['class'] ?? 'Unknown';
                                    final confidence = (brick['confidence'] ?? 0) as num;
                                    final count = brick['count'] ?? brick['quantity'] ?? 1;
                                    final color = brick['color'] ?? 'Unknown';
                                    return ListTile(
                                      leading: CircleAvatar(radius: 8, backgroundColor: _colorFromName(color)),
                                      title: Text(brickName, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                                      subtitle: Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%'),
                                      trailing: Text('x$count', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 16)),
                                    );
                                  }),
                                if (scanResults.isNotEmpty)
                                  Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: TextButton.icon(
                                    onPressed: () => _addScanToInventory(scanResults),
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: const Text('Add All to Inventory'),
                                    style: TextButton.styleFrom(foregroundColor: LegoApp.legoBlue, padding: const EdgeInsets.symmetric(vertical: 12)),
                                  ))),
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
// Help & Support Screen
// ---------------------------------------------------------------------------
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});
  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  static const _faqs = [
    (q: 'What does the LEGO Brick Counter app do?', a: 'It uses computer vision and machine learning to identify, classify, and count LEGO bricks from photos. It maintains your brick inventory and recommends LEGO sets you can build based on what you own.'),
    (q: 'How do I scan my LEGO bricks?', a: 'Tap the Scan tab at the bottom, then choose "Take Photo" or "Upload Image". Once an image is selected, tap "Detect Bricks". The AI will analyze the photo and return a list of identified bricks with confidence scores.'),
    (q: 'What is the confidence threshold in Settings?', a: 'This controls how certain the AI must be before reporting a brick. A lower threshold (e.g. 30%) finds more bricks but may include false positives. A higher threshold (e.g. 90%) is more precise but may miss some bricks. The default is 60%.'),
    (q: 'Why aren\'t my bricks being detected?', a: 'Common causes: poor lighting, blurry images, heavy stacking, or a cluttered background. Try photographing bricks spread out on a plain white surface in bright, even lighting. Also check that the backend is connected in Settings.'),
    (q: 'How does the Inventory work?', a: 'After a scan, tap "Add All to Inventory" to save your bricks. Your inventory is stored in the backend database and used by the Builds tab to match against LEGO set databases and calculate completion percentages.'),
    (q: 'What are the Builds / Recommendations?', a: 'The Builds tab compares your inventory against a database of LEGO sets and shows which sets you already have enough pieces to build, and how close you are to completing others. Sets are ranked by completion percentage.'),
    (q: 'What is Pinecone and why does it show "not_configured"?', a: 'Pinecone is a vector database used for semantic similarity search to improve brick matching. If no API key is configured, the app falls back to standard detection — it still works, just without advanced vector search features.'),
    (q: 'Can I export or back up my inventory?', a: 'Yes. Go to Settings → Export Inventory to generate a full JSON export of your brick inventory that you can copy to your clipboard and save externally.'),
    (q: 'How do I delete my scan history?', a: 'Go to Settings → Clear Scan History. You will be asked to confirm. This action is permanent and cannot be undone — all scan records will be removed from the database.'),
    (q: 'Is my data stored on a server?', a: 'Yes. All user data — inventory, scan history, and account info — is stored in a SQLite database managed by the Flask backend. The backend currently runs locally. Cloud deployment is a planned stretch goal.'),
  ];

  Future<void> _sendMessage() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email address'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      return;
    }
    if (!RegExp(r'^[\w\-.]+@[\w\-.]+\.\w{2,}$').hasMatch(_emailCtrl.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _sending = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() { _sending = false; _sent = true; });
  }

  @override
  void dispose() { _emailCtrl.dispose(); _messageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Support', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF006DB7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('How can we help?', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Browse FAQs below or send us a message.', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
            ])),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.support_agent, color: Colors.white, size: 32)),
          ]),
        ),
        const SizedBox(height: 24),
        Row(children: [
          const Icon(Icons.quiz_outlined, size: 16, color: LegoApp.legoBlue), const SizedBox(width: 6),
          Text('FREQUENTLY ASKED QUESTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.4)),
        ]),
        const SizedBox(height: 10),
        ...List.generate(_faqs.length, (i) {
          final faq = _faqs[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: Container(width: 30, height: 30, decoration: BoxDecoration(color: LegoApp.legoYellow.withOpacity(0.18), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('${i + 1}', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.brown.shade700)))),
                title: Text(faq.q, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
                iconColor: LegoApp.legoBlue,
                collapsedIconColor: Colors.grey,
                children: [Text(faq.a, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.55))],
              ),
            ),
          );
        }),
        const SizedBox(height: 28),
        Row(children: [
          const Icon(Icons.mail_outline, size: 16, color: LegoApp.legoBlue), const SizedBox(width: 6),
          Text('CONNECT WITH US', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.4)),
        ]),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _sent
                ? Column(children: [
                    const SizedBox(height: 8),
                    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48)),
                    const SizedBox(height: 16),
                    Text('Message Sent!', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text("Thanks for reaching out. We'll get back to you at ${_emailCtrl.text.trim()} soon.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
                    const SizedBox(height: 16),
                    TextButton(onPressed: () => setState(() { _sent = false; _emailCtrl.clear(); _messageCtrl.clear(); }), child: const Text('Send another message')),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Have a question or feedback?', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Enter your email and we\'ll get back to you.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Your Email Address *', hintText: 'you@example.com',
                        prefixIcon: const Icon(Icons.email_outlined, color: LegoApp.legoBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LegoApp.legoBlue, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _messageCtrl, maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Message (optional)', hintText: 'Describe your issue or suggestion...', alignLabelWithHint: true,
                        prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.message_outlined, color: LegoApp.legoBlue)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LegoApp.legoBlue, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(height: 52, child: FilledButton.icon(
                      onPressed: _sending ? null : _sendMessage,
                      icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_sending ? 'Sending...' : 'Send Message', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                      style: FilledButton.styleFrom(backgroundColor: LegoApp.legoYellow, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    )),
                  ]),
          ),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// About Screen
// ---------------------------------------------------------------------------
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _team = [
    (name: 'Sidharth Nair', role: 'Team Lead'),
    (name: 'Bishal Thapaliya', role: 'Backend & Frontend'),
    (name: 'Sravan Vallepalli', role: 'Frontend & Backend'),
    (name: 'Yeshwanth Salapu', role: 'Frontend & Backend'),
  ];

  static const _tech = [
    ('Flutter', Icons.phone_android, Color(0xFF54C5F8)),
    ('Python', Icons.code, Color(0xFF3776AB)),
    ('Flask', Icons.dns, Color(0xFF3B3B3B)),
    ('Azure CV', Icons.cloud, Color(0xFF0078D4)),
    ('OpenCV', Icons.camera_alt, Color(0xFF5C3EE8)),
    ('SQLite', Icons.storage, Color(0xFF003B57)),
    ('Pinecone', Icons.hub, Color(0xFF1F2D6A)),
    ('Google Fonts', Icons.text_fields, Color(0xFF4285F4)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Column(children: [
                Container(width: 84, height: 84, decoration: BoxDecoration(color: LegoApp.legoYellow.withOpacity(0.15), borderRadius: BorderRadius.circular(22), border: Border.all(color: LegoApp.legoYellow.withOpacity(0.4), width: 2)), child: const Icon(Icons.view_in_ar_rounded, size: 46, color: LegoApp.legoYellow)),
                const SizedBox(height: 18),
                Text('LEGO Brick Counter', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text('Intelligent Brick Detection & Inventory', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.65))),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _badge('v2.0.0', LegoApp.legoYellow.withOpacity(0.2), LegoApp.legoYellow),
                  const SizedBox(width: 10),
                  _badge('Spring 2025', Colors.white.withOpacity(0.1), Colors.white70),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('PROJECT INFORMATION'),
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _infoRow(Icons.school_outlined, Colors.blue, 'Institution', 'University of North Texas'),
              _div(),
              _infoRow(Icons.class_outlined, Colors.purple, 'Course', 'CSCE 4901 — Senior Capstone'),
              _div(),
              _infoRow(Icons.group_outlined, Colors.green, 'Team', 'NextGen Solutions'),
              _div(),
              _infoRow(Icons.calendar_today_outlined, Colors.orange, 'Semester', 'Spring 2025'),
              _div(),
              _infoRow(Icons.code_outlined, LegoApp.legoRed, 'Version', '2.0.0'),
            ]),
          ),
          const SizedBox(height: 24),
          _sectionLabel('DESCRIPTION'),
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LEGO Brick Counter is a capstone project that combines computer vision, machine learning, and database management to solve a real-world problem for LEGO enthusiasts.', style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6)),
              const SizedBox(height: 12),
              Text('The system identifies and classifies bricks from photos using Azure Computer Vision and OpenCV, maintains a smart inventory, and recommends buildable LEGO sets based on what pieces you own — highlighting which pieces are missing.', style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6)),
              const SizedBox(height: 12),
              Text('Built with Flutter for cross-platform mobile support (iOS, Android, Web) and a Python/Flask backend with SQLite for persistent storage.', style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6)),
            ])),
          ),
          const SizedBox(height: 24),
          _sectionLabel('KEY FEATURES'),
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              '🧱 Brick classification via Computer Vision & ML',
              '🔢 Automated brick counting from photos',
              '📦 Persistent inventory management',
              '🏗️ LEGO set matching & build recommendations',
              '📊 Completion percentage tracking per set',
              '📤 Inventory export to JSON',
              '🌙 Dark mode & customizable scan settings',
              '📱 Cross-platform: iOS, Android, Web',
            ].map((f) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(f, style: const TextStyle(fontSize: 14, height: 1.4)))).toList())),
          ),
          const SizedBox(height: 24),
          _sectionLabel('THE TEAM'),
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(_team.length, (i) {
              final member = _team[i];
              final colors = [LegoApp.legoRed, LegoApp.legoBlue, Colors.green, Colors.orange];
              final c = colors[i % colors.length];
              return Column(children: [
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(backgroundColor: c.withOpacity(0.15), child: Text(member.name[0].toUpperCase(), style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: c))),
                  title: Text(member.name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text(member.role, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('Team ${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c))),
                ),
              ]);
            }))),
          ),
          const SizedBox(height: 24),
          _sectionLabel('TECH STACK'),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _tech.map((t) {
              final (name, icon, color) = t;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.25), width: 1)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: color), const SizedBox(width: 7), Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13, color: color))]),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Center(child: Column(children: [
            Text('Made with ❤️ by NextGen Solutions', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('University of North Texas • CSCE 4901 • 2025', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ])),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4),
    child: Row(children: [
      Container(width: 4, height: 16, decoration: BoxDecoration(color: LegoApp.legoYellow, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.4)),
    ]),
  );

  Widget _badge(String text, Color bg, Color fg) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(text, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: fg)));

  Widget _infoRow(IconData icon, Color color, String label, String value) => ListTile(dense: true, leading: Icon(icon, color: color, size: 22), title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)), trailing: Text(value, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)));

  Widget _div() => const Divider(height: 1, indent: 54, endIndent: 16);
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

  LegoBrick({required this.id, required this.name, required this.color, this.colorName, required this.quantity, this.confidence});
}

class LegoSet {
  final String name;
  final int completion;
  final int missingPieces;
  final String imageUrl;

  LegoSet({required this.name, required this.completion, required this.missingPieces, required this.imageUrl});
}

// ---------------------------------------------------------------------------
// Search Delegate
// ---------------------------------------------------------------------------
class _BrickSearchDelegate extends SearchDelegate {
  final List<LegoBrick> bricks;
  _BrickSearchDelegate(this.bricks);

  @override
  List<Widget> buildActions(BuildContext ctx) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext ctx) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(ctx, null));

  @override
  Widget buildResults(BuildContext ctx) => _list();

  @override
  Widget buildSuggestions(BuildContext ctx) => _list();

  Widget _list() {
    final r = bricks.where((b) => b.name.toLowerCase().contains(query.toLowerCase()) || b.id.contains(query)).toList();
    return ListView.builder(
      itemCount: r.length,
      itemBuilder: (_, i) {
        final b = r[i];
        return ListTile(
          leading: CircleAvatar(radius: 20, backgroundColor: b.color, child: b.color == Colors.white || b.color == Colors.yellow ? Icon(Icons.view_in_ar, size: 16, color: Colors.grey[700]) : const Icon(Icons.view_in_ar, size: 16, color: Colors.white)),
          title: Text(b.name),
          subtitle: Text('ID: ${b.id}'),
          trailing: Text('Qty: ${b.quantity}'),
        );
      },
    );
  }
}