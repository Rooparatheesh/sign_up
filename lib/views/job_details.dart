import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class JobDetailsScreen extends StatefulWidget {
  final int controlNumber;
  final int jobId;

  const JobDetailsScreen({super.key, required this.controlNumber, required this.jobId});

  @override
  // ignore: library_private_types_in_public_api
  _JobDetailsScreenState createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  Map<String, dynamic>? jobDetails;
  bool isLoading = true;
  bool isUpdating = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchJobDetails();
  }

  Future<void> fetchJobDetails() async {
  final url = "http://10.176.20.30:4000/api/job-details/${widget.controlNumber}/${widget.jobId}";
  debugPrint("🔍 Fetching job details from: $url");

  try {
    final response = await http.get(Uri.parse(url));
    debugPrint("🔹 Response Status Code: ${response.statusCode}");
    debugPrint("🔹 Response Body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint("🔹 Response Data: $data");

      if (data["success"] == true && data["job_details"] != null) {
        setState(() {
          jobDetails = data["job_details"];
          debugPrint("✅ Job Status: ${jobDetails?["status"]}");
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "No job details found or invalid data format.";
          isLoading = false;
        });
      }
    } else {
      setState(() {
        errorMessage = "Error: ${response.statusCode}. Failed to load data.";
        isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = "Error fetching job details: $e";
      isLoading = false;
    });
  }
}

Future<void> updateJobStatus(String status, {String? reason, String? message}) async {
  if (jobDetails == null) {
    debugPrint("⚠️ Job details or job ID is null. Cannot update status.");
    return;
  }

  final currentStatus = jobDetails?["status"];
  debugPrint("🔍 Current Status: $currentStatus");

  if (currentStatus == status) {
    debugPrint("⚠️ No status change detected. Update not required.");
    return;
  }

  setState(() {
    isUpdating = true;
  });

  const url = "http://10.176.20.30:4000/update-job-status";

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id": widget.jobId,
        "status": status,
        "reason": reason,
        "message": message ?? "",
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData["success"] == true) {
      setState(() {
        jobDetails?["status"] = status;
        isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Job status updated to $status!"), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Failed: ${responseData["message"]}"), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    setState(() {
      isUpdating = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("🚨 Error updating status: $e"), backgroundColor: Colors.red),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Job Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
              fetchJobDetails();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorView()
              : _buildJobDetails(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: fetchJobDetails,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

void _showHoldReasonDialog() {
  String? selectedReason;
  TextEditingController messageController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Select Hold Reason"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile(
                  title: Text(
                    "Incomplete",
                    style: TextStyle(
                      color: selectedReason == "Incomplete" ? Colors.orange : Colors.black,
                      fontWeight: selectedReason == "Incomplete" ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  value: "Incomplete",
                  groupValue: selectedReason,
                  onChanged: (value) => setState(() => selectedReason = value as String?),
                  activeColor: Colors.orange,
                ),
                RadioListTile(
                  title: Text(
                    "Unavailable",
                    style: TextStyle(
                      color: selectedReason == "Unavailable" ? Colors.orange : Colors.black,
                      fontWeight: selectedReason == "Unavailable" ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  value: "Unavailable",
                  groupValue: selectedReason,
                  onChanged: (value) => setState(() => selectedReason = value as String?),
                  activeColor: Colors.orange,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: "Additional Comments (Optional)",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: selectedReason == null
                    ? null // Disable button if no reason is selected
                    : () async {
                        setState(() => isUpdating = true);
                        Navigator.pop(context);

                        // First, set status to "pending"
                        await updateJobStatus("pending", reason: selectedReason, message: messageController.text);

                        // Then, enable "Approve" button in the web app
                        setState(() => isUpdating = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedReason != null ? Colors.orange : Colors.grey, // Disable if no reason
                ),
                child: const Text("Submit"),
              ),
            ],
          );
        },
      );
    },
  );
}


Widget _buildJobDetails() {
  if (jobDetails == null) {
    return const Center(child: Text("No data available"));
  }

  final controlNumber = jobDetails?['control_number']?.toString() ?? "N/A";
  final assignedEmployees = _formatEmployeeNames(jobDetails?['employee_names']);
  final startDate = _formatDate(jobDetails?['start_date']);
  final endDate = _formatDate(jobDetails?['end_date']);
  final group = jobDetails?['group_section'] ?? "N/A";
  final priority = jobDetails?['priority'] ?? "N/A";
  final List<dynamic> partDetails = jobDetails?['part_details'] ?? [];

  String status = jobDetails?["status"] ?? "unknown";

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Control Number", controlNumber, Icons.confirmation_number),
            const Divider(),
            _buildDetailRow("Assigned Employees", assignedEmployees, Icons.people),
            _buildDetailRow("Start Date", startDate, Icons.calendar_today),
            _buildDetailRow("End Date", endDate, Icons.calendar_today),
            const Divider(),
            _buildDetailRow("Group", group, Icons.group),
            _buildDetailRow("Priority", priority, Icons.priority_high),
            const Text("Part Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Column(
              children: partDetails.map((part) {
                final partNumber = part['part_number'] ?? "N/A";
                final description = part['description'] ?? "N/A";
                final quantity = part['quantity']?.toString() ?? "N/A";

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow("Part Number", partNumber, Icons.build),
                    _buildDetailRow("Description", description, Icons.description),
                    _buildDetailRow("Quantity", quantity, Icons.production_quantity_limits),
                    const Divider(),
                  ],
                );
              }).toList(),
            ),

            // Status Buttons
            if (status != "completed") ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Hold Button (Only if status is 'ongoing')
                  if (status == "ongoing")
                    ElevatedButton(
                      onPressed: isUpdating ? null : () => _showHoldReasonDialog(),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text("HOLD"),
                    ),

                  
                  // Complete Button (Only if status is 'ongoing')
                  if (status == "ongoing")
                    ElevatedButton(
                      onPressed: isUpdating
                          ? null
                          : () {
                              setState(() => isUpdating = true);
                              updateJobStatus("completed", message: '').then((_) {
                                setState(() => isUpdating = false);
                              });
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("COMPLETE"),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  String _formatEmployeeNames(dynamic employeeNames) {
    if (employeeNames == null || employeeNames.toString().trim().isEmpty) return "No employees assigned";
    if (employeeNames is List) return employeeNames.join(", ");
    return employeeNames.trim();
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return "N/A";
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(date));
    } catch (e) {
      return "Invalid date";
    }
  }

  Widget _buildDetailRow(String title, String value, IconData icon, {Color color = Colors.black}) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
      ],
    );
  }
}
