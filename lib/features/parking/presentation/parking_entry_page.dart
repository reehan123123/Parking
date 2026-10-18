import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/error_state_view.dart';
import '../data/parking_camera_source.dart';
import '../data/parking_photo.dart';
import '../data/parking_photo_codec.dart';
import '../data/parking_plate_normalizer.dart';
import '../data/parking_photo_source.dart';
import '../data/parking_session_repository.dart';
import '../domain/duration_calculation_result.dart';
import '../domain/parking_duration.dart';
import '../domain/parking_duration_calculator.dart';
import '../domain/parking_duration_unit.dart';
import '../domain/parking_session.dart';
import 'parking_capture_dialog.dart';
import 'parking_entry_limits.dart';

class ParkingEntryPage extends StatefulWidget {
  const ParkingEntryPage({
    required this.repository,
    this.initialSession,
    this.photoSource,
    this.cameraSource,
    this.now,
    super.key,
  });

  final ParkingSessionRepository repository;
  final ParkingSession? initialSession;
  final ParkingPhotoSource? photoSource;
  final ParkingCameraSource? cameraSource;
  final DateTime Function()? now;

  @override
  State<ParkingEntryPage> createState() => _ParkingEntryPageState();
}

class _ParkingEntryPageState extends State<ParkingEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _durationController = TextEditingController();
  final _calculator = const ParkingDurationCalculator();

  late final ParkingPhotoSource _photoSource =
      widget.photoSource ?? ImagePickerParkingPhotoSource();
  late final ParkingCameraSource _cameraSource =
      widget.cameraSource ?? const CameraPackageParkingCameraSource();
  late DateTime _entryDate;
  late TimeOfDay _entryTime;
  ParkingDurationUnit _durationUnit = ParkingDurationUnit.minutes;
  ParkingPhoto? _selectedPhoto;
  String? _existingPhotoPath;
  ParkingSessionSaveFailure? _saveFailure;
  ParkingSessionUpdateFailure? _updateFailure;
  String? _photoError;
  String? _saveError;
  bool _continueWithoutPhoto = false;
  bool _isPickingPhoto = false;
  bool _isSaving = false;
  bool _isCleaningUp = false;

  bool get _isEditing => widget.initialSession != null;

  @override
  void initState() {
    super.initState();
    final initialSession = widget.initialSession;
    if (initialSession != null) {
      final entryTime = initialSession.entryTime.toLocal();
      _entryDate = DateTime(entryTime.year, entryTime.month, entryTime.day);
      _entryTime = TimeOfDay.fromDateTime(entryTime);
      _durationUnit = initialSession.allowedDuration.unit;
      _plateController.text = initialSession.plateNumber;
      _durationController.text = initialSession.allowedDuration.value
          .toString();
      _existingPhotoPath = initialSession.photoPath;
      _continueWithoutPhoto = initialSession.photoPath == null;
      return;
    }

    final initialNow = (widget.now ?? DateTime.now)().toLocal();
    _entryDate = DateTime(initialNow.year, initialNow.month, initialNow.day);
    _entryTime = TimeOfDay.fromDateTime(initialNow);
  }

  @override
  void dispose() {
    _plateController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  DateTime get _entryDateTime {
    return DateTime(
      _entryDate.year,
      _entryDate.month,
      _entryDate.day,
      _entryTime.hour,
      _entryTime.minute,
    );
  }

  ParkingDuration? get _enteredDuration {
    final value = int.tryParse(_durationController.text.trim());
    if (value == null) {
      return null;
    }

    return ParkingDuration(value: value, unit: _durationUnit);
  }

  DurationCalculationResult? get _expiryCalculation {
    final duration = _enteredDuration;
    if (duration == null) {
      return null;
    }

    return _calculator.calculateExpiry(
      entryTime: _entryDateTime,
      duration: duration,
    );
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || selectedDate == null) {
      return;
    }

    setState(() {
      _entryDate = selectedDate;
    });
  }

  Future<void> _selectTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _entryTime,
    );
    if (!mounted || selectedTime == null) {
      return;
    }

    setState(() {
      _entryTime = selectedTime;
    });
  }

  Future<void> _takePhoto() async {
    if (_isPickingPhoto || _isSaving) {
      return;
    }

    setState(() {
      _isPickingPhoto = true;
      _photoError = null;
      _saveError = null;
    });

    try {
      final photo = await showDialog<ParkingPhoto?>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ParkingCaptureDialog(cameraSource: _cameraSource),
      );
      if (!mounted) {
        return;
      }

      if (photo != null) {
        _setSelectedPhoto(photo);
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _photoError =
              'The camera could not be opened. Choose a file instead.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingPhoto = false;
        });
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isPickingPhoto || _isSaving) {
      return;
    }

    setState(() {
      _isPickingPhoto = true;
      _photoError = null;
      _saveError = null;
    });

    try {
      final photo = await _photoSource.pick(source: source);
      if (!mounted) {
        return;
      }

      if (photo != null) {
        _setSelectedPhoto(photo);
      }
    } on ParkingPhotoException catch (error) {
      if (mounted) {
        setState(() {
          _photoError = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _photoError = 'The image could not be selected. Try again or choose a file instead.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingPhoto = false;
        });
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedPhoto = null;
      _photoError = null;
      if (_existingPhotoPath == null) {
        _continueWithoutPhoto = false;
      }
    });
  }

  void _setContinueWithoutPhoto(bool? value) {
    final continueWithoutPhoto = value ?? false;
    setState(() {
      _continueWithoutPhoto = continueWithoutPhoto;
      if (continueWithoutPhoto) {
        _selectedPhoto = null;
        _photoError = null;
      }
    });
  }

  void _setSelectedPhoto(ParkingPhoto photo) {
    setState(() {
      _selectedPhoto = photo;
      _continueWithoutPhoto = false;
    });
  }

  String? _validatePlate(String? value) {
    final plateNumber = value?.trim() ?? '';
    if (plateNumber.isEmpty) {
      return 'Enter a vehicle registration number.';
    }

    if (plateNumber.length > 64) {
      return 'Use 64 characters or fewer.';
    }

    return null;
  }

  String? _validateDuration(String? value) {
    final durationValue = value?.trim() ?? '';
    if (durationValue.isEmpty) {
      return 'Enter a parking duration.';
    }

    if (!RegExp(r'^\d+$').hasMatch(durationValue)) {
      return 'Enter a positive whole number.';
    }

    final parsedValue = int.tryParse(durationValue);
    if (parsedValue == null || parsedValue <= 0) {
      return 'Enter a positive whole number.';
    }

    final maximum = ParkingEntryLimits.maximumFor(_durationUnit);
    if (parsedValue > maximum) {
      return 'The maximum for ${_durationUnit.label} is $maximum.';
    }

    final calculation = _calculator.calculateExpiry(
      entryTime: _entryDateTime,
      duration: ParkingDuration(value: parsedValue, unit: _durationUnit),
    );
    if (calculation is DurationCalculationFailure) {
      return 'The expiry time could not be calculated.';
    }

    return null;
  }

  void _handleDurationUnitChanged(ParkingDurationUnit? unit) {
    if (unit == null) {
      return;
    }

    setState(() {
      _durationUnit = unit;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _validatePhotoSelection();
      return;
    }

    if (!_validatePhotoSelection()) {
      return;
    }

    final calculation = _expiryCalculation;
    final duration = _enteredDuration;
    if (calculation is! DurationCalculationSuccess || duration == null) {
      setState(() {
        _saveError = 'Enter a valid duration before saving.';
      });
      return;
    }

    final session = ParkingSession(
      id: widget.initialSession?.id,
      plateNumber: ParkingPlateNormalizer.normalize(_plateController.text),
      photoPath: _existingPhotoPath,
      entryTime: _entryDateTime,
      allowedDuration: duration,
      expiresAt: calculation.expiresAt,
    );

    setState(() {
      _isSaving = true;
      _saveError = null;
      _saveFailure = null;
      _updateFailure = null;
    });

    late final Object result;
    try {
      if (_isEditing) {
        result = await widget.repository.update(
          session: session,
          replacementPhoto: _selectedPhoto,
        );
      } else {
        result = await widget.repository.save(
          session: session,
          photo: _selectedPhoto,
        );
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'The parking entry could not be saved. Check your connection and try again.';
        });
      }
      return;
    }
    if (!mounted) {
      return;
    }

    if (result is ParkingSessionSaveSuccess) {
      Navigator.of(context).pop(result.session);
      return;
    }

    if (result is ParkingSessionUpdateSuccess) {
      Navigator.of(context).pop(result.session);
      return;
    }

    if (result is ParkingSessionSaveFailure) {
      final failure = result;
      setState(() {
        _isSaving = false;
        _saveFailure = failure;
        _saveError = failure.message;
      });
      return;
    }

    final failure = result as ParkingSessionUpdateFailure;
    setState(() {
      _isSaving = false;
      _updateFailure = failure;
      _saveError = failure.message;
    });
  }

  bool _validatePhotoSelection() {
    if (_selectedPhoto != null || _continueWithoutPhoto) {
      setState(() {
        _photoError = null;
      });
      return true;
    }

    if (_existingPhotoPath != null) {
      setState(() {
        _photoError = null;
      });
      return true;
    }

    setState(() {
      _photoError =
          'Select a vehicle photo or explicitly choose Continue without photo.';
    });
    return false;
  }

  Future<void> _retryCleanup() async {
    final failure = _saveFailure;
    if (failure == null ||
        !failure.cleanupRequired ||
        failure.sessionId == null ||
        failure.photoPath == null ||
        _isCleaningUp) {
      return;
    }

    setState(() {
      _isCleaningUp = true;
      _saveError = null;
    });

    late final ParkingSessionCleanupResult result;
    try {
      result = await widget.repository.retryCleanup(
        sessionId: failure.sessionId!,
        photoPath: failure.photoPath!,
      );
    } on Exception {
      if (mounted) {
        setState(() {
          _isCleaningUp = false;
          _saveError =
              'Cleanup could not complete. Check your connection and retry.';
        });
      }
      return;
    }
    if (!mounted) {
      return;
    }

    if (result is ParkingSessionCleanupSuccess) {
      setState(() {
        _isCleaningUp = false;
        _saveFailure = null;
        _saveError = 'Cleanup completed. The incomplete session was removed. You can try again.';
      });
      return;
    }

    final cleanupFailure = result as ParkingSessionCleanupFailure;
    setState(() {
      _isCleaningUp = false;
      _saveError = cleanupFailure.message;
    });
  }

  Future<void> _retryPhotoCleanup() async {
    final failure = _updateFailure;
    if (failure == null ||
        !failure.cleanupRequired ||
        failure.photoPath == null ||
        _isCleaningUp) {
      return;
    }

    setState(() {
      _isCleaningUp = true;
      _saveError = null;
    });

    late final ParkingPhotoCleanupResult result;
    try {
      result = await widget.repository.retryPhotoCleanup(
        photoPath: failure.photoPath!,
      );
    } on Exception {
      if (mounted) {
        setState(() {
          _isCleaningUp = false;
          _saveError = 'Photo cleanup could not complete. Check your connection and retry.';
        });
      }
      return;
    }
    if (!mounted) {
      return;
    }

    if (result is ParkingPhotoCleanupSuccess) {
      setState(() {
        _isCleaningUp = false;
        _updateFailure = null;
        _saveError =
            'Photo cleanup completed. Review the changes and try saving again.';
      });
      return;
    }

    final cleanupFailure = result as ParkingPhotoCleanupFailure;
    setState(() {
      _isCleaningUp = false;
      _saveError = cleanupFailure.message;
    });
  }

  String _formatDateTime(DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(value);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date at $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Parking Entry' : 'New Parking Entry'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildIntro(context),
                      const SizedBox(height: 16),
                      _buildDetailsCard(context),
                      const SizedBox(height: 16),
                      _buildPhotoCard(context),
                      const SizedBox(height: 16),
                      _buildSaveError(context),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isSaving
                              ? (_isEditing ? 'Updating...' : 'Saving...')
                              : (_isEditing
                                    ? 'Update parking entry'
                                    : 'Save parking entry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Text(
      _isEditing
          ? 'Update the vehicle details and confirm the expiry time before saving.'
          : 'Enter the vehicle details and confirm the expiry time before saving.',
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    final calculation = _expiryCalculation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Parking details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _plateController,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.singleLineFormatter,
              ],
              decoration: const InputDecoration(
                labelText: 'Vehicle registration',
                hintText: 'For example, ABC 123',
              ),
              validator: _validatePlate,
            ),
            const SizedBox(height: 16),
            _buildDateTimeButtons(context),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Allowed duration',
                    ),
                    validator: _validateDuration,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ParkingDurationUnit>(
                    initialValue: _durationUnit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [
                      for (final unit in ParkingDurationUnit.values)
                        DropdownMenuItem(value: unit, child: Text(unit.label)),
                    ],
                    onChanged: _isSaving ? null : _handleDurationUnitChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildExpiryPreview(context, calculation),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Entry date and time',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _selectDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                MaterialLocalizations.of(context).formatMediumDate(_entryDate),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _selectTime,
              icon: const Icon(Icons.schedule_outlined),
              label: Text(
                MaterialLocalizations.of(context).formatTimeOfDay(
                  _entryTime,
                  alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                    context,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpiryPreview(
    BuildContext context,
    DurationCalculationResult? calculation,
  ) {
    if (calculation is DurationCalculationSuccess) {
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('Calculated expiry'),
          subtitle: Text(_formatDateTime(calculation.expiresAt)),
        ),
      );
    }

    return const Card(
      child: ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Expiry preview'),
        subtitle: Text('Enter a valid duration to calculate the expiry.'),
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context) {
    final photo = _selectedPhoto;
    final hasExistingPhoto = _existingPhotoPath != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vehicle photo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Use the camera when supported, or choose an existing JPEG, PNG, or WebP image.',
            ),
            const SizedBox(height: 16),
            if (photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  photo.bytes,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 220,
                    child: ErrorStateView(
                      message: 'This image cannot be previewed in the browser.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${photo.fileName} (${_formatBytes(photo.sizeInBytes)})',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            if (photo == null && hasExistingPhoto) ...[
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const ListTile(
                  leading: Icon(Icons.photo_outlined),
                  title: Text('Existing private photo will be kept'),
                  subtitle: Text(
                    'Choose a new photo only if you want to replace it.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isPickingPhoto || _isSaving ? null : _takePhoto,
                  icon: _isPickingPhoto
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    photo == null && hasExistingPhoto
                        ? 'Replace with camera'
                        : photo == null
                        ? 'Take photo'
                        : 'Retake photo',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isPickingPhoto || _isSaving
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(photo == null ? 'Choose file' : 'Replace photo'),
                ),
                if (photo != null)
                  TextButton.icon(
                    onPressed: _isSaving ? null : _removePhoto,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      _isEditing && hasExistingPhoto
                          ? 'Discard replacement'
                          : 'Remove',
                    ),
                  ),
              ],
            ),
            if (!hasExistingPhoto)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _continueWithoutPhoto,
                onChanged: _isSaving ? null : _setContinueWithoutPhoto,
                title: const Text('Continue without photo'),
                subtitle: const Text(
                  'Choose this explicitly if no photo is available.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            if (_photoError != null) ...[
              const SizedBox(height: 8),
              Text(
                _photoError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveError(BuildContext context) {
    final saveError = _saveError;
    if (saveError == null) {
      return const SizedBox.shrink();
    }

    final canRetryCleanup =
        _saveFailure?.cleanupRequired == true &&
        _saveFailure?.sessionId != null &&
        _saveFailure?.photoPath != null;
    final canRetryPhotoCleanup =
        _updateFailure?.cleanupRequired == true &&
        _updateFailure?.photoPath != null;
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorStateView(message: saveError),
            if (canRetryCleanup) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isCleaningUp ? null : _retryCleanup,
                child: Text(
                  _isCleaningUp ? 'Retrying cleanup...' : 'Retry cleanup',
                ),
              ),
            ],
            if (canRetryPhotoCleanup) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isCleaningUp ? null : _retryPhotoCleanup,
                child: Text(
                  _isCleaningUp
                      ? 'Retrying photo cleanup...'
                      : 'Retry photo cleanup',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

extension on ParkingDurationUnit {
  String get label {
    return switch (this) {
      ParkingDurationUnit.minutes => 'Minutes',
      ParkingDurationUnit.hours => 'Hours',
      ParkingDurationUnit.days => 'Days',
      ParkingDurationUnit.months => 'Months',
    };
  }
}
