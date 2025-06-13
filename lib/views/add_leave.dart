import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddLeaveScreen extends StatefulWidget {
  const AddLeaveScreen({super.key, required String employeeId, required String employeeName});

  @override
  _AddLeaveScreenState createState() => _AddLeaveScreenState();
}

class _AddLeaveScreenState extends State<AddLeaveScreen> {
  String? employeeId;
  String? employeeName;
  int? selectedLeaveType;
  DateTime? startDate;
  DateTime? endDate;
  String reason = "";
  List<Map<String, dynamic>> leaveTypes = [];

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadEmployeeDetails();
    _fetchLeaveTypes();
  }

  Future<void> _loadEmployeeDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      employeeId = prefs.getString("employeeID");
      employeeName = prefs.getString("employeeName");
    });
  }

  Future<void> _fetchLeaveTypes() async {
    try {
      final response = await http.get(Uri.parse('http://10.176.21.109:4000/api/leave_master'));
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          _startDateController.text = "${picked.toLocal()}".split(' ')[0];
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = startDate;
            _endDateController.text = "${startDate!.toLocal()}".split(' ')[0];
          }
        } else {
          endDate = picked;
          _endDateController.text = "${picked.toLocal()}".split(' ')[0];
        }
      });
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (employeeId == null || employeeName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Employee details not found")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.176.21.109:4000/api/leaverequests'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "emp_id": employeeId,
          "emp_name": employeeName,
          "leave_type": selectedLeaveType,
          "start_date": startDate?.toIso8601String(),
          "end_date": endDate?.toIso8601String(),
          "reason": reason,
        }),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
      }
    } catch (e) {
      print("❌ Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text("Leave Request", style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  employeeName ?? 'Loading...',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),

              const SizedBox(height: 24),

              // Leave type dropdown
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: "Leave Type",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: selectedLeaveType,
                items: leaveTypes.map((type) {
                  return DropdownMenuItem<int>(
                    value: type['id'],
                    child: Text(type['leave_type']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedLeaveType = value),
                validator: (value) => value == null ? "Please select leave type" : null,
              ),

              const SizedBox(height: 16),

              // Date row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      decoration: InputDecoration(
                        labelText: "From",
                        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context, true),
                      validator: (value) => value?.isEmpty ?? true ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endDateController,
                      decoration: InputDecoration(
                        labelText: "To",
                        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context, false),
                      validator: (value) => value?.isEmpty ?? true ? "Required" : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Reason field
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Reason",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
                onChanged: (value) => reason = value,
                validator: (value) => value?.isEmpty ?? true ? "Please enter reason" : null,
              ),

              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _submitLeaveRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text("Submit Request", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}