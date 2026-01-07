import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:seat_vacancy/view_model/entry_view_model.dart';

import 'coach_page.dart';

class EntryPage extends StatefulWidget {
  const EntryPage({Key? key}) : super(key: key);

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _trainNumberController = TextEditingController();

  // Add these new variables
  final _stationSearchController = TextEditingController();
  final _stationSearchFocusNode = FocusNode();
  OverlayEntry? _stationOverlayEntry;
  final LayerLink _stationLayerLink = LayerLink();
  bool _manualStationSelection = false; // Flag to enable manual search



  DateTime? _selectedDate;
  List<TrainModel> _trains = [];
  TrainModel? _selectedTrain;
  String? _selectedBoardingStation;

  // ✅ ADD these at the top of _EntryPageState class
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _showDropdown = false;



  // ✅ NEW: Station code to name mapping
  Map<String, String> _stationNames = {};



  Future<void> _loadTrains() async {
    try {
      final String response = await rootBundle.loadString('assets/trains.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _trains = data.map((json) => TrainModel.fromJson(json)).toList();
      });
    } catch (e) {
      //print('Error loading trains');
    }
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
      //print('Error loading stations');
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
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
            dialogBackgroundColor: Colors.white,
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

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      _showSnackBar('Please select journey date', isError: true);
      return;
    }

    if (_selectedTrain == null) {
      _showSnackBar('Please select a valid train', isError: true);
      return;
    }

    if (_selectedBoardingStation == null) {
      _showSnackBar('Please select boarding station', isError: true);
      return;
    }

    final viewModel = context.read<EntryViewModel>();
    final success = await viewModel.submitForm(
      trainNumber: _selectedTrain!.number,
      boardingStation: _selectedBoardingStation!,
      journeyDate: _selectedDate!,
    );

    if (success) {
      // Navigate to CoachPage on success
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CoachPage(),
          ),
        );
      }
    } else {
      _showSnackBar(viewModel.errorMessage ?? 'Submission failed', isError: true);
    }
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
      backgroundColor: const Color(0xFF6366F1),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          if (isDesktop) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ CHANGED: Replace Icon with logo image
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://i.ibb.co/93Np01wb/playstore.png',
                      width: 164,
                      height: 164,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.train_rounded,
                          size: 48,
                          color: Colors.white,
                        );
                      },
                    ),
                  ),

                ),
                const SizedBox(height: 32),
                const Text(
                  'Kali RailSeat',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Check which train seats are actually vacant between your boarding and destination stations, even after the chart is prepared.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(60),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    _buildFormHeader(),
                    const SizedBox(height: 32),
                    _buildForm(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildMobileHeader(),
            const SizedBox(height: 40),
            _buildFormCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        // ✅ CHANGED: Replace Icon with logo image
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            // decoration: const BoxDecoration(
            //   color: Colors.white,
            //   shape: BoxShape.circle,
            // ),
            child: ClipOval(
              child: Image.network(
                'https://i.ibb.co/93Np01wb/playstore.png',
                width: 148,
                height: 148,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.train_rounded,
                    size: 48,
                    color: Color(0xFF6366F1),
                  );
                },
              ),
            ),

          ),
        ),
        // const SizedBox(height: 24),
        // const Text(
        //   'Kali RailSeat',
        //   style: TextStyle(
        //     fontSize: 28,
        //     fontWeight: FontWeight.bold,
        //     color: Colors.white,
        //   ),
        //   textAlign: TextAlign.center,
        // ),
        const SizedBox(height: 12),
        Text(
          'Check which train seats are actually vacant between your boarding and destination stations, even after the chart is prepared.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
//


  Widget _buildFormHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

          const SizedBox(height: 24),
          _buildForm(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTrainNumberField(),
          const SizedBox(height: 20),
          _buildBoardingStationField(),
          const SizedBox(height: 20),
          _buildDateField(),
          const SizedBox(height: 28),
          _buildSubmitButton(),
        ],
      ),
    );
  }

// ✅ ADD THIS: Class-level FocusNode
  late FocusNode _trainNumberFocusNode;

  @override
  void initState() {
    super.initState();
    _trainNumberFocusNode = FocusNode();
    _selectedDate = DateTime.now();
    // ✅ Initialize here
    _loadTrains();
    _loadStations();
  }

  @override
  void dispose() {
    _trainNumberController.dispose();
    _trainNumberFocusNode.dispose();
    _stationSearchController.dispose(); // Add this
    _stationSearchFocusNode.dispose(); // Add this
    _removeOverlay();
    _removeStationOverlay(); // Add this
    super.dispose();
  }

  Widget _buildBoardingStationField() {
    return Consumer<EntryViewModel>(
      builder: (context, viewModel, child) {
        final isEnabled = _selectedTrain != null && !viewModel.isLoadingStations;
        final hasStations = viewModel.hasStations;
        final hasError = viewModel.errorMessage != null && _selectedTrain != null;

        // Enable manual search if API failed
        if (hasError && !_manualStationSelection) {
          _manualStationSelection = true;
        }

        // Reset manual mode when new train selected successfully
        if (hasStations && _manualStationSelection) {
          _manualStationSelection = false;
          _stationSearchController.clear();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Boarding Station',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
                if (viewModel.isLoadingStations) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Train not selected
            if (!isEnabled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.grey[400], size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Select a train first',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ]
            // Loading stations
            else if (viewModel.isLoadingStations) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading stations...',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ]
            // API succeeded - show dropdown
            else if (hasStations && !_manualStationSelection) ...[
                DropdownButtonFormField<String>(
                  value: _selectedBoardingStation,
                  menuMaxHeight: 300,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFF6366F1), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  hint: Text(
                    'Select boarding station',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    return viewModel.stationsList.map<Widget>((String station) {
                      return Text(
                        _getStationDisplay(station),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }).toList();
                  },
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6366F1)),
                  isExpanded: true,
                  items: viewModel.stationsList.map((String station) {
                    final index = viewModel.getStationIndex(station) ?? 0;
                    return DropdownMenuItem<String>(
                      value: station,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getStationDisplay(station),
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      _selectedBoardingStation = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select boarding station';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '${viewModel.stationsList.length} stations available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ]
              // API failed OR manual search enabled - show search field
              else if (hasError || _manualStationSelection) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Warning message
                      if (hasError) ...[
                        // Container(
                        //   padding: const EdgeInsets.all(12),
                        //   decoration: BoxDecoration(
                        //     color: Colors.orange[50],
                        //     borderRadius: BorderRadius.circular(8),
                        //     border: Border.all(color: Colors.orange[200]!),
                        //   ),
                        //   child: Row(
                        //     children: [
                        //       Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        //       const SizedBox(width: 12),
                        //       Expanded(
                        //         child: Text(
                        //           'Station data unavailable. Search manually from all stations.',
                        //           style: TextStyle(
                        //             fontSize: 13,
                        //             color: Colors.orange[900],
                        //             fontWeight: FontWeight.w500,
                        //           ),
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        // const SizedBox(height: 12),
                      ],

                      // Search field with overlay
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return CompositedTransformTarget(
                            link: _stationLayerLink,
                            child: TextFormField(
                              controller: _stationSearchController,
                              focusNode: _stationSearchFocusNode,
                              style: const TextStyle(fontSize: 15),
                              onTap: () {
                                if (_stationSearchController.text.trim().isNotEmpty) {
                                  _showStationOverlay(context, constraints);
                                }
                              },
                              onChanged: (value) {
                                // Clear selection if user modifies text
                                if (_selectedBoardingStation != null &&
                                    value != _getStationDisplay(_selectedBoardingStation!)) {
                                  setState(() {
                                    _selectedBoardingStation = null;
                                  });
                                }

                                // Show/update dropdown on every change
                                if (value.trim().isNotEmpty) {
                                  _showStationOverlay(context, constraints);
                                } else {
                                  _removeStationOverlay();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Search by station name or code',
                                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1), size: 20),
                                suffixIcon: _stationSearchController.text.isNotEmpty
                                    ? IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                                  onPressed: () {
                                    _stationSearchController.clear();
                                    setState(() {
                                      _selectedBoardingStation = null;
                                    });
                                    _removeStationOverlay();
                                    _stationSearchFocusNode.requestFocus();
                                  },
                                )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: _selectedBoardingStation != null
                                        ? const Color(0xFF10B981)
                                        : Colors.grey[200]!,
                                    width: _selectedBoardingStation != null ? 2 : 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              validator: (value) {
                                if (_selectedBoardingStation == null || _selectedBoardingStation!.isEmpty) {
                                  return 'Please select a boarding station';
                                }
                                return null;
                              },
                            ),
                          );
                        },
                      ),

                      // Selected station confirmation
                      if (_selectedBoardingStation != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getStationDisplay(_selectedBoardingStation!),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
          ],
        );
      },
    );
  }



  void _showStationOverlay(BuildContext context, BoxConstraints constraints) {
    _removeStationOverlay();

    final searchText = _stationSearchController.text.trim();
    if (searchText.isEmpty) return;

    final lowerSearchText = searchText.toLowerCase();

    // Search through all stations from stations.json
    final matches = _stationNames.entries.where((entry) {
      final code = entry.key.toLowerCase();
      final name = entry.value.toLowerCase();
      return code.contains(lowerSearchText) || name.contains(lowerSearchText);
    }).take(10).toList();

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _stationOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _stationLayerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: matches.isEmpty
                ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                color: const Color(0xFFEF4444).withOpacity(0.05),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No matching stations found',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final entry = matches[index];
                  final code = entry.key;
                  final name = entry.value;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedBoardingStation = code;
                        _stationSearchController.text = _getStationDisplay(code);
                      });
                      _removeStationOverlay();
                      _stationSearchFocusNode.unfocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedBoardingStation == code
                            ? const Color(0xFF6366F1).withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_stationOverlayEntry!);
  }



  void _removeStationOverlay() {
    _stationOverlayEntry?.remove();
    _stationOverlayEntry = null;
  }


  Widget _buildTrainNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Train Number',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return CompositedTransformTarget(
              link: _layerLink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _trainNumberController,
                    focusNode: _trainNumberFocusNode,
                    style: const TextStyle(fontSize: 15),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]')),
                    ],
                    onTap: () {
                      // ✅ Show dropdown when field is tapped
                      if (_trainNumberController.text.trim().isNotEmpty) {
                        _showOverlay(context, constraints);
                      }
                    },
                    onChanged: (value) {
                      // Clear selection if user modifies text
                      if (_selectedTrain != null && value != _selectedTrain!.number) {
                        setState(() {
                          _selectedTrain = null;
                          _selectedBoardingStation = null;
                        });
                        context.read<EntryViewModel>().clearStations();
                      }

                      // ✅ Show/update dropdown on every change
                      if (value.trim().isNotEmpty) {
                        _showOverlay(context, constraints);
                      } else {
                        _removeOverlay();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by train number or name',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.train_outlined, color: Color(0xFF6366F1), size: 20),
                      suffixIcon: _trainNumberController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                        onPressed: () {
                          _trainNumberController.clear();
                          setState(() {
                            _selectedTrain = null;
                            _selectedBoardingStation = null;
                          });
                          context.read<EntryViewModel>().clearStations();
                          _removeOverlay();
                          _trainNumberFocusNode.requestFocus();
                        },
                      )
                          : const Icon(Icons.search, color: Colors.grey, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _selectedTrain != null
                              ? const Color(0xFF10B981)
                              : Colors.grey[200]!,
                          width: _selectedTrain != null ? 2 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFEF4444)),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please select a train';
                      }
                      if (_selectedTrain == null) {
                        return 'Please select a train from the dropdown';
                      }
                      return null;
                    },
                  ),
                  if (_selectedTrain != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedTrain!.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

// ✅ ADD this method to remove overlay
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _showDropdown = false;
  }

// ✅ ADD this method to show overlay
  void _showOverlay(BuildContext context, BoxConstraints constraints) {
    _removeOverlay();

    final searchText = _trainNumberController.text.trim();
    if (searchText.isEmpty) return;

    final lowerSearchText = searchText.toLowerCase();
    final matches = _trains.where((train) {
      return train.number.toLowerCase().contains(lowerSearchText) ||
          train.name.toLowerCase().contains(lowerSearchText);
    }).take(10).toList();

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: matches.isEmpty
                ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                color: const Color(0xFFEF4444).withOpacity(0.05),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No matching trains found',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final train = matches[index];
                  return InkWell(
// In _showOverlay method, inside InkWell onTap:
                    onTap: () async {
                      setState(() {
                        _selectedTrain = train;
                        _trainNumberController.text = train.number;
                        _selectedBoardingStation = null;
                        _manualStationSelection = false; // ADD THIS LINE
                        _stationSearchController.clear(); // ADD THIS LINE
                      });

                      final viewModel = context.read<EntryViewModel>();
                      await viewModel.fetchTrainStations(train.number);

                      _removeOverlay();
                      _trainNumberFocusNode.unfocus();
                    },

                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTrain?.number == train.number
                            ? const Color(0xFF6366F1).withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              train.number,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              train.name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _showDropdown = true;
  }



  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Journey Date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'Select journey date'
                        : DateFormat('dd MMM yyyy, EEEE').format(_selectedDate!),
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedDate == null ? Colors.grey[400] : const Color(0xFF1F2937),
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Consumer<EntryViewModel>(
      builder: (context, viewModel, child) {
        final isLoading = viewModel.isSubmitting;

        return SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text(
              'Find Vacant Berths',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}

// Train Model
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
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
