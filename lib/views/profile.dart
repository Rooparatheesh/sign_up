import 'dart:io';
import 'package:flutter_awesome_alert_box/flutter_awesome_alert_box.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:sign_up/components/color.dart';
import 'package:sign_up/main.dart';
import 'package:sign_up/views/CompletedTasksScreen.dart';
import 'package:sign_up/views/add_leave.dart';
import 'package:sign_up/views/job_details.dart';
import 'dart:convert';
import 'package:sign_up/views/login.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'job_details_screen.dart';
import 'completed_tasks_screen.dart';
import 'notes_screen.dart';


class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String employeeName = "Loading...";
  String employeeID = "Loading...";
  String email = "Loading...";
  String designation = "Loading...";
  List<Map<String, dynamic>> menus = [];
  List<Map<String, dynamic>> notifications = [];
  int notificationCount = 0;
  List<Map<String, dynamic>> assignedJobs = [];

  String formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  void initState() {
    super.initState();
    fetchEmployeeData();
    loadMenus();
    fetchAssignedJobs();
    fetchNotifications();
  }

  void acceptJob(Map<String, dynamic> job, BuildContext context) async {
    // Prevent accepting if status is already ongoing or completed
    if (job["status"]?.toLowerCase() == "ongoing" || job["status"]?.toLowerCase() == "completed") {
      debugPrint("⚠️ Job ${job['id']} is already ${job['status']}, cannot accept again.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Job is already ${job['status']}"),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.176.21.109:4000/update-job-status'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "id": job["id"],
          "status": "ongoing",
        }),
      );

      if (!response.headers['content-type']!.contains('application/json')) {
        debugPrint("Non-JSON response: ${response.body.substring(0, response.body.length.clamp(0, 100))}");
        throw Exception("Server returned non-JSON response: ${response.statusCode} ${response.reasonPhrase}");
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData["success"] == true) {
        if (!context.mounted) return;

        setState(() {
          var jobIndex = assignedJobs.indexWhere((j) => j["id"] == job["id"]);
          if (jobIndex != -1) {
            assignedJobs[jobIndex]["status"] = "ongoing";
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData["message"] ?? "Task Accepted Successfully!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh jobs to ensure consistency
        await fetchAssignedJobs();
      } else {
        throw Exception(responseData["message"] ?? "Failed to accept job: HTTP ${response.statusCode}");
      }
    } catch (error) {
      debugPrint("Error accepting job: $error");
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("❌ Error"),
            content: Text("Error accepting job: $error"),
            actions: [
              TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> fetchEmployeeData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? empId = prefs.getString("employeeID");

    if (empId == null || empId.isEmpty) {
      debugPrint("⚠️ Employee ID is missing in SharedPreferences");
      return;
    }

    final url = "http://10.176.21.109:4000/api/employee/details/$empId";
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          employeeName = data["employee_name"] ?? "N/A";
          employeeID = data["employee_id"]?.toString() ?? "N/A";
          email = data["email_id"] ?? "N/A";
          designation = data["designation"] ?? "N/A";
        });

        prefs.setString("employeeName", employeeName);
        prefs.setString("employeeID", employeeID);
        prefs.setString("email", email);
        prefs.setString("designation", designation);
      }
    } catch (e) {
      debugPrint("⚠️ Exception while fetching data: $e");
    }
  }

  Future<void> loadMenus() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      menus = (prefs.getStringList("menus") ?? [])
          .map((menu) => jsonDecode(menu) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> fetchNotifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? empId = prefs.getString("employeeID");

    if (empId == null || empId.isEmpty) {
      debugPrint("⚠ Employee ID missing in SharedPreferences");
      return;
    }

    final url = "http://10.176.21.109:4000/api/notifications/$empId";
    debugPrint("🔍 Fetching notifications from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint("🔹 Response Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("🔹 Response Data: $data");

        if (data is List) {
          setState(() {
            notifications = List<Map<String, dynamic>>.from(data.map((n) => {
                  "id": n["id"],
                  "message": n["message"] ?? "No Message",
                  "is_read": n["is_read"] ?? false,
                }));
            notificationCount = notifications.where((n) => !n["is_read"]).length;
          });
        } else if (data is Map && data.containsKey("notifications")) {
          setState(() {
            notifications = List<Map<String, dynamic>>.from(data["notifications"].map((n) => {
                  "id": n["id"],
                  "message": n["message"] ?? "No Message",
                  "is_read": n["is_read"] ?? false,
                }));
            notificationCount = notifications.where((n) => !n["is_read"]).length;
          });
        } else {
          debugPrint("⚠ Unexpected API response format.");
        }
      } else {
        debugPrint("❌ Server Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching notifications: $e");
    }
  }

  Future<void> markAllAsRead() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? empId = prefs.getString("employeeID");

    if (empId == null || empId.isEmpty) {
      debugPrint("⚠ Employee ID missing in SharedPreferences");
      return;
    }

    final url = "http://10.176.21.109:4000/api/notifications/read/$empId";
    try {
      await http.post(Uri.parse(url));
      setState(() {
        for (var n in notifications) {
          n["is_read"] = true;
        }
        notificationCount = 0;
      });
    } catch (e) {
      debugPrint("❌ Error marking notifications as read: $e");
    }
  }

  Future<void> fetchAssignedJobs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? empId = prefs.getString("employeeID");

    if (empId == null || empId.isEmpty) {
      debugPrint("⚠ Employee ID is missing in SharedPreferences");
      return;
    }

    final url = "http://10.176.21.109:4000/api/assigned-jobs/$empId";
    debugPrint("🔍 Fetching jobs for Emp ID: $empId");

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] && data["job"] != null) {
          setState(() {
            assignedJobs = List<Map<String, dynamic>>.from(data["job"])
                .where((job) => job["status"]?.toLowerCase() != "completed")
                .toList();
          });
          debugPrint("✅ Assigned jobs: ${assignedJobs.length}");
        } else {
          setState(() {
            assignedJobs = [];
          });
          debugPrint("🚫 No assigned jobs.");
        }
      } else {
        debugPrint("❌ API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching assigned jobs: $e");
    }
  }

  void openDocument(String? docPath) async {
    if (docPath == null || docPath.isEmpty) {
      debugPrint("❌ Document path is empty.");
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
        }
      } else {
        debugPrint("❌ Failed to download document: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error opening document: $e");
    }
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "ongoing":
        return Colors.green;
      case "on hold":
        return Colors.orange;
      case "pending":
        return Colors.grey;
      case "completed":
        return Colors.blue;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
   backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text("Ms Flow", style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          // Notification Icon
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: const Text("Notifications"),
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 300,
                          child: notifications.isEmpty
                              ? const Center(child: Text("No notifications"))
                              : ListView.builder(
                                  itemCount: notifications.length > 5 ? 5 : notifications.length,
                                  itemBuilder: (context, index) {
                                    final latestNotifications = notifications.reversed.toList();
                                    final notification = latestNotifications[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: notification["is_read"] ? Colors.grey[100] : Colors.blue[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(notification["message"]),
                                    );
                                  },
                                ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              markAllAsRead();
                              Navigator.pop(context);
                            },
                            child: const Text("Mark All Read"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Close"),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        notificationCount > 9 ? '9+' : notificationCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          // Profile Menu
          PopupMenuButton<int>(
            onSelected: (value) {
              if (value == 1) logout();
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem<int>(
                value: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employeeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text("ID: $employeeID", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    Text(designation, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue[100],
                child: Text(
                  employeeName.isNotEmpty ? employeeName[0].toUpperCase() : "?",
                  style: const TextStyle(fontSize: 16, color: primaryColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              height: 160,
              width: double.infinity,
              color:  primaryColor,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Text(
                          employeeName.isNotEmpty ? employeeName[0].toUpperCase() : "?",
                          style: TextStyle(fontSize: 18, color: Colors.blue[800], fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              employeeName, 
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              email, 
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
Expanded(
  child: ListView(
    padding: EdgeInsets.zero,
    children: [
      // ...menus.map((menu) => ListTile(
      //   leading: const Icon(Icons.folder_outlined),
      //   title: Text(menu["menu_name"]),
      //   onTap: () {},
      // )),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.event_available_outlined),
        title: const Text("Add Leave"),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddLeaveScreen(
                employeeId: employeeID,
                employeeName: employeeName,
              ),
            ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: const Text("Completed Tasks"),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CompletedTasksScreen(),
            ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.note_outlined),
        title: const Text("Keep Notes"),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotesScreen(),
            ),
          );
        },
      ),
      const Divider(height: 1),

      // /// 🔁 This one will now work correctly
      // ValueListenableBuilder<ThemeMode>(
      //   valueListenable: themeNotifier,
      //   builder: (context, mode, _) {
      //     return SwitchListTile(
      //       secondary: Icon(
      //         mode == ThemeMode.dark
      //             ? Icons.light_mode_outlined
      //             : Icons.dark_mode_outlined,
      //       ),
      //       title: Text(
      //         mode == ThemeMode.dark ? "Switch to Light Mode" : "Switch to Dark Mode",
      //       ),
      //       value: mode == ThemeMode.dark,
      //       onChanged: (value) async {
      //         final prefs = await SharedPreferences.getInstance();
      //         if (value) {
      //           themeNotifier.value = ThemeMode.dark;
      //           await prefs.setString('themeMode', 'dark');
      //         } else {
      //           themeNotifier.value = ThemeMode.light;
      //           await prefs.setString('themeMode', 'light');
      //         }
      //       },
      //     );
      //   },
      // ),
    ],
  ),
),

const Divider(height: 1),
ListTile(
  leading: const Icon(Icons.logout, color: Colors.red),
  title: const Text("Sign Out", style: TextStyle(color: Colors.red)),
  onTap: logout,
),


          ],
        ),
      ),
      body: assignedJobs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "Welcome to Ms Flow",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "No tasks assigned yet",
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: assignedJobs.length,
              itemBuilder: (context, index) {
                var job = assignedJobs[index];
                final status = job["status"]?.toString().toLowerCase() ?? "";
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
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
                                "Control No: ${job['control_number']}",
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
                            if (job['doc_upload_path'] != null && job['doc_upload_path'].isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.description_outlined, color: Colors.blue),
                                onPressed: () => openDocument(job['doc_upload_path']),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Parts: ${job['part_number'] ?? 'N/A'}", style: TextStyle(color: Colors.grey[600])),
                                  const SizedBox(height: 4),
                                  Text("${formatDate(job['start_date'])} - ${formatDate(job['end_date'])}", style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (status != "ongoing" && status != "completed" && status != "on hold" && status != "pending")
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => acceptJob(job, context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text("ACCEPT"),
                                ),
                              ),
                            if (status != "ongoing" && status != "completed" && status != "on hold" && status != "pending")
                              const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => JobDetailsScreen(
                                        controlNumber: job["control_number"],
                                        jobId: job["id"],
                                        onJobCompleted: fetchAssignedJobs,
                                      ),
                                    ),
                                  ).then((result) {
                                    if (result == true) {
                                      fetchAssignedJobs();
                                    }
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text("DETAILS"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}