import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompletedTasksScreen extends StatefulWidget {
  const CompletedTasksScreen({super.key});

  @override
  State<CompletedTasksScreen> createState() => _CompletedTasksScreenState();
}

class _CompletedTasksScreenState extends State<CompletedTasksScreen> {
  List<Map<String, dynamic>> completedTasks = [];
  bool isLoading = true;
  String? errorMessage;
  String? selectedMonth;
  String? selectedYear;
  List<String> months = [
    'All',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  List<String> years = ['All'] + List.generate(10, (index) => (DateTime.now().year - index).toString());

  @override
  void initState() {
    super.initState();
    // Set default filter to show all completed tasks
    selectedMonth = 'All';
    selectedYear = 'All';
    fetchCompletedTasks();
  }

  Future<void> fetchCompletedTasks() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? empId = prefs.getString("employeeID");

    if (empId == null || empId.isEmpty) {
      setState(() {
        errorMessage = "Employee ID not found";
        isLoading = false;
      });
      return;
    }

    final url = "http://10.176.21.109:4000/api/assigned-jobs/$empId";
    debugPrint("🔍 Fetching completed tasks for Emp ID: $empId");
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {"Accept": "application/json"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("API Response: $data");
        if (data["success"] && data["job"] != null) {
          // Filter for completed tasks
          var tasks = List<Map<String, dynamic>>.from(data["job"])
              .where((job) => job["status"]?.toLowerCase() == "completed")
              .toList();
          debugPrint("Completed tasks before filter: ${tasks.length}");
          // Log part_number for each task
          for (var task in tasks) {
            debugPrint("Task part_number: ${task['part_number']}");
          }
          // Apply month/year filter if not "All"
          if (selectedMonth != 'All' || selectedYear != 'All') {
            tasks = tasks.where((job) => _matchesFilter(job)).toList();
          }
          debugPrint("Filtered completed tasks: ${tasks.length}");
          setState(() {
            completedTasks = tasks;
            isLoading = false;
          });
        } else {
          throw Exception(data["message"] ?? "No completed tasks found");
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  bool _matchesFilter(Map<String, dynamic> job) {
    if (job["actual_end_date"] == null) return false;
    try {
      final date = DateTime.parse(job["actual_end_date"]);
      final monthName = months[date.month]; // Index 1-based for months list
      final yearMatch = selectedYear == 'All' || date.year.toString() == selectedYear;
      final monthMatch = selectedMonth == 'All' || monthName == selectedMonth;
      return monthMatch && yearMatch;
    } catch (e) {
      debugPrint("Filter error: $e");
      return false;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      return DateFormat('dd-MMM-yyyy').format(DateTime.parse(dateString));
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _formatPartNumber(dynamic partNumber) {
    if (partNumber == null) return 'N/A';
    if (partNumber is String) return partNumber;
    if (partNumber is List) return partNumber.join(', ');
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(title: const Text("Completed Tasks")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Filter Tasks",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedMonth,
                            decoration: const InputDecoration(
                              labelText: "Month",
                              border: OutlineInputBorder(),
                            ),
                            items: months.map((month) => DropdownMenuItem(
                              value: month,
                              child: Text(month),
                            )).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedMonth = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedYear,
                            decoration: const InputDecoration(
                              labelText: "Year",
                              border: OutlineInputBorder(),
                            ),
                            items: years.map((year) => DropdownMenuItem(
                              value: year,
                              child: Text(year),
                            )).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedYear = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: fetchCompletedTasks,
                        icon: const Icon(Icons.search),
                        label: const Text("Search"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Task List
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: fetchCompletedTasks,
              child: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    if (completedTasks.isEmpty) {
      return const Center(
        child: Text(
          "No completed tasks found for the selected period",
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: completedTasks.length,
      itemBuilder: (context, index) {
        final task = completedTasks[index];
        debugPrint("Rendering task: ${task['control_number']}, part_number: ${task['part_number']}");
        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              "Control No: ${task['control_number']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildDetailRow("Part Number", _formatPartNumber(task['part_number']), Icons.confirmation_number),
                _buildDetailRow("Completed On", _formatDate(task['actual_end_date']), Icons.check_circle),
                _buildDetailRow("Status", "COMPLETED", Icons.info, color: Colors.green),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, color: color ?? Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}