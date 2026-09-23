/// Outcome of a device authentication attempt.
enum AuthResult {
  success,
  canceled,
  lockedOut,
  noCredentials,
  unavailable,
  error,
}
