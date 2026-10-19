import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../parking/data/parking_session_repository.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/presentation/parking_session_details_page.dart';
import '../../parking/presentation/parking_session_list_view.dart';
import '../../tenants/domain/parking_tenant_scope.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.scope,
    this.repository,
    this.onNewParkingEntry,
    this.onViewHistory,
    this.onDataChanged,
    this.refreshToken = 0,
    super.key,
  });

  final ParkingTenantScope scope;
  final ParkingSessionRepository? repository;
  final VoidCallback? onNewParkingEntry;
  final VoidCallback? onViewHistory;
  final VoidCallback? onDataChanged;
  final int refreshToken;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  static const _recentSessionPageSize = 10;

  final _searchController = TextEditingController();
  Timer? _searchTimer;
  List<ParkingSession> _sessions = const [];
  ParkingSessionSummary _summary = const ParkingSessionSummary(
    activeCount: 0,
    expiredCount: 0,
  );
  String? _listErrorMessage;
  String? _summaryErrorMessage;
  String _search = '';
  int _requestVersion = 0;
  int _summaryRequestVersion = 0;
  int _dataChangeVersion = 0;
  bool _isLoading = false;
  bool _hasMore = false;

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
    if ((oldWidget.refreshToken != widget.refreshToken ||
            oldWidget.scope != widget.scope) &&
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

  Future<void> _load({
    bool showLoading = true,
    bool includeSummary = true,
  }) async {
    final repository = widget.repository;
    if (repository == null) {
      return;
    }

    final requestVersion = ++_requestVersion;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _listErrorMessage = null;
      });
    }

    if (includeSummary) {
      unawaited(_loadSummary(repository));
    }
    final sessionsFuture = repository.list(
      scope: widget.scope,
      search: _search,
      pageSize: _recentSessionPageSize,
    );
    final sessionsResult = await sessionsFuture;

    if (!mounted || requestVersion != _requestVersion) {
      return;
    }

    if (sessionsResult is ParkingSessionListFailure) {
      setState(() {
        _isLoading = false;
        _listErrorMessage = sessionsResult.message;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _listErrorMessage = null;
      final sessionPage = sessionsResult as ParkingSessionListSuccess;
      _sessions = sessionPage.sessions;
      _hasMore = sessionPage.hasMore;
    });
  }

  Future<void> _loadSummary(ParkingSessionRepository repository) async {
    final requestVersion = ++_summaryRequestVersion;
    final result = await repository.summary(scope: widget.scope);
    if (!mounted || requestVersion != _summaryRequestVersion) {
      return;
    }

    if (result is ParkingSessionSummaryFailure) {
      setState(() {
        _summaryErrorMessage = result.message;
      });
      return;
    }

    setState(() {
      _summary = (result as ParkingSessionSummarySuccess).summary;
      _summaryErrorMessage = null;
    });
  }

  void _handleSearchChanged(String value) {
    _search = value.trim();
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_load(showLoading: false, includeSummary: false));
    });
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _handleSearchChanged('');
  }

  Future<void> _openSession(ParkingSession session) async {
    final previousRefreshToken = widget.refreshToken;
    final previousDataChangeVersion = _dataChangeVersion;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ParkingSessionDetailsPage(
          repository: widget.repository!,
          session: session,
          onDataChanged: _handleDataChanged,
        ),
      ),
    );
    if (mounted &&
        widget.refreshToken == previousRefreshToken &&
        _dataChangeVersion == previousDataChangeVersion) {
      await _load(showLoading: false);
    }
  }

  void _handleDataChanged() {
    final onDataChanged = widget.onDataChanged;
    if (onDataChanged == null) {
      return;
    }

    _dataChangeVersion++;
    onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errorMessage = _listErrorMessage ?? _summaryErrorMessage;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, l10n),
              const SizedBox(height: 24),
              if (_isLoading && _sessions.isEmpty)
                const SizedBox(height: 320, child: LoadingView())
              else if (errorMessage != null && _sessions.isEmpty)
                ErrorStateView(message: errorMessage, onRetry: () => _load())
              else ...[
                _buildSummary(context, l10n),
                const SizedBox(height: 24),
                _buildSearchField(l10n),
                const SizedBox(height: 28),
                if (errorMessage != null) ...[
                  ErrorStateView(
                    message: errorMessage,
                    onRetry: () => _load(showLoading: false),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_sessions.isEmpty)
                  EmptyStateView(
                    icon: Icons.local_parking_outlined,
                    title: _search.isEmpty
                        ? l10n.dashboardNoSessionsTitle
                        : l10n.noMatchingSessionsTitle,
                    message: _search.isEmpty
                        ? l10n.dashboardNoSessionsMessage
                        : l10n.tryDifferentSearchMessage,
                    action: _search.isEmpty && widget.onNewParkingEntry != null
                        ? FilledButton.icon(
                            onPressed: widget.onNewParkingEntry,
                            icon: const Icon(Icons.add),
                            label: Text(l10n.dashboardNewEntry),
                          )
                        : null,
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.dashboardRecentSessions,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_hasMore && widget.onViewHistory != null)
                        TextButton.icon(
                          onPressed: widget.onViewHistory,
                          icon: const Icon(Icons.history),
                          label: Text(l10n.dashboardViewAll),
                        ),
                    ],
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

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      spacing: 20,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dashboardOverviewTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.dashboardOverviewSubtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => _load(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.dashboardRefresh),
            ),
            if (widget.onNewParkingEntry != null)
              FilledButton.icon(
                onPressed: widget.onNewParkingEntry,
                icon: const Icon(Icons.add),
                label: Text(l10n.dashboardNewEntry),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, AppLocalizations l10n) {
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
                label: l10n.commonActive,
                count: _summary.activeCount,
                icon: Icons.check_circle_outline,
                accent: Theme.of(context).colorScheme.primary,
                message: l10n.dashboardActiveMessage,
              ),
            ),
            SizedBox(
              width: width,
              child: _SummaryCard(
                label: l10n.commonExpired,
                count: _summary.expiredCount,
                icon: Icons.history,
                accent: Theme.of(context).colorScheme.tertiary,
                message: l10n.dashboardExpiredMessage,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: l10n.searchRegistrationLabel,
        hintText: l10n.searchByPlateHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                onPressed: _clearSearch,
                tooltip: l10n.clearSearchTooltip,
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: _handleSearchChanged,
      onSubmitted: (_) {
        _searchTimer?.cancel();
        unawaited(_load(showLoading: false, includeSummary: false));
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
    required this.message,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color accent;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const Spacer(),
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              count.toString(),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
