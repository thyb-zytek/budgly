/// Firebase provider id reported for Google Sign-In credentials.
const String googleProviderId = 'google.com';

/// RL-01 §1.1 — whether an authenticated account counts as verified.
///
/// * Google Sign-In: verified automatically once OAuth succeeded, whatever
///   the `emailVerified` flag says.
/// * Email & password: verified only once the user confirmed the validation
///   email (`emailVerified == true`).
bool isAccountVerified({
  required bool emailVerified,
  required Iterable<String> providerIds,
}) => emailVerified || providerIds.contains(googleProviderId);
