import 'package:package_info_plus/package_info_plus.dart';

/// Fetches the application name natively from the OS.
Future<String> getAppName() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.appName;
}

/// Fetches the semantic version baked into the app during compilation.
Future<String> getAppSemanticVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  // Returns format like "1.0.4+2"
  return '${packageInfo.version}+${packageInfo.buildNumber}'; 
}