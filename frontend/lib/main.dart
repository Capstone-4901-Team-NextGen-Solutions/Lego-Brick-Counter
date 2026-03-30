import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';

import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize auth service
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
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'LEGO Brick Detection & Inventory',
        debugShowCheckedModeBanner: false,
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
                    Text(
                      isLogin ? 'Welcome Back!' : 'Create Account',
                      style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: LegoApp.legoDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLogin ? 'Sign in to continue' : 'Join the LEGO community',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
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
                        style: TextStyle(color: LegoApp.legoBlue, fontWeight: FontWeight.w600),
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
// Home Screen (unchanged)
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  final _screens = const [
    ScanScreen(),
    ScanHistoryScreen(),
    InventoryScreen(),
    RecommendationsScreen(),
    ProfileScreen(),
  ];

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

  // ---- actions ----

  void _clearSelection() => setState(() {
        _selectedImage = null;
        _errorMessage = null;
        _scannedBricks = [];
        _detectionResults = [];
        _isDetecting = false;
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
              Text('Scan LEGO Bricks', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
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
          if (_selectedImage != null) _detectButton(),
          if (_selectedImage == null) _actionButtons(),
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
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
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

  Widget _detectButton() {
    final isEnabled = _selectedImage != null && !_isDetecting;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? () {
          HapticFeedback.lightImpact();
          _detectBricks();
        } : null,
        icon: Icon(_isDetecting ? Icons.hourglass_empty : Icons.search),
        label: Text(_isDetecting ? 'Detecting...' : 'Detect Bricks'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? const Color(0xFFFFD700) : Colors.grey,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
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
            Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
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
                Text('Detection Results', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
                if (_scannedBricks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: LegoApp.legoRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${_scannedBricks.length} found',
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: LegoApp.legoRed)),
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
                    backgroundColor: LegoApp.legoBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Add All to Inventory', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
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
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[500])),
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
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.amber[800])),
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
    final quantity = rawData != null ? (rawData['count'] ?? rawData['quantity'] ?? brick.quantity) : brick.quantity;
    final colorName = brick.colorName ?? 'Unknown';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: brick.color, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brick.name,
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: LegoApp.legoDark),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: brick.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            colorName,
                            style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Confidence: ${(conf * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (quantity > 1)
                  Chip(
                    label: Text('Qty: $quantity', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    backgroundColor: LegoApp.legoYellow.withValues(alpha: 0.2),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: conf,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFFFFD700),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                  avatar: CircleAvatar(radius: 8, backgroundColor: _colorFromName(c)),
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
                    Text('My Inventory', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
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
        Text('Your inventory is empty', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[500])),
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
              Text(b.name, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('ID: ${b.id}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                InkWell(onTap: () => _updateQty(b, -1), child: const Icon(Icons.remove_circle_outline, size: 20, color: LegoApp.legoRed)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${b.quantity}', style: GoogleFonts.nunito(fontWeight: FontWeight.w800))),
                InkWell(onTap: () => _updateQty(b, 1), child: const Icon(Icons.add_circle_outline, size: 20, color: LegoApp.legoBlue)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _inventoryItem(LegoBrick b) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(radius: 20, backgroundColor: b.color,
          child: b.color == Colors.white || b.color == Colors.yellow
              ? Icon(Icons.view_in_ar, size: 18, color: Colors.grey[700])
              : const Icon(Icons.view_in_ar, size: 18, color: Colors.white)),
        title: Text(b.name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        subtitle: Text('ID: ${b.id}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20, color: LegoApp.legoRed), onPressed: () => _updateQty(b, -1)),
          Text('${b.quantity}', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: LegoApp.legoBlue), onPressed: () => _updateQty(b, 1)),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Column(children: [
        Icon(icon, color: LegoApp.legoBlue, size: 24),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
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
      setState(() => _sets = recs
          .map((d) => LegoSet(
                name: d['name'] ?? '',
                completion: d['completion_percentage'] ?? 0,
                missingPieces: d['missing_pieces'] ?? 0,
                imageUrl: d['image_url'] ?? '',
              ))
          .toList());
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
            Text('Buildable Sets', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        Text('Based on your current inventory', style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 16),
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
                        child: Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                  )
                : _sets.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.construction, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No recommendations yet', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                      ]))
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
    final diffColor = s.completion > 70 ? Colors.green : s.completion > 40 ? Colors.orange : LegoApp.legoRed;
    final diffLabel = s.completion > 70 ? 'Easy' : s.completion > 40 ? 'Medium' : 'Hard';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56, height: 56,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: pct, strokeWidth: 5, backgroundColor: Colors.grey.shade200, color: diffColor),
                Text('${s.completion}%', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: diffColor)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s.name, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700))),
                  Chip(
                    label: Text(diffLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    backgroundColor: diffColor,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey[200], color: diffColor, minHeight: 6),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (s.missingPieces > 0)
                    Chip(
                      avatar: const Icon(Icons.warning_amber, size: 14, color: LegoApp.legoRed),
                      label: Text('${s.missingPieces} missing', style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ]),
              ]),
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: LegoApp.legoYellow,
                child: Text(_initials(username), style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
              ),
              const SizedBox(height: 14),
              Text(username, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: LegoApp.legoDark)),
              if (email.isNotEmpty) Text(email, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              const SizedBox(height: 16),
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
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(children: [
            _profileTile(Icons.history, 'Scan History', () {
              // Navigate to scan history
            }),
            _profileTile(Icons.favorite, 'Favorite Sets', () {
              // Navigate to favorites
            }),
            _profileTile(Icons.settings, 'Settings', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            }),
            _profileTile(Icons.help, 'Help & Support', () {
              // Navigate to help
            }),
            _profileTile(Icons.info, 'About', () {
              // Navigate to about
            }),
            _profileTile(Icons.logout, 'Logout', _logout, color: LegoApp.legoRed),
          ]),
        ),
      ]),
    );
  }

  Widget _animatedStatCard(String label, int value, IconData icon) {
    return SizedBox(
      width: 100,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(children: [
            Icon(icon, color: LegoApp.legoBlue, size: 22),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (_, v, __) => Text(
                '${v.toInt()}',
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: LegoApp.legoDark),
              ),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ),
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? LegoApp.legoBlue).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color ?? LegoApp.legoBlue, size: 20),
        ),
        title: Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: color)),
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
        title: Text('Settings', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
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
          Text('Change Password', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700)),
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
    switch (colorName?.toLowerCase()) {
      case 'red': return Colors.red;
      case 'orange': return Colors.orange;
      case 'yellow': return Colors.yellow;
      case 'lime green': return Colors.lightGreen;
      case 'green': return Colors.green;
      case 'dark green': return Colors.green.shade800;
      case 'blue': return Colors.blue;
      case 'dark blue': return Colors.blue.shade900;
      case 'light blue': return Colors.lightBlue;
      case 'purple': return Colors.purple;
      case 'white': return Colors.white;
      case 'light gray': return Colors.grey.shade300;
      case 'dark gray': return Colors.grey.shade700;
      case 'black': return Colors.black;
      case 'brown': return const Color(0xFF795548);
      case 'tan': return const Color(0xFFD2B48C);
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
        title: Text('Scan History', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
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
                              title: Text(formattedDate, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 16)),
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

                                    return ListTile(
                                      leading: CircleAvatar(radius: 8, backgroundColor: _colorFromName(color)),
                                      title: Text(brickName, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                                      subtitle: Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%'),
                                      trailing: Text('x$count', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 16)),
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
  final int completion;
  final int missingPieces;
  final String imageUrl;

  LegoSet({
    required this.name,
    required this.completion,
    required this.missingPieces,
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

