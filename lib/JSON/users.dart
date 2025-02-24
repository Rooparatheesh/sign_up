import 'dart:convert';

Users usersFromMap(String str) => Users.fromMap(json.decode(str));

String usersToMap(Users data) => json.encode(data.toMap());

class Users {
  final int? usrId;
  final String? fullName;
  final String? email;
  final String usrName;
  final String password;
  final DateTime? dob; // DOB field
  final String selfIntro; // Self-introduction field
  final String hobby; // Hobby field

  Users({
    this.usrId,
    this.fullName,
    this.email,
    required this.usrName,
    required this.password,
    this.dob, // DOB in constructor
    this.selfIntro = '', // Default empty string for selfIntro
    this.hobby = '', // Default empty string for hobby
  });

  factory Users.fromMap(Map<String, dynamic> json) => Users(
        usrId: json["usrId"],
        fullName: json["fullName"],
        email: json["email"],
        usrName: json["usrName"],
        password: json["usrPassword"],
        dob: json["dob"] != null ? DateTime.parse(json["dob"]) : null,
        selfIntro: json["selfIntro"] ?? '',
        hobby: json["hobby"] ?? '',
      );

  Map<String, dynamic> toMap() => {
        "usrId": usrId,
        "fullName": fullName,
        "email": email,
        "usrName": usrName,
        "usrPassword": password,
        "dob": dob?.toIso8601String(), // Convert DOB to string
        "selfIntro": selfIntro,
        "hobby": hobby,
      };

  // CopyWith method for creating a modified copy of the Users object
  Users copyWith({
    int? usrId,
    String? fullName,
    String? email,
    String? usrName,
    String? password,
    DateTime? dob,
    String? selfIntro,
    String? hobby,
  }) {
    return Users(
      usrId: usrId ?? this.usrId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      usrName: usrName ?? this.usrName,
      password: password ?? this.password,
      dob: dob ?? this.dob,
      selfIntro: selfIntro ?? this.selfIntro,
      hobby: hobby ?? this.hobby,
    );
  }
}
