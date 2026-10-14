import 'dart:async';

import 'package:flutter/material.dart';

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
        _errorMessage = 'This parking session has no identifier.';
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

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete parking session?'),
        content: Text(
          'Delete the parking session for ${_session.plateNumber}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Session'),
        actions: [
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _edit,
            tooltip: 'Edit session',
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _confirmDelete,
            tooltip: 'Delete session',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
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
        _buildDetailsCard(context),
        const SizedBox(height: 16),
        _buildPhotoCard(context),
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
        ParkingSessionStatusChip(session: _session),
      ],
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _DetailRow(
              label: 'Entry time',
              value: ParkingSessionFormatters.dateTime(
                context,
                _session.entryTime,
              ),
            ),
            const Divider(height: 24),
            _DetailRow(
              label: 'Allowed duration',
              value:
                  '${_session.allowedDuration.value} '
                  '${_durationUnitLabel(_session.allowedDuration.unit)}',
            ),
            const Divider(height: 24),
            _DetailRow(
              label: 'Expiry',
              value: ParkingSessionFormatters.dateTime(
                context,
                _session.expiresAt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context) {
    final photoUrl = _photoUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: photoUrl == null
            ? const Row(
                children: [
                  Icon(Icons.photo_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No vehicle photo is attached to this session.',
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vehicle photo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'The private vehicle photo could not be displayed.',
                            ),
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

  String _durationUnitLabel(ParkingDurationUnit unit) {
    return switch (unit) {
      ParkingDurationUnit.minutes => 'minutes',
      ParkingDurationUnit.hours => 'hours',
      ParkingDurationUnit.days => 'days',
      ParkingDurationUnit.months => 'months',
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
