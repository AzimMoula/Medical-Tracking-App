import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medical_tracking_app/services/auth_service.dart';
import 'package:intl/intl.dart';

class MedicationHistoryPage extends StatefulWidget {
  const MedicationHistoryPage({super.key});

  @override
  State<MedicationHistoryPage> createState() => _MedicationHistoryPageState();
}

class _MedicationHistoryPageState extends State<MedicationHistoryPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  Map<String, List<MedicationHistory>> _historyData = {};
  Map<String, MedicationDetails> _medicationDetails = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMedicationHistory();
  }

  Future<void> _loadMedicationHistory() async {
    setState(() => _isLoading = true);

    try {
      final user = AuthService.getCurrentUser();
      if (user == null) return;

      // Load medication details
      final medicationsSnapshot = await FirebaseFirestore.instance
          .collection('medications')
          .doc(user.uid)
          .collection('medicines')
          .get();

      for (final doc in medicationsSnapshot.docs) {
        final data = doc.data();
        _medicationDetails[doc.id] = MedicationDetails(
          id: doc.id,
          name: data['pill_name'] ?? 'Unknown',
          category: data['category'] ?? 'general',
          type: data['type'] ?? 'pill',
        );
      }

      // Load medication history (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final historySnapshot = await FirebaseFirestore.instance
          .collection('medication_history')
          .doc(user.uid)
          .collection('entries')
          .where('date', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .orderBy('date', descending: true)
          .get();

      final Map<String, List<MedicationHistory>> tempHistory = {};

      for (final doc in historySnapshot.docs) {
        final data = doc.data();
        final medicationId = data['medication_id'] as String;

        final history = MedicationHistory(
          id: doc.id,
          medicationId: medicationId,
          medicationName: data['medication_name'] ?? 'Unknown',
          dosage: data['dosage'] ?? '',
          scheduledTime: (data['scheduled_time'] as Timestamp).toDate(),
          actualTime: data['actual_time'] != null
              ? (data['actual_time'] as Timestamp).toDate()
              : null,
          status: MedicationStatus.values.firstWhere(
            (e) => e.name == data['status'],
            orElse: () => MedicationStatus.missed,
          ),
          notes: data['notes'] ?? '',
        );

        if (!tempHistory.containsKey(medicationId)) {
          tempHistory[medicationId] = [];
        }
        tempHistory[medicationId]!.add(history);
      }

      // Add test data for demonstration (TODO: Remove this after review)
      _addTestDataForDemonstration(tempHistory);

      setState(() {
        _historyData = tempHistory;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading medication history: $e');
      setState(() => _isLoading = false);
    }
  }

  // TODO: Remove this method after reviewing the UI
  void _addTestDataForDemonstration(
      Map<String, List<MedicationHistory>> tempHistory) {
    final now = DateTime.now();

    // Add test medications if none exist
    if (_medicationDetails.isEmpty) {
      _medicationDetails['test_aspirin'] = MedicationDetails(
        id: 'test_aspirin',
        name: 'Aspirin 100mg',
        category: 'bp_control',
        type: 'pill',
      );

      _medicationDetails['test_metformin'] = MedicationDetails(
        id: 'test_metformin',
        name: 'Metformin 500mg',
        category: 'diabetes',
        type: 'pill',
      );

      _medicationDetails['test_vitamin_d'] = MedicationDetails(
        id: 'test_vitamin_d',
        name: 'Vitamin D3',
        category: 'vitamins',
        type: 'pill',
      );

      _medicationDetails['test_ibuprofen'] = MedicationDetails(
        id: 'test_ibuprofen',
        name: 'Ibuprofen 400mg',
        category: 'pain',
        type: 'pill',
      );
    }

    // Generate test history for the past 14 days
    for (int i = 0; i < 14; i++) {
      final date = now.subtract(Duration(days: i));

      // Aspirin - morning dose (mostly taken, some missed)
      if (i < 12) {
        // Skip last 2 days to show recent missed
        tempHistory.putIfAbsent('test_aspirin', () => []).add(
              MedicationHistory(
                id: 'test_aspirin_${i}_morning',
                medicationId: 'test_aspirin',
                medicationName: 'Aspirin 100mg',
                dosage: '100mg',
                scheduledTime: DateTime(date.year, date.month, date.day, 8, 0),
                actualTime: i == 2 || i == 7
                    ? null
                    : DateTime(date.year, date.month, date.day, 8,
                        i % 2 == 0 ? 5 : 15),
                status: i == 2 || i == 7
                    ? MedicationStatus.missed
                    : MedicationStatus.taken,
                notes: i == 5 ? 'Took with breakfast' : '',
              ),
            );
      }

      // Aspirin - evening dose
      if (i < 10) {
        tempHistory.putIfAbsent('test_aspirin', () => []).add(
              MedicationHistory(
                id: 'test_aspirin_${i}_evening',
                medicationId: 'test_aspirin',
                medicationName: 'Aspirin 100mg',
                dosage: '100mg',
                scheduledTime: DateTime(date.year, date.month, date.day, 20, 0),
                actualTime: i == 4
                    ? null
                    : DateTime(date.year, date.month, date.day, 20,
                        i % 3 == 0 ? 10 : 5),
                status:
                    i == 4 ? MedicationStatus.skipped : MedicationStatus.taken,
                notes: i == 4 ? 'Skipped - forgot to bring medication' : '',
              ),
            );
      }

      // Metformin - with meals
      if (i < 13) {
        for (int meal = 0; meal < 3; meal++) {
          final hour = meal == 0 ? 8 : (meal == 1 ? 13 : 19);
          final mealName =
              meal == 0 ? 'breakfast' : (meal == 1 ? 'lunch' : 'dinner');

          tempHistory.putIfAbsent('test_metformin', () => []).add(
                MedicationHistory(
                  id: 'test_metformin_${i}_$meal',
                  medicationId: 'test_metformin',
                  medicationName: 'Metformin 500mg',
                  dosage: '500mg',
                  scheduledTime:
                      DateTime(date.year, date.month, date.day, hour, 0),
                  actualTime: (i == 1 && meal == 1) || (i == 6 && meal == 2)
                      ? null
                      : DateTime(date.year, date.month, date.day, hour, 15),
                  status: (i == 1 && meal == 1) || (i == 6 && meal == 2)
                      ? MedicationStatus.missed
                      : MedicationStatus.taken,
                  notes: meal == 0 ? 'With $mealName' : '',
                ),
              );
        }
      }

      // Vitamin D - once daily
      if (i < 10 && i % 2 == 0) {
        // Every other day for the past 10 days
        tempHistory.putIfAbsent('test_vitamin_d', () => []).add(
              MedicationHistory(
                id: 'test_vitamin_d_$i',
                medicationId: 'test_vitamin_d',
                medicationName: 'Vitamin D3',
                dosage: '1000 IU',
                scheduledTime: DateTime(date.year, date.month, date.day, 9, 0),
                actualTime: DateTime(date.year, date.month, date.day, 9, 20),
                status: MedicationStatus.taken,
                notes: i == 8 ? 'Weekly vitamin dose' : '',
              ),
            );
      }

      // Ibuprofen - as needed (sporadic)
      if (i == 1 || i == 5 || i == 9) {
        tempHistory.putIfAbsent('test_ibuprofen', () => []).add(
              MedicationHistory(
                id: 'test_ibuprofen_$i',
                medicationId: 'test_ibuprofen',
                medicationName: 'Ibuprofen 400mg',
                dosage: '400mg',
                scheduledTime: DateTime(date.year, date.month, date.day, 14, 0),
                actualTime: DateTime(date.year, date.month, date.day, 14, 30),
                status: MedicationStatus.taken,
                notes: i == 5
                    ? 'For headache'
                    : (i == 9 ? 'For back pain' : 'For muscle pain'),
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 10,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withAlpha(150),
                Colors.lightBlueAccent.withAlpha(140),
                Colors.cyan.withAlpha(150),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.black12, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        title: const Text('Medication History'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'Calendar'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarView(),
                _buildAnalyticsView(),
              ],
            ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        // Calendar Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month - 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_selectedDate),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month + 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        // Calendar Grid
        Expanded(
          child: _buildCalendarGrid(),
        ),

        // Selected Date Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.purple),
                    const SizedBox(width: 6),
                    Text(
                      'Selected: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Selected Date Details - Always show something when a date is selected
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Medications for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_getHistoryForDate(_selectedDate).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_getHistoryForDate(_selectedDate).length} doses',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Summary for the day
              if (_getHistoryForDate(_selectedDate).isNotEmpty) ...[
                _buildDaySummary(_selectedDate),
                const SizedBox(height: 12),
              ],

              Expanded(
                child: _getHistoryForDate(_selectedDate).isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No medications scheduled for this date',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap any date on the calendar to see medication history',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _getHistoryForDate(_selectedDate).length,
                        itemBuilder: (context, index) {
                          final history =
                              _getHistoryForDate(_selectedDate)[index];
                          return _buildHistoryListTile(history);
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(_selectedDate.year, _selectedDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: daysInMonth + firstWeekday,
      itemBuilder: (context, index) {
        if (index < firstWeekday) {
          return Container(); // Empty cells for previous month
        }

        final day = index - firstWeekday + 1;
        final date = DateTime(_selectedDate.year, _selectedDate.month, day);
        final historyForDay = _getHistoryForDate(date);
        final isSelected = _isSameDay(date, _selectedDate);
        final isToday = _isSameDay(date, DateTime.now());

        return GestureDetector(
          onTap: () {
            debugPrint(
                '📅 Calendar date tapped: ${DateFormat('yyyy-MM-dd').format(date)}');
            debugPrint(
                '🔍 History for this date: ${_getHistoryForDate(date).length} entries');
            setState(() {
              _selectedDate = date;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.purple
                  : isToday
                      ? Colors.purple.withAlpha(100)
                      : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Colors.purple
                    : isToday
                        ? Colors.purple.withAlpha(150)
                        : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.purple.withAlpha(100),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (historyForDay.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (historyForDay
                          .any((h) => h.status == MedicationStatus.taken))
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (historyForDay
                          .any((h) => h.status == MedicationStatus.missed))
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (historyForDay
                          .any((h) => h.status == MedicationStatus.skipped))
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 2),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Statistics
          _buildOverallStats(),

          const SizedBox(height: 24),

          // Weekly Adherence Trend
          _buildWeeklyTrend(),

          const SizedBox(height: 24),

          // Medication Timing Analysis
          _buildTimingAnalysis(),

          const SizedBox(height: 24),

          // Medication-wise Charts
          const Text(
            '💊 Individual Medication Analysis',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ..._medicationDetails.entries.map((entry) {
            final medicationId = entry.key;
            final medication = entry.value;
            final history = _historyData[medicationId] ?? [];

            if (history.isEmpty) return const SizedBox.shrink();

            return Column(
              children: [
                _buildMedicationChart(medication, history),
                const SizedBox(height: 24),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildOverallStats() {
    final allHistory = _historyData.values.expand((list) => list).toList();
    final totalMedications = allHistory.length;
    final takenCount =
        allHistory.where((h) => h.status == MedicationStatus.taken).length;
    final missedCount =
        allHistory.where((h) => h.status == MedicationStatus.missed).length;
    final skippedCount =
        allHistory.where((h) => h.status == MedicationStatus.skipped).length;

    final adherenceRate =
        totalMedications > 0 ? (takenCount / totalMedications * 100) : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Overall Adherence (Last 30 Days)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Adherence Rate',
                    '${adherenceRate.toStringAsFixed(1)}%',
                    Colors.blue,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Doses',
                    totalMedications.toString(),
                    Colors.purple,
                    Icons.medication,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Taken',
                    takenCount.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Missed',
                    missedCount.toString(),
                    Colors.red,
                    Icons.cancel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Skipped',
                    skippedCount.toString(),
                    Colors.orange,
                    Icons.remove_circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withAlpha(200),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationChart(
      MedicationDetails medication, List<MedicationHistory> history) {
    final takenCount =
        history.where((h) => h.status == MedicationStatus.taken).length;
    final missedCount =
        history.where((h) => h.status == MedicationStatus.missed).length;
    final skippedCount =
        history.where((h) => h.status == MedicationStatus.skipped).length;
    final total = history.length;
    final adherenceRate = total > 0 ? (takenCount / total * 100) : 0.0;

    // Get recent activity (last 7 days)
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentHistory =
        history.where((h) => h.scheduledTime.isAfter(weekAgo)).toList();
    final recentTaken =
        recentHistory.where((h) => h.status == MedicationStatus.taken).length;
    final recentTotal = recentHistory.length;
    final recentRate =
        recentTotal > 0 ? (recentTaken / recentTotal * 100) : 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(medication.category).withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    medication.type == 'pill'
                        ? Icons.medication
                        : Icons.local_drink,
                    color: _getCategoryColor(medication.category),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        medication.category.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getCategoryColor(medication.category),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Chip(
                      label: Text(
                        '${adherenceRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: _getAdherenceColor(adherenceRate),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Overall',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Recent Performance Indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: recentRate >= 80
                    ? Colors.green.withAlpha(30)
                    : recentRate >= 60
                        ? Colors.orange.withAlpha(30)
                        : Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: recentRate >= 80
                      ? Colors.green
                      : recentRate >= 60
                          ? Colors.orange
                          : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    recentRate >= 80
                        ? Icons.trending_up
                        : recentRate >= 60
                            ? Icons.trending_flat
                            : Icons.trending_down,
                    color: recentRate >= 80
                        ? Colors.green
                        : recentRate >= 60
                            ? Colors.orange
                            : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last 7 days: ${recentRate.toStringAsFixed(1)}% ($recentTaken/$recentTotal)',
                    style: TextStyle(
                      color: recentRate >= 80
                          ? Colors.green.shade700
                          : recentRate >= 60
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Custom Progress Chart
            SizedBox(
              height: 200,
              child: _buildCustomChart(
                  takenCount, missedCount, skippedCount, total),
            ),

            // Last few doses quick view
            if (history.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (history.length > 10 ? 10 : history.length),
                  itemBuilder: (context, index) {
                    final sortedHistory = [...history]..sort(
                        (a, b) => b.scheduledTime.compareTo(a.scheduledTime));
                    final historyItem = sortedHistory[index];
                    final daysDiff = DateTime.now()
                        .difference(historyItem.scheduledTime)
                        .inDays;

                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _getStatusColor(historyItem.status),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStatusIcon(historyItem.status),
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            daysDiff == 0 ? 'Today' : '${daysDiff}d',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomChart(
      int takenCount, int missedCount, int skippedCount, int total) {
    if (total == 0) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final takenPercent = takenCount / total;
    final missedPercent = missedCount / total;
    final skippedPercent = skippedCount / total;

    return Column(
      children: [
        // Progress bars
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn('Taken', takenCount, Colors.green, takenPercent),
              _buildStatColumn(
                  'Missed', missedCount, Colors.red, missedPercent),
              _buildStatColumn(
                  'Skipped', skippedCount, Colors.orange, skippedPercent),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Overall progress bar
        Container(
          width: double.infinity,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade300,
          ),
          child: Row(
            children: [
              if (takenCount > 0)
                Expanded(
                  flex: takenCount,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (missedCount > 0)
                Expanded(
                  flex: missedCount,
                  child: Container(
                    color: Colors.red,
                  ),
                ),
              if (skippedCount > 0)
                Expanded(
                  flex: skippedCount,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: missedCount == 0 && takenCount > 0
                          ? null
                          : const BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(
      String label, int count, Color color, double percent) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  flex: (percent * 100).round(),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  flex: 100 - (percent * 100).round(),
                  child: Container(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryListTile(MedicationHistory history) {
    final medication = _medicationDetails[history.medicationId];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(history.status).withAlpha(50),
        child: Icon(
          _getStatusIcon(history.status),
          color: _getStatusColor(history.status),
        ),
      ),
      title: Text(
        medication?.name ?? history.medicationName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dosage: ${history.dosage}'),
          Text(
              'Scheduled: ${DateFormat('HH:mm').format(history.scheduledTime)}'),
          if (history.actualTime != null)
            Text('Taken: ${DateFormat('HH:mm').format(history.actualTime!)}'),
          if (history.notes.isNotEmpty)
            Text('Notes: ${history.notes}',
                style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
      trailing: Chip(
        label: Text(
          history.status.name.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: _getStatusColor(history.status),
      ),
    );
  }

  List<MedicationHistory> _getHistoryForDate(DateTime date) {
    final allHistory = _historyData.values.expand((list) => list).toList();
    return allHistory.where((history) {
      return _isSameDay(history.scheduledTime, date);
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Color _getStatusColor(MedicationStatus status) {
    switch (status) {
      case MedicationStatus.taken:
        return Colors.green;
      case MedicationStatus.missed:
        return Colors.red;
      case MedicationStatus.skipped:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(MedicationStatus status) {
    switch (status) {
      case MedicationStatus.taken:
        return Icons.check_circle;
      case MedicationStatus.missed:
        return Icons.cancel;
      case MedicationStatus.skipped:
        return Icons.remove_circle;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'diabetes':
        return Colors.blue;
      case 'bp_control':
        return Colors.red;
      case 'vitamins':
        return Colors.orange;
      case 'fever':
        return Colors.purple;
      case 'cold':
        return Colors.cyan;
      case 'antibiotics':
        return Colors.green;
      case 'pain':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Color _getAdherenceColor(double rate) {
    if (rate >= 90) return Colors.green;
    if (rate >= 70) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildDaySummary(DateTime date) {
    final dayHistory = _getHistoryForDate(date);
    final taken =
        dayHistory.where((h) => h.status == MedicationStatus.taken).length;
    final missed =
        dayHistory.where((h) => h.status == MedicationStatus.missed).length;
    final skipped =
        dayHistory.where((h) => h.status == MedicationStatus.skipped).length;
    final total = dayHistory.length;
    final rate = total > 0 ? (taken / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rate >= 80
            ? Colors.green.withAlpha(30)
            : rate >= 60
                ? Colors.orange.withAlpha(30)
                : Colors.red.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rate >= 80
              ? Colors.green
              : rate >= 60
                  ? Colors.orange
                  : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            rate >= 80
                ? Icons.check_circle
                : rate >= 60
                    ? Icons.warning
                    : Icons.error,
            color: rate >= 80
                ? Colors.green
                : rate >= 60
                    ? Colors.orange
                    : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Daily adherence: ${rate.toStringAsFixed(1)}% ($taken/$total)',
              style: TextStyle(
                color: rate >= 80
                    ? Colors.green.shade700
                    : rate >= 60
                        ? Colors.orange.shade700
                        : Colors.red.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (missed > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${missed} missed',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (skipped > 0)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${skipped} skipped',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrend() {
    // Calculate weekly adherence for the last 4 weeks
    final now = DateTime.now();
    final weeks = <String, Map<String, int>>{};

    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: (i * 7) + now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekLabel = 'Week ${i + 1}';

      final weekHistory = _historyData.values
          .expand((list) => list)
          .where((h) =>
              h.scheduledTime.isAfter(weekStart) &&
              h.scheduledTime.isBefore(weekEnd.add(const Duration(days: 1))))
          .toList();

      final taken =
          weekHistory.where((h) => h.status == MedicationStatus.taken).length;
      final missed =
          weekHistory.where((h) => h.status == MedicationStatus.missed).length;
      final skipped =
          weekHistory.where((h) => h.status == MedicationStatus.skipped).length;

      weeks[weekLabel] = {
        'taken': taken,
        'missed': missed,
        'skipped': skipped,
        'total': taken + missed + skipped,
      };
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 Weekly Adherence Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: weeks.entries.map((entry) {
                  final weekData = entry.value;
                  final total = weekData['total'] ?? 0;
                  final taken = weekData['taken'] ?? 0;
                  final adherenceRate = total > 0 ? (taken / total) : 0.0;
                  final barHeight = adherenceRate * 150; // Max height 150

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${(adherenceRate * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 40,
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: adherenceRate >= 0.8
                                  ? [
                                      Colors.green.shade300,
                                      Colors.green.shade600
                                    ]
                                  : adherenceRate >= 0.6
                                      ? [
                                          Colors.orange.shade300,
                                          Colors.orange.shade600
                                        ]
                                      : [
                                          Colors.red.shade300,
                                          Colors.red.shade600
                                        ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.key,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '$taken/$total',
                          style:
                              const TextStyle(fontSize: 8, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingAnalysis() {
    // Analyze medication timing patterns
    final allHistory = _historyData.values.expand((list) => list).toList();
    final takenHistory =
        allHistory.where((h) => h.status == MedicationStatus.taken).toList();

    // Group by hour of day
    final hourlyData = <int, int>{};
    for (int hour = 0; hour < 24; hour++) {
      hourlyData[hour] = 0;
    }

    for (final history in takenHistory) {
      final hour = history.actualTime?.hour ?? history.scheduledTime.hour;
      hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
    }

    // Find peak hours
    final sortedHours = hourlyData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final peakHours = sortedHours.take(3).toList();

    // Calculate on-time percentage
    final onTimeCount = takenHistory.where((h) {
      if (h.actualTime == null)
        return true; // Assume on time if no actual time recorded
      final diff = h.actualTime!.difference(h.scheduledTime).inMinutes.abs();
      return diff <= 30; // Within 30 minutes is considered on time
    }).length;

    final onTimePercentage = takenHistory.isNotEmpty
        ? (onTimeCount / takenHistory.length * 100)
        : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⏰ Timing Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // On-time statistics
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'On-Time Rate',
                    '${onTimePercentage.toStringAsFixed(1)}%',
                    Colors.blue,
                    Icons.schedule,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Doses Taken',
                    takenHistory.length.toString(),
                    Colors.green,
                    Icons.medication,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Peak hours
            const Text(
              'Most Active Hours:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ...peakHours.take(3).map((entry) {
              final hour = entry.key;
              final count = entry.value;
              final timeString = hour == 0
                  ? '12:00 AM'
                  : hour < 12
                      ? '${hour}:00 AM'
                      : hour == 12
                          ? '12:00 PM'
                          : '${hour - 12}:00 PM';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha(100)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeString,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count doses',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// Data Models
class MedicationHistory {
  final String id;
  final String medicationId;
  final String medicationName;
  final String dosage;
  final DateTime scheduledTime;
  final DateTime? actualTime;
  final MedicationStatus status;
  final String notes;

  MedicationHistory({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.scheduledTime,
    this.actualTime,
    required this.status,
    required this.notes,
  });
}

class MedicationDetails {
  final String id;
  final String name;
  final String category;
  final String type;

  MedicationDetails({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
  });
}

enum MedicationStatus {
  taken,
  missed,
  skipped,
}
