import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/analysis_result.dart';
import '../screens/dictionary_screen.dart';
import '../services/network_service.dart';
import '../services/saved_cards_repository.dart';
import '../services/xp_service.dart';

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _flutterTts = FlutterTts();
  final SavedCardsRepository _cardsRepository = SavedCardsRepository.instance;
  late final String _apiEndpoint;
  late final NetworkService _networkService;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  CameraLensDirection _activeDirection = CameraLensDirection.back;
  FlashMode _flashMode = FlashMode.off;
  bool _initializingCamera = true;
  bool _isAnalyzing = false;
  bool _isSwitchingCamera = false;
  bool _dialogVisible = false;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  Uint8List? _latestCapturedBytes;
  String? _errorText;

  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _apiEndpoint = dotenv.isInitialized
        ? (dotenv.maybeGet('HF_ANALYZE_ENDPOINT')?.trim() ?? '')
        : '';
    _networkService = NetworkService(_apiEndpoint);
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scanAnimation = CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    );
    _initializeCamera();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _initializeCamera([
    CameraLensDirection direction = CameraLensDirection.back,
  ]) async {
    setState(() {
      _initializingCamera = true;
      _errorText = null;
    });
    try {
      _cameras = await availableCameras();
      final description = _selectCamera(direction);
      if (description == null) {
        setState(() {
          _errorText = 'Thiết bị không có camera phù hợp';
        });
        return;
      }

      final previous = _cameraController;
      _cameraController = null;
      await previous?.dispose();

      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {
        await controller.setFlashMode(FlashMode.off);
        _flashMode = FlashMode.off;
      }

      _cameraController = controller;
      _activeDirection = description.lensDirection;

      _minZoomLevel = await controller.getMinZoomLevel();
      _maxZoomLevel = await controller.getMaxZoomLevel();
      _currentZoomLevel = _currentZoomLevel.clamp(_minZoomLevel, _maxZoomLevel);
      await controller.setZoomLevel(_currentZoomLevel);
    } catch (e) {
      setState(() {
        _errorText = 'Không thể mở camera: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _initializingCamera = false;
        });
      }
    }
  }

  CameraDescription? _selectCamera(CameraLensDirection direction) {
    try {
      final exactMatch = _cameras.where(
        (cam) => cam.lensDirection == direction,
      );
      if (exactMatch.isNotEmpty) {
        return exactMatch.first;
      }

      final fallback = direction == CameraLensDirection.front
          ? _cameras.where(
              (cam) => cam.lensDirection == CameraLensDirection.back,
            )
          : _cameras.where(
              (cam) => cam.lensDirection == CameraLensDirection.front,
            );
      if (fallback.isNotEmpty) {
        return fallback.first;
      }

      return _cameras.isNotEmpty ? _cameras.first : null;
    } catch (_) {
      return _cameras.isNotEmpty ? _cameras.first : null;
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null) return;
    final nextMode = _flashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;
    try {
      await controller.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (e) {
      _showSnack('Không thể đổi flash: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_initializingCamera || _isSwitchingCamera || _isAnalyzing) {
      return;
    }
    if (_cameras.length < 2) {
      _showSnack('Thiết bị chỉ có một camera');
      return;
    }
    final targetDirection = _activeDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    setState(() {
      _isSwitchingCamera = true;
      _errorText = null;
    });

    try {
      final hasTargetCamera = _cameras.any(
        (cam) => cam.lensDirection == targetDirection,
      );
      if (!hasTargetCamera) {
        _showSnack('Thiết bị không có camera ${targetDirection.name}');
        return;
      }

      await _initializeCamera(targetDirection);
    } catch (e) {
      _showSnack('Không thể chuyển camera: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Future<void> _captureFromCamera() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isAnalyzing) {
      return;
    }
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      await _processImage(bytes);
    } catch (e) {
      _showSnack('Không thể chụp ảnh: $e');
    }
  }

  Future<void> _setZoomLevel(double zoom) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final clamped = zoom.clamp(_minZoomLevel, _maxZoomLevel);
    try {
      await controller.setZoomLevel(clamped);
      if (mounted) {
        setState(() {
          _currentZoomLevel = clamped;
        });
      }
    } catch (_) {
      // Ignore zoom updates when camera is transitioning.
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoomLevel = _currentZoomLevel;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_initializingCamera || _isSwitchingCamera || _isAnalyzing) {
      return;
    }
    final nextZoom = (_baseZoomLevel * details.scale).clamp(
      _minZoomLevel,
      _maxZoomLevel,
    );
    await _setZoomLevel(nextZoom);
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _processImage(bytes);
      }
    } catch (e) {
      _showSnack('Không thể mở thư viện: $e');
    }
  }

  Future<void> _processImage(Uint8List bytes) async {
    if (!mounted) return;
    if (_apiEndpoint.isEmpty) {
      _showSnack('Thieu HF_ANALYZE_ENDPOINT trong file .env');
      return;
    }
    setState(() {
      _latestCapturedBytes = bytes;
      _errorText = null;
    });
    _setAnalyzing(true);
    try {
      final result = await _networkService.uploadImage(bytes);
      if (!mounted) return;
      if (result.word.isEmpty) {
        throw Exception('AI chưa nhận diện được vật thể này');
      }
      await _showResultDialog(result);
    } catch (e) {
      await _showFailureDialog(e.toString());
    } finally {
      if (mounted) {
        _setAnalyzing(false);
      }
    }
  }

  void _setAnalyzing(bool status) {
    if (_isAnalyzing == status) return;
    setState(() {
      _isAnalyzing = status;
    });
    if (status) {
      _scanController.repeat();
    } else {
      _scanController.stop();
    }
  }

  Future<void> _showResultDialog(AnalysisResult result) async {
    if (!mounted || _dialogVisible) return;
    _dialogVisible = true;
    final alreadySaved = _cardsRepository.containsWord(result.normalizedWord);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isSaved = alreadySaved;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _ResultDialog(
              result: result,
              imageBytes: _latestCapturedBytes,
              isSaved: isSaved,
              onClose: () {
                Navigator.of(dialogContext).pop();
              },
              onSave: () async {
                final saved = await _handleSave(result);
                if (saved) {
                  setModalState(() => isSaved = true);
                  Navigator.of(dialogContext).pop();
                  _dialogVisible = false;
                  _navigateToDictionary();
                }
              },
              onSpeak: () => _speakWord(result.word),
            );
          },
        );
      },
    );
    _dialogVisible = false;
  }

  Future<void> _showFailureDialog(String message) async {
    if (!mounted || _dialogVisible) return;
    _dialogVisible = true;
    final readable = message.replaceFirst('Exception: ', '');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FailureDialog(
        message: readable,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
    _dialogVisible = false;
  }

  Future<bool> _handleSave(AnalysisResult result) async {
    try {
      final existingWord = await _cardsRepository.findExistingWord(
        result.normalizedWord,
      );

      if (existingWord != null) {
        if (!mounted) {
          return false;
        }
        final shouldReplace = await _showReplaceImageDialog(result.word);
        if (!shouldReplace) {
          return false;
        }

        await _cardsRepository.replaceExistingWord(
          existingWord: existingWord,
          result: result,
          imageBytes: _latestCapturedBytes,
        );

        if (!mounted) {
          return true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật ảnh mới cho "${result.word}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return true;
      }

      final savedCard = await _cardsRepository.saveResult(
        result,
        _latestCapturedBytes,
      );
      if (savedCard == null) {
        _showSnack('Thẻ đã có trong bộ sưu tập');
        return true;
      }

      await XPService.instance.addXP(50);

      if (!mounted) {
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu "${result.word}" vào Supabase. +50 XP!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } catch (error) {
      _showSnack('Lưu thẻ thất bại: $error');
      return false;
    }
  }

  Future<bool> _showReplaceImageDialog(String word) async {
    final shouldReplace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Từ đã có trong từ điển'),
          content: Text(
            'Từ "$word" đã có trong từ điển. Bạn có muốn thay hình ảnh đã có bằng hình ảnh bạn vừa chụp hoặc tải lên không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Không'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Thay ảnh'),
            ),
          ],
        );
      },
    );
    return shouldReplace ?? false;
  }

  void _navigateToDictionary() {
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DictionaryScreen()),
      );
    }
  }

  Future<void> _speakWord(String word) async {
    await _flutterTts.speak(word);
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildCameraPreview()),
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: _buildTopControls(),
                    ),
                    if (_errorText != null)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: _buildErrorBanner(),
                      ),
                  ],
                ),
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;
    if (_initializingCamera) {
      return _PreviewFrame(
        child: _PreviewPlaceholder(
          icon: Icons.camera_alt,
          message: 'Đang khởi tạo camera...',
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return _PreviewFrame(
        child: _PreviewPlaceholder(
          icon: Icons.videocam_off,
          message: 'Không thể hiển thị camera',
        ),
      );
    }
    final showCapturedPreview = _isAnalyzing && _latestCapturedBytes != null;
    return _PreviewFrame(
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: showCapturedPreview
                    ? Image.memory(
                        _latestCapturedBytes!,
                        key: const ValueKey('captured-preview'),
                        fit: BoxFit.cover,
                      )
                    : _buildLiveCameraPreview(controller),
              ),
              if (_isAnalyzing) _ScanningOverlay(animation: _scanAnimation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(
        key: const ValueKey('live-camera-preview'),
        controller,
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(
          key: const ValueKey('live-camera-preview'),
          controller,
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _GlassButton(
          icon: _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
          label: _flashMode == FlashMode.off ? 'Flash off' : 'Flash on',
          onPressed: _toggleFlash,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isAnalyzing
              ? Container(
                  key: const ValueKey('analyzing'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'AI đang phân tích...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
              : Container(
                  key: const ValueKey('hint'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Căn vật thể vào khung',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    final disableCapture = _initializingCamera || _isAnalyzing;
    final zoomDisabled =
        _initializingCamera ||
        _isSwitchingCamera ||
        _isAnalyzing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _maxZoomLevel <= _minZoomLevel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: _isAnalyzing ? 1 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: const Text(
              'Đang gửi ảnh cho AI trên Hugging Face...',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          if (!zoomDisabled) ...[
            Row(
              children: [
                const Icon(Icons.zoom_out, color: Colors.white70, size: 18),
                Expanded(
                  child: Slider(
                    value: _currentZoomLevel,
                    min: _minZoomLevel,
                    max: _maxZoomLevel,
                    onChanged: (value) {
                      _setZoomLevel(value);
                    },
                  ),
                ),
                const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ControlPill(
                icon: Icons.photo_library,
                label: 'Album',
                onTap: _pickImageFromGallery,
                trailing: _latestCapturedBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          _latestCapturedBytes!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ),
                      )
                    : null,
              ),
              _CaptureButton(
                disabled: disableCapture,
                onTap: _captureFromCamera,
              ),
              _ControlPill(
                icon: Icons.cameraswitch,
                label: 'Đổi cam',
                onTap: _cameras.length < 2 || _isSwitchingCamera
                    ? null
                    : _switchCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorText == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorText!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _errorText = null;
              });
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _cameraController?.dispose();
    _flutterTts.stop();
    super.dispose();
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 56),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onTap, required this.disabled});

  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70, width: 4),
        ),
        padding: const EdgeInsets.all(6),
        child: Container(
          decoration: BoxDecoration(
            color: disabled ? Colors.white24 : Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final alignmentY = animation.value * 2 - 1;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black26),
            Align(
              alignment: Alignment(0, alignmentY),
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF7DD9FF),
                      Colors.white,
                      Color(0xFF7DD9FF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white70,
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.result,
    required this.imageBytes,
    required this.isSaved,
    required this.onSave,
    required this.onClose,
    required this.onSpeak,
  });

  final AnalysisResult result;
  final Uint8List? imageBytes;
  final bool isSaved;
  final VoidCallback onClose;
  final VoidCallback onSpeak;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSaved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Đã lưu thẻ'),
                      ],
                    ),
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageBytes != null
                      ? Image.memory(
                          imageBytes!,
                          height: 180,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 180,
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image,
                            size: 64,
                            color: Colors.grey,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(result.topic),
                    backgroundColor: const Color(0xFFE3F2FD),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.word,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  result.phonetic,
                  style: const TextStyle(fontSize: 20, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Text(
                  result.vietnameseMeaning,
                  style: const TextStyle(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.forum, color: Colors.blueGrey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          result.exampleSentence,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onSave(),
                        child: Text(isSaved ? 'CẬP NHẬT ẢNH' : 'LƯU THẺ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: onSpeak,
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'Nghe phát âm',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureDialog extends StatelessWidget {
  const _FailureDialog({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Chưa nhận diện được',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onClose, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
