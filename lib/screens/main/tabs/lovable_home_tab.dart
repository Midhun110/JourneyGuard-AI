import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/place_suggestion.dart';
import '../../../services/location_service.dart';
import '../../../services/routing_service.dart';
import '../../../services/notification_service.dart';
import '../../route_risk/route_risk_screen.dart';
import '../../settings/settings_screen.dart';
import '../../notifications/notification_center_screen.dart';

class LovableHomeTab extends StatefulWidget {
  final VoidCallback? onSwitchToPlan;

  const LovableHomeTab({super.key, this.onSwitchToPlan});

  @override
  State<LovableHomeTab> createState() => _LovableHomeTabState();
}

class _LovableHomeTabState extends State<LovableHomeTab> {
  final _fromController = TextEditingController(text: 'Current location');
  final _toController = TextEditingController(text: 'Kochi International Airport');
  final _routingService = RoutingService();
  final _locationService = LocationService();

  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  LatLng? _fromLatLng;
  LatLng? _toLatLng;
  bool _isAnalyzing = false;
  bool _isGettingLocation = false;

  Timer? _fromDebounceTimer;
  Timer? _toDebounceTimer;
  bool _isSearchingFrom = false;
  bool _isSearchingTo = false;
  bool _hasSearchedFrom = false;
  bool _hasSearchedTo = false;

  List<PlaceSuggestion> _fromSuggestions = [];
  List<PlaceSuggestion> _toSuggestions = [];
  bool _showFromSuggestions = false;
  bool _showToSuggestions = false;

  @override
  void initState() {
    super.initState();
    _initDefaultCoordinates();
  }

  Future<void> _initDefaultCoordinates() async {
    // Default coordinates: Kochi City Center to Kochi Airport
    _fromLatLng = const LatLng(9.9816, 76.2999);
    _toLatLng = const LatLng(10.1520, 76.3922);
  }

  @override
  void dispose() {
    _fromDebounceTimer?.cancel();
    _toDebounceTimer?.cancel();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        final name = await _routingService.reverseGeocode(pos);
        setState(() {
          _fromLatLng = pos;
          _fromController.text = name ?? 'Current location';
        });
        _showMessage('Location updated to your current position');
      } else {
        _showError('Unable to get GPS location. Please check permissions.');
      }
    } catch (_) {
      _showError('Could not fetch location.');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _searchFrom(String query) {
    _fromDebounceTimer?.cancel();
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) {
      setState(() {
        _fromSuggestions = [];
        _showFromSuggestions = false;
        _isSearchingFrom = false;
        _hasSearchedFrom = false;
      });
      return;
    }

    setState(() {
      _isSearchingFrom = true;
      _showFromSuggestions = true;
      _hasSearchedFrom = false;
    });

    _fromDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _routingService.searchPlaceSuggestions(cleanQuery);
        if (mounted) {
          setState(() {
            _fromSuggestions = results;
            _isSearchingFrom = false;
            _hasSearchedFrom = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _fromSuggestions = [];
            _isSearchingFrom = false;
            _hasSearchedFrom = true;
          });
        }
      }
    });
  }

  void _searchTo(String query) {
    _toDebounceTimer?.cancel();
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) {
      setState(() {
        _toSuggestions = [];
        _showToSuggestions = false;
        _isSearchingTo = false;
        _hasSearchedTo = false;
      });
      return;
    }

    setState(() {
      _isSearchingTo = true;
      _showToSuggestions = true;
      _hasSearchedTo = false;
    });

    _toDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _routingService.searchPlaceSuggestions(cleanQuery);
        if (mounted) {
          setState(() {
            _toSuggestions = results;
            _isSearchingTo = false;
            _hasSearchedTo = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _toSuggestions = [];
            _isSearchingTo = false;
            _hasSearchedTo = true;
          });
        }
      }
    });
  }

  void _selectFromSuggestion(PlaceSuggestion place) {
    _fromDebounceTimer?.cancel();
    setState(() {
      _fromController.text = place.name;
      _fromLatLng = place.latLng;
      _fromSuggestions = [];
      _showFromSuggestions = false;
      _isSearchingFrom = false;
      _hasSearchedFrom = false;
    });
  }

  void _selectToSuggestion(PlaceSuggestion place) {
    _toDebounceTimer?.cancel();
    setState(() {
      _toController.text = place.name;
      _toLatLng = place.latLng;
      _toSuggestions = [];
      _showToSuggestions = false;
      _isSearchingTo = false;
      _hasSearchedTo = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.lovableGreen,
            onPrimary: Colors.black,
            surface: Color(0xFF111927),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.lovableGreen,
            onPrimary: Colors.black,
            surface: Color(0xFF111927),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _analyzeRoute() async {
    if (_fromController.text.trim().isEmpty) {
      _showError('Please specify starting location.');
      return;
    }
    if (_toController.text.trim().isEmpty) {
      _showError('Please specify destination.');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      _fromLatLng ??= await _routingService.geocodePlace(_fromController.text);
      _toLatLng ??= await _routingService.geocodePlace(_toController.text);

      if (_fromLatLng == null || _toLatLng == null) {
        _showError('Could not locate one of the points. Try selecting from search.');
        setState(() => _isAnalyzing = false);
        return;
      }

      final routes = await _routingService.fetchRoutes(
        origin: _fromLatLng!,
        destination: _toLatLng!,
      );

      if (routes.isEmpty) {
        _showError('No routes found between these locations.');
        setState(() => _isAnalyzing = false);
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RouteRiskScreen(
            routes: routes,
            fromName: _fromController.text,
            toName: _toController.text,
            departureTime: _selectedDateTime,
            fromLocation: _fromLatLng!,
            toLocation: _toLatLng!,
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to analyze route. Please verify network connection.');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.riskCritical,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.lovableGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd-MM-yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Brand Header
              _buildTopHeader(),
              const SizedBox(height: 24),

              // Greeting & Headline
              _buildGreeting(),
              const SizedBox(height: 20),

              // Location Input Card
              _buildLocationCard(),
              const SizedBox(height: 16),

              // Date & Time Picker Row
              _buildDateTimeRow(dateFormat, timeFormat),
              const SizedBox(height: 20),

              // Primary CTA Button
              _buildAnalyzeButton(),
              const SizedBox(height: 24),

              // Weather At Departure Card
              _buildWeatherDepartureCard(),
              const SizedBox(height: 20),

              // Live Status Chips
              _buildLiveStatusChips(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lovableGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.lovableGreen.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.lovableGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JOURNEYGUARD AI',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Plan your journey',
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Notification Center button (Module G)
            ListenableBuilder(
              listenable: NotificationService.instance,
              builder: (context, _) {
                final unread = NotificationService.instance.unreadCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Alerts & Push Notifications',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationCenterScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.lovableTeal,
                        size: 21,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceFor(context),
                        padding: const EdgeInsets.all(10),
                        side: BorderSide(color: AppColors.borderFor(context)),
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.riskCritical,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),
            // Settings button (Requirement 1)
            IconButton(
              tooltip: 'Settings & Theme',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.lovableTeal,
                size: 21,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceFor(context),
                padding: const EdgeInsets.all(10),
                side: BorderSide(color: AppColors.borderFor(context)),
              ),
            ),
            const SizedBox(width: 8),
            // Circular GPS button
            IconButton(
              onPressed: _isGettingLocation ? null : _useMyLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.lovableGreen,
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.lovableTeal,
                      size: 21,
                    ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceFor(context),
                padding: const EdgeInsets.all(10),
                side: BorderSide(color: AppColors.borderFor(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning, Midhun',
          style: TextStyle(
            color: AppColors.textSecondaryFor(context),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Where are you heading today?',
          style: TextStyle(
            color: AppColors.textPrimaryFor(context),
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: AppColors.cardShadowFor(context),
      ),
      child: Column(
        children: [
          // FROM Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.lovableGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lovableGreen,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FROM',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextField(
                      controller: _fromController,
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        hintText: 'Starting location',
                        hintStyle: TextStyle(color: AppColors.textMutedFor(context)),
                      ),
                      onChanged: _searchFrom,
                    ),
                  ],
                ),
              ),
              if (_isSearchingFrom)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.lovableGreen),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(Icons.gps_fixed, size: 18, color: AppColors.textMutedFor(context)),
                  onPressed: _useMyLocation,
                  tooltip: 'Current location',
                ),
            ],
          ),

          if (_showFromSuggestions &&
              (_isSearchingFrom ||
                  _fromSuggestions.isNotEmpty ||
                  (_hasSearchedFrom && _fromSuggestions.isEmpty)))
            _buildSuggestionsDropdown(
              isSearching: _isSearchingFrom,
              hasSearched: _hasSearchedFrom,
              suggestions: _fromSuggestions,
              onSelect: _selectFromSuggestion,
              accentColor: AppColors.lovableGreen,
            ),

          // Connector line
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Row(
              children: [
                Column(
                  children: List.generate(
                    4,
                    (index) => Container(
                      width: 2,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: AppColors.isDark(context)
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Divider(color: AppColors.borderFor(context), height: 16),
                ),
              ],
            ),
          ),

          // DESTINATION Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.lovableTeal,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.lovableTeal,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DESTINATION',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextField(
                      controller: _toController,
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        hintText: 'Enter destination (e.g. Munnar, Punalur)',
                        hintStyle: TextStyle(color: AppColors.textMutedFor(context)),
                      ),
                      onChanged: _searchTo,
                    ),
                  ],
                ),
              ),
              if (_isSearchingTo)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.lovableTeal),
                    ),
                  ),
                )
              else if (_toController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _toController.clear();
                    _searchTo('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textMutedFor(context),
                    ),
                  ),
                )
              else
                Icon(Icons.search, size: 20, color: AppColors.textMutedFor(context)),
            ],
          ),

          if (_showToSuggestions &&
              (_isSearchingTo ||
                  _toSuggestions.isNotEmpty ||
                  (_hasSearchedTo && _toSuggestions.isEmpty)))
            _buildSuggestionsDropdown(
              isSearching: _isSearchingTo,
              hasSearched: _hasSearchedTo,
              suggestions: _toSuggestions,
              onSelect: _selectToSuggestion,
              accentColor: AppColors.lovableTeal,
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsDropdown({
    required bool isSearching,
    required bool hasSearched,
    required List<PlaceSuggestion> suggestions,
    required Function(PlaceSuggestion) onSelect,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: AppColors.cardShadowFor(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: isSearching
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Searching matching places...',
                      style: TextStyle(
                        color: AppColors.textMutedFor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : (hasSearched && suggestions.isEmpty)
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 20,
                          color: AppColors.textMutedFor(context),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No places found',
                              style: TextStyle(
                                color: AppColors.textPrimaryFor(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Check spelling or try searching another city',
                              style: TextStyle(
                                color: AppColors.textMutedFor(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      color: AppColors.borderFor(context),
                      height: 1,
                    ),
                    itemBuilder: (ctx, i) {
                      final s = suggestions[i];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: accentColor,
                          ),
                        ),
                        title: Text(
                          s.name,
                          style: TextStyle(
                            color: AppColors.textPrimaryFor(context),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: s.districtState.isNotEmpty
                            ? Text(
                                s.districtState,
                                style: TextStyle(
                                  color: AppColors.textMutedFor(context),
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Icon(
                          Icons.north_west_rounded,
                          size: 14,
                          color: AppColors.textMutedFor(context).withValues(alpha: 0.6),
                        ),
                        onTap: () => onSelect(s),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildDateTimeRow(DateFormat dateFormat, DateFormat timeFormat) {
    return Row(
      children: [
        // DATE Picker Chip
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceFor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderFor(context)),
                boxShadow: AppColors.cardShadowFor(context),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.lovableGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DATE',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(_selectedDateTime),
                        style: TextStyle(
                          color: AppColors.textPrimaryFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // TIME Picker Chip
        Expanded(
          child: GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceFor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderFor(context)),
                boxShadow: AppColors.cardShadowFor(context),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: AppColors.lovableGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TIME',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeFormat.format(_selectedDateTime),
                        style: TextStyle(
                          color: AppColors.textPrimaryFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: AppColors.lovableGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.lovableGreen.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isAnalyzing ? null : _analyzeRoute,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isAnalyzing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Analyzing Road & Weather Risks...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'AI Analyze Route',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                ],
              ),
      ),
    );
  }

  Widget _buildWeatherDepartureCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.weatherCardGradientFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.isDark(context)
              ? const Color(0xFF144D55)
              : Colors.transparent,
        ),
        boxShadow: AppColors.isDark(context)
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'WEATHER AT DEPARTURE',
                style: TextStyle(
                  color: AppColors.isDark(context)
                      ? const Color(0xFF5EEAD4)
                      : Colors.white.withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.isDark(context)
                      ? const Color(0xFF114F57)
                      : Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.water_drop_outlined,
                  color: AppColors.isDark(context)
                      ? const Color(0xFF5EEAD4)
                      : Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Large temperature and condition
          const Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '28°',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Light rain',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Feels like 31° · Visibility 8 km',
            style: TextStyle(
              color: AppColors.isDark(context)
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          // Stat chips
          Row(
            children: [
              _buildWeatherMiniStat(
                icon: Icons.umbrella_outlined,
                label: '32%',
                sublabel: 'Precipitation',
              ),
              const SizedBox(width: 16),
              _buildWeatherMiniStat(
                icon: Icons.air_rounded,
                label: '12 km/h',
                sublabel: 'Wind SW',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMiniStat({
    required IconData icon,
    required String label,
    required String sublabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.isDark(context)
            ? const Color(0xFF0C2B31)
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.isDark(context)
              ? const Color(0xFF194952)
              : Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.isDark(context)
                ? const Color(0xFF5EEAD4)
                : Colors.white,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  color: AppColors.isDark(context)
                      ? const Color(0xFF64748B)
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusChips() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderFor(context)),
              boxShadow: AppColors.cardShadowFor(context),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.lovableGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Safe corridor active',
                    style: TextStyle(
                      color: AppColors.textSecondaryFor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderFor(context)),
              boxShadow: AppColors.cardShadowFor(context),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.lovableTeal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Live radar connected',
                    style: TextStyle(
                      color: AppColors.textSecondaryFor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
