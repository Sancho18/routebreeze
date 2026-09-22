/// Outcome of a device authentication attempt (LOCK-01..06).
enum AuthResult {
  success,
  canceled,
  lockedOut,
  noCredentials,
  unavailable,
  error,
}
