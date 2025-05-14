import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

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
          var tasks = List<Map<String, dynamic>>.from(data["job"])
              .where((job) => job["status"]?.toLowerCase() == "completed")
              .toList();
          debugPrint("Completed tasks before filter: ${tasks.length}");
          for (var task in tasks) {
            debugPrint("Task part_number: ${task['part_number']}");
          }
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

  Future<Map<String, dynamic>?> fetchJobDetails(String controlNumber, dynamic jobId) async {
    final url = "http://10.176.21.109:4000/api/job-details/$controlNumber/$jobId";
    debugPrint("🔍 Fetching job details from: $url");
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {"Accept": "application/json"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("Job Details Response: $data");
        if (data["success"] && data["job_details"] != null) {
          final jobDetails = Map<String, dynamic>.from(data["job_details"]);
          // Map job_description to part_details[0].description if available
          if (jobDetails["part_details"] != null && jobDetails["part_details"].isNotEmpty) {
            jobDetails["job_description"] = jobDetails["part_details"][0]["description"] ?? "N/A";
          } else {
            jobDetails["job_description"] = "N/A";
          }
          return jobDetails;
        } else {
          throw Exception(data["message"] ?? "No job details found");
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e) {
      debugPrint("Error fetching job details: $e");
      return null;
    }
  }

  bool _matchesFilter(Map<String, dynamic> job) {
    if (job["actual_end_date"] == null) return false;
    try {
      final date = DateTime.parse(job["actual_end_date"]);
      final monthName = months[date.month];
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
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _formatPartNumber(dynamic partNumber) {
    if (partNumber == null) return 'N/A';
    if (partNumber is String) return partNumber;
    if (partNumber is List) return partNumber.join(', ');
    if (partNumber is int) return partNumber.toString();
    return 'Unknown';
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is String) return value.isEmpty ? 'N/A' : value;
    if (value is int || value is double) return value.toString();
    if (value is List) return value.join(', ');
    return value.toString();
  }

  void openDocument(String? docPath) async {
    if (docPath == null || docPath.isEmpty) {
      debugPrint("❌ Document path is empty.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No document available")),
      );
      return;
    }

    const String baseUrl = "http://10.176.21.109:4000";
    final String cleanedPath = docPath.replaceAll('\\', '/').replaceFirst(RegExp(r'^/'), '');
    final String fullUrl = "$baseUrl/$cleanedPath";

    debugPrint("📂 Downloading document from: $fullUrl");

    try {
      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = cleanedPath.split('/').last;
        final filePath = "${directory.path}/$fileName";
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        debugPrint("✅ Document downloaded: $filePath");

        final result = await OpenFile.open(filePath);
        debugPrint("📖 OpenFile result: ${result.message}");

        if (result.type != ResultType.done) {
          debugPrint("⚠ OpenFile failed: ${result.message}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to open document: ${result.message}")),
          );
        }
      } else {
        debugPrint("❌ Failed to download document: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to download document")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error opening document: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening document: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Completed Tasks")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
              "Control No: ${_formatValue(task['control_number'])}",
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
            trailing: IconButton(
              icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
              onPressed: () => _showTaskDetailsDialog(context, task),
            ),
          ),
        );
      },
    );
  }

  void _showTaskDetailsDialog(BuildContext context, Map<String, dynamic> task) async {
    // Show loading dialog while fetching details
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading job details..."),
            ],
          ),
        );
      },
    );

    // Fetch additional job details
    final jobDetails = await fetchJobDetails(
      _formatValue(task['control_number']),
      _formatValue(task['id']),
    );

    // Close loading dialog
    Navigator.of(context).pop();

    // Merge task data with job details
    final mergedTask = {
      ...task,
      if (jobDetails != null) ...jobDetails,
    };

    // Show details dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Task Details - ${_formatValue(mergedTask['control_number'])}"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogDetailRow("Control Number", _formatValue(mergedTask['control_number'])),
                _buildDialogDetailRow("Part Number", _formatPartNumber(mergedTask['part_number'])),
                _buildDialogDetailRow("Start Date", _formatDate(mergedTask['start_date'])),
                _buildDialogDetailRow("End Date", _formatDate(mergedTask['end_date'])),
                _buildDialogDetailRow("Completed On", _formatDate(mergedTask['actual_end_date'])),
                _buildDialogDetailRow("Status", _formatValue(mergedTask['status'])),
                _buildDialogDetailRow("Job Description", _formatValue(mergedTask['job_description'])),
                _buildDialogDetailRow("Assigned Date", _formatDate(mergedTask['assigned_date'])),
                _buildDialogDetailRow("Priority", _formatValue(mergedTask['priority'])),
                _buildDialogDetailRow("Assigned By", _formatValue(mergedTask['assigned_by'])),
                _buildDialogDetailRow("Job ID", _formatValue(mergedTask['id'])),
                if (mergedTask['doc_upload_path'] != null && mergedTask['doc_upload_path'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          "Document",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.file_present, color: Colors.blue),
                          onPressed: () => openDocument(mergedTask['doc_upload_path']),
                          tooltip: "View Document",
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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