import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/validation/indian_mobile_normalizer.dart';
import '../../../l10n/app_localizations.dart';
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
    this.tenantId,
    this.initialSession,
    this.photoSource,
    this.cameraSource,
    this.now,
    super.key,
  });

  final ParkingSessionRepository repository;
  final String? tenantId;
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
  final _totalChargeController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _contactController = TextEditingController();
  final _calculator = const ParkingDurationCalculator();

  late final ParkingPhotoSource _photoSource =
      widget.photoSource ?? ImagePickerParkingPhotoSource();
  late final ParkingCameraSource _cameraSource =
      widget.cameraSource ?? const CameraPackageParkingCameraSource();
  late DateTime _entryDate;
  late TimeOfDay _entryTime;
  ParkingDurationUnit _durationUnit = ParkingDurationUnit.minutes;
  bool _isFullyPaid = false;
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
      _totalChargeController.text = _formatAmount(initialSession.totalCharge);
      _paidAmountController.text = _formatAmount(initialSession.paidAmount);
      _contactController.text = initialSession.contactNumber ?? '';
      _isFullyPaid =
          initialSession.totalCharge > 0 &&
          initialSession.paidAmount >= initialSession.totalCharge;
      return;
    }

    final initialNow = (widget.now ?? DateTime.now)().toLocal();
    _entryDate = DateTime(initialNow.year, initialNow.month, initialNow.day);
    _entryTime = TimeOfDay.fromDateTime(initialNow);
  }

  String _formatAmount(double amount) {
    return amount == 0 ? '' : amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _plateController.dispose();
    _durationController.dispose();
    _totalChargeController.dispose();
    _paidAmountController.dispose();
    _contactController.dispose();
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
          _photoError = AppLocalizations.of(context).cameraOpenError;
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
          _photoError = AppLocalizations.of(context).imageSelectError;
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

  String? _validatePlate(String? value, AppLocalizations l10n) {
    final plateNumber = value?.trim() ?? '';
    if (plateNumber.isEmpty) {
      return l10n.plateRequired;
    }

    if (plateNumber.length > 64) {
      return l10n.plateTooLong;
    }

    return null;
  }

  String? _validateContact(String? value, AppLocalizations l10n) {
    final contact = value?.trim() ?? '';
    if (contact.isEmpty) {
      return l10n.contactRequired;
    }

    if (IndianMobileNormalizer.tryNormalize(contact) == null) {
      return l10n.contactInvalid;
    }

    return null;
  }

  String? _validateDuration(String? value, AppLocalizations l10n) {
    final durationValue = value?.trim() ?? '';
    if (durationValue.isEmpty) {
      return l10n.durationRequired;
    }

    if (!RegExp(r'^\d+$').hasMatch(durationValue)) {
      return l10n.durationPositiveInteger;
    }

    final parsedValue = int.tryParse(durationValue);
    if (parsedValue == null || parsedValue <= 0) {
      return l10n.durationPositiveInteger;
    }

    final maximum = ParkingEntryLimits.maximumFor(_durationUnit);
    if (parsedValue > maximum) {
      return l10n.durationMaxExceeded(
        _durationUnit.lowercaseLabel(l10n),
        maximum,
      );
    }

    final calculation = _calculator.calculateExpiry(
      entryTime: _entryDateTime,
      duration: ParkingDuration(value: parsedValue, unit: _durationUnit),
    );
    if (calculation is DurationCalculationFailure) {
      return l10n.expiryCalculationError;
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

  double? get _enteredTotalCharge {
    final text = _totalChargeController.text.trim();
    if (text.isEmpty) {
      return 0;
    }
    return double.tryParse(text);
  }

  double? get _enteredPaidAmount {
    if (_isFullyPaid) {
      return _enteredTotalCharge;
    }
    final text = _paidAmountController.text.trim();
    if (text.isEmpty) {
      return 0;
    }
    return double.tryParse(text);
  }

  String? _validateTotalCharge(String? value, AppLocalizations l10n) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    final amount = double.tryParse(text);
    if (amount == null) {
      return l10n.amountInvalid;
    }
    if (amount < 0) {
      return l10n.chargeNegative;
    }
    return null;
  }

  String? _validatePaidAmount(String? value, AppLocalizations l10n) {
    if (_isFullyPaid) {
      return null;
    }
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    final amount = double.tryParse(text);
    if (amount == null) {
      return l10n.amountInvalid;
    }
    if (amount < 0) {
      return l10n.paidNegative;
    }
    final total = _enteredTotalCharge ?? 0;
    if (amount > total) {
      return l10n.paidExceedsTotal;
    }
    return null;
  }

  void _handleFullyPaidChanged(bool? value) {
    setState(() {
      _isFullyPaid = value ?? false;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
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
        _saveError = l10n.durationBeforeSaving;
      });
      return;
    }

    final totalCharge = _enteredTotalCharge;
    final paidAmount = _enteredPaidAmount;
    if (totalCharge == null || paidAmount == null) {
      setState(() {
        _saveError = l10n.chargeBeforeSaving;
      });
      return;
    }

    final session = ParkingSession(
      id: widget.initialSession?.id,
      tenantId: widget.initialSession?.tenantId ?? widget.tenantId,
      createdBy: widget.initialSession?.createdBy,
      plateNumber: ParkingPlateNormalizer.normalize(_plateController.text),
      photoPath: _existingPhotoPath,
      entryTime: _entryDateTime,
      allowedDuration: duration,
      expiresAt: calculation.expiresAt,
      totalCharge: totalCharge,
      paidAmount: paidAmount,
      contactNumber: IndianMobileNormalizer.tryNormalize(
        _contactController.text,
      ),
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
          _saveError = l10n.saveGenericError;
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
      _photoError = AppLocalizations.of(context).photoSelectionRequired;
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

    final l10n = AppLocalizations.of(context);
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
          _saveError = l10n.cleanupGenericError;
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
        _saveError = l10n.cleanupSuccessMessage;
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

    final l10n = AppLocalizations.of(context);
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
          _saveError = l10n.photoCleanupGenericError;
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
        _saveError = l10n.photoCleanupSuccessMessage;
      });
      return;
    }

    final cleanupFailure = result as ParkingPhotoCleanupFailure;
    setState(() {
      _isCleaningUp = false;
      _saveError = cleanupFailure.message;
    });
  }

  String _formatDateTime(DateTime value, AppLocalizations l10n) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(value);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return l10n.dateTimeAtTemplate(date, time);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.entryPageEditTitle : l10n.entryPageNewTitle,
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
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
                      _buildIntro(context, l10n),
                      const SizedBox(height: 16),
                      _buildDetailsCard(context, l10n),
                      const SizedBox(height: 16),
                      _buildChargeCard(context, l10n),
                      const SizedBox(height: 16),
                      _buildPhotoCard(context, l10n),
                      const SizedBox(height: 16),
                      _buildSaveError(context, l10n),
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
                              ? (_isEditing
                                    ? l10n.updatingButton
                                    : l10n.savingButton)
                              : (_isEditing
                                    ? l10n.updateEntryButton
                                    : l10n.saveEntryButton),
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

  Widget _buildIntro(BuildContext context, AppLocalizations l10n) {
    return Text(
      _isEditing ? l10n.introEditing : l10n.introCreating,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }

  Widget _buildDetailsCard(BuildContext context, AppLocalizations l10n) {
    final calculation = _expiryCalculation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.parkingDetailsTitle,
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
              decoration: InputDecoration(
                labelText: l10n.vehicleRegistrationLabel,
                hintText: l10n.vehicleRegistrationHint,
              ),
              validator: (value) => _validatePlate(value, l10n),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^[0-9+ ]*$')),
              ],
              decoration: InputDecoration(
                labelText: l10n.detailContactNumber,
                hintText: l10n.contactNumberHint,
              ),
              validator: (value) => _validateContact(value, l10n),
            ),
            const SizedBox(height: 16),
            _buildDateTimeButtons(context, l10n),
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
                    decoration: InputDecoration(
                      labelText: l10n.detailAllowedDuration,
                    ),
                    validator: (value) => _validateDuration(value, l10n),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ParkingDurationUnit>(
                    initialValue: _durationUnit,
                    decoration: InputDecoration(labelText: l10n.unitLabel),
                    items: [
                      for (final unit in ParkingDurationUnit.values)
                        DropdownMenuItem(
                          value: unit,
                          child: Text(unit.capitalizedLabel(l10n)),
                        ),
                    ],
                    onChanged: _isSaving ? null : _handleDurationUnitChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildExpiryPreview(context, l10n, calculation),
          ],
        ),
      ),
    );
  }

  Widget _buildChargeCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.parkingChargeTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _totalChargeController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: l10n.totalChargeLabel,
                hintText: l10n.totalChargeHint,
                prefixText: '₹ ',
              ),
              validator: (value) => _validateTotalCharge(value, l10n),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _isFullyPaid,
              onChanged: _isSaving ? null : _handleFullyPaidChanged,
              title: Text(l10n.fullyPaidLabel),
              subtitle: Text(l10n.fullyPaidSubtitle),
            ),
            if (!_isFullyPaid) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _paidAmountController,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.detailAmountPaid,
                  hintText: l10n.amountPaidHint,
                  prefixText: '₹ ',
                ),
                validator: (value) => _validatePaidAmount(value, l10n),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeButtons(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.entryDateTimeLabel,
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
    AppLocalizations l10n,
    DurationCalculationResult? calculation,
  ) {
    if (calculation is DurationCalculationSuccess) {
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: Text(l10n.calculatedExpiryTitle),
          subtitle: Text(_formatDateTime(calculation.expiresAt, l10n)),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(l10n.expiryPreviewTitle),
        subtitle: Text(l10n.expiryPreviewMessage),
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context, AppLocalizations l10n) {
    final photo = _selectedPhoto;
    final hasExistingPhoto = _existingPhotoPath != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.vehiclePhotoTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.vehiclePhotoInstructions),
            const SizedBox(height: 16),
            if (photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  photo.bytes,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => SizedBox(
                    height: 220,
                    child: ErrorStateView(message: l10n.imagePreviewError),
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
                child: ListTile(
                  leading: const Icon(Icons.photo_outlined),
                  title: Text(l10n.existingPhotoKeptTitle),
                  subtitle: Text(l10n.existingPhotoKeptSubtitle),
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
                        ? l10n.replaceWithCamera
                        : photo == null
                        ? l10n.takePhoto
                        : l10n.retakePhoto,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isPickingPhoto || _isSaving
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    photo == null ? l10n.chooseFile : l10n.replacePhoto,
                  ),
                ),
                if (photo != null)
                  TextButton.icon(
                    onPressed: _isSaving ? null : _removePhoto,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      _isEditing && hasExistingPhoto
                          ? l10n.discardReplacement
                          : l10n.removeButton,
                    ),
                  ),
              ],
            ),
            if (!hasExistingPhoto)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _continueWithoutPhoto,
                onChanged: _isSaving ? null : _setContinueWithoutPhoto,
                title: Text(l10n.continueWithoutPhoto),
                subtitle: Text(l10n.continueWithoutPhotoSubtitle),
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

  Widget _buildSaveError(BuildContext context, AppLocalizations l10n) {
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
                  _isCleaningUp
                      ? l10n.retryingCleanup
                      : l10n.retryCleanupButton,
                ),
              ),
            ],
            if (canRetryPhotoCleanup) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isCleaningUp ? null : _retryPhotoCleanup,
                child: Text(
                  _isCleaningUp
                      ? l10n.retryingPhotoCleanup
                      : l10n.retryPhotoCleanupButton,
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
  String capitalizedLabel(AppLocalizations l10n) {
    return switch (this) {
      ParkingDurationUnit.minutes => l10n.durationUnitMinutesCap,
      ParkingDurationUnit.hours => l10n.durationUnitHoursCap,
      ParkingDurationUnit.days => l10n.durationUnitDaysCap,
      ParkingDurationUnit.months => l10n.durationUnitMonthsCap,
    };
  }

  String lowercaseLabel(AppLocalizations l10n) {
    return switch (this) {
      ParkingDurationUnit.minutes => l10n.durationUnitMinutes,
      ParkingDurationUnit.hours => l10n.durationUnitHours,
      ParkingDurationUnit.days => l10n.durationUnitDays,
      ParkingDurationUnit.months => l10n.durationUnitMonths,
    };
  }
}
