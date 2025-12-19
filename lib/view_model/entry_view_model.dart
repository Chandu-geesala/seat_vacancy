import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

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

class EntryViewModel extends ChangeNotifier {
  // Loading states
  bool _isLoadingStations = false;
  bool _isSubmitting = false;
  bool _isFetchingComposition = false;
  bool _isSearchingVacancy = false;

  // Data
  List<String> _stationsList = [];
  String? _errorMessage;
  TrainDetailsModel? _trainDetails;
  Map<String, dynamic>? _trainComposition;
  List<dynamic>? _coachData;
  List<VacantBerthResult>? _vacantBerths;

  // Stored data for later use
  String? _boardingStation;
  DateTime? _journeyDate;
  String? _trainNumber;

  // Search progress
  int _processedCoaches = 0;
  int _totalCoaches = 0;

  // Getters
  bool get isLoadingStations => _isLoadingStations;
  bool get isSubmitting => _isSubmitting;
  bool get isFetchingComposition => _isFetchingComposition;
  bool get isSearchingVacancy => _isSearchingVacancy;
  List<String> get stationsList => _stationsList;
  String? get errorMessage => _errorMessage;
  TrainDetailsModel? get trainDetails => _trainDetails;
  bool get hasStations => _stationsList.isNotEmpty;
  Map<String, dynamic>? get trainComposition => _trainComposition;
  List<dynamic>? get coachData => _coachData;
  List<VacantBerthResult>? get vacantBerths => _vacantBerths;
  String? get boardingStation => _boardingStation;
  DateTime? get journeyDate => _journeyDate;
  String? get trainNumber => _trainNumber;
  double get searchProgress =>
      _totalCoaches > 0 ? _processedCoaches / _totalCoaches : 0.0;

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

      //print('🚀 Fetching train data from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timeout');
        },
      );

      //print('📡 Response status: ${response.statusCode}');

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

          //print('✅ Stations loaded: ${_stationsList.length} stations');
          //print('📍 Stations: ${_stationsList.join(", ")}');

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
      //print('❌ Exception');
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

    _trainNumber = trainNumber;
    _boardingStation = boardingStation;
    _journeyDate = journeyDate;

    notifyListeners();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(journeyDate);

      //print('=' * 80);
      //print('🚂 FETCHING TRAIN COMPOSITION');
      //print('=' * 80);

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

        //print('✅ Train composition loaded: ${_coachData!.length} coaches');
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
    _errorMessage = null;
    _processedCoaches = 0;
    _totalCoaches = _coachData!.length;
    notifyListeners();

    final fromStationUpper = fromStation.toUpperCase();
    final toStationUpper = toStation.toUpperCase();

    //print('=' * 80);
    //print('🔍 SMART VACANCY SEARCH');
    //print('FROM: $fromStationUpper → TO: $toStationUpper');
    //print('=' * 80);

    final List<VacantBerthResult> results = [];

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
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

      //print('=' * 80);
      //print('🎯 SEARCH COMPLETE!');
      //print('Total Results: ${results.length}');
      //print('Coaches with vacancy: ${results.map((r) => r.coachName).toSet().length}');
      //print('=' * 80);

      _vacantBerths = results;
      _isSearchingVacancy = false;
      notifyListeners();
      return true;
    } catch (e) {
      //print('❌ Search Exception ');
      _errorMessage = 'Search failed ';
      _isSearchingVacancy = false;
      notifyListeners();
      return false;
    }
  }

  /// Process single coach for vacancy
  Future<void> _processCoach(
      dynamic coach,
      String fromStation,
      String toStation,
      Map<String, String> headers,
      List<VacantBerthResult> results,
      ) async {
    try {
      //print('🔵 Checking ${coach['coachName']} (${coach['classCode']})');

      final payload = {
        'trainNo': _trainComposition!['trainNo'],
        'boardingStation': _boardingStation ?? _trainComposition!['from'],
        'remoteStation': _trainComposition!['remote'],
        'trainSourceStation': _trainComposition!['from'],
        'jDate': DateFormat('yyyy-MM-dd').format(_journeyDate ?? DateTime.now()),
        'coach': coach['coachName'],
        'cls': coach['classCode'],
      };

      final response = await http.post(
        Uri.parse('https://www.irctc.co.in/online-charts/api/coachComposition'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] == null || data['error'].toString().isEmpty) {
          List<dynamic> berths = data['bdd'] ?? [];

          for (var berth in berths) {
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
      //print('❌ Error fetching ${coach['coachName']} ');
    }
  }

  /// SMART LOGIC: Analyze berth segments for vacancy matches
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
      matchType = 'EXACT'; // Fully vacant
    } else if (vacantSegs.isNotEmpty && occupiedSegs.isNotEmpty) {
      matchType = 'PARTIAL'; // Some segments occupied
    } else if (vacantSegs.length > 1) {
      matchType = 'EXTENDED'; // Vacant beyond user's journey
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

    if (fromIndex == -1 || toIndex == -1 ||
        segFromIndex == -1 || segToIndex == -1) {
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
    _stationsList = [];
    _errorMessage = null;
    _trainDetails = null;
    _trainComposition = null;
    _coachData = null;
    _vacantBerths = null;
    _boardingStation = null;
    _journeyDate = null;
    _trainNumber = null;
    _processedCoaches = 0;
    _totalCoaches = 0;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrainModel && other.number == number;
  }

  @override
  int get hashCode => number.hashCode;
}
