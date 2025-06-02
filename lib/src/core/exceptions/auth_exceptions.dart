class AuthenticationException implements Exception {
  final String message;
  final String code;

  const AuthenticationException({
    required this.message,
    required this.code,
  });
}