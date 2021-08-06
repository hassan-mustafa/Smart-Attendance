import 'package:http/http.dart' as http;
import 'dart:convert';
import '../model/login_model.dart';

class APIService {
  Future<LoginResponseModel> login(LoginRequestModel requestModel) async {
    String url = "https://attendance.fekracomputers.net/api/authenticate";
    final response = await http.post(url, body: requestModel.toJson());
    print(json.decode(response.body));
    if (response.statusCode == 200 || response.statusCode == 400) {
      return LoginResponseModel.fromJson(
        json.decode(response.body),
      );}
      else {
      throw Exception('Failed to load data!');
    }
  }
}
