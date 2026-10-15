import 'dart:async';

import 'package:flutter/material.dart';

import '../data/parking_camera_source.dart';
import '../data/parking_photo.dart';
import '../data/parking_photo_codec.dart';

class ParkingCaptureDialog extends StatefulWidget {
  const ParkingCaptureDialog({
    required this.cameraSource,
    this.cameraOperationTimeout = const Duration(seconds: 20),
    super.key,
  });

  final ParkingCameraSource cameraSource;
  final Duration cameraOperationTimeout;

  @override
  State<ParkingCaptureDialog> createState() => _ParkingCaptureDialogState();
}

class _ParkingCaptureDialogState extends State<ParkingCaptureDialog> {
  static const _cameraCleanupTimeout = Duration(seconds: 5);

  ParkingCameraSession? _cameraSession;
  ParkingPhoto? _capturedPhoto;
  String? _errorMessage;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isSwitching = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    _isDisposed = true;
    final session = _cameraSession;
    _cameraSession = null;
    if (session != null) {
      unawaited(_disposeSession(session));
    }
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    Future<ParkingCameraSession>? openFuture;
    try {
      openFuture = widget.cameraSource.open();
      final session = await openFuture.timeout(widget.cameraOperationTimeout);
      if (!mounted || _isDisposed) {
        unawaited(_disposeSession(session));
        return;
      }

      setState(() {
        _cameraSession = session;
        _isInitializing = false;
      });
    } on TimeoutException {
      final pendingOpen = openFuture;
      if (pendingOpen != null) {
        unawaited(_disposeLateSession(pendingOpen));
      }
      _setError(
        'The camera took too long to initialize. Check permissions and try again.',
      );
    } on ParkingCameraException catch (error) {
      _setError(error.message);
    } on Exception {
      _setError(
        'The camera could not be initialized. Check browser permissions and try again.',
      );
    }
  }

  Future<void> _capturePhoto() async {
    final session = _cameraSession;
    if (session == null ||
        _isCapturing ||
        _isSwitching ||
        _capturedPhoto != null) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final photo = await session.capture().timeout(
        widget.cameraOperationTimeout,
      );
      if (!mounted) {
        return;
      }

      _detachCameraSession(session);
      await _disposeSession(session);
      if (!mounted) {
        return;
      }

      setState(() {
        _capturedPhoto = photo;
      });
    } on TimeoutException {
      await _handleSessionFailure(
        session,
        'The camera capture took too long. Try again or choose a file instead.',
      );
    } on ParkingPhotoException catch (error) {
      await _handleSessionFailure(session, error.message);
    } on ParkingCameraException catch (error) {
      await _handleSessionFailure(session, error.message);
    } on Exception {
      await _handleSessionFailure(
        session,
        'The photo could not be captured. Try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _retakePhoto() {
    if (_isInitializing || _isCapturing || _isSwitching) {
      return;
    }

    setState(() {
      _capturedPhoto = null;
      _errorMessage = null;
      _isInitializing = true;
    });
    unawaited(_initializeCamera());
  }

  void _retryCamera() {
    if (_isInitializing || _isCapturing || _isSwitching) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _isInitializing = true;
    });
    unawaited(_initializeCamera());
  }

  Future<void> _switchCamera() async {
    final cameraSession = _cameraSession;
    if (cameraSession == null) {
      return;
    }
    if (cameraSession is! ParkingCameraSwitchingSession) {
      return;
    }
    if (_isCapturing || _isSwitching || _capturedPhoto != null) {
      return;
    }

    final switchingSession = cameraSession as ParkingCameraSwitchingSession;
    if (!switchingSession.canSwitchCamera) {
      return;
    }

    setState(() {
      _isSwitching = true;
      _errorMessage = null;
    });

    try {
      await switchingSession.switchCamera().timeout(
        widget.cameraOperationTimeout,
      );
    } on TimeoutException {
      await _handleSessionFailure(
        cameraSession,
        'Switching cameras took too long. Try again or choose a file instead.',
      );
    } on ParkingCameraException catch (error) {
      await _handleSessionFailure(cameraSession, error.message);
    } on Exception {
      await _handleSessionFailure(
        cameraSession,
        'The selected camera could not be opened. Try another camera or choose a file instead.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSwitching = false;
        });
      }
    }
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = false;
      _isCapturing = false;
      _isSwitching = false;
      _errorMessage = message;
    });
  }

  Future<void> _handleSessionFailure(
    ParkingCameraSession session,
    String message,
  ) async {
    _detachCameraSession(session);
    await _disposeSession(session);
    _setError(message);
  }

  void _detachCameraSession(ParkingCameraSession session) {
    if (identical(_cameraSession, session)) {
      _cameraSession = null;
    }
  }

  Future<void> _disposeLateSession(
    Future<ParkingCameraSession> openFuture,
  ) async {
    try {
      final session = await openFuture;
      await _disposeSession(session);
    } on Object catch (error, stackTrace) {
      _reportCameraError(
        error,
        stackTrace,
        'while resolving a timed-out camera initialization',
      );
    }
  }

  void _usePhoto() {
    final photo = _capturedPhoto;
    if (photo != null) {
      Navigator.of(context).pop(photo);
    }
  }

  Future<void> _disposeSession(ParkingCameraSession session) async {
    try {
      await session.dispose().timeout(_cameraCleanupTimeout);
    } on Object catch (error, stackTrace) {
      _reportCameraError(
        error,
        stackTrace,
        'while releasing the camera session',
      );
    }
  }

  void _reportCameraError(Object error, StackTrace stackTrace, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'parking camera',
        context: ErrorDescription(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Take vehicle photo'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 64)
            .clamp(240.0, 520.0)
            .toDouble(),
        child: _buildContent(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_errorMessage != null)
          OutlinedButton(
            onPressed: _isInitializing || _isCapturing || _isSwitching
                ? null
                : _retryCamera,
            child: const Text('Retry'),
          ),
        if (_capturedPhoto == null &&
            _cameraSession is ParkingCameraSwitchingSession &&
            (_cameraSession! as ParkingCameraSwitchingSession)
                .canSwitchCamera &&
            _errorMessage == null)
          OutlinedButton.icon(
            onPressed: _isCapturing || _isSwitching
                ? null
                : () => unawaited(_switchCamera()),
            icon: _isSwitching
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cameraswitch_outlined),
            label: Text(_isSwitching ? 'Switching...' : 'Switch camera'),
          ),
        if (_capturedPhoto == null &&
            _cameraSession != null &&
            _errorMessage == null)
          FilledButton.icon(
            onPressed: _isCapturing ? null : _capturePhoto,
            icon: _isCapturing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt_outlined),
            label: Text(_isCapturing ? 'Capturing...' : 'Capture'),
          ),
        if (_capturedPhoto != null) ...[
          OutlinedButton(onPressed: _retakePhoto, child: const Text('Retake')),
          FilledButton(onPressed: _usePhoto, child: const Text('Use Photo')),
        ],
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isInitializing) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return SizedBox(
        height: 220,
        child: Center(child: Text(errorMessage, textAlign: TextAlign.center)),
      );
    }

    final photo = _capturedPhoto;
    if (photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(photo.bytes, height: 320, fit: BoxFit.contain),
      );
    }

    final session = _cameraSession;
    if (session == null) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text('The camera is unavailable. Choose an existing photo.'),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(aspectRatio: 4 / 3, child: session.preview),
    );
  }
}
