class HttpException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic response;

  HttpException(this.message, {this.statusCode, this.response});

  @override
  String toString() => 'HttpException: $message${statusCode != null ? ' ($statusCode)' : ''}';
}

class NetworkException extends HttpException {
  NetworkException(String message) : super(message);
}

class TimeoutException extends HttpException {
  TimeoutException(String message) : super(message);
}

class ClientException extends HttpException {
  ClientException(String message) : super(message);
}

class ServerException extends HttpException {
  ServerException(String message, int statusCode) : super(message, statusCode: statusCode);
}