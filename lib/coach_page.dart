import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:seat_vacancy/view_model/entry_view_model.dart';

class CoachPage extends StatefulWidget {
  const CoachPage({Key? key}) : super(key: key);

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String? _selectedFromStation;
  String? _selectedToStation;
  bool _isInitialized = false;

  Map<int, bool> _expandedSegments = {};

  // ✅ NEW: Station code to name mapping
  Map<String, String> _stationNames = {};

  Map<String, bool> _expandedCoaches = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _loadStations(); // ✅ NEW
  }

  // Add this method anywhere in CoachPageState class
  void _openTelegramSupport() async {
    final url = Uri.parse('https://t.me/+UyTq6xPWZBtmN2Y1');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      showSnackBar('Could not open Telegram link', isError: true);
    }
  }

  void showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }


  // ✅ NEW: Load station names
  Future<void> _loadStations() async {
    try {
      final String response = await rootBundle.loadString('assets/stations.json');
      final List<dynamic> data = json.decode(response);

      final Map<String, String> stationMap = {};
      for (var station in data) {
        final code = station['code']?.toString() ?? '';
        final name = station['name']?.toString() ?? '';
        if (code.isNotEmpty && name.isNotEmpty) {
          stationMap[code] = name;
        }
      }

      setState(() {
        _stationNames = stationMap;
      });

      //print('✅ Loaded ${_stationNames.length} station names');
    } catch (e) {
      //print('Error loading stations ');
    }
  }

  // ✅ NEW: Helper to get display name
  String _getStationDisplay(String code) {
    final name = _stationNames[code];
    if (name != null && name.isNotEmpty) {
      return '$name ($code)';
    }
    return code; // Fallback to code only
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize FROM station with boarding station (only once)
    if (!_isInitialized) {
      final viewModel = context.read<EntryViewModel>();
      if (viewModel.boardingStation != null) {
        setState(() {
          _selectedFromStation = viewModel.boardingStation!.toUpperCase();
          _isInitialized = true;
        });

        //print('🎯 Initialized FROM station: $_selectedFromStation');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Get stations for TO dropdown (only stations AFTER FROM station)
  List<String> getToStations(List<String> allStations) {
    // ✅ Return empty list if no FROM station selected
    if (_selectedFromStation == null || allStations.isEmpty) {
      return [];
    }

    final fromIndex = allStations.indexOf(_selectedFromStation!);

    // ✅ Return empty if FROM station not found or is last station
    if (fromIndex == -1 || fromIndex >= allStations.length - 1) {
      return [];
    }

    // Return stations after FROM station
    final toStations = allStations.sublist(fromIndex + 1);
    //print('TO stations available: $toStations');
    return toStations;
  }


  void _handleSearch() {
    if (_selectedFromStation == null) {
      _showSnackBar('Please select FROM station', isError: true);
      return;
    }

    if (_selectedToStation == null) {
      _showSnackBar('Please select TO station', isError: true);
      return;
    }

    final viewModel = context.read<EntryViewModel>();

    // Call vacancy search API
    _showSnackBar('Searching vacant berths...', isError: false);
    //print('=' * 60);
    //print('🔍 SEARCH INITIATED');
    //print('FROM: $_selectedFromStation → TO: $_selectedToStation');
    //print('=' * 60);

    viewModel.searchVacantBerths(
      fromStation: _selectedFromStation!,
      toStation: _selectedToStation!,
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<EntryViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isFetchingComposition) {
            return _buildLoadingState();
          }

          if (viewModel.errorMessage != null) {
            return _buildErrorState(viewModel.errorMessage!);
          }

          if (viewModel.trainComposition == null) {
            return _buildEmptyState();
          }

          return _buildContent(viewModel);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Loading Train Details...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Something went wrong',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.train_outlined,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'No Train Data',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(EntryViewModel viewModel) {
    final composition = viewModel.trainComposition!;
    final coaches = viewModel.coachData!;
    final stations = viewModel.stationsList;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // App Bar with Train Info (keep as is)
        SliverAppBar(
          expandedHeight: 140,
          pinned: true,
          backgroundColor: const Color(0xFF6366F1),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          // NEW: Add Telegram button
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openTelegramSupport,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.support_agent,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Support',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        composition['trainName'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${composition['trainNo']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_getStationDisplay(composition['from'])} → ${_getStationDisplay(composition['to'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Content
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Train composition diagram (keep as is)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Train Composition',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${coaches.length} coaches available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Horizontal coach diagram (keep as is)
                SizedBox(
                  height: 85,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: coaches.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildEngineCard();
                      }
                      final coach = coaches[index - 1];
                      return _buildCoachCard(coach);
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Search Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSearchSection(stations, viewModel),
                ),

                const SizedBox(height: 20),

                // Search Progress Indicator
                if (viewModel.isSearchingVacancy || viewModel.isSearchingMultiSegment)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSearchProgress(viewModel),
                  ),

                const SizedBox(height: 20),

                // ✅ NEW: Direct Results Section
                // Direct Results Section
                if (viewModel.vacantBerths != null && viewModel.vacantBerths!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildResultsSection(viewModel),
                  ),

// Multi-Segment Alternative Paths
                if (viewModel.multiSegmentPaths != null && viewModel.multiSegmentPaths!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildMultiSegmentSection(viewModel),
                  ),

// No seats found message (when both searches complete with no results)
                if (viewModel.vacantBerths != null &&
                    viewModel.vacantBerths!.isEmpty &&
                    viewModel.multiSegmentPaths != null &&
                    viewModel.multiSegmentPaths!.isEmpty &&
                    !viewModel.isSearchingVacancy &&
                    !viewModel.isSearchingMultiSegment)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 56,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Seats Available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFromStation != null && _selectedToStation != null
                                ? 'Unfortunately, there are no vacant seats for\n${_getStationDisplay(_selectedFromStation!)} → ${_getStationDisplay(_selectedToStation!)}'
                                : 'No vacant seats found for this route',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 20,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Try selecting different stations or check another date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),


                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }


  /// ✅ NEW: Build multi-segment alternative paths UI
  Widget _buildMultiSegmentSection(EntryViewModel viewModel) {
    final paths = viewModel.multiSegmentPaths!;
    final from = _selectedFromStation;
    final to = _selectedToStation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with info banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFFD97706),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No Direct Seats Available',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'But you can travel by changing seats at intermediate stations!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Title
        if (from != null && to != null)
          Text(
            'Alternative Paths: ${_getStationDisplay(from)} → ${_getStationDisplay(to)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),

        const SizedBox(height: 12),

        // Path cards
        ...paths.asMap().entries.map((entry) {
          final index = entry.key;
          final path = entry.value;
          return _buildPathCard(path, index + 1);
        }).toList(),
      ],
    );
  }


  /// Build individual path card
  Widget _buildPathCard(MultiSegmentPath path, int pathNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Path header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#$pathNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path.summary,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        path.pathDescription,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Segments
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: path.segments.asMap().entries.map((entry) {
                final segIndex = entry.key;
                final segment = entry.value;
                final isLast = segIndex == path.segments.length - 1;

                return Column(
                  children: [
                    _buildSegmentRow(segment, segIndex + 1),
                    if (!isLast) _buildTransferIndicator(),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }


  /// Build segment row showing from-to with available seats
  /// Build segment row showing from-to with available seats
  Widget _buildSegmentRow(PathSegment segment, int segmentNumber) {
    // Track expansion state for each segment
    final isExpanded = _expandedSegments[segmentNumber] ?? false;
    final displaySeats = isExpanded
        ? segment.availableSeats
        : segment.availableSeats.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segment route
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$segmentNumber',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_getStationDisplay(segment.fromStation)} → ${_getStationDisplay(segment.toStation)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${segment.availableSeats.length} seats',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Available seats chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: displaySeats.map((berth) {
              return InkWell(
                onTap: () => _showBerthDetailsDialog(berth),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${berth.coachName}-${berth.berthNo}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Load More button
          if (segment.availableSeats.length > 10) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _expandedSegments[segmentNumber] = !isExpanded;
                  });
                },
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: const Color(0xFF10B981),
                ),
                label: Text(
                  isExpanded
                      ? 'Show Less'
                      : 'Load ${segment.availableSeats.length - 10} More Seats',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  /// Build transfer indicator between segments
  Widget _buildTransferIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Container(
            width: 2,
            height: 20,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.swap_horiz,
                  size: 14,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Change seat here',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSearchProgress(EntryViewModel viewModel) {
    final isMultiSegment = viewModel.isSearchingMultiSegment;
    final message = isMultiSegment
        ? 'Finding alternative paths...'
        : 'Searching coaches...';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (!isMultiSegment) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Processing ${(viewModel.searchProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!isMultiSegment) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: viewModel.searchProgress,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF10B981),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }



  Widget _buildEngineCard() {
    return Container(
      width: 65,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.train, color: Colors.white, size: 22),
          SizedBox(height: 4),
          Text(
            'ENGINE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(dynamic coach) {
    final coachName = coach['coachName'] ?? 'N/A';
    final classCode = coach['classCode'] ?? '';

    return Container(
      width: 65,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            coachName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              classCode,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(List<String> stations, EntryViewModel viewModel) {
    final toStations = getToStations(stations);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Vacant Berths',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // FROM Station Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FROM Station (Your Boarding Point)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedFromStation,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on, color: Color(0xFF10B981), size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  hint: Text(
                    'Select starting station',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  // ✅ Custom selected item builder
                  selectedItemBuilder: (BuildContext context) {
                    return stations.map<Widget>((String station) {
                      return Text(
                        _getStationDisplay(station),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }).toList();
                  },
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF10B981)),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  items: stations.map<DropdownMenuItem<String>>((String station) {
                    return DropdownMenuItem<String>(
                      value: station, // ✅ Backend uses CODE
                      child: Text(
                        _getStationDisplay(station), // ✅ Display NAME (CODE)
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      _selectedFromStation = value;
                      _selectedToStation = null;
                    });
                    viewModel.clearVacantBerths();
                    //print('✅ FROM station selected: $value');
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Arrow Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_downward,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // TO Station Dropdown (filtered)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TO Station (Where You Want to Get Down)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _selectedFromStation == null
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedToStation,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.flag,
                      color: _selectedFromStation == null
                          ? Colors.grey[400]
                          : const Color(0xFF10B981),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: _selectedFromStation == null
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  hint: Text(
                    _selectedFromStation == null
                        ? 'Select FROM station first'
                        : 'Select destination station',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  // ✅ Custom selected item builder
                  selectedItemBuilder: (BuildContext context) {
                    return toStations.map<Widget>((String station) {
                      return Text(
                        _getStationDisplay(station),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }).toList();
                  },
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: _selectedFromStation == null
                        ? Colors.grey[400]
                        : const Color(0xFF10B981),
                  ),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  items: toStations.isEmpty
                      ? null
                      : toStations.map<DropdownMenuItem<String>>((String station) {
                    return DropdownMenuItem<String>(
                      value: station, // ✅ Backend uses CODE
                      child: Text(
                        _getStationDisplay(station), // ✅ Display NAME (CODE)
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _selectedFromStation == null
                      ? null
                      : (String? value) {
                    setState(() {
                      _selectedToStation = value;
                    });
                    viewModel.clearVacantBerths();
                    //print('✅ TO station selected: $value');
                  },
                ),
              ),
              if (_selectedFromStation != null && toStations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${toStations.length} stations available after ${_getStationDisplay(_selectedFromStation!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // Search Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: viewModel.isSearchingVacancy ? null : _handleSearch,
              icon: viewModel.isSearchingVacancy
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF10B981),
                ),
              )
                  : const Icon(Icons.search, size: 20),
              label: Text(
                viewModel.isSearchingVacancy ? 'Searching...' : 'Find Vacant Berths',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF10B981),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildResultsSection(EntryViewModel viewModel) {
    final results = viewModel.vacantBerths!;

    // Safely cache current selections
    final from = _selectedFromStation;
    final to = _selectedToStation;

    // If either selection is null now, just show a generic message
    if (from == null || to == null) {
      if (results.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No vacant berths found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        );
      }
    }

    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No vacant berths found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            if (from != null && to != null)
              Text(
                'from ${_getStationDisplay(from)} to ${_getStationDisplay(to)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    }

    // Group by coach
    final Map<String, List<VacantBerthResult>> groupedResults = {};

    for (var result in results) {
      groupedResults.putIfAbsent(result.coachName, () => []).add(result);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Vacant Berths', '${results.length}', Icons.event_seat),
              Container(width: 2, height: 40, color: Colors.white.withOpacity(0.3)),
              _buildSummaryItem('Coaches', '${groupedResults.length}', Icons.train),
            ],
          ),
        ),

        const SizedBox(height: 20),

        if (from != null && to != null)
          Text(
            'Available Berths: ${_getStationDisplay(from)} → ${_getStationDisplay(to)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),

        const SizedBox(height: 12),

        // Coach cards
        const SizedBox(height: 12),

// Helper hint - shows once
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.touch_app,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap on any seat number to see detailed journey segments',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

// Coach cards
        ...groupedResults.entries.map((entry) {
          return _buildCoachResultCard(entry.key, entry.value);
        }).toList(),

      ],
    );
  }




  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCoachResultCard(String coachName, List<VacantBerthResult> berths) {
    final firstBerth = berths.first;
    final coachKey = coachName; // Unique key for this coach
    final isExpanded = _expandedCoaches[coachKey] ?? false;
    final displayBerths = isExpanded ? berths : berths.take(10).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coach Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.train, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coach $coachName',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Class: ${firstBerth.coachClass} • ${berths.length} vacant berths',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Berth List
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: displayBerths.map((berth) {
                    return buildBerthChip(berth);
                  }).toList(),
                ),

                // Load More button for coach
                if (berths.length > 10) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _expandedCoaches[coachKey] = !isExpanded;
                        });
                      },
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: const Color(0xFF10B981),
                      ),
                      label: Text(
                        isExpanded
                            ? 'Show Less'
                            : 'Load ${berths.length - 10} More Seats',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget buildBerthChip(VacantBerthResult berth) {
    final color = berth.isFullyVacant ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBerthDetailsDialog(berth),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_seat, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${berth.berthNo}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  berth.hasPartialVacancy ? Icons.info_outline : Icons.touch_app,
                  color: Colors.white.withOpacity(0.8),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  void _showBerthDetailsDialog(VacantBerthResult berth) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header (same as before) ...
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event_seat,
                      color: Color(0xFF10B981),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Berth ${berth.berthNo} • ${berth.berthCode}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Coach ${berth.coachName} • ${berth.coachClass}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // NEW: unified, ordered segments list
              const Text(
                'Journey Segments:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              ..._buildOrderedSegments(berth),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  List<Widget> _buildOrderedSegments(VacantBerthResult berth) {
    // combine vacant + occupied with a flag
    final all = <Map<String, dynamic>>[
      ...berth.vacantSegments.map((s) => {'seg': s, 'vacant': true}),
      ...berth.occupiedSegments.map((s) => {'seg': s, 'vacant': false}),
    ];

    // sort by from-station index, then to-station index
    all.sort((a, b) {
      final sa = a['seg'] as SegmentInfo;
      final sb = b['seg'] as SegmentInfo;

      final fromA = _stationNames.keys.toList().indexOf(sa.from);
      final fromB = _stationNames.keys.toList().indexOf(sb.from);
      if (fromA != fromB) return fromA.compareTo(fromB);

      final toA = _stationNames.keys.toList().indexOf(sa.to);
      final toB = _stationNames.keys.toList().indexOf(sb.to);
      return toA.compareTo(toB);
    });

    return all.map((entry) {
      final segment = entry['seg'] as SegmentInfo;
      final isVacant = entry['vacant'] as bool;
      final color = isVacant ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      final label = isVacant ? 'VACANT' : 'OCCUPIED';

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_getStationDisplay(segment.from)} → ${_getStationDisplay(segment.to)} ($label)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }



}
