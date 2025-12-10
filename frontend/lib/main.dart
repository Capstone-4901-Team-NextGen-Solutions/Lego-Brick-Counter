import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'models/lego_brick_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();
  runApp(const LegoApp());
}

class LegoApp extends StatelessWidget {
  const LegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lego Brick Counter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ScanScreen(),
    const InventoryScreen(),
    const RecommendationsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lego Brick Counter'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_objects),
            label: 'Suggestions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  List<LegoBrick> _scannedBricks = [];
  bool _isProcessing = false;
  String? _errorMessage;
  XFile? _selectedImage;
  XFile? _lastFailedImage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scan Lego Bricks',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (_selectedImage != null && !_isProcessing)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: _clearSelection,
                          tooltip: 'Clear',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Image Preview - CORRECTED
                  if (_selectedImage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImagePreview(), // JUST THIS, NO EXTRA CODE
                      ),
                    ),
                  
                  // Loading State
                  if (_isProcessing)
                    Column(
                      children: [
                        const SizedBox(
                          height: 60,
                          width: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Analyzing bricks...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This may take a few seconds',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  // Error State
                  else if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Upload Failed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _retryUpload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  // Action Buttons
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.camera_alt,
                          label: 'Take Photo',
                          onPressed: _takePhoto,
                        ),
                        _buildActionButton(
                          icon: Icons.photo_library,
                          label: 'Upload Image',
                          onPressed: _uploadImage,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Detected Bricks',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_scannedBricks.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_scannedBricks.length} found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
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
                                  Icon(
                                    Icons.view_in_ar_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No bricks detected yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Take a photo or upload an image\nto start scanning',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Expanded(
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: ListView.builder(
                                itemCount: _scannedBricks.length,
                                itemBuilder: (context, index) {
                                  final brick = _scannedBricks[index];
                                  return _buildBrickCard(brick);
                                },
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) return Container();
    
    if (kIsWeb) {
      // For web: Display image from bytes/memory
      return FutureBuilder<Uint8List>(
        future: _selectedImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Icon(Icons.error, color: Colors.red));
          }
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
          );
        },
      );
    } else {
      // For mobile: Convert XFile to File
      return Image.file(
        File(_selectedImage!.path),
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
  }

  Widget _buildBrickCard(LegoBrick brick) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: brick.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brick.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ID: ${brick.id}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (brick.confidence != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(brick.confidence! * 100).toInt()}% confident',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${brick.quantity}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                  Text(
                    'qty',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedImage = null;
      _errorMessage = null;
      _scannedBricks = [];
    });
  }

  void _takePhoto() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        await _processImage(image);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera error: ${e.toString()}';
      });
    }
  }

  void _retryUpload() {
    if (_lastFailedImage != null) {
      _processImage(_lastFailedImage!);
    }
  }

  void _uploadImage() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        await _processImage(image);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gallery error: ${e.toString()}';
      });
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _lastFailedImage = imageFile;
    });

    try {
      var result = await ApiService.uploadImage(imageFile);

      if (!mounted) return;

      if (result['success'] == true) {
        final List<LegoBrick> newBricks = (result['results'] as List)
            .map((brickData) => LegoBrick(
                  id: brickData['id'],
                  name: brickData['name'],
                  color: _parseColor(brickData['color']),
                  quantity: brickData['quantity'],
                  confidence: brickData['confidence']?.toDouble(),
                ))
            .toList();

        // Save to database
        for (var brick in newBricks) {
          final brickModel = LegoBrickModel.fromLegoBrick(brick);
          await DatabaseService.mergeOrAddBrick(brickModel);
        }

        setState(() {
          _scannedBricks = newBricks;
          _errorMessage = null;
        });

        _animationController.forward(from: 0);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Found ${_scannedBricks.length} brick(s) and saved to inventory!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Upload failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: Unable to connect to server.\nPlease check your connection and try again.';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Color _parseColor(String colorName) {
    switch (colorName.toLowerCase()) {
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
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<LegoBrickModel> _inventory = [];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  void _loadInventory() {
    setState(() {
      _inventory = DatabaseService.getAllBricks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = DatabaseService.getStatistics();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          //Statistics
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Bricks', '${stats['totalBricks']}'),
                  _buildStatItem('Unique Types', '${stats['uniqueTypes']}'),
                  _buildStatItem('Recent Scans', '${stats['recentScans']}'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          //Inventory List
          Expanded(
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Inventory',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchInventory,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _inventory.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, 
                                       size: 64, 
                                       color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No bricks in inventory',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Scan some bricks to get started!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _inventory.length,
                              itemBuilder: (context, index) {
                                final brick = _inventory[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: brick.color,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                    ),
                                    title: Text(brick.name),
                                    subtitle: Text('ID: ${brick.id}'),
                                    trailing: Chip(
                                      label: Text('${brick.quantity}'),
                                      backgroundColor: Colors.red[100],
                                    ),
                                    onTap: () => _showBrickDetails(brick),
                                    onLongPress: () => _showBrickOptions(brick),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _searchInventory() {
    showSearch(
      context: context,
      delegate: _BrickSearchDelegate(_inventory),
    );
  }

  void _showBrickOptions(LegoBrickModel brick) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Quantity'),
              onTap: () {
                Navigator.pop(context);
                _editBrickQuantity(brick);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteBrick(brick);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(context);
                _showBrickDetails(brick);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editBrickQuantity(LegoBrickModel brick) {
    final controller = TextEditingController(text: '${brick.quantity}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newQuantity = int.tryParse(controller.text);
              if (newQuantity != null && newQuantity > 0) {
                brick.updateQuantity(newQuantity);
                _loadInventory();
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quantity updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteBrick(LegoBrickModel brick) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Brick'),
        content: Text('Are you sure you want to delete ${brick.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseService.deleteBrick(brick.id);
              _loadInventory();
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${brick.name} deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBrickDetails(LegoBrickModel brick) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(brick.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${brick.id}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Quantity: ${brick.quantity}', style: const TextStyle(fontSize: 16)),
            if (brick.confidence != null) ...[
              const SizedBox(height: 8),
              Text('Confidence: ${(brick.confidence! * 100).toStringAsFixed(1)}%',
                   style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            Text('Scanned: ${_formatDate(brick.scannedAt)}',
                 style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: brick.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recommendedSets = [
      LegoSet(
        name: 'Classic Creative Brick Box',
        completion: 85,
        missingPieces: 12,
        imageUrl: '',
      ),
      LegoSet(
        name: 'Space Rocket',
        completion: 72,
        missingPieces: 23,
        imageUrl: '',
      ),
      LegoSet(
        name: 'Medieval Castle',
        completion: 45,
        missingPieces: 56,
        imageUrl: '',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buildable Sets',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Based on your current inventory',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: recommendedSets.length,
              itemBuilder: (context, index) {
                final set = recommendedSets[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          set.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: set.completion / 100,
                          backgroundColor: Colors.grey[300],
                          color: set.completion > 75 
                              ? Colors.green 
                              : set.completion > 50 
                                  ? Colors.orange 
                                  : Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${set.completion}% Complete',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              '${set.missingPieces} pieces missing',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.red,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lego Enthusiast',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Member since 2024',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView(
              children: [
                _buildProfileOption(
                  icon: Icons.history,
                  title: 'Scan History',
                  onTap: () {},
                ),
                _buildProfileOption(
                  icon: Icons.favorite,
                  title: 'Favorite Sets',
                  onTap: () {},
                ),
                _buildProfileOption(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {},
                ),
                _buildProfileOption(
                  icon: Icons.help,
                  title: 'Help & Support',
                  onTap: () {},
                ),
                _buildProfileOption(
                  icon: Icons.info,
                  title: 'About',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
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

//Data Models
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

//Search Delegate
class _BrickSearchDelegate extends SearchDelegate {
  final List<LegoBrickModel> bricks;

  _BrickSearchDelegate(this.bricks);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = DatabaseService.searchBricks(query);

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No bricks found', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final brick = results[index];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: brick.color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
          ),
          title: Text(brick.name),
          subtitle: Text('ID: ${brick.id} • Qty: ${brick.quantity}'),
          trailing: Text('Qty: ${brick.quantity}'),
        );
      },
    );
  }
}