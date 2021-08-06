class LoginResponseModel {
  final String token;
  final String serial;
  final String error;

  LoginResponseModel({this.token,this.serial,this.error});

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      token: json["Role"] != null ? json["Role"] : "",
      serial: json["Card_Serial"] != null ? json["Card_Serial"] : "",
      error: json["Error"] != null ? json["Error"] : "",
    );
  }
}

class LoginRequestModel {
  String email;
  String password;

  LoginRequestModel({
    this.email,
    this.password,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = {
      'email': email.trim(),
      'password': password.trim(),
    };

    return map;
  }
}
