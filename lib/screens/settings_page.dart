import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medical_tracking_app/services/auth_service.dart';
import 'package:medical_tracking_app/services/alarm_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _fullScreenAlarms = true;
  String _alarmTone = 'marimba.mp3';
  String _snoozeInterval = '5';
  int _maxSnoozes = 3;

  bool _isLoading = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
    _getAppVersion();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _emailController.text = user.email ?? '';
        _nameController.text = user.displayName ?? '';
      });

      // Load additional user data from Firestore
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _phoneController.text = data['phone'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('user_settings')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _notificationsEnabled = data['notifications_enabled'] ?? true;
            _soundEnabled = data['sound_enabled'] ?? true;
            _vibrationEnabled = data['vibration_enabled'] ?? true;
            _fullScreenAlarms = data['full_screen_alarms'] ?? true;
            _alarmTone = data['alarm_tone'] ?? 'marimba.mp3';
            _snoozeInterval = data['snooze_interval'] ?? '5';
            _maxSnoozes = data['max_snoozes'] ?? 3;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('user_settings')
            .doc(user.uid)
            .set({
          'notifications_enabled': _notificationsEnabled,
          'sound_enabled': _soundEnabled,
          'vibration_enabled': _vibrationEnabled,
          'full_screen_alarms': _fullScreenAlarms,
          'alarm_tone': _alarmTone,
          'snooze_interval': _snoozeInterval,
          'max_snoozes': _maxSnoozes,
          'updated_at': Timestamp.now(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Settings saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update display name
        await user.updateDisplayName(_nameController.text.trim());

        // Save additional data to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'updated_at': Timestamp.now(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getAppVersion() async {
    setState(() {
      _appVersion = '1.0.0 (1)';
    });
  }

  Future<void> _checkPermissions() async {
    final results = await [
      Permission.notification,
      Permission.scheduleExactAlarm,
      Permission.systemAlertWindow,
      Permission.ignoreBatteryOptimizations,
    ].request();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPermissionStatus(
                  'Notifications', results[Permission.notification]!),
              _buildPermissionStatus(
                  'Exact Alarms', results[Permission.scheduleExactAlarm]!),
              _buildPermissionStatus('System Alert Window',
                  results[Permission.systemAlertWindow]!),
              _buildPermissionStatus('Ignore Battery Optimization',
                  results[Permission.ignoreBatteryOptimizations]!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPermissionStatus(String name, PermissionStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case PermissionStatus.granted:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case PermissionStatus.denied:
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case PermissionStatus.permanentlyDenied:
        color = Colors.red.shade800;
        icon = Icons.block;
        break;
      default:
        color = Colors.orange;
        icon = Icons.warning;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
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
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            _buildWelcomeHeader(),
            const SizedBox(height: 24),

            // Profile Section
            _buildModernSectionCard(
              title: 'Profile Information',
              icon: Icons.person_rounded,
              iconColor: Colors.blue,
              children: [
                _buildModernTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  enabled: false,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                _buildModernButton(
                  onPressed: _saveProfile,
                  icon: Icons.save_rounded,
                  label: 'Save Profile',
                  color: Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Notification Settings
            _buildModernSectionCard(
              title: 'Alarm & Notifications',
              icon: Icons.notifications_rounded,
              iconColor: Colors.orange,
              children: [
                _buildModernSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive medication reminders',
                  icon: Icons.notifications_active_rounded,
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildModernSwitchTile(
                  title: 'Alarm Sound',
                  subtitle: 'Play audio when alarm rings',
                  icon: Icons.volume_up_rounded,
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() {
                      _soundEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildModernSwitchTile(
                  title: 'Vibration',
                  subtitle: 'Vibrate device on alarm',
                  icon: Icons.vibration_rounded,
                  value: _vibrationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _vibrationEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildModernSwitchTile(
                  title: 'Full-Screen Alarms',
                  subtitle: 'Show over other apps like system alarm',
                  icon: Icons.fullscreen_rounded,
                  value: _fullScreenAlarms,
                  onChanged: (value) {
                    setState(() {
                      _fullScreenAlarms = value;
                    });
                    _saveSettings();
                  },
                ),
                const SizedBox(height: 12),
                _buildModernOptionTile(
                  title: 'Alarm Tone',
                  subtitle: _alarmTone.replaceAll('.mp3', '').toUpperCase(),
                  icon: Icons.music_note_rounded,
                  onTap: _showAlarmToneDialog,
                ),
                _buildModernOptionTile(
                  title: 'Snooze Duration',
                  subtitle: '$_snoozeInterval minutes',
                  icon: Icons.snooze_rounded,
                  onTap: _showSnoozeIntervalDialog,
                ),
                _buildModernOptionTile(
                  title: 'Max Snoozes',
                  subtitle: '$_maxSnoozes times',
                  icon: Icons.repeat_rounded,
                  onTap: _showMaxSnoozesDialog,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // App Settings
            _buildModernSectionCard(
              title: 'App Settings',
              icon: Icons.settings_rounded,
              iconColor: Colors.purple,
              children: [
                _buildModernActionTile(
                  title: 'App Permissions',
                  subtitle: 'Manage notification & alarm permissions',
                  icon: Icons.security_rounded,
                  color: Colors.green,
                  onTap: _checkPermissions,
                ),
                _buildModernActionTile(
                  title: 'Test Alarm',
                  subtitle: 'Test your alarm settings',
                  icon: Icons.alarm_rounded,
                  color: Colors.orange,
                  onTap: () async {
                    try {
                      await AlarmNotificationService.showTestAlarm();
                      if (mounted) {
                        _showSuccessSnackBar(
                            '🔔 Test alarm will ring in 10 seconds');
                      }
                    } catch (e) {
                      if (mounted) {
                        _showErrorSnackBar('Failed to set test alarm: $e');
                      }
                    }
                  },
                ),
                _buildModernInfoTile(
                  title: 'App Version',
                  subtitle: _appVersion.isEmpty ? 'Loading...' : _appVersion,
                  icon: Icons.info_rounded,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Account Actions
            _buildModernSectionCard(
              title: 'Account',
              icon: Icons.account_circle_rounded,
              iconColor: Colors.red,
              children: [
                _buildModernActionTile(
                  title: 'Sign Out',
                  subtitle: 'Sign out of your account',
                  icon: Icons.logout_rounded,
                  color: Colors.red,
                  onTap: _showSignOutDialog,
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showAlarmToneDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Select Alarm Tone'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'marimba.mp3',
            'nokia.mp3',
            'mozart.mp3',
            'star_wars.mp3',
            'one_piece.mp3',
          ]
              .map((tone) => Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _alarmTone == tone
                          ? Colors.blue.withOpacity(0.1)
                          : null,
                    ),
                    child: RadioListTile<String>(
                      title: Text(
                        tone.replaceAll('.mp3', '').toUpperCase(),
                        style: TextStyle(
                          fontWeight: _alarmTone == tone
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color:
                              _alarmTone == tone ? Colors.blue : Colors.black87,
                        ),
                      ),
                      value: tone,
                      groupValue: _alarmTone,
                      activeColor: Colors.blue,
                      onChanged: (value) {
                        setState(() {
                          _alarmTone = value!;
                        });
                        _saveSettings();
                        Navigator.pop(context);
                      },
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSnoozeIntervalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.snooze_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Snooze Interval'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['1', '5', '10', '15', '30']
              .map((interval) => Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _snoozeInterval == interval
                          ? Colors.orange.withOpacity(0.1)
                          : null,
                    ),
                    child: RadioListTile<String>(
                      title: Text(
                        '$interval minutes',
                        style: TextStyle(
                          fontWeight: _snoozeInterval == interval
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _snoozeInterval == interval
                              ? Colors.orange
                              : Colors.black87,
                        ),
                      ),
                      value: interval,
                      groupValue: _snoozeInterval,
                      activeColor: Colors.orange,
                      onChanged: (value) {
                        setState(() {
                          _snoozeInterval = value!;
                        });
                        _saveSettings();
                        Navigator.pop(context);
                      },
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMaxSnoozesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.repeat_rounded,
                color: Colors.purple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Maximum Snoozes'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 2, 3, 5, 10]
              .map((count) => Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _maxSnoozes == count
                          ? Colors.purple.withOpacity(0.1)
                          : null,
                    ),
                    child: RadioListTile<int>(
                      title: Text(
                        '$count times',
                        style: TextStyle(
                          fontWeight: _maxSnoozes == count
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _maxSnoozes == count
                              ? Colors.purple
                              : Colors.black87,
                        ),
                      ),
                      value: count,
                      groupValue: _maxSnoozes,
                      activeColor: Colors.purple,
                      onChanged: (value) {
                        setState(() {
                          _maxSnoozes = value!;
                        });
                        _saveSettings();
                        Navigator.pop(context);
                      },
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        content:
            const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await AuthService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  // Modern UI Helper Methods
  Widget _buildWelcomeHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'User';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.cyan.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $displayName!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your profile and app preferences',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.grey[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? Colors.grey.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: enabled ? Colors.blue : Colors.grey,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelStyle: TextStyle(
            color: enabled ? Colors.grey[700] : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildModernSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: value ? Colors.blue : Colors.grey[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildModernOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.grey[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
