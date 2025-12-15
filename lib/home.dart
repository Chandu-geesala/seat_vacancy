import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  final _trainNumberController = TextEditingController();
  final _boardingStationController = TextEditingController();
  final _searchFromStationController = TextEditingController();
  // NEW: optional TO station controller
  final _searchToStationController = TextEditingController();

  DateTime? _selectedDate;

  bool _isLoading = false;
  bool _isSearchingVacancy = false;
  Map<String, dynamic>? _trainData;
  List<dynamic>? _coachData;
  List<Map<String, dynamic>>? _vacantBerths;
  String? _errorMessage;

  @override
  void dispose() {
    _trainNumberController.dispose();
    _boardingStationController.dispose();
    _searchFromStationController.dispose();
    _searchToStationController.dispose(); // NEW
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1976D2),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _printSeparator() {
    print('=' * 80);
  }

  void _printLog(String message) {
    print('🔵 $message');
  }

  void _printSuccess(String message) {
    print('✅ $message');
  }

  void _printError(String message) {
    print('❌ $message');
  }

  Future<void> _fetchTrainData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnackBar('Please select journey date', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _trainData = null;
      _coachData = null;
      _vacantBerths = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      _printSeparator();
      _printLog('🚂 FETCHING TRAIN COMPOSITION');
      _printSeparator();

      final payload = {
        'trainNo': _trainNumberController.text.trim(),
        'jDate': dateStr,
        'boardingStation': _boardingStationController.text.trim().toUpperCase(),
      };

      _printLog('Request Payload:');
      print(JsonEncoder.withIndent('  ').convert(payload));

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Origin': 'https://www.irctc.co.in',
        'Referer': 'https://www.irctc.co.in/online-charts/',
      };

      final url = 'https://www.irctc.co.in/online-charts/api/trainComposition';

      final compositionResponse = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      );

      _printSeparator();
      _printLog('📦 FULL RAW RESPONSE:');
      _printSeparator();
      print(compositionResponse.body);
      _printSeparator();

      if (compositionResponse.statusCode == 200) {
        _printSuccess('HTTP 200 OK - Request Successful');

        final data = jsonDecode(compositionResponse.body);

        _printLog('Parsed JSON Response:');
        print(JsonEncoder.withIndent('  ').convert(data));
        _printSeparator();

        if (data['error'] != null && data['error'].toString().isNotEmpty) {
          _printError('API returned error: ${data['error']}');
          setState(() {
            _errorMessage = data['error'];
            _isLoading = false;
          });
          return;
        }

        final coaches = data['cdd'] ?? [];

        _printSuccess('Train Data Extracted:');
        print('  Train: ${data['trainName']} (${data['trainNo']})');
        print('  Route: ${data['from']} → ${data['to']}');
        print('  Total Coaches: ${coaches.length}');

        setState(() {
          _trainData = data;
          _coachData = coaches;
          _isLoading = false;
        });

        _printSeparator();
        _printSuccess('✨ DATA SUCCESSFULLY LOADED TO UI');
        _printSeparator();

        _showSnackBar('Train data fetched successfully!', isError: false);
      } else {
        _printError('HTTP Error ${compositionResponse.statusCode}');
        setState(() {
          _errorMessage = 'Failed to fetch data. Status: ${compositionResponse.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      _printSeparator();
      _printError('Exception Occurred: $e');
      print('Stack Trace:');
      print(stackTrace);
      _printSeparator();

      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchVacantBerths() async {
    if (_trainData == null || _coachData == null) {
      _showSnackBar('Please fetch train data first', isError: true);
      return;
    }

    if (_selectedDate == null) {
      _showSnackBar('Please select journey date', isError: true);
      return;
    }

    if (_searchFromStationController.text.trim().isEmpty) {
      _showSnackBar('Please enter FROM station to search', isError: true);
      return;
    }

    setState(() {
      _isSearchingVacancy = true;
      _vacantBerths = null;
      _errorMessage = null;
    });

    final fromStation = _searchFromStationController.text.trim().toUpperCase();
    final toStationRaw = _searchToStationController.text.trim();
    final String? toStation =
    toStationRaw.isEmpty ? null : toStationRaw.toUpperCase(); // optional

    _printSeparator();
    _printLog('🔍 SEARCHING VACANT BERTHS');
    _printLog('FROM: $fromStation, TO: ${toStation ?? "(ANY)"}');
    _printSeparator();

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final boardingStation = _boardingStationController.text.trim().toUpperCase();
    final List<Map<String, dynamic>> allVacantBerths = [];

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Origin': 'https://www.irctc.co.in',
        'Referer': 'https://www.irctc.co.in/online-charts/',
      };

      int processedCoaches = 0;
      int totalVacantFound = 0;

      for (var coach in _coachData!) {
        processedCoaches++;

        _printLog(
            '[$processedCoaches/${_coachData!.length}] Checking ${coach['coachName']} (${coach['classCode']})');

        final payload = {
          'trainNo': _trainData!['trainNo'],
          'boardingStation': boardingStation,
          'remoteStation': _trainData!['remote'],
          'trainSourceStation': _trainData!['from'],
          'jDate': dateStr,
          'coach': coach['coachName'],
          'cls': coach['classCode'],
        };

        try {
          final response = await http.post(
            Uri.parse('https://www.irctc.co.in/online-charts/api/coachComposition'),
            headers: headers,
            body: jsonEncode(payload),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

            // sample shape you mentioned:
            // {
            //   "chartStatusResponseDto": {...},
            //   "coach_berth_data": [
            //     {
            //        "coach_name": "A1",
            //        "coach_class": "2A",
            //        "berth_details": { "bdd": [ ... ] }
            //     }
            //   ]
            // }

            if (data['error'] == null || data['error'].toString().isEmpty) {
              // get berth list depending on shape
              List<dynamic> berths;
              if (data['bdd'] != null) {
                berths = data['bdd'];
              } else if (data['coach_berth_data'] != null &&
                  data['coach_berth_data'] is List &&
                  (data['coach_berth_data'] as List).isNotEmpty &&
                  (data['coach_berth_data'][0]['berth_details']?['bdd']) != null) {
                berths = data['coach_berth_data'][0]['berth_details']['bdd'];
              } else {
                berths = [];
              }

              for (var berth in berths) {
                final bsd = berth['bsd'] ?? [];

                for (var segment in bsd) {
                  final segFrom = (segment['from'] ?? '').toString().toUpperCase();
                  final segTo = (segment['to'] ?? '').toString().toUpperCase();
                  final bool isVacant = segment['occupancy'] == false;

                  // condition:
                  // 1) FROM always must match
                  // 2) TO matches only if user entered it, otherwise ignore TO
                  final bool matchesFrom = segFrom == fromStation;
                  final bool matchesTo = toStation == null ? true : segTo == toStation;

                  if (matchesFrom && matchesTo && isVacant) {
                    allVacantBerths.add({
                      'coach_name': coach['coachName'],
                      'coach_class': coach['classCode'],
                      'berth_no': berth['berthNo'],
                      'berth_code': berth['berthCode'],
                      'cabin': berth['cabinCoupeNameNo'],
                      'from': segFrom,
                      'to': segTo,
                      'quota': segment['quota'],
                      'all_segments': bsd,
                    });
                    totalVacantFound++;
                    break; // move to next berth
                  }
                }
              }

              _printSuccess(
                  'Found ${berths.length} berths, ${allVacantBerths.where((b) => b['coach_name'] == coach['coachName']).length} vacant matching filter');
            }
          }

          // Small delay to avoid overwhelming the server
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          _printError('Error fetching ${coach['coachName']}: $e');
        }
      }

      _printSeparator();
      _printSuccess('🎯 SEARCH COMPLETE!');
      print('Total Vacant Berths Found: $totalVacantFound');
      print('Across ${allVacantBerths.map((b) => b['coach_name']).toSet().length} coaches');
      _printSeparator();

      setState(() {
        _vacantBerths = allVacantBerths;
        _isSearchingVacancy = false;
      });

      if (allVacantBerths.isEmpty) {
        final toText = toStation == null ? '' : ' to $toStation';
        _showSnackBar(
          'No vacant berths found from $fromStation$toText',
          isError: false,
        );
      } else {
        _showSnackBar('Found $totalVacantFound vacant berths!', isError: false);
      }
    } catch (e) {
      _printError('Search Exception: $e');
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isSearchingVacancy = false;
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.train, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      'Smart Vacancy Finder',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find vacant berths from any station',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInputForm(),
                        const SizedBox(height: 24),
                        if (_isLoading) _buildLoadingWidget('Fetching train data...'),
                        if (_isSearchingVacancy)
                          _buildLoadingWidget('Searching vacant berths...'),
                        if (_errorMessage != null) _buildErrorWidget(),
                        if (_trainData != null && !_isSearchingVacancy)
                          _buildSearchSection(),
                        const SizedBox(height: 16),
                        if (_vacantBerths != null) _buildVacantBerthsWidget(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter Journey Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _trainNumberController,
              decoration: const InputDecoration(
                labelText: 'Train Number',
                hintText: 'e.g., 18464',
                prefixIcon: Icon(Icons.train_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter train number';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _boardingStationController,
              decoration: const InputDecoration(
                labelText: 'Boarding Station (for API)',
                hintText: 'e.g., HUP, NDLS, SBC',
                prefixIcon: Icon(Icons.location_on_outlined),
                helperText: 'Required for API call',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter boarding station';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Journey Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'Select date'
                      : DateFormat('dd MMM yyyy').format(_selectedDate!),
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDate == null ? Colors.grey[600] : Colors.black87,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchTrainData,
              icon: const Icon(Icons.search),
              label: const Text(
                'Fetch Train Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trainData!['trainName'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_coachData!.length} coaches • Ready to search',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white30, height: 1),
          const SizedBox(height: 20),

          const Text(
            'Search Vacant Berths',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          // FROM Station Input
          TextFormField(
            controller: _searchFromStationController,
            decoration: InputDecoration(
              labelText: 'FROM Station',
              hintText: 'e.g., SBC, NDLS, HUP',
              prefixIcon: const Icon(Icons.my_location),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              helperText: 'Required: station you want to board from',
              helperStyle: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            textCapitalization: TextCapitalization.characters,
          ),

          const SizedBox(height: 12),

          // NEW: TO Station Input (optional)
          TextFormField(
            controller: _searchToStationController,
            decoration: InputDecoration(
              labelText: 'TO Station (optional)',
              hintText: 'e.g., BBS, VSKP',
              prefixIcon: const Icon(Icons.flag_circle_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              helperText:
              'Leave empty to see all vacant berths from FROM station till wherever vacant',
              helperStyle: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            textCapitalization: TextCapitalization.characters,
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isSearchingVacancy ? null : _searchVacantBerths,
            icon: const Icon(Icons.manage_search, size: 24),
            label: const Text(
              'Find Vacant Berths',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4CAF50),
              padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          if (_isSearchingVacancy) ...[
            const SizedBox(height: 8),
            Text(
              'This may take a minute...',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacantBerthsWidget() {
    if (_vacantBerths!.isEmpty) {
      final from = _searchFromStationController.text.toUpperCase();
      final toRaw = _searchToStationController.text.trim();
      final to = toRaw.isEmpty ? null : toRaw.toUpperCase();

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
              to == null
                  ? 'from $from'
                  : 'from $from to $to',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Group by coach
    final groupedByCoach = <String, List<Map<String, dynamic>>>{};
    for (var berth in _vacantBerths!) {
      final coachName = berth['coach_name'];
      if (!groupedByCoach.containsKey(coachName)) {
        groupedByCoach[coachName] = [];
      }
      groupedByCoach[coachName]!.add(berth);
    }

    final from = _searchFromStationController.text.toUpperCase();
    final toRaw = _searchToStationController.text.trim();
    final to = toRaw.isEmpty ? null : toRaw.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Vacant Berths',
                '${_vacantBerths!.length}',
                Icons.event_seat,
              ),
              Container(
                  width: 2,
                  height: 40,
                  color: Colors.white.withOpacity(0.3)),
              _buildSummaryItem(
                'Coaches',
                '${groupedByCoach.length}',
                Icons.train,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          to == null
              ? 'Available Berths from $from'
              : 'Available Berths from $from to $to',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF263238),
          ),
        ),

        const SizedBox(height: 12),

        // Berth cards grouped by coach
        ...groupedByCoach.entries.map((entry) {
          return _buildCoachGroupCard(entry.key, entry.value);
        }).toList(),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCoachGroupCard(String coachName, List<Map<String, dynamic>> berths) {
    final firstBerth = berths.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
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
              color: const Color(0xFF4CAF50).withOpacity(0.1),
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
                    color: const Color(0xFF4CAF50),
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
                          color: Color(0xFF263238),
                        ),
                      ),
                      Text(
                        'Class: ${firstBerth['coach_class']} • ${berths.length} vacant berths',
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
              children:
              berths.map((berth) => _buildBerthChip(berth)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBerthChip(Map<String, dynamic> berth) {
    return InkWell(
      onTap: () {
        _showBerthDetailsDialog(berth);
      },
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
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
              '${berth['berth_no']} (${berth['berth_code']})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBerthDetailsDialog(Map<String, dynamic> berth) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event_seat,
                      color: Color(0xFF4CAF50),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Berth #${berth['berth_no']} (${berth['berth_code']})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Coach ${berth['coach_name']} • Cabin ${berth['cabin']}',
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
                'Route Segments:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...((berth['all_segments'] ?? []) as List).map((segment) {
                final isVacant = segment['occupancy'] == false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isVacant
                              ? const Color(0xFF4CAF50)
                              : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${segment['from']} → ${segment['to']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Quota: ${segment['quota']} • ${isVacant ? 'VACANT' : 'OCCUPIED'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(vertical: 12),
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
