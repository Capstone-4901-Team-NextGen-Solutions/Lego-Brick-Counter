// camera_screen.dart
// Platform-aware camera capture:
//   - Desktop web: shows a dialog with live camera preview via dart:html getUserMedia
//   - Mobile web:  uses ImagePicker camera (Safari/Chrome handle it natively)
//   - Native:      uses camera package with full-screen live preview
//
// pubspec.yaml: camera: ^0.11.0 and image_picker: ^1.0.0 (already present)

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

class CameraCapture {
  static Future<XFile?> capture(BuildContext context) async {
    if (kIsWeb) {
      if (_isMobileBrowser()) {
        // Mobile browser (phone/tablet) — ImagePicker camera works natively
        try {
          return await ImagePicker().pickImage(
            source: ImageSource.camera,
            maxWidth: 1200, maxHeight: 1200, imageQuality: 85,
          );
        } catch (_) {
          return await ImagePicker().pickImage(source: ImageSource.gallery);
        }
      } else {
        // Desktop browser — show a camera dialog using getUserMedia
        if (!context.mounted) return null;
        return await showDialog<XFile?>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _WebCameraDialog(),
        );
      }
    }

    // Native app
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not access camera: $e'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
        ));
      }
      return null;
    }

    if (cameras.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No camera found on this device'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
        ));
      }
      return null;
    }

    if (!context.mounted) return null;
    return Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NativeCameraScreen(cameras: cameras),
      ),
    );
  }

  static bool _isMobileBrowser() {
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      return ua.contains('mobile') || ua.contains('android') ||
             ua.contains('iphone') || ua.contains('ipad');
    } catch (_) { return false; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop web camera dialog
// ─────────────────────────────────────────────────────────────────────────────

class _WebCameraDialog extends StatefulWidget {
  const _WebCameraDialog();
  @override
  State<_WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<_WebCameraDialog> {
  html.VideoElement? _video;
  html.MediaStream?  _stream;
  bool    _ready     = false;
  bool    _capturing = false;
  String? _error;

  static const _yellow = Color(0xFFFFD700);
  static const _dark   = Color(0xFF1A1A2E);
  static const _viewId = 'lego-camera-preview';

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _stopStream() {
    _stream?.getTracks().forEach((t) => t.stop());
    _video?.srcObject = null;
  }

  Future<void> _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'environment', 'width': 1280, 'height': 720},
        'audio': false,
      });
      _stream = stream;
      _video  = html.VideoElement()
        ..autoplay  = true
        ..muted     = true
        ..srcObject = stream
        ..style.width    = '100%'
        ..style.height   = '100%'
        ..style.objectFit = 'cover';

      ui_web.platformViewRegistry.registerViewFactory(
          _viewId, (int _) => _video!);

      await _video!.onLoadedData.first;
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() =>
        _error = 'Camera access denied.\n'
                 'Allow camera in browser settings, or upload from gallery.');
    }
  }

  Future<void> _capture() async {
    final video = _video;
    if (video == null || !_ready || _capturing) return;
    setState(() => _capturing = true);
    try {
      final canvas = html.CanvasElement(
          width: video.videoWidth, height: video.videoHeight);
      canvas.context2D.drawImage(video, 0, 0);

      final blob = await canvas.toBlob('image/jpeg', 0.92);
      if (blob == null) throw Exception('Capture failed');

      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;
      final bytes = Uint8List.fromList(
          (reader.result as ByteBuffer).asUint8List());

      final xFile = XFile.fromData(bytes,
          name: 'capture.jpg', mimeType: 'image/jpeg');
      _stopStream();
      if (mounted) Navigator.of(context).pop(xFile);
    } catch (e) {
      setState(() => _capturing = false);
    }
  }

  void _cancel() { _stopStream(); Navigator.of(context).pop(null); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: size.width.clamp(0.0, 640.0),
          height: size.height * 0.75,
          child: Column(children: [
            // Top bar
            Container(color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _cancel),
                Expanded(child: Text('Take Photo', textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w700))),
                const SizedBox(width: 48),
              ])),
            // Preview
            Expanded(child: _error != null ? _errorView()
              : !_ready
                  ? const Center(child: CircularProgressIndicator(color: _yellow))
                  : HtmlElementView(viewType: _viewId)),
            // Bottom bar
            Container(color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconBtn(icon: Icons.photo_library_outlined,
                    onTap: () async {
                      _stopStream();
                      final img = await ImagePicker().pickImage(
                          source: ImageSource.gallery, imageQuality: 85);
                      if (mounted) Navigator.of(context).pop(img);
                    }),
                  GestureDetector(onTap: (_ready && !_capturing) ? _capture : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 68, height: 68,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _capturing ? Colors.grey : _yellow,
                        border: Border.all(color: Colors.white, width: 4)),
                      child: _capturing
                          ? const Padding(padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt, color: _dark, size: 30),
                    )),
                  const SizedBox(width: 50),
                ])),
          ]),
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, VoidCallback? onTap}) =>
      GestureDetector(onTap: onTap, child: Container(width: 50, height: 50,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.15),
          border: Border.all(color: Colors.white.withOpacity(0.3))),
        child: Icon(icon, color: Colors.white, size: 24)));

  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.videocam_off, color: Colors.white54, size: 56),
      const SizedBox(height: 16),
      Text(_error ?? 'Camera unavailable', textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () async {
          _stopStream();
          final img = await ImagePicker().pickImage(
              source: ImageSource.gallery, imageQuality: 85);
          if (mounted) Navigator.of(context).pop(img);
        },
        icon: const Icon(Icons.photo_library, color: Colors.white),
        label: const Text('Upload from gallery',
            style: TextStyle(color: Colors.white)),
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white38))),
    ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// Native camera screen
// ─────────────────────────────────────────────────────────────────────────────

class _NativeCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _NativeCameraScreen({required this.cameras});
  @override
  State<_NativeCameraScreen> createState() => _NativeCameraScreenState();
}

class _NativeCameraScreenState extends State<_NativeCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _initialized = false, _capturing = false;
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
      ctrl.dispose(); if (mounted) setState(() => _initialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _init(widget.cameras[_cameraIndex]);
    }
  }

  Future<void> _init(CameraDescription cam) async {
    final old = _controller;
    if (old != null) { await old.dispose(); _controller = null; }
    if (!mounted) return;
    setState(() { _initialized = false; _error = null; });
    final ctrl = CameraController(cam, ResolutionPreset.high,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    try {
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
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
               : _flash == FlashMode.auto ? FlashMode.always : FlashMode.off;
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
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
        setState(() => _capturing = false);
      }
    }
  }

  IconData get _flashIcon => _flash == FlashMode.always ? Icons.flash_on
      : _flash == FlashMode.auto ? Icons.flash_auto : Icons.flash_off;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(child: Column(children: [
      _topBar(), Expanded(child: _previewArea()), _bottomBar()])));

  Widget _previewArea() {
    if (_error != null) return _errorView();
    if (!_initialized || _controller == null)
      return const Center(child: CircularProgressIndicator(color: _yellow));
    return Stack(fit: StackFit.expand, children: [
      SizedBox.expand(child: FittedBox(fit: BoxFit.contain,
        child: SizedBox(
          width:  _controller!.value.previewSize?.height ?? 640,
          height: _controller!.value.previewSize?.width  ?? 480,
          child: CameraPreview(_controller!)))),
      if (_capturing) Container(color: Colors.white38),
    ]);
  }

  Widget _topBar() => Container(color: Colors.black87,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(null)),
      Expanded(child: Text('Take Photo', textAlign: TextAlign.center,
          style: GoogleFonts.nunito(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w700))),
      IconButton(icon: Icon(_flashIcon, color: Colors.white),
          onPressed: _initialized ? _toggleFlash : null),
    ]));

  Widget _bottomBar() => Container(color: Colors.black87,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _iconBtn(icon: Icons.photo_library_outlined, onTap: () async {
        final img = await ImagePicker()
            .pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (img != null && mounted) Navigator.of(context).pop(img);
      }),
      GestureDetector(onTap: _capturing ? null : _capture,
        child: AnimatedContainer(duration: const Duration(milliseconds: 100),
          width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: _capturing ? Colors.grey : _yellow,
            border: Border.all(color: Colors.white, width: 4)),
          child: _capturing
              ? const Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.camera_alt, color: _dark, size: 32))),
      _iconBtn(icon: Icons.flip_camera_android,
          onTap: widget.cameras.length > 1 ? _switchCamera : null),
    ]));

  Widget _iconBtn({required IconData icon, VoidCallback? onTap}) {
    final e = onTap != null;
    return GestureDetector(onTap: onTap, child: Container(width: 50, height: 50,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: Colors.white.withOpacity(e ? 0.15 : 0.05),
        border: Border.all(color: Colors.white.withOpacity(e ? 0.3 : 0.08))),
      child: Icon(icon, color: Colors.white.withOpacity(e ? 1.0 : 0.25), size: 26)));
  }

  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.videocam_off, color: Colors.white54, size: 56),
      const SizedBox(height: 16),
      Text(_error ?? 'Camera unavailable', textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: () => _init(widget.cameras[_cameraIndex]),
        icon: const Icon(Icons.refresh), label: const Text('Retry')),
    ])));
}