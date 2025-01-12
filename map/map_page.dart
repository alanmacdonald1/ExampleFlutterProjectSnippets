// DISCLAIMER:
// This file is an example for how to use Google Maps in Flutter with dynamic markers.
// Note: This file will NOT work as a standalone app.
// Dependencies and project setup are required for functionality:
// - google_maps_flutter
// - geolocator


import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/map/mapbottomsheet.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../utils/data/get_data.dart';
import 'package:habapp/config/googleMapRegionCentres.dart';

import 'package:habapp/config/date_range.dart';

// these nasty futures
class MapData {
  final List<SiteData> markerData;
  final Position userLocation;

  MapData({required this.markerData, required this.userLocation});
}


enum AlertType { red, all }

class MapPage extends StatefulWidget {
  final ValueNotifier<bool> mapUpdateNotifier;
  final ValueNotifier<String> selectedCountryNotifier;
  final ValueNotifier<String> selectedLocationNotifier;
  final ValueNotifier<String> selectedRegionNotifier;
  final ValueNotifier<DateRange> selectedDateRangeNotifier;
  final List<SiteData> markerData;
  final LatLng userLocation; // User location is passed directly
  final Function(String, {String? speciesName}) onLocationSelected;
  final String selectedRegion; // Updated to ValueNotifier
  final String selectedLocation;
  final String selectedCountry;

  const MapPage({
    Key? key,
    required this.mapUpdateNotifier,
    required this.markerData,
    required this.userLocation,
    required this.onLocationSelected,
    required this.selectedCountryNotifier,
    required this.selectedRegionNotifier,
    required this.selectedLocationNotifier,
    required this.selectedDateRangeNotifier,
    required this.selectedCountry,
    required this.selectedRegion, // Accept the notifier
    required this.selectedLocation, // Accept the notifier
  }) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage>
    with AutomaticKeepAliveClientMixin<MapPage> {
  final Set<Marker> _markers = {};


  DateRange selectedDateRange  = DateRange.sixweeks;
  AlertType selectedAlertType = AlertType.all;
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  late CameraPosition _initialCameraPosition;
  CameraPosition?
      _lastCameraPosition; // Allow null initially to avoid LateInitializationError

  List<SiteData> filteredData = [];

  late String selectedCountry;
  late String selectedRegion;
  late String selectedLocation;
  late bool mapUpdate;

  bool? changeMap;
  List<Map<String, dynamic>> timelineData = []; // Define timelineData

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // update country and region
    selectedCountry = widget.selectedCountryNotifier.value;
    selectedRegion = widget.selectedRegionNotifier.value;
    selectedLocation = widget.selectedLocationNotifier.value;
    selectedDateRange = widget.selectedDateRangeNotifier.value;

    mapUpdate = widget.mapUpdateNotifier.value;


    _initialCameraPosition = PageStorage.of(context).readState(
          context,
          identifier: 'cameraPosition',
        ) as CameraPosition? ??
        CameraPosition(
          target: widget.userLocation,
          zoom: 6,
        );

    updateTimelineData();
    // Load initial markers based on filtered data
    _updateMarkers();
  }

  // Filter and build timelineData
  void updateTimelineData() {
    final now = DateTime.now();
    late DateTime cutoffDate;

    // Determine cutoff date based on selectedDateRange
    switch (selectedDateRange) {
      case DateRange.today:
        cutoffDate = now.subtract(const Duration(days: 1));
        break;
      case DateRange.twoweeks:
        cutoffDate = now.subtract(const Duration(days: 14));
        break;
      case DateRange.sixweeks:
        cutoffDate = now.subtract(const Duration(days: 43));
        break;
      case DateRange.lastyear:
        cutoffDate = now.subtract(const Duration(days: 366));
        break;
      case DateRange.alltime:
        cutoffDate = DateTime.fromMillisecondsSinceEpoch(0); // Include all
        break;
    }

    // Filter markers based on cutoff date and region
    final visibleMarkers = widget.markerData.where((siteData) {
      bool isWithinDateRange = siteData.dateCollectedToxin.isAfter(cutoffDate);
      bool isInSelectedRegion =
          selectedRegion == "All data" || siteData.region == selectedRegion;
      return isWithinDateRange && isInSelectedRegion;
    }).toList();

    // Build timeline data
    timelineData = buildTimelineData(visibleMarkers);
  }


  bool _shouldMarkerBeVisible(SiteData siteData) {
    DateTime now = DateTime.now();
    DateTime cutoffDate;
    switch (selectedDateRange) {
      case DateRange.today:
        cutoffDate = now.subtract(const Duration(days: 1));
        break;
      case DateRange.twoweeks:
        cutoffDate = now.subtract(const Duration(days: 14));
        break;
      case DateRange.sixweeks:
        cutoffDate = now.subtract(const Duration(days: 42));
        break;
      case DateRange.lastyear:
        cutoffDate = now.subtract(const Duration(days: 366));
        break;
      case DateRange.alltime:
        cutoffDate = DateTime.fromMillisecondsSinceEpoch(0); // Show all time
        break;
    }
    bool isWithinDateRange = siteData.dateCollectedToxin.isAfter(cutoffDate);
    bool matchesAlertType = (selectedAlertType == AlertType.all) ||
        (selectedAlertType == AlertType.red && siteData.alert == 'red');
    return isWithinDateRange && matchesAlertType;
  }

  // Loads the markers from provided data
  void _updateMarkers() {
    Set<String> addedMarkerIds = {}; // To track unique marker IDs

    final visibleMarkers = widget.markerData
        .where((siteData) {
          // Check if the selected region is "all data"
          if (selectedRegion == "All data") {
            return _shouldMarkerBeVisible(siteData); // Show all markers
          } else {
            // Filter by the selected region and other conditions
            return siteData.region == selectedRegion &&
                _shouldMarkerBeVisible(siteData);
          }
        })
        .map((siteData) {

          String markerId =
              siteData.siteName + siteData.dateCollectedToxin.toString();

          if (addedMarkerIds.contains(markerId)) return null;
          addedMarkerIds.add(markerId);

          BitmapDescriptor customIcon =
              getMarkerColorBasedOnAlert(siteData.alert, siteData.pAlert);

          return Marker(
            markerId: MarkerId(markerId),
            position:
                LatLng(siteData.location.latitude, siteData.location.longitude),
            icon: customIcon,
            onTap: () {
              MapBottomSheet(
                siteData: siteData,
                selectedCountry: selectedCountry,
                onLocationSelected: (selectedLocationName, {speciesName}) {
                  setState(() {
                    widget.onLocationSelected(selectedLocationName,
                        speciesName: speciesName);
                  });
                },
              ).show(context);
            },
          );
        })
        .whereType<Marker>()
        .toSet(); // Filters out any nulls and duplicates

    setState(() {
      _markers.clear();
      _markers.addAll(visibleMarkers);
    });
  }

  @override
  void dispose() {
    // Save last camera position if widget is still mounted
    if (mounted) {
      _saveLastCameraPosition();
    }
    super.dispose();
  }

  void _onSelectionChanged() {

    final currentLocation = selectedLocation;
    final currentRegion = selectedRegion;
    if (currentLocation != "NONE") {
      _goToLocation(currentLocation);
    } else {
      _goToRegion(currentRegion);
    }
    widget.selectedLocationNotifier.value = "NONE";
  }

  Future<void> _goToLocation(String locationName) async {
    SiteData? siteData =
        widget.markerData.firstWhere((site) => site.siteName == locationName);
    // Update

    final GoogleMapController controller = await _controller.future;
    final LatLng targetPosition =
        LatLng(siteData.location.latitude, siteData.location.longitude);

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
          targetPosition.latitude - 0.02, targetPosition.longitude - 0.02),
      northeast: LatLng(
          targetPosition.latitude + 0.02, targetPosition.longitude + 0.02),
    );

    // Apply bounds with padding
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));

    _lastCameraPosition = CameraPosition(
        target: targetPosition, zoom: await controller.getZoomLevel());
    widget.mapUpdateNotifier.value = false; // Reset the notifier here
  }

  Future<void> _goToRegion(String selectedRegion) async {
    final LatLng? regionCenter = googleMapRegionCentres[selectedRegion];
    if (regionCenter != null) {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(regionCenter, 8));
      _lastCameraPosition = CameraPosition(target: regionCenter, zoom: 8);
    }
    widget.mapUpdateNotifier.value = false; // Reset the notifier here
  }

  List<SiteData> allMarkers = [];

  BitmapDescriptor getMarkerColorBasedOnAlert(String? alert, String? p_alert) {
    switch (alert) {
      case 'amber':
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow);
      case 'red':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'green':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'yellow':
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  void _saveLastCameraPosition() {
    if (mounted && _controller.isCompleted) {
      _controller.future.then((controller) async {
        final currentPosition = await controller.getVisibleRegion();
        _lastCameraPosition = CameraPosition(
          target: LatLng(
            (currentPosition.southwest.latitude +
                    currentPosition.northeast.latitude) /
                2,
            (currentPosition.southwest.longitude +
                    currentPosition.northeast.longitude) /
                2,
          ),
          zoom: await controller.getZoomLevel(),
        );
        PageStorage.of(context).writeState(
          context,
          _lastCameraPosition,
          identifier: 'cameraPosition',
        );
      });
    }
  }

  // Save the last camera position on map move
  void _onCameraMove(CameraPosition position) {
    _lastCameraPosition = position;
    PageStorage.of(context).writeState(
      context,
      _lastCameraPosition,
      identifier: 'cameraPosition',
    );
  }

// Helper functions to determine icon and color based on status
  List<Map<String, dynamic>> buildTimelineData(List<SiteData> markers) {
    // Step 1: Sort the markers by dateCollectedToxin and dateCollectedSpecies
    markers.sort((a, b) {
      // Compare by dateCollectedToxin first
      int toxinComparison =
          b.dateCollectedToxin.compareTo(a.dateCollectedToxin);
      if (toxinComparison != 0) return toxinComparison;

      // If dateCollectedToxin is the same, compare by dateCollectedSpecies
      return b.dateCollectedSpecies.compareTo(a.dateCollectedSpecies);
    });

    // Step 2: Identify the latest date for each marker and build timeline data
    List<Map<String, dynamic>> timelineData = markers.map((marker) {
      // Get the later of the two dates
      DateTime latestDate =
          marker.dateCollectedToxin.isAfter(marker.dateCollectedSpecies)
              ? marker.dateCollectedToxin
              : marker.dateCollectedSpecies;

      // Add to timeline data with relevant status and latest date
      return {
        'siteName': marker.siteName,
        'latestDate': latestDate,
        'status': marker.alert,
      };
    }).toList();

    // Step 3: Sort timelineData by latestDate to get the chronological order for display
    timelineData.sort((a, b) => a['latestDate'].compareTo(b['latestDate']));

    return timelineData;
  }

// Function to get the icon based on the alert status
  IconData getStatusIcon(String status) {
    switch (status) {
      case 'red':
        return Icons.error;
      case 'amber':
        return Icons.warning;
      case 'green':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

// Function to get the color based on the alert status
  Color getStatusColor(String status) {
    switch (status) {
      case 'red':
        return Colors.red;
      case 'amber':
        return Colors.orange;
      case 'green':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.height*0.1,
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Region and Location Information
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            selectedCountry == 'Malaysia'
                                ? 'assets/images/malay_flag.png'
                                : 'assets/images/scot_flag.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedRegion,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),

                  // Timeline section with markers and status
                  selectedRegion!="All data" ? Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Oldest to most recent',
                            style: TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                          Row(
                            children: [
                              SizedBox(width: 3),
                              Icon(
                                Icons.arrow_forward,
                                size: 10,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4), // Space between labels and icons
                      // Dynamically generate rows for timeline
                      ...List.generate(
                        (timelineData.length / 10).ceil(),
                        // Calculate the number of rows needed
                        (rowIndex) {
                          int startIndex =
                              rowIndex * 10; // Start index for the row
                          int endIndex = (startIndex + 10)
                              .clamp(0, timelineData.length); // End index
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: timelineData
                                .sublist(startIndex, endIndex)
                                .asMap()
                                .entries
                                .map((entry) {
                              final indexInRow = entry.key;
                              final item = entry.value;
                              final status = item['status'];

                              // Add the number only to the first icon of the row
                              return indexInRow == 0
                                  ? Row(
                                      children: [
                                        Text(
                                          (startIndex + 1).toString(),
                                          // Add row number, e.g., 1 for the first row
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 1),
                                          child: status == "red"
                                              ? Image.asset(
                                                  'assets/images/biohazard.png',
                                                  width: 20,
                                                  height: 20,
                                                  fit: BoxFit.cover,
                                                )
                                              : Icon(
                                                  getStatusIcon(status),
                                                  color: getStatusColor(status),
                                                  size: 12,
                                                ),
                                        ),
                                      ],
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      child: status == "red"
                                          ? Image.asset(
                                              'assets/images/biohazard.png',
                                              width: 20,
                                              height: 20,
                                              fit: BoxFit.cover,
                                            )
                                          : Icon(
                                              getStatusIcon(status),
                                              color: getStatusColor(status),
                                              size: 12,
                                            ),
                                    );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ) :  const Column()
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.mapUpdateNotifier,
          builder: (context, mapChange, child) {
            if (mapChange) {
              _onSelectionChanged();
            }

            return buildMapContent(); // Your method to build the map content
          },
        ),
      ),
    );
  }

// Separate method for map content to keep `build` cleaner
  Widget buildMapContent() {
    return Column(
      children: [
        const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                key: const PageStorageKey('MapPage'),
                mapType: MapType.hybrid,
                initialCameraPosition: _initialCameraPosition,
                onMapCreated: (GoogleMapController controller) {
                  if (!_controller.isCompleted) {
                    _controller.complete(controller);
                  }
                },
                onCameraMove: _onCameraMove,
                markers: _markers,
              ),
              // Styled overlay text for selected region
            ],
          ),
        ),
      ],
    );
  }
}
