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

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    required this.scope,
    this.repository,
    this.onDataChanged,
    this.refreshToken = 0,
    super.key,
  });

  final ParkingTenantScope scope;
  final ParkingSessionRepository? repository;
  final VoidCallback? onDataChanged;
  final int refreshToken;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with WidgetsBindingObserver {
  static const _historyPageSize = 50;

  final _searchController = TextEditingController();
  Timer? _searchTimer;
  List<ParkingSession> _sessions = const [];
  String? _errorMessage;
  String _search = '';
  int _requestVersion = 0;
  int _dataChangeVersion = 0;
  int _offset = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _retryAppend = false;
  ParkingSessionStatus? _statusFilter;
  ParkingPaymentStatus? _paymentFilter;

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
    if ((oldWidget.refreshToken != widget.refreshToken ||
            oldWidget.scope != widget.scope) &&
        widget.repository != null) {
      if (oldWidget.scope != widget.scope) {
        _offset = 0;
        _hasMore = false;
        _isLoadingMore = false;
      }
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

  Future<void> _load({bool showLoading = true, bool append = false}) async {
    final repository = widget.repository;
    if (repository == null) {
      return;
    }

    final requestVersion = ++_requestVersion;
    final pageOffset = append ? _offset : 0;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } else if (append && mounted) {
      setState(() {
        _isLoadingMore = true;
        _errorMessage = null;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }

    final result = await repository.list(
      scope: widget.scope,
      search: _search,
      offset: pageOffset,
      pageSize: _historyPageSize,
    );
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }

    if (result is ParkingSessionListFailure) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = result.message;
        _retryAppend = append;
      });
      return;
    }

    final page = result as ParkingSessionListSuccess;
    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = null;
      _sessions = append ? [..._sessions, ...page.sessions] : page.sessions;
      _offset = pageOffset + page.sessions.length;
      _hasMore = page.hasMore;
      _retryAppend = false;
    });
  }

  void _handleSearchChanged(String value) {
    final search = value.trim();
    if (search != _search) {
      _requestVersion++;
      _offset = 0;
      _hasMore = false;
      _isLoadingMore = false;
      _retryAppend = false;
    }
    _search = search;
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

  List<ParkingSession> get _filteredSessions {
    final statusFilter = _statusFilter;
    final paymentFilter = _paymentFilter;
    if (statusFilter == null && paymentFilter == null) {
      return _sessions;
    }

    final now = DateTime.now();
    return _sessions
        .where((session) {
          if (statusFilter != null && session.statusAt(now) != statusFilter) {
            return false;
          }
          if (paymentFilter != null && session.paymentStatus != paymentFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  bool get _hasActiveFilters => _statusFilter != null || _paymentFilter != null;

  void _toggleStatusFilter(ParkingSessionStatus value) {
    setState(() {
      _statusFilter = _statusFilter == value ? null : value;
    });
  }

  void _togglePaymentFilter(ParkingPaymentStatus value) {
    setState(() {
      _paymentFilter = _paymentFilter == value ? null : value;
    });
  }

  void _loadMore() {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    unawaited(_load(showLoading: false, append: true));
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, l10n),
              const SizedBox(height: 20),
              _buildSearchField(l10n),
              const SizedBox(height: 16),
              _buildFilterChips(l10n),
              const SizedBox(height: 20),
              if (_isLoading && _sessions.isEmpty)
                const SizedBox(height: 320, child: LoadingView())
              else if (_errorMessage != null && _sessions.isEmpty)
                ErrorStateView(message: _errorMessage!, onRetry: _load)
              else if (_errorMessage != null) ...[
                ErrorStateView(
                  message: _errorMessage!,
                  onRetry: () =>
                      _load(showLoading: false, append: _retryAppend),
                ),
                const SizedBox(height: 16),
                _buildSessionList(l10n),
              ] else
                _buildSessionList(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.historyTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        IconButton(
          onPressed: _isLoading ? null : () => _load(),
          tooltip: l10n.historyRefreshTooltip,
          icon: const Icon(Icons.refresh),
        ),
      ],
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
        unawaited(_load(showLoading: false));
      },
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text(l10n.commonActive),
          selected: _statusFilter == ParkingSessionStatus.active,
          onSelected: (_) => _toggleStatusFilter(ParkingSessionStatus.active),
        ),
        FilterChip(
          label: Text(l10n.commonExpired),
          selected: _statusFilter == ParkingSessionStatus.expired,
          onSelected: (_) => _toggleStatusFilter(ParkingSessionStatus.expired),
        ),
        FilterChip(
          label: Text(l10n.historyFilterPaid),
          selected: _paymentFilter == ParkingPaymentStatus.paid,
          onSelected: (_) => _togglePaymentFilter(ParkingPaymentStatus.paid),
        ),
        FilterChip(
          label: Text(l10n.historyFilterPartiallyPaid),
          selected: _paymentFilter == ParkingPaymentStatus.partiallyPaid,
          onSelected: (_) =>
              _togglePaymentFilter(ParkingPaymentStatus.partiallyPaid),
        ),
        FilterChip(
          label: Text(l10n.historyFilterUnpaid),
          selected: _paymentFilter == ParkingPaymentStatus.unpaid,
          onSelected: (_) => _togglePaymentFilter(ParkingPaymentStatus.unpaid),
        ),
        if (_hasActiveFilters)
          ActionChip(
            avatar: const Icon(Icons.clear, size: 18),
            label: Text(l10n.historyClearFilters),
            onPressed: () {
              setState(() {
                _statusFilter = null;
                _paymentFilter = null;
              });
            },
          ),
      ],
    );
  }

  Widget _buildSessionList(AppLocalizations l10n) {
    final sessions = _filteredSessions;
    if (sessions.isEmpty) {
      final noRawSessions = _sessions.isEmpty;
      return EmptyStateView(
        icon: Icons.history,
        title: noRawSessions && _search.isEmpty
            ? l10n.historyNoHistoryTitle
            : l10n.noMatchingSessionsTitle,
        message: !noRawSessions && _hasActiveFilters
            ? l10n.historyNoMatchFilters
            : _search.isEmpty
            ? l10n.historySavedWillAppear
            : l10n.tryDifferentSearchMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ParkingSessionListView(sessions: sessions, onSessionTap: _openSession),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _isLoadingMore
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loadMore,
                    icon: const Icon(Icons.expand_more),
                    label: Text(l10n.historyLoadMore),
                  ),
          ),
      ],
    );
  }
}
