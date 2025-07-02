import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:medical_tracking_app/services/auth_service.dart';
import 'package:medical_tracking_app/services/medication_alarm_service.dart';
import 'package:medical_tracking_app/services/alarm_service.dart';
import 'package:medical_tracking_app/widgets/time_field.dart';

class AddSchedule extends StatefulWidget {
  const AddSchedule({super.key});

  @override
  State<AddSchedule> createState() => _AddScheduleState();
}

class _AddScheduleState extends State<AddSchedule> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController durationController = TextEditingController();
  TextEditingController medicationCountController = TextEditingController();
  List<MedicationController> medicationControllers = [];
  bool isIndefinite = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    medicationControllers.add(MedicationController());
    medicationCountController.text = '1';

    // Check alarm permissions when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAlarmPermissions();
    });
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
        title: const Text('Add Medications'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duration Section
              const Text(
                'Schedule Duration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
              ),
              const SizedBox(height: 8),
              DateTimeField(
                controller: durationController,
                setState: () => setState(() {}),
                time: false,
                onChanged: (bool isDefinite) {
                  setState(() {
                    isIndefinite = !isDefinite;
                  });
                },
              ),

              const SizedBox(height: 15),

              // Number of Medications Section
              const Text(
                'Number of Medications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: medicationCountController,
                onChanged: _updateMedicationControllers,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  labelText: 'Enter number of medications',
                  suffixIcon: _buildCounterButtons(),
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 10),

              // Medications List
              Expanded(
                child: medicationControllers.isEmpty
                    ? const Center(
                        child: Text(
                          'Add medications above to get started',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: medicationControllers.length,
                        itemBuilder: (context, index) =>
                            _buildMedicationCard(index),
                      ),
              ),

              // Save Button
              Container(
                height: 66,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: isLoading ? null : _saveMedications,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          medicationControllers.length == 1
                              ? 'Save Medication'
                              : 'Save ${medicationControllers.length} Medications',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(int medicationIndex) {
    final medication = medicationControllers[medicationIndex];

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Card(
          elevation: 1,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with medication number and delete button
                Row(
                  children: [
                    Text(
                      'Medication ${medicationIndex + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    if (medicationControllers.length > 1)
                      IconButton(
                        onPressed: () => _removeMedication(medicationIndex),
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Medication Name and Category
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: medication.nameController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15)),
                          labelText: 'Medication Name *',
                          hintText: 'e.g., Paracetamol',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter medication name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: medication.type,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15)),
                          labelText: 'Type',
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'pill', child: Text('Pill/Tablet')),
                          DropdownMenuItem(
                              value: 'syrup', child: Text('Syrup')),
                        ],
                        onChanged: (value) {
                          setState(() => medication.type = value!);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Total Pills Available and Type
                Row(
                  children: [
                    if (medication.type == 'pill') ...[
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: medication.totalPillsController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15)),
                            labelText: 'Total Pills Available',
                            hintText: '30',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final number = int.tryParse(value.trim());
                              if (number == null || number <= 0) {
                                return 'Enter a valid number';
                              }
                            } else if (value == null || value.trim().isEmpty) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8)
                    ],
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: medication.category,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15)),
                          labelText: 'Category',
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'diabetes', child: Text('Diabetes')),
                          DropdownMenuItem(
                              value: 'bp_control',
                              child: Text('Blood Pressure')),
                          DropdownMenuItem(
                              value: 'vitamins', child: Text('Vitamins')),
                          DropdownMenuItem(
                              value: 'fever', child: Text('Fever')),
                          DropdownMenuItem(
                              value: 'cold', child: Text('Cold & Flu')),
                          DropdownMenuItem(
                              value: 'antibiotics', child: Text('Antibiotics')),
                          DropdownMenuItem(
                              value: 'pain', child: Text('Pain Relief')),
                          DropdownMenuItem(
                              value: 'general', child: Text('General')),
                        ],
                        onChanged: (value) {
                          setState(() => medication.category = value!);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Daily Schedule Header
                Row(
                  children: [
                    const Text(
                      'Daily Schedule',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _addScheduleTime(medicationIndex),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Time'),
                    ),
                  ],
                ),

                // Schedule Times
                ...medication.scheduleControllers.asMap().entries.map((entry) {
                  int scheduleIndex = entry.key;
                  var schedule = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DateTimeField(
                              color: Colors.white70,
                              controller: schedule.timeController,
                              setState: () => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: schedule.dosageController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white70,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                labelText: 'Dosage',
                                hintText: '2 tablets/ 5ml',
                              ),
                              textCapitalization: medication.type == 'syrup'
                                  ? TextCapitalization.none
                                  : TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter dosage';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (medication.scheduleControllers.length > 1)
                            IconButton(
                              onPressed: () => _removeScheduleTime(
                                  medicationIndex, scheduleIndex),
                              icon: const Icon(Icons.close,
                                  color: Colors.red, size: 25),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ));
  }

  Future<void> _saveMedications() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) {
        _showError('Please log in first');
        return;
      }

      for (var medication in medicationControllers) {
        Map<String, dynamic> medicationData = {
          'pill_name': medication.nameController.text.trim(),
          'type': medication.type,
          'category': medication.category,
          'total_pills':
              int.tryParse(medication.totalPillsController.text.trim()) ?? 0,
          'duration':
              parseDurationText(!isIndefinite, durationController.text) ??
                  {
                    'is_indefinite': isIndefinite,
                    'start_date': Timestamp.now(),
                    'end_date': null,
                    'duration_text': 'Indefinite',
                  },
          'is_active': true,
          'created_at': Timestamp.now(),
          'updated_at': Timestamp.now(),
        };

        DocumentReference medicationRef = await FirebaseFirestore.instance
            .collection('medications')
            .doc(AuthService.getCurrentUser()?.uid)
            .collection('medicines')
            .add(medicationData);

        // Save schedules
        for (int i = 0; i < medication.scheduleControllers.length; i++) {
          var schedule = medication.scheduleControllers[i];

          Map<String, dynamic> scheduleData = {
            'medication_id': medicationRef.id,
            'medication_name': medication.nameController.text.trim(),
            'time': schedule.timeController.text.trim(),
            'dosage': schedule.dosageController.text.trim(),
            'is_active': true,
            'created_at': Timestamp.now(),
          };

          await FirebaseFirestore.instance
              .collection('medications')
              .doc(AuthService.getCurrentUser()?.uid)
              .collection('medicines')
              .doc(medicationRef.id)
              .collection('schedules')
              .add(scheduleData);
        }

        await MedicationAlarmService.scheduleMedicationAlarms(medicationRef.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              medicationControllers.length == 1
                  ? 'Medication saved and alarms set!'
                  : '${medicationControllers.length} medications saved and alarms set!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      debugPrint('Error in _saveMedications: $e');
      if (mounted) {
        _showError('Failed to save medications. Please try again. $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _updateMedicationControllers(String value) {
    int newCount = int.tryParse(value) ?? 0;
    int currentCount = medicationControllers.length;

    setState(() {
      if (newCount > currentCount) {
        for (int i = currentCount; i < newCount; i++) {
          medicationControllers.add(MedicationController());
        }
      } else if (newCount < currentCount) {
        for (int i = currentCount - 1; i >= newCount; i--) {
          medicationControllers[i].dispose();
          medicationControllers.removeAt(i);
        }
      }
    });
  }

  void _removeMedication(int index) {
    setState(() {
      medicationControllers[index].dispose();
      medicationControllers.removeAt(index);
      medicationCountController.text = medicationControllers.length.toString();
    });
  }

  void _addScheduleTime(int medicationIndex) {
    setState(() {
      medicationControllers[medicationIndex]
          .scheduleControllers
          .add(ScheduleController());
    });
  }

  void _removeScheduleTime(int medicationIndex, int scheduleIndex) {
    setState(() {
      medicationControllers[medicationIndex]
          .scheduleControllers[scheduleIndex]
          .dispose();
      medicationControllers[medicationIndex]
          .scheduleControllers
          .removeAt(scheduleIndex);
    });
  }

  Widget _buildCounterButtons() {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              int current = int.tryParse(medicationCountController.text) ?? 0;
              medicationCountController.text = (current + 1).toString();
              _updateMedicationControllers(medicationCountController.text);
            },
            style: IconButton.styleFrom(
              minimumSize: const Size(56, 56),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
            ),
            icon: const Icon(Icons.add),
          ),
          const VerticalDivider(
            width: 0,
            indent: 8,
            endIndent: 8,
            color: Colors.black26,
          ),
          TextButton(
            onPressed: () {
              int current = int.tryParse(medicationCountController.text) ?? 0;
              if (current > 0) {
                medicationCountController.text = (current - 1).toString();
                _updateMedicationControllers(medicationCountController.text);
              }
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(56, 56),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
            ),
            child: const Text('-',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                )),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    durationController.dispose();
    medicationCountController.dispose();
    for (var medication in medicationControllers) {
      medication.dispose();
    }
    super.dispose();
  }

  // ✅ NEW: Check alarm permissions
  Future<void> _checkAlarmPermissions() async {
    try {
      debugPrint('🔍 Checking alarm permissions...');

      // Request permissions if needed
      final hasPermissions =
          await AlarmNotificationService.requestAllPermissions();

      if (!hasPermissions) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ Some permissions are missing. Alarms may not work properly.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ All alarm permissions granted!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
    }
  }
}

class MedicationController {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController totalPillsController = TextEditingController();
  List<ScheduleController> scheduleControllers = [ScheduleController()];
  String category = 'general';
  String type = 'pill';

  void dispose() {
    nameController.dispose();
    totalPillsController.dispose();
    for (var schedule in scheduleControllers) {
      schedule.dispose();
    }
  }
}

class ScheduleController {
  final TextEditingController timeController = TextEditingController();
  final TextEditingController dosageController = TextEditingController();

  void dispose() {
    timeController.dispose();
    dosageController.dispose();
  }
}
