import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sign_up/views/login.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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
     fetchAssignedJobs(); // Add this line
    fetchNotifications();
  }
void acceptJob(Map<String, dynamic> job) {
  // Implement logic for accepting a job
  print("Accepted job: ${job['control_number']}");
  // You can send API request or update local state
}

void showJobDetails(Map<String, dynamic> job) {
  // Implement logic for showing job details
  print("Showing details for job: ${job['control_number']}");
  // You can navigate to another screen with job details
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
    const url = "http://10.176.21.109:4000/api/notifications";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          notifications = List<Map<String, dynamic>>.from(data["notifications"]);
          notificationCount = notifications.where((n) => n["unread"]).length;
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching notifications: $e");
    }
  }

  Future<void> markAllAsRead() async {
    const url = "http://10.176.21.109:4000/api/notifications/read";
    try {
      await http.post(Uri.parse(url));
      setState(() {
        for (var n in notifications) {
          n["unread"] = false;
        }
        notificationCount = 0;
      });
    } catch (e) {
      debugPrint("⚠️ Error marking notifications as read: $e");
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
          assignedJobs = List<Map<String, dynamic>>.from(data["job"]); // ✅ Fix here
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



  void openDocument(String docPath) async {
    final url = "http://10.176.21.109:4000$docPath";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      debugPrint("❌ Could not open document.");
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
      title: const Text("Dashboard"),
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
                                itemCount: notifications.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    leading: Icon(
                                      notifications[index]["type"] == "message"
                                          ? Icons.message
                                          : Icons.notifications,
                                      color: Colors.blue,
                                    ),
                                    title: Text(notifications[index]["title"]),
                                    subtitle: Text(notifications[index]["body"]),
                                    trailing: notifications[index]["unread"]
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
          Expanded(
            child: ListView.builder(
              itemCount: menus.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.menu),
                  title: Text(menus[index]["menu_name"]),
                  onTap: () {},
                );
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
    ? const Center(child: Text("No Assigned Jobs", style: TextStyle(fontSize: 18)))
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
                      ElevatedButton(
                        onPressed: () => acceptJob(job),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, // Accept button color
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("ACCEPT"),
                      ),
                      ElevatedButton(
                        onPressed: () => showJobDetails(job),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Details button color
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("DETAILS"),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: job['doc_upload_path'] != null
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