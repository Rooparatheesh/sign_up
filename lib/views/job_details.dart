import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class JobDetailsScreen extends StatefulWidget {
  final int controlNumber;
  final int jobId;
  final VoidCallback? onJobCompleted;

  const JobDetailsScreen({
    super.key,
    required this.controlNumber,
    required this.jobId,
    this.onJobCompleted,
  });

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
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
    final url = "http://10.176.21.109:4000/api/job-details/${widget.controlNumber}/${widget.jobId}";
    
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
        if (data["success"] == true && data["job_details"] != null) {
          setState(() {
            jobDetails = data["job_details"];
            isLoading = false;
          });
        } else {
          throw Exception(data["message"] ?? "No job details found");
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> updateJobStatus(String status, {String? reason}) async {
    if (jobDetails == null || jobDetails?["status"] == status) return;

    setState(() => isUpdating = true);

    try {
      final response = await http.post(
        Uri.parse("http://10.176.21.109:4000/update-job-status"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": widget.jobId,
          "status": status,
          "reason": reason,
        }),
      ).timeout(const Duration(seconds: 10));

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData["success"] == true) {
        if (status == "completed") {
          // Show success message
          _showSuccessSnackbar(responseData["message"] ?? "Job completed successfully!");
          // Call the onJobCompleted callback to notify the Profile screen
          widget.onJobCompleted?.call();
          // Navigate back with a result indicating completion
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            jobDetails?["status"] = status;
            if (status == "on hold") {
              jobDetails?["on_hold_date"] = responseData["on_hold_date"];
              jobDetails?["hold_reason"] = responseData["hold_reason"];
            } else {
              jobDetails?["on_hold_date"] = null;
              jobDetails?["hold_reason"] = null;
            }
          });
          _showSuccessSnackbar(responseData["message"] ?? "Job status updated!");
        }
      } else {
        throw Exception(responseData["message"] ?? "Update failed");
      }
    } catch (e) {
      _showErrorSnackbar(e.toString());
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Job Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchJobDetails,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) return _buildLoadingView();
    if (errorMessage != null) return _buildErrorView();
    if (jobDetails == null) return _buildNoDataView();
    return _buildJobDetailsView();
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: fetchJobDetails,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataView() {
    return const Center(child: Text("No job data available"));
  }

  Widget _buildJobDetailsView() {
    final status = jobDetails!["status"]?.toString().toLowerCase() ?? "unknown";
    final isCompleted = status == "completed";
    final isOnHold = status == "on hold";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildJobInfoCard(),
          const SizedBox(height: 16),
          _buildPartsCard(),
          if (!isCompleted) _buildActionButtons(status, isOnHold),
        ],
      ),
    );
  }

  Widget _buildJobInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusIndicator(),
            const SizedBox(height: 16),
            _buildDetailRow("Control Number", jobDetails!['control_number']?.toString(), Icons.numbers),
            _buildDetailRow("Assigned Employees", _formatNames(jobDetails?['employee_names']), Icons.people),
            _buildDetailRow("Start Date", _formatDateTime(jobDetails?['start_date']), Icons.calendar_today),
            _buildDetailRow("End Date", _formatDateTime(jobDetails?['end_date']), Icons.calendar_today),
            _buildDetailRow("Group", jobDetails?['group_section'], Icons.group),
            _buildDetailRow("Priority", jobDetails?['priority'], Icons.priority_high),
            if (jobDetails?['on_hold_date'] != null)
              _buildDetailRow("On Hold Since", _formatDateTime(jobDetails?['on_hold_date']), Icons.pause_circle_outline),
            if (jobDetails?['actual_end_date'] != null)
              _buildDetailRow("Completed On", _formatDateTime(jobDetails?['actual_end_date']), Icons.check_circle_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final status = jobDetails!["status"]?.toString().toLowerCase() ?? "unknown";
    final color = {
      "completed": Colors.green,
      "on hold": Colors.orange,
      "ongoing": Colors.blue,
    }[status] ?? Colors.grey;

    return Row(
      children: [
        Icon(_getStatusIcon(status), color: color),
        const SizedBox(width: 8),
        Text(
          status.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    return {
      "completed": Icons.check_circle,
      "on hold": Icons.pause_circle,
      "ongoing": Icons.autorenew,
    }[status] ?? Icons.help_outline;
  }

  Widget _buildPartsCard() {
    final parts = jobDetails?['part_details'] ?? [];
    if (parts.isEmpty) return const SizedBox();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Part Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...parts.map((part) => Column(
              children: [
                _buildDetailRow("Part Number", part['part_number'], Icons.confirmation_number),
                _buildDetailRow("Description", part['description'], Icons.description),
                _buildDetailRow("Quantity", part['quantity']?.toString(), Icons.format_list_numbered),
                const Divider(),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Text(value ?? "N/A", style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status, bool isOnHold) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (status == "ongoing")
            _buildActionButton(
              "Hold", 
              Icons.pause, 
              Colors.orange, 
              _showHoldDialog,
            ),
          if (status == "ongoing")
            _buildActionButton(
              "Complete", 
              Icons.check, 
              Colors.green, 
              () => updateJobStatus("completed"),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: isUpdating ? null : onPressed,
      icon: Icon(icon, size: 20),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showHoldDialog() {
    String? selectedReason;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Put Job On Hold"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select reason:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...["Incomplete", "Unavailable", "Waiting for Parts", "Quality Issue", "Other"]
                    .map((reason) => RadioListTile<String>(
                      title: Text(reason),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (value) => setState(() => selectedReason = value),
                    )),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: "Additional comments",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: selectedReason == null ? null : () {
                  final reason = controller.text.isEmpty
                    ? selectedReason!
                    : "${selectedReason!}: ${controller.text}";
                  Navigator.pop(context);
                  updateJobStatus("on hold", reason: reason);
                },
                child: const Text("Confirm"),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatNames(dynamic names) {
    if (names == null) return "N/A";
    if (names is List) return names.join(", ");
    return names.toString();
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return "N/A";
    try {
      return DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.parse(dateTime));
    } catch (e) {
      return "Invalid date";
    }
  }
}