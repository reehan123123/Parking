import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../parking/data/parking_session_repository.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/presentation/parking_session_details_page.dart';
import '../../parking/presentation/parking_session_list_view.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    this.repository,
    this.onDataChanged,
    this.refreshToken = 0,
    super.key,
  });

  final ParkingSessionRepository? repository;
  final VoidCallback? onDataChanged;
  final int refreshToken;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  List<ParkingSession> _sessions = const [];
  String? _errorMessage;
  String _search = '';
  int _requestVersion = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.repository != null) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken &&
        widget.repository != null) {
      unawaited(_load(showLoading: false));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.repository != null) {
      unawaited(_load(showLoading: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    final repository = widget.repository;
    if (repository == null) {
      return;
    }

    final requestVersion = ++_requestVersion;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final result = await repository.list(search: _search);
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }

    if (result is ParkingSessionListFailure) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _sessions = (result as ParkingSessionListSuccess).sessions;
    });
  }

  void _handleSearchChanged(String value) {
    _search = value.trim();
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_load(showLoading: false));
    });
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _handleSearchChanged('');
  }

  Future<void> _openSession(ParkingSession session) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ParkingSessionDetailsPage(
          repository: widget.repository!,
          session: session,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );
    if (mounted) {
      await _load(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildSearchField(),
              const SizedBox(height: 20),
              if (_isLoading && _sessions.isEmpty)
                const SizedBox(height: 320, child: LoadingView())
              else if (_errorMessage != null && _sessions.isEmpty)
                ErrorStateView(message: _errorMessage!, onRetry: _load)
              else if (_errorMessage != null) ...[
                ErrorStateView(
                  message: _errorMessage!,
                  onRetry: () => _load(showLoading: false),
                ),
                const SizedBox(height: 16),
                _buildSessionList(),
              ] else
                _buildSessionList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'History',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        IconButton(
          onPressed: _isLoading ? null : () => _load(),
          tooltip: 'Refresh history',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Search registration',
        hintText: 'Search by plate number',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                onPressed: _clearSearch,
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: _handleSearchChanged,
      onSubmitted: (_) {
        _searchTimer?.cancel();
        unawaited(_load(showLoading: false));
      },
    );
  }

  Widget _buildSessionList() {
    if (_sessions.isEmpty) {
      return EmptyStateView(
        icon: Icons.history,
        title: _search.isEmpty ? 'No parking history' : 'No matching sessions',
        message: _search.isEmpty
            ? 'Saved parking sessions will appear here.'
            : 'Try a different registration search.',
      );
    }

    return ParkingSessionListView(
      sessions: _sessions,
      onSessionTap: _openSession,
    );
  }
}
