import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimeField extends StatefulWidget {
  const DateTimeField({
    super.key,
    required this.controller,
    required this.setState,
    this.time = true,
    this.onChanged,
    this.color,
  });
  final TextEditingController controller;
  final VoidCallback setState;
  final bool time;
  final Function(bool)? onChanged;
  final Color? color;
  @override
  State<DateTimeField> createState() => _DateTimeFieldState();
}

class _DateTimeFieldState extends State<DateTimeField> {
  int duration = 0;
  bool indefinite = false;
  String previousText = '';
  @override
  void initState() {
    super.initState();
    if (!widget.time) {
      widget.controller.text = 'Indefinite';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      readOnly: true,
      onTap: () {
        if (widget.time) {
          FocusScope.of(context).unfocus();
          showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          ).then((value) {
            if (value != null && context.mounted) {
              widget.controller.text = value.format(context);
              widget.setState();
            }
          });
        } else if (indefinite) {
          FocusScope.of(context).unfocus();
          showDateRangePicker(
            context: context,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          ).then((value) {
            if (value != null && context.mounted) {
              widget.controller.text =
                  '${formatDate(value.start)} to ${formatDate(value.end)}';
              duration = value.end.difference(value.start).inDays + 1;
              widget.setState();
            }
          });
        } else {
          FocusScope.of(context).unfocus();
          setState(() {
            widget.controller.text = 'Indefinite';
            duration = 0;
          });
          return;
        }
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please select a time';
        }
        return null;
      },
      decoration: InputDecoration(
        filled: widget.color != null,
        fillColor: widget.color,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        labelText: widget.time ? 'Time' : 'Duration',
        prefixIcon: !widget.time
            ? Checkbox(
                value: indefinite,
                onChanged: (value) {
                  setState(() {
                    indefinite = value!;
                    if (!indefinite) previousText = widget.controller.text;
                  });
                  if (indefinite) {
                    showDateRangePicker(
                      context: context,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    ).then((value) {
                      if (value != null && context.mounted) {
                        widget.controller.text =
                            '${formatDate(value.start)} to ${formatDate(value.end)}';
                        duration = value.end.difference(value.start).inDays + 1;
                        widget.setState();
                      }
                    });
                  }
                  widget.controller.text =
                      indefinite ? previousText : 'Indefinite';
                  widget.setState();
                  widget.onChanged!(indefinite);
                })
            : null,
        suffixIcon: !widget.time
            ? Container(
                height: 56,
                width: 102,
                alignment: Alignment.center,
                child: Text(
                  widget.controller.text.isEmpty || !indefinite
                      ? ''
                      : '$duration Days',
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                  ),
                ),
              )
            : null,
      ),
      keyboardType: TextInputType.datetime,
    );
  }
}

String formatDate(DateTime date) {
  return DateFormat('dd MMM yyyy').format(date).toString();
}

Map<String, dynamic>? parseDurationText(bool indefinite, String durationText) {
  if (durationText.isEmpty) return null;

  try {
    List<String> parts = durationText.split(' to ');
    if (parts.length != 2) return null;

    DateTime startDate = DateFormat('dd MMM yyyy').parse(parts[0].trim());
    DateTime endDate = DateFormat('dd MMM yyyy').parse(parts[1].trim());

    int totalDays = endDate.difference(startDate).inDays + 1;
    DateTime now = DateTime.now();
    bool isActive = now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1)));

    return {
      'is_indefinite': indefinite,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'total_days': totalDays,
      'is_active': isActive,
      'duration_text': indefinite ? 'Indefinite' : durationText,
    };
  } catch (e) {
    debugPrint('Error parsing duration: $e');
    return null;
  }
}
