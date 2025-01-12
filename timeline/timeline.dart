// DISCLAIMER:
// This file is an example of data filtering, sorting, and dynamic state handling in Flutter.
// Note: This file will NOT work as a standalone app.
// Dependencies and project setup are required for functionality:
// - Ensure that SiteData and other external imports are properly defined in your project.


import 'package:flutter/material.dart';
import '../utils/data/get_data.dart';

// main filter for REGION, DATE RANGE and ALERT STATUS
import 'package:habapp/widgets/filter/filter_bottom_sheet.dart';

import 'package:habapp/config/date_range.dart';


class TimelinePage extends StatefulWidget {
  final List<SiteData> markerData;

  final Function(String, dynamic, dynamic) onLocationSelected;
  final ValueNotifier<String> selectedCountryNotifier;
  final ValueNotifier<String> selectedLocationNotifier;
  final ValueNotifier<String> selectedRegionNotifier;
  final ValueNotifier<DateRange> selectedDateRangeNotifier;
  final VoidCallback onMapChange;

  const TimelinePage({
    Key? key,
    required this.markerData,

    required this.selectedDateRangeNotifier,
    required this.onLocationSelected,
    required this.selectedCountryNotifier,
    required this.selectedLocationNotifier,
    required this.selectedRegionNotifier,
    required this.onMapChange,
  }) : super(key: key);

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _tappedRows = {}; // Store tapped rows
  List<Map<String, dynamic>> todayData = [];
  List<Map<String, dynamic>> twoweeksData = [];
  List<Map<String, dynamic>> sixweeksData = [];
  List<Map<String, dynamic>> yearData = [];
  List<Map<String, dynamic>> allTimeData = [];
  String sortOption = 'Site Name';

  // Define mutable state variables for country, region, and alert
  late String selectedCountry;
  late String selectedRegion;
  late DateRange selectedDateRange;

  @override
  void initState() {

    super.initState();
    // Initialize state variables from widget properties
    selectedCountry = widget.selectedCountryNotifier.value;
    selectedRegion = widget.selectedRegionNotifier.value;
    selectedDateRange = widget.selectedDateRangeNotifier.value;
    _processMarkerData();
  }



  void _processMarkerData() {

    final filteredData = selectedRegion == 'All data'
        ? widget.markerData
        : widget.markerData.where((data) => data.region == selectedRegion).toList();

    // Clear all data by default
    todayData = [];
    twoweeksData = [];
    sixweeksData = [];
    yearData = [];
    allTimeData = [];

    // Process data based on selectedDateRange
    switch (selectedDateRange) {
      case DateRange.today:
        todayData = _filterAndSortData(filteredData, 0, 0);
        break;

      case DateRange.twoweeks:
        todayData = _filterAndSortData(filteredData, 0, 0);
        twoweeksData = _filterAndSortData(filteredData, 1, 14);
        break;

      case DateRange.sixweeks:
        todayData = _filterAndSortData(filteredData, 0, 0);
        twoweeksData = _filterAndSortData(filteredData, 1, 14);
        sixweeksData = _filterAndSortData(filteredData, 15, 42);
        break;

      case DateRange.lastyear:
        todayData = _filterAndSortData(filteredData, 0, 0);
        twoweeksData = _filterAndSortData(filteredData, 1, 14);
        sixweeksData = _filterAndSortData(filteredData, 15, 42);
        yearData = _filterAndSortData(filteredData, 43,365);
        break;

      case DateRange.alltime:
        todayData = _filterAndSortData(filteredData, 0, 0);
        twoweeksData = _filterAndSortData(filteredData, 1, 14);
        sixweeksData = _filterAndSortData(filteredData, 15, 42);
        yearData = _filterAndSortData(filteredData, 43, 365);
        allTimeData = _filterAndSortData(filteredData, 366);
        break;

      default:
    }
  }

  List<Map<String, dynamic>> _filterAndSortData(
      List<SiteData> data, int startDay, [int? endDay]) {
    final now = DateTime.now();
    final filtered = data
        .where((item) => now.difference(item.dateCollectedToxin).inDays >= startDay &&
        (endDay == null || now.difference(item.dateCollectedToxin).inDays <= endDay))
        .map(_siteDataToMap)
        .toList();
    _sortData(filtered);
    return filtered;
  }

  void _sortData(List<Map<String, dynamic>> data) {
    data.sort((a, b) {
      if (sortOption == 'Site Name') {
        return a['siteName']?.compareTo(b['siteName'] ?? '') ?? 0;
      } else if (sortOption == 'Alert Status') {
        final alertOrder = {'red': 0, 'amber': 1, 'yellow': 2, 'green': 3};
        int aOrder = alertOrder[a['alert']] ?? 3;
        int bOrder = alertOrder[b['alert']] ?? 3;
        return aOrder.compareTo(bOrder);
      }
      return 0;
    });
  }

  void _triggerMapChange() {
    // Check if onMapChange is non-null before calling it
    if (widget.onMapChange != null) {
      widget.onMapChange();
    }
  }

  Future<void> _showFilterModal() async {
    // Open the filter modal and wait for the selected region, country, and alert
    final result = await FilterBottomSheet(
      selectedDateRange: selectedDateRange,
      selectedCountry: selectedCountry,
      selectedRegion: selectedRegion,
    ).show(context);

    if (result != null) {

      _triggerMapChange();

      final newCountry = result['selectedCountry']!;
      final newRegion = result['selectedRegion']!;

      DateRange parseDateRange(dynamic value) {
        if (value is DateRange) {
          return value;
        } else if (value is String) {
          switch (value) {
            case 'today':
              return DateRange.today;
            case 'twoweeks':
              return DateRange.twoweeks;
            case 'sixweeks':
              return DateRange.sixweeks;
            case 'lastyear':
              return DateRange.lastyear;
            case 'alltime':
              return DateRange.alltime;
            default:
              throw ArgumentError('Invalid DateRange value: $value');
          }
        }
        throw ArgumentError('Unsupported DateRange value: $value');
      }


      final newDateRange = parseDateRange(result['selectedDateRange']);




      // If the country has changed, fetch new marker data first
      List<SiteData> updatedMarkerData = widget.markerData;
      if (widget.selectedCountryNotifier.value != newCountry) {
        updatedMarkerData = await fetchRecentSiteData(newCountry); // Fetch asynchronously
      }

      // Now update the state
      setState(() {
        selectedCountry = newCountry;
        selectedRegion = newRegion;
        selectedDateRange = newDateRange;

        // Update the marker data if it was re-fetched
        if (widget.selectedCountryNotifier.value != newCountry) {
          widget.markerData.clear();
          widget.markerData.addAll(updatedMarkerData);
        }

        // Update notifiers
        widget.selectedCountryNotifier.value = newCountry;
        widget.selectedRegionNotifier.value = newRegion;
        widget.selectedDateRangeNotifier.value = newDateRange;

        // Re-process marker data based on new selections
        _processMarkerData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              selectedCountry == 'Malaysia'
                  ? 'assets/images/malay_flag.png'
                  : 'assets/images/scot_flag.png',
              width: 24,
              height: 24,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 8),
            Text(selectedRegion),
            IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: _showFilterModal,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Sort by: '),
                _buildSortButton('Site Name'),
                _buildSortButton('Alert Status'),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              key: const PageStorageKey("TimelinePageScrollPosition"),
              controller: _scrollController,
              slivers: [
                if (selectedDateRange == DateRange.today || selectedDateRange == DateRange.twoweeks || selectedDateRange == DateRange.sixweeks || selectedDateRange == DateRange.lastyear || selectedDateRange == DateRange.alltime)
                  _buildHeader("Today's Data"),
                _buildDataList(todayData),
                if (selectedDateRange == DateRange.twoweeks || selectedDateRange == DateRange.sixweeks || selectedDateRange==DateRange.lastyear || selectedDateRange == DateRange.alltime)
                  _buildHeader('Last 2 weeks'),
                _buildDataList(twoweeksData),
                if (selectedDateRange == DateRange.sixweeks || selectedDateRange==DateRange.lastyear || selectedDateRange == DateRange.alltime)
                  _buildHeader('Last 6 weeks'),
                _buildDataList(sixweeksData),
                if (selectedDateRange  == DateRange.lastyear || selectedDateRange ==DateRange.alltime)
                  _buildHeader('Last Year'),
                _buildDataList(yearData),
                if (selectedDateRange == DateRange.alltime)
                  _buildHeader('All time'),
                _buildDataList(allTimeData),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton(String label) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          sortOption = label;
          _processMarkerData();
        });
      },
      child: Text(
        label,
        style: TextStyle(
          color: Colors.black,
          fontWeight: sortOption == label ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Map<String, dynamic> _siteDataToMap(SiteData data) {
    final mostRecentDate = data.dateCollectedToxin.isAfter(data.dateCollectedSpecies)
        ? data.dateCollectedToxin
        : data.dateCollectedSpecies;
    return {
      'siteName': data.siteName,
      'district': data.district,
      'date': '${mostRecentDate.day}/${mostRecentDate.month}/${mostRecentDate.year}',
      'timeAgo': _timeAgo(mostRecentDate),
      'alert': data.alert,
    };
  }

  String _timeAgo(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inDays > 0) return '${duration.inDays} days ago';
    if (duration.inHours > 0) return '${duration.inHours} hours ago';
    return '${duration.inMinutes} minutes ago';
  }

  Widget _buildStickyHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        color: Colors.blueGrey[50],
        child: const Row(
          children: [
            Expanded(flex: 2, child: Text('Site Name')),
            Expanded(flex: 2, child: Text('District',)),
            Expanded(flex: 1, child: Text('Date', )),
            Expanded(flex: 1, child: Text('Alert')),
          ],
        ),
      ),
    );
  }



  SliverToBoxAdapter _buildHeader(String title) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.blueGrey[800],
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  SliverList _buildDataList(List<Map<String, dynamic>> data) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final item = data[index];
          final isTapped = _tappedRows.contains(index);

          return Column(
            children: [
              GestureDetector(
                onTap: () {
                  _triggerMapChange();

                  setState(() => _tappedRows.add(index));
                  widget.onLocationSelected(widget.selectedCountryNotifier.value, widget.selectedRegionNotifier.value,item['siteName']);
                },
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  color: isTapped ? Colors.blueGrey[700] : Colors.white,
                  child: Row(
                    children: [
                      _buildDataColumn(item, 'siteName', 'district'),
                      _buildDataColumn(item, 'date', 'timeAgo'),
                      _buildAlertIcon(item),
                    ],
                  ),
                ),
              ),
              Divider(color: Colors.grey[300], thickness: 1, height: 1),
            ],
          );
        },
        childCount: data.length,
      ),
    );
  }

  Widget _buildDataColumn(Map<String, dynamic> item, String titleKey, String subtitleKey) {
    return Expanded(
      flex: 2,
      child: SingleChildScrollView( // Allows the column to scroll if content overflows
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item[titleKey],
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item[subtitleKey],
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertIcon(Map<String, dynamic> item) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 1 / 6,
      child: Center(
        child: item['alert'] == 'red'
            ? Image.asset(
          'assets/images/biohazard.png',
          width: 25,
          height: 25,
          fit: BoxFit.cover,
        )
            : Icon(
          item['alert'] == 'green' ? Icons.check_circle : Icons.warning,
          size: 25,
          color: item['alert'] == 'green'
              ? Colors.green
              : item['alert'] == 'amber'
              ? Colors.amber
              : Colors.yellow[700],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
