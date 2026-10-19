import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../data/parking_session_repository.dart';
import '../domain/parking_duration_unit.dart';
import '../domain/parking_session.dart';
import 'parking_entry_page.dart';
import 'parking_session_list_view.dart';

class ParkingSessionDetailsPage extends StatefulWidget {
  const ParkingSessionDetailsPage({
    required this.repository,
    required this.session,
    this.onDataChanged,
    super.key,
  });

  final ParkingSessionRepository repository;
  final ParkingSession session;
  final VoidCallback? onDataChanged;

  @override
  State<ParkingSessionDetailsPage> createState() =>
      _ParkingSessionDetailsPageState();
}

class _ParkingSessionDetailsPageState extends State<ParkingSessionDetailsPage>
    with WidgetsBindingObserver {
  late ParkingSession _session = widget.session;
  String? _photoUrl;
  String? _errorMessage;
  String? _mutationError;
  String? _deleteError;
  bool _isLoading = true;
  bool _isDeleting = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isDeleting) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final sessionId = _session.id;
    if (sessionId == null || sessionId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = AppLocalizations.of(context).sessionNoIdError;
      });
      return;
    }

    final requestVersion = ++_requestVersion;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _mutationError = null;
      _deleteError = null;
    });

    final detailResult = await widget.repository.getById(sessionId: sessionId);
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }

    if (detailResult is ParkingSessionDetailFailure) {
      setState(() {
        _isLoading = false;
        _errorMessage = detailResult.message;
      });
      return;
    }

    final session = (detailResult as ParkingSessionDetailSuccess).session;
    String? photoUrl;
    final photoPath = session.photoPath;
    if (photoPath != null) {
      final photoResult = await widget.repository.createSignedPhotoUrl(
        sessionId: session.id!,
        photoPath: photoPath,
      );
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }
      if (photoResult is ParkingSessionPhotoUrlSuccess) {
        photoUrl = photoResult.url;
      } else {
        _mutationError = (photoResult as ParkingSessionPhotoUrlFailure).message;
      }
    }

    setState(() {
      _isLoading = false;
      _session = session;
      _photoUrl = photoUrl;
      if (_mutationError == null) {
        _errorMessage = null;
      }
    });
  }

  Future<void> _edit() async {
    final updatedSession = await Navigator.of(context).push<ParkingSession>(
      MaterialPageRoute(
        builder: (context) => ParkingEntryPage(
          repository: widget.repository,
          initialSession: _session,
        ),
      ),
    );
    if (!mounted || updatedSession == null) {
      return;
    }

    widget.onDataChanged?.call();
    await _load();
  }

  Future<void> _confirmDelete() async {
    if (_isDeleting) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSessionDialogTitle),
        content: Text(l10n.deleteSessionDialogMessage(_session.plateNumber)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
      _mutationError = null;
    });

    final result = await widget.repository.delete(session: _session);
    if (!mounted) {
      return;
    }

    if (result is ParkingSessionDeleteSuccess) {
      widget.onDataChanged?.call();
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isDeleting = false;
      _deleteError = (result as ParkingSessionDeleteFailure).message;
      _mutationError = _deleteError;
    });
  }

  Future<void> _retryDelete() async {
    await _confirmDelete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionDetailsTitle),
        actions: [
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _edit,
            tooltip: l10n.editSessionTooltip,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _confirmDelete,
            tooltip: l10n.deleteSessionTooltip,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildBody(context, l10n),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_isLoading) {
      return const SizedBox(height: 320, child: LoadingView());
    }

    if (_errorMessage != null) {
      return ErrorStateView(message: _errorMessage!, onRetry: _load);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mutationError != null) ...[
          ErrorStateView(
            message: _mutationError!,
            onRetry: _deleteError == null ? _load : _retryDelete,
          ),
          const SizedBox(height: 16),
        ],
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildDetailsCard(context, l10n),
        const SizedBox(height: 16),
        _buildPhotoCard(context, l10n),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _session.plateNumber,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ParkingSessionStatusChip(session: _session),
            if (_session.totalCharge > 0) ...[
              const SizedBox(height: 6),
              ParkingPaymentStatusChip(session: _session),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _DetailRow(
              label: l10n.detailEntryTime,
              value: ParkingSessionFormatters.dateTime(
                context,
                _session.entryTime,
              ),
            ),
            const Divider(height: 24),
            _DetailRow(
              label: l10n.detailContactNumber,
              value: _session.contactNumber ?? l10n.detailNotProvided,
            ),
            const Divider(height: 24),
            _DetailRow(
              label: l10n.detailAllowedDuration,
              value:
                  '${_session.allowedDuration.value} '
                  '${_durationUnitLabel(_session.allowedDuration.unit, l10n)}',
            ),
            const Divider(height: 24),
            _DetailRow(
              label: l10n.detailExpiry,
              value: ParkingSessionFormatters.dateTime(
                context,
                _session.expiresAt,
              ),
            ),
            if (_session.totalCharge > 0) ...[
              const Divider(height: 24),
              _DetailRow(
                label: l10n.detailTotalCharge,
                value: ParkingSessionFormatters.currency(_session.totalCharge),
              ),
              const Divider(height: 24),
              _DetailRow(
                label: l10n.detailAmountPaid,
                value: ParkingSessionFormatters.currency(_session.paidAmount),
              ),
              const Divider(height: 24),
              _DetailRow(
                label: l10n.detailRemainingBalance,
                value: ParkingSessionFormatters.currency(
                  _session.remainingBalance,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context, AppLocalizations l10n) {
    final photoUrl = _photoUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: photoUrl == null
            ? Row(
                children: [
                  const Icon(Icons.photo_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.noVehiclePhotoMessage)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.vehiclePhotoTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.photoDisplayError),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          return child;
                        }
                        return const SizedBox(
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _durationUnitLabel(ParkingDurationUnit unit, AppLocalizations l10n) {
    return switch (unit) {
      ParkingDurationUnit.minutes => l10n.durationUnitMinutes,
      ParkingDurationUnit.hours => l10n.durationUnitHours,
      ParkingDurationUnit.days => l10n.durationUnitDays,
      ParkingDurationUnit.months => l10n.durationUnitMonths,
    };
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
