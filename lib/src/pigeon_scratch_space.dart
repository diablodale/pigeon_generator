import 'dart:io';

import 'package:build/build.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pigeon/pigeon.dart';
import 'package:scratch_space/scratch_space.dart';

final _scratchSpace = PigeonScratchSpace();

/// A resource that manages a scratch space for Pigeon code generation. This
/// ensures that the scratch space is created before use and cleaned up after
/// the build process is complete.
final scratchSpaceResource = Resource<PigeonScratchSpace>(
  () {
    if (!_scratchSpace.exists) {
      _scratchSpace.tempDir.createSync(recursive: true);
      _scratchSpace.exists = true;
    }

    return _scratchSpace;
  },
  beforeExit: () async {
    try {
      if (_scratchSpace.exists) {
        await _scratchSpace.delete();
      } else {
        await _scratchSpace.tempDir.delete(recursive: true);
      }
    } on FileSystemException {
      log.warning('Failed to delete temp dir: ${_scratchSpace.tempDir.path}.');
    }
  },
);

/// A specialized [ScratchSpace] for handling Pigeon generated files.
@visibleForTesting
class PigeonScratchSpace extends ScratchSpace {
  @override
  File fileFor(AssetId id) {
    final packagePath = p.url.join('package', id.package, id.path);

    return File(p.join(tempDir.path, p.normalize(packagePath)));
  }

  /// Creates a new [PigeonOptions] object with the output paths updated to use
  /// scratch space locations.
  ///
  /// Parameters:
  /// - [pigeonOptions]: The original [PigeonOptions] configuration object
  ///   containing the desired output settings
  /// - [allowedOutputs]: An iterable of [AssetId] objects representing the
  ///   files that are permitted to be generated. Only paths matching these
  ///   assets will be updated to use scratch space locations
  ///
  /// Returns:
  /// - [PigeonOptions] object with output paths remapped to scratch space
  /// locations, merged with the original options to preserve other settings
  ///
  /// Example:
  /// ```dart
  /// final originalOptions = PigeonOptions(
  ///   dartOut: 'lib/generated/api.dart',
  ///   javaOut: 'android/src/main/java/Api.java',
  /// );
  ///
  /// final allowedOutputs = [
  ///   AssetId('my_package', 'lib/generated/api.dart'),
  ///   AssetId('my_package', 'android/src/main/java/Api.java'),
  /// ];
  ///
  /// final scratchOptions = scratchSpace.getPigeonOptions(
  ///   originalOptions,
  ///   allowedOutputs,
  /// );
  /// ```
  PigeonOptions getPigeonOptions(
    PigeonOptions pigeonOptions,
    Iterable<AssetId> allowedOutputs,
  ) {
    final oldPigeonOptions = pigeonOptions;

    String? getPath(String? output) {
      if (output == null) return null;

      // Some inputs (e.g. schema copies surfaced through symlinks) are not
      // owned by this build step; their outputs won't be in allowedOutputs.
      // Skip rather than throw.
      AssetId? assetId;
      for (final allowedOutput in allowedOutputs) {
        if (allowedOutput.path == output) {
          assetId = allowedOutput;
          break;
        }
      }
      if (assetId == null) return null;

      // Pigeon derives identifiers and #includes from these output paths using
      // a posix path context in several generators (Kotlin, Java, ObjC, Swift,
      // GObject). Hand them forward-slash paths even on Windows so the basename
      // is parsed correctly. dart:io still writes to this path, and copy-back
      // via fileFor() resolves to the same file.
      final nativePath = fileFor(assetId).path;

      // On Windows, '\' is the OS path separator and is prohibited in file and
      // directory names by the Win32 API, so every '\' in nativePath is a
      // separator — replacing them all with '/' is lossless and gives a path
      // dart:io can still write to (it accepts '/' on Windows).
      if (Platform.isWindows) {
        return nativePath.replaceAll('\\', '/');
      } else {
        return nativePath;
      }
    }

    final newPigeonOptions = PigeonOptions(
      dartOut: getPath(pigeonOptions.dartOut),
      cppHeaderOut: getPath(pigeonOptions.cppHeaderOut),
      cppSourceOut: getPath(pigeonOptions.cppSourceOut),
      gobjectHeaderOut: getPath(pigeonOptions.gobjectHeaderOut),
      gobjectSourceOut: getPath(pigeonOptions.gobjectSourceOut),
      kotlinOut: getPath(pigeonOptions.kotlinOut),
      javaOut: getPath(pigeonOptions.javaOut),
      swiftOut: getPath(pigeonOptions.swiftOut),
      objcHeaderOut: getPath(pigeonOptions.objcHeaderOut),
      objcSourceOut: getPath(pigeonOptions.objcSourceOut),
      astOut: getPath(pigeonOptions.astOut),
    );

    return oldPigeonOptions.merge(newPigeonOptions);
  }
}
