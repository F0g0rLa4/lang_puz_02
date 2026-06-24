import 'dart:io';

/// Returns the current Operating System as a capitalized string.
String getOperatingSystem() {
  if (Platform.isWindows) return 'Windows';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isFuchsia) return 'Fuchsia';
  return 'Unknown OS';
}

/// Returns a detailed OS string including the version if available.
String getDetailedOS() {
  return '${getOperatingSystem()} (${Platform.operatingSystemVersion})';
}