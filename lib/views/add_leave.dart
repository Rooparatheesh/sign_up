import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddLeaveScreen extends StatefulWidget {
  const AddLeaveScreen({super.key, required String employeeId, required String employeeName});

  @override
  // ignore: library_private_types_in_public_api
  _AddLeaveScreenState createState() => _AddLeaveScreenState();
}

class _AddLeaveScreenState extends State<AddLeaveScreen> {
  String? employeeId;
  String? employeeName;
  int? selectedLeaveType; // ✅ Defined at class level (Fixed)
  DateTime? startDate;
  DateTime? endDate;
  String reason = "";
  List<Map<String, dynamic>> leaveTypes = [];

  // ✅ Controllers to Display Dates in TextFields
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadEmployeeDetails();
    _fetchLeaveTypes();
  }

  // ✅ Fetch Employee ID & Name from SharedPreferences
  Future<void> _loadEmployeeDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      employeeId = prefs.getString("employeeID");
      employeeName = prefs.getString("employeeName");
    });
  }

  // ✅ Fetch Leave Types from API
  Future<void> _fetchLeaveTypes() async {
    try {
      final response = await http.get(Uri.parse('http://10.176.20.30:4000/api/leave_master'));
      if (response.statusCode == 200) {
        setState(() {
          leaveTypes = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
      } else {
        throw Exception("Failed to load leave types");
      }
    } catch (e) {
      print("❌ Error: $e");
    }
  }

  // ✅ Handle Date Selection & Update UI
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          _startDateController.text = "${picked.toLocal()}".split(' ')[0]; // ✅ Update TextField
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = startDate;
            _endDateController.text = "${startDate!.toLocal()}".split(' ')[0]; // ✅ Update TextField
          }
        } else {
          endDate = picked;
          _endDateController.text = "${picked.toLocal()}".split(' ')[0]; // ✅ Update TextField
        }
      });
    }
  }

  // ✅ Submit Leave Request
  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (employeeId == null || employeeName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error: Employee details not found.")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.176.20.30:4000/api/leaverequests'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "emp_id": employeeId,
          "emp_name": employeeName,
          "leave_type": selectedLeaveType, // ✅ Using correct leave type (int)
          "start_date": startDate?.toIso8601String(),
          "end_date": endDate?.toIso8601String(),
          "reason": reason,
        }),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ ${responseData['message']}")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ ${responseData['message']}")),
        );
      }
    } catch (e) {
      print("❌ Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Leave Request")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Display Employee Name
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  "Employee Name: ${employeeName ?? 'Loading...'}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              // ✅ Leave Type Dropdown
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: "Leave Type"),
                value: selectedLeaveType,
                items: leaveTypes.map((type) {
                  return DropdownMenuItem<int>(
                    value: type['id'], // ✅ Use `id` instead of `leave_type`
                    child: Text(type['leave_type']), // Show leave type name
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedLeaveType = value),
                validator: (value) => value == null ? "Select leave type" : null,
              ),

              // ✅ Start Date Picker (TextField)
              TextFormField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: "From Date",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, true),
                validator: (value) => value == null || value.isEmpty ? "Select start date" : null,
              ),

              // ✅ End Date Picker (TextField)
              TextFormField(
                controller: _endDateController,
                decoration: const InputDecoration(
                  labelText: "To Date",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, false),
                validator: (value) => value == null || value.isEmpty ? "Select end date" : null,
              ),

              // ✅ Reason TextField
              TextFormField(
                decoration: const InputDecoration(labelText: "Reason"),
                maxLines: 3,
                onChanged: (value) => reason = value,
                validator: (value) => value!.isEmpty ? "Enter reason" : null,
              ),

              const SizedBox(height: 20),

              // ✅ Submit Button
              Center(
                child: ElevatedButton(
                  onPressed: _submitLeaveRequest,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text("Submit", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
