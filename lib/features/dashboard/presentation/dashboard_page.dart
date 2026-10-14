import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../parking/data/parking_session_repository.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/presentation/parking_session_details_page.dart';
import '../../parking/presentation/parking_session_list_view.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    this.repository,
    this.onNewParkingEntry,
    this.onDataChanged,
    this.refreshToken = 0,
    super.key,
  });

  final ParkingSessionRepository? repository;
  final VoidCallback? onNewParkingEntry;
  final VoidCallback? onDataChanged;
  final int refreshToken;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  List<ParkingSession> _sessions = const [];
  ParkingSessionSummary _summary = const ParkingSessionSummary(
    activeCount: 0,
    expiredCount: 0,
  );
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
  void didUpdateWidget(covariant DashboardPage oldWidget) {
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

    final summaryFuture = repository.summary();
    final sessionsFuture = repository.list(search: _search);
    final summaryResult = await summaryFuture;
    final sessionsResult = await sessionsFuture;

    if (!mounted || requestVersion != _requestVersion) {
      return;
    }

    if (summaryResult is ParkingSessionSummaryFailure) {
      setState(() {
        _isLoading = false;
        _errorMessage = summaryResult.message;
      });
      return;
    }

    if (sessionsResult is ParkingSessionListFailure) {
      setState(() {
        _isLoading = false;
        _errorMessage = sessionsResult.message;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _summary = (summaryResult as ParkingSessionSummarySuccess).summary;
      _sessions = (sessionsResult as ParkingSessionListSuccess).sessions;
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
              if (_isLoading && _sessions.isEmpty)
                const SizedBox(height: 320, child: LoadingView())
              else if (_errorMessage != null && _sessions.isEmpty)
                ErrorStateView(message: _errorMessage!, onRetry: () => _load())
              else ...[
                _buildSummary(context),
                const SizedBox(height: 20),
                _buildSearchField(),
                const SizedBox(height: 20),
                if (_errorMessage != null) ...[
                  ErrorStateView(
                    message: _errorMessage!,
                    onRetry: () => _load(showLoading: false),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_sessions.isEmpty)
                  EmptyStateView(
                    icon: Icons.local_parking_outlined,
                    title: _search.isEmpty
                        ? 'No parking sessions yet'
                        : 'No matching sessions',
                    message: _search.isEmpty
                        ? 'Create a parking entry to start tracking a vehicle.'
                        : 'Try a different registration search.',
                    action: _search.isEmpty && widget.onNewParkingEntry != null
                        ? FilledButton.icon(
                            onPressed: widget.onNewParkingEntry,
                            icon: const Icon(Icons.add),
                            label: const Text('New Parking Entry'),
                          )
                        : null,
                  )
                else ...[
                  Text(
                    'Recent sessions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ParkingSessionListView(
                    sessions: _sessions,
                    onSessionTap: _openSession,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
        Wrap(
          spacing: 8,
          children: [
            IconButton(
              onPressed: _isLoading ? null : () => _load(),
              tooltip: 'Refresh sessions',
              icon: const Icon(Icons.refresh),
            ),
            if (widget.onNewParkingEntry != null)
              FilledButton.icon(
                onPressed: widget.onNewParkingEntry,
                icon: const Icon(Icons.add),
                label: const Text('New Parking Entry'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 600
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _SummaryCard(
                label: 'Active',
                count: _summary.activeCount,
                icon: Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
            ),
            SizedBox(
              width: width,
              child: _SummaryCard(
                label: 'Expired',
                count: _summary.expiredCount,
                icon: Icons.history,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        );
      },
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
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(
          count.toString(),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
