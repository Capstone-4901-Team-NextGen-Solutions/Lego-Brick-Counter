import 'package:flutter/material.dart';

void main() {
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

class _ScanScreenState extends State<ScanScreen> {
  List<LegoBrick> _scannedBricks = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Camera/Upload Section
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Scan Lego Bricks',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.camera_alt,
                        label: 'Take Photo',
                        onPressed: () => _takePhoto(),
                      ),
                      _buildActionButton(
                        icon: Icons.photo_library,
                        label: 'Upload Image',
                        onPressed: () => _uploadImage(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Results Section
          Expanded(
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan Results',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _scannedBricks.isEmpty
                        ? const Expanded(
                            child: Center(
                              child: Text(
                                'No bricks scanned yet\nUse camera or upload an image',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : Expanded(
                            child: ListView.builder(
                              itemCount: _scannedBricks.length,
                              itemBuilder: (context, index) {
                                final brick = _scannedBricks[index];
                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    color: brick.color,
                                  ),
                                  title: Text(brick.name),
                                  subtitle: Text('Quantity: ${brick.quantity}'),
                                  trailing: Text('ID: ${brick.id}'),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 40),
          onPressed: onPressed,
          color: Colors.red,
        ),
        Text(label),
      ],
    );
  }

  void _takePhoto() {
    // TODO: Implement camera functionality
    _mockScanBricks();
  }

  void _uploadImage() {
    // TODO: Implement image picker
    _mockScanBricks();
  }

  void _mockScanBricks() {
    // Mock data for demonstration
    setState(() {
      _scannedBricks = [
        LegoBrick(
          id: '3001',
          name: '2x4 Brick',
          color: Colors.red,
          quantity: 5,
        ),
        LegoBrick(
          id: '3003',
          name: '2x2 Brick',
          color: Colors.blue,
          quantity: 3,
        ),
        LegoBrick(
          id: '3023',
          name: '1x2 Plate',
          color: Colors.yellow,
          quantity: 8,
        ),
      ];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bricks scanned successfully!')),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final List<LegoBrick> _inventory = [
    LegoBrick(id: '3001', name: '2x4 Brick', color: Colors.red, quantity: 15),
    LegoBrick(id: '3003', name: '2x2 Brick', color: Colors.blue, quantity: 12),
    LegoBrick(id: '3023', name: '1x2 Plate', color: Colors.yellow, quantity: 20),
    LegoBrick(id: '3005', name: '1x1 Brick', color: Colors.green, quantity: 8),
    LegoBrick(id: '2456', name: '2x6 Brick', color: Colors.black, quantity: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Statistics
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Bricks', '58'),
                  _buildStatItem('Unique Types', '5'),
                  _buildStatItem('Sets Possible', '3'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Inventory List
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
                      child: ListView.builder(
                        itemCount: _inventory.length,
                        itemBuilder: (context, index) {
                          final brick = _inventory[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                color: brick.color,
                              ),
                              title: Text(brick.name),
                              subtitle: Text('ID: ${brick.id}'),
                              trailing: Chip(
                                label: Text('${brick.quantity}'),
                                backgroundColor: Colors.red[100],
                              ),
                              onTap: () => _showBrickDetails(brick),
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
    // TODO: Implement search functionality
    showSearch(
      context: context,
      delegate: _BrickSearchDelegate(_inventory),
    );
  }

  void _showBrickDetails(LegoBrick brick) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(brick.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${brick.id}'),
            Text('Quantity: ${brick.quantity}'),
            const SizedBox(height: 16),
            Container(
              width: 50,
              height: 50,
              color: brick.color,
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

// Data Models
class LegoBrick {
  final String id;
  final String name;
  final Color color;
  final int quantity;

  LegoBrick({
    required this.id,
    required this.name,
    required this.color,
    required this.quantity,
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

// Search Delegate
class _BrickSearchDelegate extends SearchDelegate {
  final List<LegoBrick> bricks;

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
    final results = bricks.where((brick) =>
        brick.name.toLowerCase().contains(query.toLowerCase()) ||
        brick.id.contains(query)).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final brick = results[index];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            color: brick.color,
          ),
          title: Text(brick.name),
          subtitle: Text('ID: ${brick.id}'),
          trailing: Text('Qty: ${brick.quantity}'),
        );
      },
    );
  }
}