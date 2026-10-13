/// Custom domain exceptions for TiggoMate.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() =>
      'AppException: $message ${code != null ? '($code)' : ''}';
}

class VehicleConnectionException extends AppException {
  const VehicleConnectionException(super.message, {super.code, super.details});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.details});
}

class AiServiceException extends AppException {
  const AiServiceException(super.message, {super.code, super.details});
}

class KnowledgeRetrievalException extends AppException {
  const KnowledgeRetrievalException(super.message, {super.code, super.details});
}
