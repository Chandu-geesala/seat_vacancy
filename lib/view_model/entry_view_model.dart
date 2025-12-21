import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:collection';

/// Smart Vacancy Berth Model with segment matching info
class VacantBerthResult {
  final String coachName;
  final String coachClass;
  final int berthNo;
  final String berthCode;
  final String cabin;
  final String matchType; // 'EXACT', 'PARTIAL', 'EXTENDED'
  final List<SegmentInfo> vacantSegments;
  final List<SegmentInfo> occupiedSegments;

  VacantBerthResult({
    required this.coachName,
    required this.coachClass,
    required this.berthNo,
    required this.berthCode,
    required this.cabin,
    required this.matchType,
    required this.vacantSegments,
    required this.occupiedSegments,
  });

  bool get isFullyVacant => occupiedSegments.isEmpty;
  bool get hasPartialVacancy => occupiedSegments.isNotEmpty;
}

class SegmentInfo {
  final String from;
  final String to;
  final String quota;
  final bool isVacant;

  SegmentInfo({
    required this.from,
    required this.to,
    required this.quota,
    required this.isVacant,
  });
}

/// NEW: Multi-segment journey path model
class MultiSegmentPath {
  final List<PathSegment> segments;
  final int transferCount;
  final String pathDescription;

  MultiSegmentPath({
    required this.segments,
    required this.transferCount,
    required this.pathDescription,
  });

  String get summary =>
      '${segments.length} segment${segments.length > 1 ? 's' : ''} • $transferCount transfer${transferCount != 1 ? 's' : ''}';
}

class PathSegment {
  final String fromStation;
  final String toStation;
  final List<VacantBerthResult> availableSeats;

  PathSegment({
    required this.fromStation,
    required this.toStation,
    required this.availableSeats,
  });
}

class EntryViewModel extends ChangeNotifier {
  // Loading states
  bool _isLoadingStations = false;
  bool _isSubmitting = false;
  bool _isFetchingComposition = false;
  bool _isSearchingVacancy = false;
  bool _isSearchingMultiSegment = false;

  // Data
  List<String> _stationsList = [];
  String? _errorMessage;
  TrainDetailsModel? _trainDetails;
  Map<String, dynamic>? _trainComposition;
  List<dynamic>? _coachData;
  List<VacantBerthResult>? _vacantBerths;
  List<MultiSegmentPath>? _multiSegmentPaths;

  // Stored data for later use
  String? _boardingStation;
  DateTime? _journeyDate;
  String? _trainNumber;

  // Search progress
  int _processedCoaches = 0;
  int _totalCoaches = 0;

  // NEW: Cache for optimization - stores ALL vacant segments
  Map<String, List<VacantBerthResult>> _segmentCache = {};

  // Getters
  bool get isLoadingStations => _isLoadingStations;
  bool get isSubmitting => _isSubmitting;
  bool get isFetchingComposition => _isFetchingComposition;
  bool get isSearchingVacancy => _isSearchingVacancy;
  bool get isSearchingMultiSegment => _isSearchingMultiSegment;
  List<String> get stationsList => _stationsList;
  String? get errorMessage => _errorMessage;
  TrainDetailsModel? get trainDetails => _trainDetails;
  bool get hasStations => _stationsList.isNotEmpty;
  Map<String, dynamic>? get trainComposition => _trainComposition;
  List<dynamic>? get coachData => _coachData;
  List<VacantBerthResult>? get vacantBerths => _vacantBerths;
  List<MultiSegmentPath>? get multiSegmentPaths => _multiSegmentPaths;
  String? get boardingStation => _boardingStation;
  DateTime? get journeyDate => _journeyDate;
  String? get trainNumber => _trainNumber;
  double get searchProgress =>
      _totalCoaches > 0 ? _processedCoaches / _totalCoaches : 0.0;

  // Clear previous vacancy results
  void clearVacantBerths() {
    _vacantBerths = null;
    _multiSegmentPaths = null;
    _processedCoaches = 0;
    _totalCoaches = 0;
    _isSearchingVacancy = false;
    _isSearchingMultiSegment = false;
    notifyListeners();
  }

  /// Fetch train stations from API
  Future<bool> fetchTrainStations(String trainNumber) async {
    if (trainNumber.isEmpty) {
      _errorMessage = 'Train number is required';
      notifyListeners();
      return false;
    }

    _isLoadingStations = true;
    _errorMessage = null;
    _stationsList = [];
    _trainDetails = null;
    notifyListeners();

    try {
      final url = 'https://pongal.sardarspy4.workers.dev/$trainNumber';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['stnlist'] != null && data['stnlist'] is List) {
          _stationsList = List<String>.from(data['stnlist']);

          _trainDetails = TrainDetailsModel(
            trainNumber: data['trno']?.toString() ?? trainNumber,
            trainName: data['trname']?.toString() ?? '',
            stations: _stationsList,
            allStationCodes: data['allscodes'] != null
                ? List<String>.from(data['allscodes'])
                : [],
          );

          _isLoadingStations = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = 'No stations found for this train';
          _isLoadingStations = false;
          notifyListeners();
          return false;
        }
      } else if (response.statusCode == 404) {
        _errorMessage = 'Train not found. Please check the train number.';
        _isLoadingStations = false;
        notifyListeners();
        return false;
      } else {
        _errorMessage = 'Server error (${response.statusCode})';
        _isLoadingStations = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error: Please Try Again';
      _isLoadingStations = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch train composition from IRCTC API
  Future<bool> fetchTrainComposition({
    required String trainNumber,
    required String boardingStation,
    required DateTime journeyDate,
  }) async {
    _isFetchingComposition = true;
    _errorMessage = null;
    _trainComposition = null;
    _coachData = null;
    _vacantBerths = null;
    _multiSegmentPaths = null;

    _trainNumber = trainNumber;
    _boardingStation = boardingStation;
    _journeyDate = journeyDate;

    notifyListeners();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(journeyDate);

      final payload = {
        'trainNo': trainNumber,
        'jDate': dateStr,
        'boardingStation': boardingStation.toUpperCase(),
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Origin': 'https://www.irctc.co.in',
        'Referer': 'https://www.irctc.co.in/online-charts/',
      };

      final url = 'https://www.irctc.co.in/online-charts/api/trainComposition';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] != null && data['error'].toString().isNotEmpty) {
          _errorMessage = data['error'];
          _isFetchingComposition = false;
          notifyListeners();
          return false;
        }

        _trainComposition = data;
        _coachData = data['cdd'] ?? [];
        _isFetchingComposition = false;

        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to fetch data. Status: ${response.statusCode}';
        _isFetchingComposition = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error:Please Try Again';
      _isFetchingComposition = false;
      notifyListeners();
      return false;
    }
  }

  /// OPTIMIZED: Search for vacant berths with smart segment matching
  Future<bool> searchVacantBerths({
    required String fromStation,
    required String toStation,
  }) async {
    if (_trainComposition == null || _coachData == null) {
      _errorMessage = 'Please fetch train composition first';
      notifyListeners();
      return false;
    }

    _isSearchingVacancy = true;
    _vacantBerths = null;
    _multiSegmentPaths = null;
    _errorMessage = null;
    _processedCoaches = 0;
    _totalCoaches = _coachData!.length;
    _segmentCache.clear(); // Clear cache for new search
    notifyListeners();

    final fromStationUpper = fromStation.toUpperCase();
    final toStationUpper = toStation.toUpperCase();

    final List<VacantBerthResult> results = [];

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Origin': 'https://www.irctc.co.in',
        'Referer': 'https://www.irctc.co.in/online-charts/',
      };

      // Process coaches in batches for better performance
      const batchSize = 3;

      for (int i = 0; i < _coachData!.length; i += batchSize) {
        final batch = _coachData!.skip(i).take(batchSize).toList();

        await Future.wait(
          batch.map((coach) => _processCoach(
            coach,
            fromStationUpper,
            toStationUpper,
            headers,
            results,
          )),
        );

        _processedCoaches = (i + batchSize).clamp(0, _coachData!.length);
        notifyListeners();
      }

      _vacantBerths = results;
      _isSearchingVacancy = false;

     //print('✅ Direct search complete: ${results.length} berths found');
     //print('📦 Segment cache size: ${_segmentCache.length} segments');

      // NEW: If no direct seats found, automatically search for multi-segment paths
      if (results.isEmpty) {
       //print('🔄 No direct seats, searching multi-segment paths...');
        await _searchMultiSegmentPaths(fromStationUpper, toStationUpper);
      }

      notifyListeners();
      return true;
    } catch (e) {
     //print('❌ Search error: $e');
      _errorMessage = 'Search failed';
      _isSearchingVacancy = false;
      notifyListeners();
      return false;
    }
  }

  /// NEW: 🚀 SMART MULTI-SEGMENT PATH FINDER (BFS + Memoization)
  Future<void> _searchMultiSegmentPaths(
      String fromStation,
      String toStation,
      ) async {
    _isSearchingMultiSegment = true;
    notifyListeners();

    try {
     //print('🔍 Starting multi-segment search: $fromStation → $toStation');

      // Build graph of all possible segments with available seats
      final segmentGraph = _buildSegmentGraph();

     //print('📊 Graph has ${segmentGraph.length} nodes');

      if (segmentGraph.isEmpty) {
       //print('❌ Graph is empty, no paths possible');
        _multiSegmentPaths = [];
        _isSearchingMultiSegment = false;
        notifyListeners();
        return;
      }

      // Use BFS to find optimal paths
      final paths = _findOptimalPaths(segmentGraph, fromStation, toStation);

     //print('✅ Found ${paths.length} alternative paths');

      _multiSegmentPaths = paths;
      _isSearchingMultiSegment = false;
      notifyListeners();
    } catch (e) {
     //print('❌ Multi-segment error: $e');
      _multiSegmentPaths = [];
      _isSearchingMultiSegment = false;
      notifyListeners();
    }
  }

  /// Build a graph of all station-to-station segments with available seats
  Map<String, Map<String, List<VacantBerthResult>>> _buildSegmentGraph() {
    final graph = <String, Map<String, List<VacantBerthResult>>>{};

   //print('🔨 Building graph from ${_segmentCache.length} cached segments');

    // Use cached berth data from the initial search
    for (var entry in _segmentCache.entries) {
      final key = entry.key; // Format: "FROM->TO"
      final berths = entry.value;

      if (berths.isEmpty) continue;

      final parts = key.split('->');
      if (parts.length != 2) continue;

      final from = parts[0];
      final to = parts[1];

      graph.putIfAbsent(from, () => {});
      graph[from]![to] = berths;

     //print('  📍 $from → $to: ${berths.length} seats');
    }

    return graph;
  }

  /// BFS to find top 3 optimal paths (minimum transfers)
  List<MultiSegmentPath> _findOptimalPaths(
      Map<String, Map<String, List<VacantBerthResult>>> graph,
      String start,
      String end,
      ) {
   //print('🚀 BFS from $start to $end');

    final paths = <MultiSegmentPath>[];
    final queue = Queue<_PathState>();

    // Initialize BFS
    queue.add(_PathState(
      currentStation: start,
      segments: [],
      visitedStations: {start},
    ));

    int iterations = 0;
    const maxIterations = 1000;

    while (queue.isNotEmpty && paths.length < 3 && iterations < maxIterations) {
      iterations++;
      final state = queue.removeFirst();

      // Reached destination
      if (state.currentStation == end && state.segments.isNotEmpty) {
        final path = MultiSegmentPath(
          segments: state.segments,
          transferCount: state.segments.length - 1,
          pathDescription: _buildPathDescription(state.segments),
        );
        paths.add(path);
       //print('  ✅ Path ${paths.length}: ${path.pathDescription}');
        continue;
      }

      // Explore next segments
      final nextStations = graph[state.currentStation] ?? {};

      for (final entry in nextStations.entries) {
        final nextStation = entry.key;
        final availableSeats = entry.value;

        // Skip if already visited in this path or no seats
        if (state.visitedStations.contains(nextStation) ||
            availableSeats.isEmpty) {
          continue;
        }

        // Skip if station is PAST destination (backtracking)
        final destIndex = _stationsList.indexOf(end);
        final nextIndex = _stationsList.indexOf(nextStation);
        if (destIndex != -1 && nextIndex > destIndex) {
          continue;
        }

        // Create new path state
        final newSegment = PathSegment(
          fromStation: state.currentStation,
          toStation: nextStation,
          availableSeats: availableSeats,
        );

        queue.add(_PathState(
          currentStation: nextStation,
          segments: [...state.segments, newSegment],
          visitedStations: {...state.visitedStations, nextStation},
        ));
      }
    }

    // Sort by transfer count (fewer is better)
    paths.sort((a, b) => a.transferCount.compareTo(b.transferCount));

    return paths.take(3).toList();
  }

  String _buildPathDescription(List<PathSegment> segments) {
    return segments.map((s) => '${s.fromStation} → ${s.toStation}').join(' ➜ ');
  }

  /// ✅ FIXED: Process single coach for vacancy
  Future<void> _processCoach(
      dynamic coach,
      String fromStation,
      String toStation,
      Map<String, String> headers,
      List<VacantBerthResult> results,
      ) async {
    try {
      final payload = {
        'trainNo': _trainComposition!['trainNo'],
        'boardingStation': _boardingStation ?? _trainComposition!['from'],
        'remoteStation': _trainComposition!['remote'],
        'trainSourceStation': _trainComposition!['from'],
        'jDate':
        DateFormat('yyyy-MM-dd').format(_journeyDate ?? DateTime.now()),
        'coach': coach['coachName'],
        'cls': coach['classCode'],
      };

      final response = await http
          .post(
        Uri.parse(
            'https://www.irctc.co.in/online-charts/api/coachComposition'),
        headers: headers,
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] == null || data['error'].toString().isEmpty) {
          List<dynamic> berths = data['bdd'] ?? [];

          for (var berth in berths) {
            // ✅ NEW: Cache ALL vacant segments first (for multi-segment)
            final allSegments = _extractAllVacantSegments(berth, coach);

            // Then check if matches user query (for direct results)
            final matchResult = _analyzeBerthSegments(
              berth,
              fromStation,
              toStation,
            );

            if (matchResult != null) {
              results.add(VacantBerthResult(
                coachName: coach['coachName'],
                coachClass: coach['classCode'],
                berthNo: berth['berthNo'],
                berthCode: berth['berthCode'],
                cabin: berth['cabinCoupeNameNo'] ?? '',
                matchType: matchResult['type'],
                vacantSegments: matchResult['vacant'],
                occupiedSegments: matchResult['occupied'],
              ));
            }
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      // Silent fail for individual coaches
    }
  }

  /// ✅ NEW: Extract and cache ALL vacant segments (regardless of user query)
  void _extractAllVacantSegments(Map<String, dynamic> berth, dynamic coach) {
    final List<dynamic> bsd = berth['bsd'] ?? [];
    if (bsd.isEmpty) return;

    List<SegmentInfo> vacantSegs = [];
    List<SegmentInfo> occupiedSegs = [];

    for (var segment in bsd) {
      final segFrom = (segment['from'] ?? '').toString().toUpperCase();
      final segTo = (segment['to'] ?? '').toString().toUpperCase();
      final isVacant = segment['occupancy'] == false;
      final quota = segment['quota'] ?? '';

      final segInfo = SegmentInfo(
        from: segFrom,
        to: segTo,
        quota: quota,
        isVacant: isVacant,
      );

      if (isVacant) {
        vacantSegs.add(segInfo);
      } else {
        occupiedSegs.add(segInfo);
      }
    }

    // Cache ALL vacant segments
    if (vacantSegs.isNotEmpty) {
      final berthResult = VacantBerthResult(
        coachName: coach['coachName'],
        coachClass: coach['classCode'],
        berthNo: berth['berthNo'],
        berthCode: berth['berthCode'],
        cabin: berth['cabinCoupeNameNo'] ?? '',
        matchType: 'CACHE', // Dummy type for cache only
        vacantSegments: vacantSegs,
        occupiedSegments: occupiedSegs,
      );

      for (var seg in vacantSegs) {
        final key = '${seg.from}->${seg.to}';
        _segmentCache.putIfAbsent(key, () => []);
        _segmentCache[key]!.add(berthResult);
      }
    }
  }

  /// SMART LOGIC: Analyze berth segments for vacancy matches (for direct results)
  Map<String, dynamic>? _analyzeBerthSegments(
      Map<String, dynamic> berth,
      String fromStation,
      String toStation,
      ) {
    final List<dynamic> bsd = berth['bsd'] ?? [];
    if (bsd.isEmpty) return null;

    List<SegmentInfo> vacantSegs = [];
    List<SegmentInfo> occupiedSegs = [];
    bool hasMatchingVacantSegment = false;

    for (var segment in bsd) {
      final segFrom = (segment['from'] ?? '').toString().toUpperCase();
      final segTo = (segment['to'] ?? '').toString().toUpperCase();
      final isVacant = segment['occupancy'] == false;
      final quota = segment['quota'] ?? '';

      final segInfo = SegmentInfo(
        from: segFrom,
        to: segTo,
        quota: quota,
        isVacant: isVacant,
      );

      if (isVacant) {
        vacantSegs.add(segInfo);

        // Check if this vacant segment covers the user's journey
        if (_segmentCoversJourney(segFrom, segTo, fromStation, toStation)) {
          hasMatchingVacantSegment = true;
        }
      } else {
        occupiedSegs.add(segInfo);
      }
    }

    if (!hasMatchingVacantSegment) return null;

    // Determine match type
    String matchType = 'EXACT';
    if (vacantSegs.length == 1 && occupiedSegs.isEmpty) {
      matchType = 'EXACT';
    } else if (vacantSegs.isNotEmpty && occupiedSegs.isNotEmpty) {
      matchType = 'PARTIAL';
    } else if (vacantSegs.length > 1) {
      matchType = 'EXTENDED';
    }

    return {
      'type': matchType,
      'vacant': vacantSegs,
      'occupied': occupiedSegs,
    };
  }

  /// Check if segment covers the user's journey
  bool _segmentCoversJourney(
      String segFrom,
      String segTo,
      String userFrom,
      String userTo,
      ) {
    final fromIndex = _stationsList.indexOf(userFrom);
    final toIndex = _stationsList.indexOf(userTo);
    final segFromIndex = _stationsList.indexOf(segFrom);
    final segToIndex = _stationsList.indexOf(segTo);

    if (fromIndex == -1 ||
        toIndex == -1 ||
        segFromIndex == -1 ||
        segToIndex == -1) {
      return false;
    }

    // Segment must start at or before user's FROM and end at or after user's TO
    return segFromIndex <= fromIndex && segToIndex >= toIndex;
  }

  /// Submit form
  Future<bool> submitForm({
    required String trainNumber,
    required String boardingStation,
    required DateTime journeyDate,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await fetchTrainComposition(
        trainNumber: trainNumber,
        boardingStation: boardingStation,
        journeyDate: journeyDate,
      );

      _isSubmitting = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Submission failed: ${e.toString()}';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  void clearStations() {
    _stationsList = [];
    _trainDetails = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearCompositionData() {
    _trainComposition = null;
    _coachData = null;
    _vacantBerths = null;
    _multiSegmentPaths = null;
    notifyListeners();
  }

  bool isValidStation(String stationCode) {
    return _stationsList.contains(stationCode.toUpperCase());
  }

  int? getStationIndex(String stationCode) {
    final index = _stationsList.indexOf(stationCode.toUpperCase());
    return index >= 0 ? index : null;
  }

  void reset() {
    _isLoadingStations = false;
    _isSubmitting = false;
    _isFetchingComposition = false;
    _isSearchingVacancy = false;
    _isSearchingMultiSegment = false;
    _stationsList = [];
    _errorMessage = null;
    _trainDetails = null;
    _trainComposition = null;
    _coachData = null;
    _vacantBerths = null;
    _multiSegmentPaths = null;
    _boardingStation = null;
    _journeyDate = null;
    _trainNumber = null;
    _processedCoaches = 0;
    _totalCoaches = 0;
    _segmentCache.clear();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

/// Helper class for BFS pathfinding
class _PathState {
  final String currentStation;
  final List<PathSegment> segments;
  final Set<String> visitedStations;

  _PathState({
    required this.currentStation,
    required this.segments,
    required this.visitedStations,
  });
}

/// Train Details Model
class TrainDetailsModel {
  final String trainNumber;
  final String trainName;
  final List<String> stations;
  final List<String> allStationCodes;

  TrainDetailsModel({
    required this.trainNumber,
    required this.trainName,
    required this.stations,
    required this.allStationCodes,
  });
}

/// Train Model
class TrainModel {
  final String number;
  final String name;

  TrainModel({required this.number, required this.name});

  factory TrainModel.fromJson(Map<String, dynamic> json) {
    return TrainModel(
      number: json['number']?.toString() ?? '',
      name: json['name'] ?? '',
    );
  }

  @override
  String toString() => '$number - $name';

  @override
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrainModel && other.number == number;
  }

  @override
  int get hashCode => number.hashCode;
}
