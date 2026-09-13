class AttendanceRecord {
  final String date;
  final String status;

  const AttendanceRecord({required this.date, required this.status});

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class EmployeeAttendanceData {
  final String empCode;
  final String name;
  final String company;
  final String month;
  final Map<String, dynamic> summary;
  final List<AttendanceRecord> attendance;
  final List<Map<String, dynamic>> messReturns;
  final String notice;

  const EmployeeAttendanceData({
    required this.empCode,
    required this.name,
    required this.company,
    required this.month,
    required this.summary,
    required this.attendance,
    required this.messReturns,
    required this.notice,
  });

  factory EmployeeAttendanceData.fromJson(Map<String, dynamic> json) {
    final rawAttendance = json['attendance'];
    final List<AttendanceRecord> records = [];

    if (rawAttendance is List) {
      for (final item in rawAttendance) {
        if (item is Map) {
          records.add(
            AttendanceRecord.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawSummary = json['summary'];
    Map<String, dynamic> summaryMap = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary)
        : <String, dynamic>{};

    if (summaryMap.containsKey('VACATION') && !summaryMap.containsKey('V')) {
      summaryMap['V'] = summaryMap['VACATION'];
    }

    final rawMess = json['messReturns'];
    final List<Map<String, dynamic>> messList = [];
    if (rawMess is List) {
      for (final item in rawMess) {
        if (item is Map) {
          messList.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return EmployeeAttendanceData(
      empCode: json['empCode']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      summary: summaryMap,
      attendance: records,
      messReturns: messList,
      notice: json['notice']?.toString() ?? '',
    );
  }
}
