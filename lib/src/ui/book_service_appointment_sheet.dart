import 'package:flutter/material.dart';
import '../service/service_appointment_manager.dart';
import '../theme/app_theme.dart';
import '../ui/app_notification.dart';
import '../ui/chery_service_centres_screen.dart';

/// Interactive modal sheet to book or reschedule a Chery Service appointment with reminder.
class BookServiceAppointmentSheet extends StatefulWidget {
  final CheryServiceCentre? preselectedCentre;
  final String? initialServiceType;
  final ServiceAppointment? existingAppointment; // If rescheduling

  const BookServiceAppointmentSheet({
    super.key,
    this.preselectedCentre,
    this.initialServiceType,
    this.existingAppointment,
  });

  static Future<ServiceAppointment?> show(
    BuildContext context, {
    CheryServiceCentre? preselectedCentre,
    String? initialServiceType,
    ServiceAppointment? existingAppointment,
  }) {
    final colors = AppColors(context);
    return showModalBottomSheet<ServiceAppointment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BookServiceAppointmentSheet(
        preselectedCentre: preselectedCentre,
        initialServiceType: initialServiceType,
        existingAppointment: existingAppointment,
      ),
    );
  }

  @override
  State<BookServiceAppointmentSheet> createState() => _BookServiceAppointmentSheetState();
}

class _BookServiceAppointmentSheetState extends State<BookServiceAppointmentSheet> {
  late CheryServiceCentre _selectedCentre;
  late String _selectedServiceType;
  late DateTime _selectedDate;
  late String _selectedTimeSlot;
  late String _selectedReminder;
  final TextEditingController _notesController = TextEditingController();

  static const List<String> _serviceTypes = [
    '1,000 km 1st Inspection & Activation (FOC)',
    '10,000 km Minor Service (RM 407.50)',
    '20,000 km Service (RM 444.60 • Free Labour)',
    '30,000 km Service (RM 715.90 • Spark Plugs)',
    '40,000 km Major Hybrid Service (RM 1,085.60)',
    'High-Voltage BMS & 3DHT Diagnostic Scan',
    'General PHEV Inspection / Troubleshooting',
    'Tyre Rotation & Alignment Check',
  ];

  static const List<String> _timeSlots = [
    '08:30 AM',
    '09:30 AM',
    '10:30 AM',
    '11:30 AM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
  ];

  static const Map<String, String> _reminders = {
    '1_day_before': '1 day before',
    '2_hours_before': '2 hours before',
    'morning_of': 'Morning of service (8:00 AM)',
    'none': 'No reminder',
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAppointment;

    if (existing != null) {
      // Find centre by ID
      final match = CheryServiceDirectory.centres.firstWhere(
        (c) => c.id == existing.centreId,
        orElse: () => CheryServiceDirectory.centres.first,
      );
      _selectedCentre = match;
      _selectedServiceType = existing.serviceType;
      _selectedDate = existing.appointmentDate;
      _selectedTimeSlot = existing.timeSlot;
      _selectedReminder = existing.reminderPreference;
      _notesController.text = existing.notes;
    } else {
      _selectedCentre = widget.preselectedCentre ?? CheryServiceDirectory.centres.first;
      _selectedServiceType = widget.initialServiceType ?? _serviceTypes.first;
      // Default to tomorrow or next business day
      var nextDay = DateTime.now().add(const Duration(days: 1));
      if (nextDay.weekday == DateTime.sunday) {
        nextDay = nextDay.add(const Duration(days: 1));
      }
      _selectedDate = DateTime(nextDay.year, nextDay.month, nextDay.day);
      _selectedTimeSlot = _timeSlots[1]; // 09:30 AM
      _selectedReminder = '1_day_before';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = now.add(const Duration(days: 0));
    final last = now.add(const Duration(days: 180));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(first) ? first : _selectedDate,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (date) {
        // Chery service centres are typically closed on Sundays
        return date.weekday != DateTime.sunday;
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _handleSave() async {
    final isReschedule = widget.existingAppointment != null;
    final apt = ServiceAppointment(
      id: widget.existingAppointment?.id ?? 'apt_${DateTime.now().millisecondsSinceEpoch}',
      centreId: _selectedCentre.id,
      centreName: _selectedCentre.name,
      centreAddress: _selectedCentre.address,
      centrePhone: _selectedCentre.phone,
      serviceType: _selectedServiceType,
      appointmentDate: _selectedDate,
      timeSlot: _selectedTimeSlot,
      reminderPreference: _selectedReminder,
      notes: _notesController.text.trim(),
      createdAt: widget.existingAppointment?.createdAt ?? DateTime.now(),
    );

    await ServiceAppointmentManager.instance.setAppointment(apt);

    if (mounted) {
      Navigator.pop(context, apt);
      AppNotification.show(
        context,
        title: isReschedule ? 'Appointment Rescheduled' : 'Service Appointment Confirmed',
        message: '${apt.serviceType} at ${apt.centreName} on ${apt.formattedDate} (${apt.timeSlot}).',
        type: NotificationType.success,
        icon: Icons.calendar_month_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;
    final isReschedule = widget.existingAppointment != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: colors.evTeal.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event_available_rounded, color: colors.evTeal, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isReschedule ? 'Reschedule Service' : 'Book Service Appointment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Official Chery Authorised 3S/4S Network',
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Form content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Section 1: Service Centre
                    _buildSectionHeader(colors, '1. SELECT SERVICE CENTRE', Icons.storefront_rounded),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.tileBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CheryServiceCentre>(
                          isExpanded: true,
                          value: _selectedCentre,
                          dropdownColor: colors.cardBg,
                          items: CheryServiceDirectory.centres.map((c) {
                            return DropdownMenuItem<CheryServiceCentre>(
                              value: c,
                              child: Text(
                                '${c.name} (${c.type} • ${c.state})',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textPrimary,
                                  fontWeight: c.id == _selectedCentre.id ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCentre = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '📍 ${_selectedCentre.address}',
                        style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Service Milestone / Type
                    _buildSectionHeader(colors, '2. SERVICE MILESTONE / TYPE', Icons.build_circle_outlined),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.tileBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedServiceType,
                          dropdownColor: colors.cardBg,
                          items: _serviceTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colors.textPrimary,
                                  fontWeight: type == _selectedServiceType ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedServiceType = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 3: Date & Time Slot
                    _buildSectionHeader(colors, '3. APPOINTMENT DATE & TIME', Icons.calendar_today_rounded),
                    const SizedBox(height: 6),
                    // Date picker button
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.tileBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.event, size: 18, color: colors.evTeal),
                                const SizedBox(width: 10),
                                Text(
                                  _formatDateDisplay(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.evTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Change Date',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.evTeal),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Time slot chips
                    Text(
                      'Available Time Slots (Mon - Sat):',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _timeSlots.map((slot) {
                        final isSelected = slot == _selectedTimeSlot;
                        return ChoiceChip(
                          label: Text(
                            slot,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.black : colors.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: colors.evTeal,
                          backgroundColor: colors.tileBg,
                          side: BorderSide(
                            color: isSelected ? colors.evTeal : colors.border,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedTimeSlot = slot);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Section 4: Reminder Preference
                    _buildSectionHeader(colors, '4. SET REMINDER NOTIFICATION', Icons.alarm_rounded),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.tileBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: _reminders.entries.map((entry) {
                          final isSelected = entry.key == _selectedReminder;
                          return InkWell(
                            onTap: () => setState(() => _selectedReminder = entry.key),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 16,
                                    color: isSelected ? colors.evTeal : colors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isSelected ? colors.textPrimary : colors.textSecondary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 5: Notes / Special Requests
                    _buildSectionHeader(colors, '5. NOTES / SPECIAL REQUESTS (OPTIONAL)', Icons.edit_note_rounded),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      style: TextStyle(fontSize: 13, color: colors.textPrimary),
                      maxLines: 2,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.tileBg,
                        hintText: 'e.g. Please check firmware update, tyre balancing, or AC...',
                        hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.evTeal)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Bottom Confirmation Deck
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _handleSave,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        isReschedule ? 'Update Booking' : 'Confirm Appointment',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.evTeal,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(AppColors colors, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: colors.evTeal),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatDateDisplay(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
