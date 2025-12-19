import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seat_vacancy/view_model/entry_view_model.dart';
import 'entry_page.dart';

void main() {
  runApp(const KaliRailSeatApp());
}

/// KaliRailSeat App
/// Purpose:
/// Check which train seats are actually vacant between your boarding
/// and destination stations, even after the reservation chart is prepared.
class KaliRailSeatApp extends StatelessWidget {
  const KaliRailSeatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EntryViewModel(),
      child: MaterialApp(
        title: 'KaliRailSeat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,

          /// Brand colors
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E40AF), // Rail Blue
            brightness: Brightness.light,
          ),

          scaffoldBackgroundColor: const Color(0xFFF5F7FA),

          /// Input fields (station search, train number, etc.)
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1E40AF),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),

          /// Buttons (Search Vacant Seats)
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),

        /// Entry Page (Intro + Search)
        home: const EntryPage(),
      ),
    );
  }
}
