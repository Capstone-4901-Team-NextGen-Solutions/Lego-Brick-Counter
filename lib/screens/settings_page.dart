import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  void _onThemeModeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settings',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: SettingsPage(
        themeMode: _themeMode,
        onThemeModeChanged: _onThemeModeChanged,
      ),
    );
  }
}

class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B6AF5),
          brightness: Brightness.light,
        ),
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F6FA),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1D2E),
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF1A1D2E)),
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B6AF5),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1117),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF0F0F5),
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFFF0F0F5)),
        ),
      );
}

class SettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _hapticFeedback = true;
  bool _autoSave = true;
  bool _cloudSync = false;
  bool _analyticsEnabled = false;
  bool _locationServices = false;
  bool _biometricLogin = true;
  bool _compactView = false;
  bool _showBadges = true;

  bool get _isDark =>
      widget.themeMode == ThemeMode.dark ||
      (widget.themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  void _toggleDarkMode(bool value) {
    widget.onThemeModeChanged(value ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 110,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text('Settings',
                  style: Theme.of(context).appBarTheme.titleTextStyle),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ProfileCard(),
                const SizedBox(height: 24),
                _SectionLabel('Appearance'),
                _SettingsCard(children: [
                  _SwitchTile(
                    icon: Icons.dark_mode_rounded,
                    iconColor: const Color(0xFF5B6AF5),
                    title: 'Dark Mode',
                    subtitle: 'Switch to a darker color scheme',
                    value: _isDark,
                    onChanged: _toggleDarkMode,
                  ),
                  _Divider(),
                  _NavigationTile(
                    icon: Icons.accessibility_new_rounded,
                    iconColor: const Color(0xFF2DC9A0),
                    title: 'Accessibility',
                    subtitle: 'Text size, contrast & more',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AccessibilityPage())),
                  ),
                ]),
                const SizedBox(height: 20),
                _SectionLabel('Notifications & Sound'),
                _SettingsCard(children: [
                  _SwitchTile(
                    icon: Icons.notifications_rounded,
                    iconColor: const Color(0xFFFF6B6B),
                    title: 'Push Notifications',
                    subtitle: 'Receive alerts and reminders',
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.volume_up_rounded,
                    iconColor: const Color(0xFFFF9F43),
                    title: 'Sound Effects',
                    subtitle: 'Play audio on interactions',
                    value: _soundEnabled,
                    onChanged: (v) => setState(() => _soundEnabled = v),
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.vibration_rounded,
                    iconColor: const Color(0xFFFF6B6B),
                    title: 'Haptic Feedback',
                    subtitle: 'Vibrate on key actions',
                    value: _hapticFeedback,
                    onChanged: (v) => setState(() => _hapticFeedback = v),
                  ),
                ]),
                const SizedBox(height: 20),
                _SectionLabel('Data & Storage'),
                _SettingsCard(children: [
                  _SwitchTile(
                    icon: Icons.save_rounded,
                    iconColor: const Color(0xFF5B6AF5),
                    title: 'Auto-Save',
                    subtitle: 'Automatically save your progress',
                    value: _autoSave,
                    onChanged: (v) => setState(() => _autoSave = v),
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.cloud_sync_rounded,
                    iconColor: const Color(0xFF54A0FF),
                    title: 'Cloud Sync',
                    subtitle: 'Backup data across devices',
                    value: _cloudSync,
                    onChanged: (v) => setState(() => _cloudSync = v),
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.bar_chart_rounded,
                    iconColor: const Color(0xFF2DC9A0),
                    title: 'Analytics',
                    subtitle: 'Share anonymous usage data',
                    value: _analyticsEnabled,
                    onChanged: (v) => setState(() => _analyticsEnabled = v),
                  ),
                ]),
                const SizedBox(height: 20),
                _SectionLabel('Privacy & Security'),
                _SettingsCard(children: [
                  _SwitchTile(
                    icon: Icons.location_on_rounded,
                    iconColor: const Color(0xFFFF9F43),
                    title: 'Location Services',
                    subtitle: 'Allow app to use your location',
                    value: _locationServices,
                    onChanged: (v) => setState(() => _locationServices = v),
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.fingerprint_rounded,
                    iconColor: const Color(0xFF5B6AF5),
                    title: 'Biometric Login',
                    subtitle: 'Use Face ID or fingerprint',
                    value: _biometricLogin,
                    onChanged: (v) => setState(() => _biometricLogin = v),
                  ),
                ]),
                const SizedBox(height: 20),
                _SectionLabel('Display'),
                _SettingsCard(children: [
                  _SwitchTile(
                    icon: Icons.view_compact_rounded,
                    iconColor: const Color(0xFF2DC9A0),
                    title: 'Compact View',
                    subtitle: 'Show more content on screen',
                    value: _compactView,
                    onChanged: (v) => setState(() => _compactView = v),
                  ),
                  _Divider(),
                  _SwitchTile(
                    icon: Icons.new_releases_rounded,
                    iconColor: const Color(0xFFFF6B6B),
                    title: 'Show Badges',
                    subtitle: 'Display notification badges',
                    value: _showBadges,
                    onChanged: (v) => setState(() => _showBadges = v),
                  ),
                ]),
                const SizedBox(height: 20),
                _SectionLabel('About'),
                _SettingsCard(children: [
                  _NavigationTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF54A0FF),
                    title: 'About This App',
                    subtitle: 'Version 1.0.0',
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('About', style: TextStyle(fontWeight: FontWeight.w800)),
                        content: const Text('MyApp v1.0.0\nBuilt with Flutter · © 2025'),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                      ),
                    ),
                  ),
                  _Divider(),
                  _NavigationTile(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: const Color(0xFF5B6AF5),
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    onTap: () {},
                  ),
                  _Divider(),
                  _NavigationTile(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFF2DC9A0),
                    title: 'Terms of Service',
                    subtitle: 'Usage terms and conditions',
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 20),
                _SettingsCard(children: [
                  _NavigationTile(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFFF6B6B),
                    title: 'Sign Out',
                    subtitle: 'Log out of your account',
                    titleColor: const Color(0xFFFF6B6B),
                    onTap: () {},
                    showChevron: false,
                  ),
                ]),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class AccessibilityPage extends StatefulWidget {
  const AccessibilityPage({super.key});
  @override
  State<AccessibilityPage> createState() => _AccessibilityPageState();
}

class _AccessibilityPageState extends State<AccessibilityPage> {
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _reducedMotion = false;
  bool _screenReader = false;
  bool _boldText = false;
  bool _buttonShapes = false;

  String get _textScaleLabel {
    if (_textScale < 0.9) return 'Small';
    if (_textScale < 1.1) return 'Default';
    if (_textScale < 1.4) return 'Large';
    return 'Extra Large';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Accessibility'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _SectionLabel('Text Size'),
          _SettingsCard(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        _IconBox(icon: Icons.text_fields_rounded, color: const Color(0xFF5B6AF5)),
                        const SizedBox(width: 12),
                        const Text('Text Size', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B6AF5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_textScaleLabel,
                            style: const TextStyle(color: Color(0xFF5B6AF5), fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF5B6AF5),
                      thumbColor: const Color(0xFF5B6AF5),
                      inactiveTrackColor: const Color(0xFF5B6AF5).withOpacity(0.2),
                    ),
                    child: Slider(
                      min: 0.7, max: 1.6, divisions: 6,
                      value: _textScale,
                      onChanged: (v) => setState(() => _textScale = v),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _SectionLabel('Display'),
          _SettingsCard(children: [
            _SwitchTile(
              icon: Icons.contrast_rounded, iconColor: const Color(0xFF1A1D2E),
              title: 'High Contrast', subtitle: 'Increase color contrast for readability',
              value: _highContrast, onChanged: (v) => setState(() => _highContrast = v),
            ),
            _Divider(),
            _SwitchTile(
              icon: Icons.format_bold_rounded, iconColor: const Color(0xFF5B6AF5),
              title: 'Bold Text', subtitle: 'Make all text heavier weight',
              value: _boldText, onChanged: (v) => setState(() => _boldText = v),
            ),
            _Divider(),
            _SwitchTile(
              icon: Icons.smart_button_rounded, iconColor: const Color(0xFF54A0FF),
              title: 'Button Shapes', subtitle: 'Always show button outlines',
              value: _buttonShapes, onChanged: (v) => setState(() => _buttonShapes = v),
            ),
          ]),
          const SizedBox(height: 20),
          _SectionLabel('Motion & Interaction'),
          _SettingsCard(children: [
            _SwitchTile(
              icon: Icons.animation_rounded, iconColor: const Color(0xFFFF9F43),
              title: 'Reduce Motion', subtitle: 'Minimize transitions and animations',
              value: _reducedMotion, onChanged: (v) => setState(() => _reducedMotion = v),
            ),
            _Divider(),
            _SwitchTile(
              icon: Icons.record_voice_over_rounded, iconColor: const Color(0xFF2DC9A0),
              title: 'Screen Reader', subtitle: 'Enable TalkBack / VoiceOver support',
              value: _screenReader, onChanged: (v) => setState(() => _screenReader = v),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6AF5), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF5B6AF5).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alex Johnson', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('alex.johnson@email.com', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: const Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45))),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _IconBox(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            ]),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(value: value, onChanged: onChanged, activeColor: const Color(0xFF5B6AF5)),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final bool showChevron;
  const _NavigationTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap, this.titleColor, this.showChevron = true});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _IconBox(icon: icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: titleColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
              ]),
            ),
            if (showChevron) Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 70, endIndent: 16,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08));
  }
}
