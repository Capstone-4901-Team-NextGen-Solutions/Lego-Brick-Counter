import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

void main() {
  runApp(const LegoApp());
}

class LegoApp extends StatelessWidget {
  const LegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lego Brick Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthGate(),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class AuthService {
  static final ValueNotifier<bool> loggedIn = ValueNotifier(false);
  static bool get isLoggedIn => loggedIn.value;
  static void login() => loggedIn.value = true;
  static void logout() => loggedIn.value = false;
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.loggedIn,
      builder: (context, isLoggedIn, _) =>
          isLoggedIn ? const HomeScreen() : const AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!isLogin && _pass.text.trim() != _confirm.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    AuthService.login();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLogin ? 'Login' : 'Create Account',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                      controller: _email,
                      decoration:
                          const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _pass,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Password')),
                  if (!isLogin) ...[
                    const SizedBox(height: 16),
                    TextField(
                        controller: _confirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Confirm Password')),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text(isLogin ? 'Login' : 'Register'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin
                        ? 'New here? Create an account'
                        : 'Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home
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
    InventoryScreen(),
    RecommendationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lego Brick Counter'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _screens[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_objects), label: 'Suggestions'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (i) => setState(() => _idx = i),
      ),
    );
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

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  List<LegoBrick> _scannedBricks = [];
  bool _isProcessing = false;
  String? _errorMessage;
  XFile? _selectedImage;
  XFile? _lastFailedImage;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl =
        AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ---- actions ----

  void _clearSelection() => setState(() {
        _selectedImage = null;
        _errorMessage = null;
        _scannedBricks = [];
      });

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _errorMessage = null);
    try {
      final img = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (img != null) {
        setState(() => _selectedImage = img);
        await _processImage(img);
      }
    } catch (e) {
      setState(() => _errorMessage = '${source == ImageSource.camera ? "Camera" : "Gallery"} error: $e');
    }
  }

  void _retryUpload() {
    if (_lastFailedImage != null) _processImage(_lastFailedImage!);
  }

  Future<void> _processImage(XFile imageFile) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _lastFailedImage = imageFile;
    });

    try {
      final result = await ApiService.uploadImage(imageFile);

      if (result['success'] == true) {
        setState(() {
          _scannedBricks = (result['results'] as List)
              .map((d) => LegoBrick(
                    id: d['id'] ?? '0000',
                    name: d['name'] ?? 'Unknown',
                    color: _parseColor(d['color'] ?? ''),
                    quantity: d['quantity'] ?? 1,
                    confidence: (d['confidence'] as num?)?.toDouble(),
                  ))
              .toList();
          _errorMessage = null;
        });
        _animCtrl.forward(from: 0);

        if (mounted) {
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
        }
      } else {
        setState(
            () => _errorMessage = result['error'] ?? 'Upload failed.');
      }
    } catch (e) {
      setState(() =>
          _errorMessage = 'Network error. Check your connection.');
    } finally {
      setState(() => _isProcessing = false);
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildScanCard(),
          const SizedBox(height: 16),
          Expanded(child: _buildResultsCard()),
        ],
      ),
    );
  }

  Widget _buildScanCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Scan Lego Bricks',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (_selectedImage != null && !_isProcessing)
                IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _clearSelection,
                    tooltip: 'Clear'),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null) _imagePreview(),
          if (_isProcessing) _loadingWidget(),
          if (!_isProcessing && _errorMessage != null) _errorWidget(),
          if (!_isProcessing && _errorMessage == null) _actionButtons(),
        ]),
      ),
    );
  }

  Widget _imagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List>(
          future: _selectedImage!.readAsBytes(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData) {
              return const Center(child: Icon(Icons.error, color: Colors.red));
            }
            return Image.memory(snap.data!,
                fit: BoxFit.cover, width: double.infinity);
          },
        ),
      ),
    );
  }

  Widget _loadingWidget() {
    return Column(children: [
      const SizedBox(
          height: 60,
          width: 60,
          child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation(Colors.red))),
      const SizedBox(height: 20),
      const Text('Analyzing bricks…',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Text('This may take a few seconds',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ]);
  }

  Widget _errorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 40),
        const SizedBox(height: 12),
        Text('Upload Failed',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900)),
        const SizedBox(height: 8),
        Text(_errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.red.shade800)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _retryUpload,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
        ),
      ]),
    );
  }

  Widget _actionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionBtn(Icons.camera_alt, 'Take Photo',
            () => _pickImage(ImageSource.camera)),
        _actionBtn(Icons.photo_library, 'Upload Image',
            () => _pickImage(ImageSource.gallery)),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 32),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildResultsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Detected Bricks',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_scannedBricks.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${_scannedBricks.length} found',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _scannedBricks.isEmpty
                ? Expanded(
                    child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.view_in_ar_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('No bricks detected yet',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            Text('Take a photo or upload an image\nto start scanning',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[500])),
                          ]),
                    ),
                  )
                : Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: ListView.builder(
                        itemCount: _scannedBricks.length,
                        itemBuilder: (_, i) => _brickCard(_scannedBricks[i]),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _brickCard(LegoBrick brick) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: brick.color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brick.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _tag('ID: ${brick.id}', Colors.blue),
                    const SizedBox(width: 8),
                    if (brick.confidence != null)
                      _tag(
                          '${(brick.confidence! * 100).toInt()}%', Colors.green),
                  ]),
                ]),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text('${brick.quantity}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900)),
              Text('qty',
                  style: TextStyle(fontSize: 10, color: Colors.red.shade700)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tag(String text, MaterialColor c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: c.shade50, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.shade900)),
    );
  }
}

// ---------------------------------------------------------------------------
// Inventory Screen — loads from API
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

  @override
  Widget build(BuildContext context) {
    final totalBricks = _inventory.fold<int>(0, (s, b) => s + b.quantity);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Total Bricks', '$totalBricks'),
                _stat('Unique Types', '${_inventory.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('My Inventory',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(children: [
                      IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadInventory),
                      IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => showSearch(
                              context: context,
                              delegate: _BrickSearchDelegate(_inventory))),
                    ]),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
                if (_error != null)
                  Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))),
                if (!_loading && _error == null)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _inventory.length,
                      itemBuilder: (_, i) {
                        final b = _inventory[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Container(width: 40, height: 40, color: b.color),
                            title: Text(b.name),
                            subtitle: Text('ID: ${b.id}'),
                            trailing: Chip(
                                label: Text('${b.quantity}'),
                                backgroundColor: Colors.red[100]),
                          ),
                        );
                      },
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]);
}

// ---------------------------------------------------------------------------
// Recommendations Screen — loads from API
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
            const Text('Buildable Sets',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        const Text('Based on your current inventory',
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
        if (!_loading)
          Expanded(
            child: ListView.builder(
              itemCount: _sets.length,
              itemBuilder: (_, i) {
                final s = _sets[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: s.completion / 100,
                            backgroundColor: Colors.grey[300],
                            color: s.completion > 75
                                ? Colors.green
                                : s.completion > 50
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                          const SizedBox(height: 8),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${s.completion}% Complete'),
                                Text('${s.missingPieces} missing',
                                    style: const TextStyle(color: Colors.red)),
                              ]),
                        ]),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Screen — shows Pinecone status
// ---------------------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _backendStatus = 'checking…';
  String _pineconeStatus = 'checking…';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final health = await ApiService.getHealth();
    setState(() {
      _backendStatus = health['status'] ?? health['error'] ?? 'unknown';
      _pineconeStatus = health['pinecone_status'] ?? 'unknown';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.person, size: 40, color: Colors.white)),
              const SizedBox(height: 16),
              const Text('Lego Enthusiast',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Backend: $_backendStatus',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text('Pinecone: $_pineconeStatus',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(children: [
            _profileTile(Icons.history, 'Scan History', () {}),
            _profileTile(Icons.favorite, 'Favorite Sets', () {}),
            _profileTile(Icons.settings, 'Settings', () {}),
            _profileTile(Icons.help, 'Help & Support', () {}),
            _profileTile(Icons.info, 'About', () {}),
            _profileTile(Icons.logout, 'Logout', AuthService.logout),
          ]),
        ),
      ]),
    );
  }

  Widget _profileTile(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
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
  final int quantity;
  final double? confidence;

  LegoBrick({
    required this.id,
    required this.name,
    required this.color,
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
          leading: Container(width: 40, height: 40, color: b.color),
          title: Text(b.name),
          subtitle: Text('ID: ${b.id}'),
          trailing: Text('Qty: ${b.quantity}'),
        );
      },
    );
  }
}
