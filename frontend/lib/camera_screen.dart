//camera_screen.dart
//Requires: camera: ^0.11.0  in pubspec.yaml

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';


class CameraCapture {
  static Future<XFile?> capture(BuildContext context) async {
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not access camera: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return null;
    }

    if (cameras.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No camera found on this device'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return null;
    }

    if (!context.mounted) return null;
    return Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CameraScreen(cameras: cameras),
      ),
    );
  }
}

//Camera screen — desktop-safe layout 
class _CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _CameraScreen({required this.cameras});

  @override
  State<_CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<_CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _initialized = false;
  bool _capturing = false;
  String? _error;
  FlashMode _flash = FlashMode.off;

  static const _yellow = Color(0xFFFFD700);
  static const _dark   = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init(widget.cameras[_cameraIndex]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      if (mounted) setState(() => _initialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _init(widget.cameras[_cameraIndex]);
    }
  }

  Future<void> _init(CameraDescription cam) async {
    //Dispose previous controller cleanly
    final old = _controller;
    if (old != null) {
      await old.dispose();
      _controller = null;
    }

    if (!mounted) return;
    setState(() { _initialized = false; _error = null; });

    final ctrl = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      //Flash not supported on all desktop cameras — ignores errors
      try { await ctrl.setFlashMode(_flash); } catch (_) {}
      setState(() { _controller = ctrl; _initialized = true; });
    } on CameraException catch (e) {
      ctrl.dispose();
      if (mounted) setState(() => _error = '${e.code}: ${e.description}');
    } catch (e) {
      ctrl.dispose();
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    await _init(widget.cameras[_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    final next = _flash == FlashMode.off ? FlashMode.auto
               : _flash == FlashMode.auto ? FlashMode.always
               : FlashMode.off;
    try { await _controller?.setFlashMode(next); } catch (_) {}
    setState(() => _flash = next);
  }

  Future<void> _capture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _capturing) return;
    HapticFeedback.mediumImpact();
    setState(() => _capturing = true);
    try {
      final file = await ctrl.takePicture();
      if (mounted) Navigator.of(context).pop(file);
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Capture failed: ${e.description}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _capturing = false);
      }
    }
  }

  IconData get _flashIcon => _flash == FlashMode.always ? Icons.flash_on
      : _flash == FlashMode.auto ? Icons.flash_auto
      : Icons.flash_off;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            // ── Preview area fills all remaining space ──────────────────
            Expanded(child: _previewArea()),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _previewArea() {
    if (_error != null) return _errorView();
    if (!_initialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: _yellow),
      );
    }

    // SizedBox.expand + FittedBox gives a desktop-safe fullscreen preview
    // without needing AspectRatio (which requires bounded constraints).
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview fills the box, letterboxed if needed
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width:  _controller!.value.previewSize?.height ?? 640,
              height: _controller!.value.previewSize?.width  ?? 480,
              child: CameraPreview(_controller!),
            ),
          ),
        ),
        // Capture flash overlay
        if (_capturing)
          Container(color: Colors.white38),
      ],
    );
  }

  Widget _topBar() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(null),
            tooltip: 'Cancel',
          ),
          Expanded(
            child: Text(
              'Take Photo',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(_flashIcon, color: Colors.white),
            onPressed: _initialized ? _toggleFlash : null,
            tooltip: 'Flash',
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery shortcut
          _iconBtn(
            icon: Icons.photo_library_outlined,
            onTap: () async {
              final img = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (img != null && mounted) Navigator.of(context).pop(img);
            },
            tooltip: 'Pick from gallery',
          ),

          // Shutter
          GestureDetector(
            onTap: _capturing ? null : _capture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _capturing ? Colors.grey : _yellow,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: _capturing
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt, color: _dark, size: 32),
            ),
          ),

          // Switch camera
          _iconBtn(
            icon: Icons.flip_camera_android,
            onTap: widget.cameras.length > 1 ? _switchCamera : null,
            tooltip: 'Switch camera',
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(enabled ? 0.15 : 0.05),
            border: Border.all(
              color: Colors.white.withOpacity(enabled ? 0.3 : 0.08),
            ),
          ),
          child: Icon(icon,
            color: Colors.white.withOpacity(enabled ? 1.0 : 0.25),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off, color: Colors.white54, size: 56),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Camera unavailable',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _init(widget.cameras[_cameraIndex]),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}