import 'dart:io';

/// Extracts the semantic version from the latest Git commit/tag.
/// ONLY works on desktop/CLI environments with Git installed.
Future<String> getGitSemanticVersion() async {
  try {
    ProcessResult result = await Process.run('git', ['describe', '--tags', '--always']);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    } else {
      return 'git-error-${result.exitCode}';
    }
  } catch (e) {
    return 'unknown-version';
  }
}