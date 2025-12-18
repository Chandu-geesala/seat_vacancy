import 'package:flutter/material.dart';
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

  // ✅ NEW: Station code to name mapping
  Map<String, String> _stationNames = {};

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

      print('✅ Loaded ${_stationNames.length} station names');
    } catch (e) {
      print('Error loading stations: $e');
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

        print('🎯 Initialized FROM station: $_selectedFromStation');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Get stations for TO dropdown (only stations AFTER FROM station)
  List<String> _getToStations(List<String> allStations) {
    if (_selectedFromStation == null) return [];

    final fromIndex = allStations.indexOf(_selectedFromStation!);
    if (fromIndex == -1 || fromIndex >= allStations.length - 1) return [];

    // Return stations after FROM station
    final toStations = allStations.sublist(fromIndex + 1);
    print('📍 TO stations available: $toStations');
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
    print('=' * 60);
    print('🔍 SEARCH INITIATED');
    print('FROM: $_selectedFromStation → TO: $_selectedToStation');
    print('=' * 60);

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

    print('🚂 Building content with ${stations.length} stations: $stations');

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // App Bar with Train Info
        SliverAppBar(
          expandedHeight: 140,
          pinned: true,
          backgroundColor: const Color(0xFF6366F1),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
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
                              '${_getStationDisplay(composition['from'])} → ${_getStationDisplay(composition['to'])}', // ✅ Display names
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

                // Train composition diagram
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

                // Horizontal coach diagram
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
                if (viewModel.isSearchingVacancy)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSearchProgress(viewModel),
                  ),

                const SizedBox(height: 20),

                // Results Section
                if (viewModel.vacantBerths != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildResultsSection(viewModel),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
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
    final toStations = _getToStations(stations);

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
          Row(
            children: [


              const Expanded(
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
                    SizedBox(height: 2),
                    Text(
                      'Select your journey stations',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
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
                  items: stations.map((String station) {
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
                    print('✅ FROM station selected: $value');
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
                        size: 20
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
                          : const Color(0xFF10B981)
                  ),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  items: toStations.isEmpty
                      ? null
                      : toStations.map((String station) {
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
                    print('✅ TO station selected: $value');
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

  Widget _buildSearchProgress(EntryViewModel viewModel) {
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
                    const Text(
                      'Searching coaches...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Processing ${(viewModel.searchProgress * 100).toInt()}%',
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
      ),
    );
  }

  Widget _buildResultsSection(EntryViewModel viewModel) {
    final results = viewModel.vacantBerths!;

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
            Text(
              'from ${_getStationDisplay(_selectedFromStation!)} to ${_getStationDisplay(_selectedToStation!)}', // ✅ Display names
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
      if (!groupedResults.containsKey(result.coachName)) {
        groupedResults[result.coachName] = [];
      }
      groupedResults[result.coachName]!.add(result);
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

        Text(
          'Available Berths: ${_getStationDisplay(_selectedFromStation!)} → ${_getStationDisplay(_selectedToStation!)}', // ✅ Display names
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),

        const SizedBox(height: 12),

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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 2),
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
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: berths.map((berth) => _buildBerthChip(berth)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBerthChip(VacantBerthResult berth) {
    final color = berth.isFullyVacant ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return InkWell(
      onTap: () {
        _showBerthDetailsDialog(berth);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_seat, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              '${berth.berthNo}', // ✅ Only berth number
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (berth.hasPartialVacancy) ...[
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, color: Colors.white, size: 14),
            ],
          ],
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
              const Text(
                'Vacancy Segments:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...berth.vacantSegments.map((segment) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_getStationDisplay(segment.from)} → ${_getStationDisplay(segment.to)} (VACANT)', // ✅ Display names
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              if (berth.occupiedSegments.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Occupied Segments:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...berth.occupiedSegments.map((segment) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_getStationDisplay(segment.from)} → ${_getStationDisplay(segment.to)} (OCCUPIED)', // ✅ Display names
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
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
}
