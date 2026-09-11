import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';

class AttendanceTrackerScreen extends StatefulWidget {
  const AttendanceTrackerScreen({super.key});

  @override
  State<AttendanceTrackerScreen> createState() =>
      _AttendanceTrackerScreenState();
}

class _AttendanceTrackerScreenState extends State<AttendanceTrackerScreen> {
  final TextEditingController _empCodeController = TextEditingController();

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 1200,
  );

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  String _name = '';
  String _company = '';

  bool _isLoading = false;
  bool _isScanning = true;
  bool _isOnline = true;

  EmployeeAttendanceData? _attendanceData;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _checkInternet();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final online = !results.contains(ConnectivityResult.none);
      if (!mounted) return;
      setState(() {
        _isOnline = online;
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _scannerController.dispose();
    _empCodeController.dispose();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkInternet() async {
    final online = await _hasInternet();
    if (!mounted) return;
    setState(() {
      _isOnline = online;
    });
  }

  String get _selectedMonthKey {
    List<String> months = [
      "JAN",
      "FEB",
      "MAR",
      "APR",
      "MAY",
      "JUN",
      "JUL",
      "AUG",
      "SEP",
      "OCT",
      "NOV",
      "DEC"
    ];
    String mStr = months[_selectedMonth.month - 1];
    String yStr = _selectedMonth.year.toString();
    return "$mStr $yStr";
  }

  String get _selectedMonthName {
    return DateFormat('MMMM yyyy').format(_selectedMonth);
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select any date in the month',
    );

    if (picked == null) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });

    final empCode = _empCodeController.text.trim();
    if (empCode.isNotEmpty) {
      await _loadAttendance(empCode, resetMonth: false);
    }
  }

  void _handleQrScan(String value) {
    if (!_isScanning) return;
    final code = value.trim();
    if (code.isEmpty) return;

    setState(() {
      _isScanning = false;
      _empCodeController.text = code;
    });

    _loadAttendance(code, resetMonth: true);
  }

  Future<void> _loadAttendance(
    String empCode, {
    bool resetMonth = false,
  }) async {
    empCode = empCode.trim().toUpperCase();

    if (empCode.isEmpty) {
      _showMessage('Please scan QR or enter EMP Code.', Colors.orange);
      return;
    }

    if (resetMonth) {
      setState(() {
        _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
      });
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _attendanceData = null;
      _name = '';
      _company = '';
    });

    if (!_isOnline) {
      final online = await _hasInternet();
      if (!mounted) return;
      setState(() {
        _isOnline = online;
      });

      if (!online) {
        setState(() {
          _isLoading = false;
          _isScanning = true;
        });
        _showMessage(
          'No internet connection. Please connect to the internet.',
          Colors.red,
        );
        return;
      }
    }

    final data =
        await AttendanceService.fetchAttendance(empCode, _selectedMonthKey);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isScanning = true;
    });

    if (data == null) {
      _showMessage(
        'Unable to load attendance. Employee not found or network error.',
        Colors.red,
      );
    } else {
      setState(() {
        _attendanceData = data;
        _name = data.name;
        _company = data.company;
      });
    }
  }

  Future<void> _searchEmployee() async {
    final code = _empCodeController.text.trim();
    if (code.isEmpty) {
      _showMessage('Enter EMP Code first.', Colors.orange);
      return;
    }
    await _loadAttendance(code, resetMonth: false);
  }

  void _clearEmployee() {
    setState(() {
      _empCodeController.clear();
      _name = '';
      _company = '';
      _attendanceData = null;
      _isScanning = true;
      _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    });
  }

  String _displayStatus(String status) {
    final value = status.trim().toUpperCase();
    switch (value) {
      case 'P':
        return 'Present';
      case 'AB':
        return 'Absent';
      case 'OT':
        return 'Overtime';
      case 'OFF':
        return 'Week Off';
      case 'DR':
        return 'Duty Return';
      case 'DS':
        return 'Duty Stop';
      case 'IDLE':
        return 'Idle';
      case 'SICK':
        return 'Sick';
      case 'CASH':
        return 'Cash';
      case 'V':
      case 'VACATION':
        return 'Vacation';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  IconData _statusIcon(String status) {
    final value = status.trim().toUpperCase();
    switch (value) {
      case 'P':
        return Icons.check_circle;
      case 'AB':
        return Icons.cancel;
      case 'OT':
        return Icons.timer;
      case 'OFF':
        return Icons.event_busy;
      case 'SICK':
        return Icons.sick;
      case 'DR':
        return Icons.login;
      case 'DS':
        return Icons.logout;
      case 'IDLE':
        return Icons.pause_circle;
      case 'CASH':
        return Icons.payments;
      case 'V':
      case 'VACATION':
        return Icons.card_travel;
      default:
        return Icons.info;
    }
  }

  Color _statusColor(String status) {
    final value = status.trim().toUpperCase();
    switch (value) {
      case 'P':
        return Colors.green;
      case 'AB':
        return Colors.red;
      case 'OT':
        return Colors.orange;
      case 'OFF':
        return Colors.blue;
      case 'SICK':
        return Colors.orange;
      case 'DR':
        return Colors.teal;
      case 'DS':
        return Colors.deepOrange;
      case 'IDLE':
        return Colors.yellow;
      case 'CASH':
        return Colors.purple;
      case 'V':
      case 'VACATION':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  int _summaryValue(String key) {
    final summary = _attendanceData?.summary;
    if (summary == null) return 0;
    var value = summary[key];
    if (value == null && key == 'V') value = summary['VACATION'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Attendance Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.refresh),
            onPressed: _clearEmployee,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final code = _empCodeController.text.trim();
          if (code.isNotEmpty) {
            await _loadAttendance(code, resetMonth: false);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInternetStatus(),
              const SizedBox(height: 12),
              _buildScanner(),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isScanning = true;
                  });
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Tap here to Scan Again'),
              ),
              const SizedBox(height: 12),
              _buildEmployeeInput(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_isLoading && _attendanceData != null) ...[
                _buildEmployeeCard(),
                const SizedBox(height: 16),
                _buildMonthSelector(),
                const SizedBox(height: 16),
                _buildSummary(),
                const SizedBox(height: 16),
                _buildAttendanceList(),
                const SizedBox(height: 16),
                _buildMessReturnContainer(),
              ],
              if (!_isLoading && _attendanceData == null) _buildWelcomeCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInternetStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isOnline
            ? Colors.green.withOpacity(0.10)
            : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isOnline
              ? Colors.green.withOpacity(0.30)
              : Colors.orange.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            size: 20,
            color: _isOnline ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isOnline ? Colors.green[800] : Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 230,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                if (!_isScanning) return;
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue;
                  if (value != null && value.trim().isNotEmpty) {
                    _handleQrScan(value);
                    break;
                  }
                }
              },
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
                child: IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.flash_on),
                  onPressed: () {
                    _scannerController.toggleTorch();
                  },
                ),
              ),
            ),
            if (!_isScanning)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'QR Scanned',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeInput() {
    return TextField(
      controller: _empCodeController,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: 'EMP Code',
        hintText: 'Scan QR or enter EMP Code',
        prefixIcon: const Icon(Icons.badge_outlined),
        suffixIcon: IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search),
          onPressed: _isLoading ? null : _searchEmployee,
        ),
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) {
        _searchEmployee();
      },
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.calendar_month,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Check Your Attendance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan your QR code or enter your EMP Code to view your monthly attendance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name.isEmpty ? '-' : _name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _company.isEmpty ? '-' : _company,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EMP: ${_empCodeController.text.trim().toUpperCase()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return InkWell(
      onTap: _selectMonth,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Attendance Month',
          prefixIcon: Icon(Icons.calendar_month),
          suffixIcon: Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(),
        ),
        child: Text(
          _selectedMonthName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedMonthName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            _summaryCard('Present', _summaryValue('P'), Icons.check_circle,
                Colors.green),
            _summaryCard(
                'Absent', _summaryValue('AB'), Icons.cancel, Colors.red),
            _summaryCard('Week Off', _summaryValue('OFF'), Icons.event_busy,
                Colors.blue),
            _summaryCard(
                'Overtime', _summaryValue('OT'), Icons.timer, Colors.orange),
            _summaryCard(
                'Sick', _summaryValue('SICK'), Icons.sick, Colors.orange),
            _summaryCard(
                'Idle', _summaryValue('IDLE'), Icons.pause_circle, Colors.grey),
            _summaryCard(
                'Duty Return', _summaryValue('DR'), Icons.login, Colors.teal),
            _summaryCard('Duty Stop', _summaryValue('DS'), Icons.logout,
                Colors.deepOrange),
            _summaryCard(
                'Cash', _summaryValue('CASH'), Icons.payments, Colors.purple),
            _summaryCard('Vacation', _summaryValue('V'), Icons.card_travel,
                Colors.indigo),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    final records = List<AttendanceRecord>.from(
      _attendanceData?.attendance ?? <AttendanceRecord>[],
    );

    records.sort((a, b) => a.date.compareTo(b.date));

    if (records.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Icon(Icons.event_note, size: 50, color: Colors.grey),
              const SizedBox(height: 10),
              const Text(
                'No attendance records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                'No attendance has been recorded for $_selectedMonthName.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Daily Attendance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = records[index];
                DateTime? date;

                try {
                  date = DateTime.parse(record.date);
                } catch (_) {}

                final dateText = date == null
                    ? record.date
                    : DateFormat('dd-MM-yyyy').format(date);

                final weekday =
                    date == null ? '' : DateFormat('EEE').format(date);
                final statusColor = _statusColor(record.status);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.12),
                    child: Icon(_statusIcon(record.status), color: statusColor),
                  ),
                  title: Text(
                    dateText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: weekday.isEmpty ? null : Text(weekday),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _displayStatus(record.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessReturnContainer() {
    final messList = _attendanceData?.messReturns ?? [];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant,
                      size: 25, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Mess',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            if (messList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    'No mess return records for this month.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: messList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final mess = messList[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(
                      child: Text(
                        mess['mealType'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
