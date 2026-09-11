import 'dart:convert';
import 'package:http/http.dart' as http;
import 'attendance_model.dart';

class AttendanceService {
  static const String scriptUrl =
      'https://script.google.com/macros/s/AKfycbwqGECS62PuolhoBVoQ5l5Zq2aXG7SuOm3trGBpSVqmU_a24sPqzM1xZ1_SM30OLlx1UQ/exec';

  static Future<EmployeeAttendanceData?> fetchAttendance(
    String empCode,
    String monthKey,
  ) async {
    try {
      final uri = Uri.parse(
        '$scriptUrl'
        '?action=getAttendance'
        '&empCode=${Uri.encodeComponent(empCode)}'
        '&month=${Uri.encodeComponent(monthKey)}',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final body = response.body.trim();
      if (body.isEmpty) return null;

      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;

      final data = Map<String, dynamic>.from(decoded);

      if (data['success'] != true) {
        return null;
      }

      return EmployeeAttendanceData.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
