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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text("Completed Tasks", style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Filter Tasks",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedMonth,
                        decoration: InputDecoration(
                          labelText: "Month",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedYear,
                        decoration: InputDecoration(
                          labelText: "Year",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: fetchCompletedTasks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text("Apply Filter", style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
          
          // Tasks list
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading tasks...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[300], size: 48),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: fetchCompletedTasks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }
    
    if (completedTasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.task_alt, color: Colors.grey, size: 48),
              SizedBox(height: 16),
              Text(
                "No completed tasks found",
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: completedTasks.length,
      itemBuilder: (context, index) {
        final task = completedTasks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Control No: ${_formatValue(task['control_number'])}",
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "COMPLETED",
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow("Part Number", _formatPartNumber(task['part_number'])),
                const SizedBox(height: 6),
                _buildInfoRow("Completed", _formatDate(task['actual_end_date'])),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showTaskDetailsDialog(context, task),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text("View Details"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[600],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        const Text(": ", style: TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _showTaskDetailsDialog(BuildContext context, Map<String, dynamic> task) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading details..."),
            ],
          ),
        );
      },
    );

    final jobDetails = await fetchJobDetails(
      _formatValue(task['control_number']),
      _formatValue(task['id']),
    );

    Navigator.of(context).pop();

    final mergedTask = {
      ...task,
      if (jobDetails != null) ...jobDetails,
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            "Task Details",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailItem("Control Number", _formatValue(mergedTask['control_number'])),
                  _buildDetailItem("Part Number", _formatPartNumber(mergedTask['part_number'])),
                  _buildDetailItem("Start Date", _formatDate(mergedTask['start_date'])),
                  _buildDetailItem("End Date", _formatDate(mergedTask['end_date'])),
                  _buildDetailItem("Completed On", _formatDate(mergedTask['actual_end_date'])),
                  _buildDetailItem("Status", _formatValue(mergedTask['status'])),
                  _buildDetailItem("Job Description", _formatValue(mergedTask['job_description'])),
                  _buildDetailItem("Assigned Date", _formatDate(mergedTask['assigned_date'])),
                  _buildDetailItem("Priority", _formatValue(mergedTask['priority'])),
                  _buildDetailItem("Assigned By", _formatValue(mergedTask['assigned_by'])),
                  _buildDetailItem("Total Working Days", _formatValue(mergedTask['total_working_days'])),
                  if (mergedTask['doc_upload_path'] != null && mergedTask['doc_upload_path'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Text(
                            "Document",
                            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => openDocument(mergedTask['doc_upload_path']),
                            icon: const Icon(Icons.file_present_outlined, size: 18),
                            label: const Text("View"),
                            style: TextButton.styleFrom(foregroundColor: Colors.blue[600]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}