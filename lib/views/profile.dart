import 'dart:io';
import 'package:flutter_awesome_alert_box/flutter_awesome_alert_box.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:sign_up/views/add_leave.dart';
import 'dart:convert';
import 'package:sign_up/views/login.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:sign_up/views/job_details.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';


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
  List<Map<String, dynamic>> jobList = []; // Initialize
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
     fetchAssignedJobs(); // Add this line
    fetchNotifications();
  }

void acceptJob(Map<String, dynamic> job, BuildContext context) async {
  try {
    final response = await http.post(
      Uri.parse('http://10.176.20.30:4000/update-task-status'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id": job["id"],
        "status": "ongoing",
        "employee_id": job["employee_id"],
        "assigned_by": job["assigned_by"],
      }),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData["success"] == true) {
      if (!context.mounted) return; // ✅ Prevent UI updates if context is unmounted

      setState(() {
        var jobIndex = assignedJobs.indexWhere((j) => j["id"] == job["id"]);
        if (jobIndex != -1) {
          assignedJobs[jobIndex]["status"] = responseData["status"]; // ✅ Update with real-time status
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(responseData["message"] ?? "Task Accepted Successfully!"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      throw Exception(responseData["message"] ?? "Failed to accept job");
    }
  } catch (error) {
    if (!context.mounted) return; // ✅ Avoid showing dialog if unmounted

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

    final url = "http://10.176.20.30:4000/api/employee/details/$empId";
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

  final url = "http://10.176.20.30:4000/api/notifications/$empId";
  debugPrint("🔍 Fetching notifications from: $url");

  try {
    final response = await http.get(Uri.parse(url));
    debugPrint("🔹 Response Status Code: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint("🔹 Response Data: $data");

      if (data is List) {
        // ✅ If API returns a list directly
        setState(() {
          notifications = List<Map<String, dynamic>>.from(data.map((n) => {
            "id": n["id"],  // ✅ Use "id" (not "notification_id")
            "message": n["message"] ?? "No Message",
            "is_read": n["is_read"] ?? false,
          }));
          notificationCount = notifications.where((n) => !n["is_read"]).length;
        });
      } else if (data is Map && data.containsKey("notifications")) {
        // ✅ If API returns { "notifications": [...] }
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

  final url = "http://10.176.20.30:4000/api/notifications/read/$empId";
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

  final url = "http://10.176.20.30:4000/api/assigned-jobs/$empId";
  debugPrint("🔍 Fetching jobs for Emp ID: $empId");

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["success"] && data["job"] != null) {
        setState(() {
          assignedJobs = List<Map<String, dynamic>>.from(data["job"]);
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

  const String baseUrl = "http://10.176.20.30:4000";

  // 🔹 Remove extra slashes
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
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(

      actions: [
        // Notification Button with Popup
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
  title: const Text("Notifications"),
  content: SizedBox(
    width: double.maxFinite,
    height: 300,
    child: notifications.isEmpty
        ? const Center(child: Text("No new notifications"))
        : ListView.builder(
            itemCount: notifications.length > 5 ? 5 : notifications.length,
            itemBuilder: (context, index) {
              final latestNotifications = notifications.reversed.toList(); // Get latest first
              final notification = latestNotifications[index];
              return ListTile(
                leading: Icon(
                  notification["is_read"]
                      ? Icons.notifications_none
                      : Icons.notifications,
                  color: notification["is_read"] ? Colors.grey : Colors.blue,
                ),
                title: Text(notification["message"]),
                trailing: notification["is_read"] == false
                    ? const Icon(Icons.circle, color: Colors.red, size: 12)
                    : null,
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
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text(
                    notificationCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),

        // User Profile Icon
        PopupMenuButton<int>(
          onSelected: (value) {
            if (value == 1) {
              logout();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<int>(
              value: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employeeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Emp ID: $employeeID", style: const TextStyle(color: Colors.grey)),
                  Text("Email: $email", style: const TextStyle(color: Colors.grey)),
                  Text("Designation: $designation", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const PopupMenuDivider(),
          ],
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.blueGrey,
              radius: 22,
              child: Text(
                employeeName.isNotEmpty ? employeeName[0].toUpperCase() : "?",
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    ),
   drawer: Drawer(
  child: Column(
    children: [
      UserAccountsDrawerHeader(
        accountName: Text(employeeName),
        accountEmail: Text(email),
        currentAccountPicture: CircleAvatar(
          backgroundColor: Colors.blueGrey,
          child: Text(
            employeeName.isNotEmpty ? employeeName[0].toUpperCase() : "?",
            style: const TextStyle(fontSize: 24, color: Colors.white),
          ),
        ),
      ),

      // Menu List
      Expanded(
        child: ListView.builder(
          itemCount: menus.length + 1, // +1 for Add Leave
          itemBuilder: (context, index) {
            if (index < menus.length) {
              return ListTile(
                leading: const Icon(Icons.menu),
                title: Text(menus[index]["menu_name"]),
                onTap: () {
                  // Add navigation logic for other menus here
                },
              );
            } else {
              // "Add Leave" Menu Item
              return ListTile(
                leading: const Icon(Icons.time_to_leave),
                title: const Text("Add Leave"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddLeaveScreen(employeeId: '', employeeName: '',)),
                  );
                },
              );
            }
          },
        ),
      ),

      const Divider(),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text("Sign Out"),
        onTap: logout,
      ),
    ],
  ),
),

  body: assignedJobs.isEmpty
    ? const Center(child: Text("Welcome to Ms Flow ", style: TextStyle(fontSize: 18)))
    : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: assignedJobs.length,
        itemBuilder: (context, index) {
          var job = assignedJobs[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text("Control No: ${job['control_number']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Parts: ${job['part_number'] ?? 'N/A'}"),
                  Text("Start Date: ${formatDate(job['start_date'])}"),
                  Text("End Date: ${formatDate(job['end_date'])}"),
                  const SizedBox(height: 8), // Space before buttons
                 Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      job["status"].toString().toUpperCase(), // ✅ Display dynamic status
      style: TextStyle(
        color: job["status"] == "ongoing" ? Colors.green : Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
    if (job["status"] != "ongoing" && job["status"] != "completed"&& job["status"] != "on hold"&& job["status"] != "pending") 
  ElevatedButton(
    onPressed: () => acceptJob(job, context),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    ),
    child: const Text("ACCEPT"),
  ),
    
   ElevatedButton(
  onPressed: () {
  debugPrint("🆔 Navigating to job details: ${job['control_number']}");
if (assignedJobs.isNotEmpty && index >= 0 && index < assignedJobs.length) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => JobDetailsScreen(
        controlNumber: assignedJobs[index]["control_number"],
        jobId: assignedJobs[index]["id"],
      ),
    ),
  );
} else {
  debugPrint("Error: assignedJobs is empty or index is out of range.");
}



  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue, // Button color
    foregroundColor: Colors.white,
  ),
  child: const Text("DETAILS"),
),

                    ],
                  ),
                ],
              ),
              trailing: job['doc_upload_path'] != null && job['doc_upload_path'].isNotEmpty
    ? IconButton(
        icon: const Icon(Icons.file_present, color: Colors.blue),
        onPressed: () {
          openDocument(job['doc_upload_path']);
        },
      )
    : null,

            ),
          );
        },
      ),


  );
}
}