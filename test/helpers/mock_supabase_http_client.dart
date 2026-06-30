import 'dart:convert';
import 'package:http/http.dart' as http;

class MockSupabaseHttpClient extends http.BaseClient {
  http.Response Function(http.BaseRequest request)? handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = handler != null 
        ? handler!(request) 
        : http.Response('[]', 200);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
