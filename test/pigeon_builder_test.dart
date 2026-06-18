import 'dart:io';

import 'package:build/build.dart';
import 'package:pigeon_generator/src/pigeon_builder.dart';
import 'package:pigeon_generator/src/pigeon_config.dart';
import 'package:test/test.dart';

/// Minimal [BuildStep] stub that only provides [inputId].
/// All other members throw [UnimplementedError] — they must not be reached
/// when the builder's inputs-folder guard fires and returns early.
class _StubBuildStep implements BuildStep {
  _StubBuildStep(this.inputId);

  @override
  final AssetId inputId;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('PigeonBuilder', () {
    late Directory tempDir;
    late String originalDir;

    setUp(() async {
      originalDir = Directory.current.path;
      tempDir = await Directory.systemTemp.createTemp('pigeon_builder_test_');
      Directory.current = tempDir;
    });

    tearDown(() async {
      Directory.current = originalDir;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('buildExtensions', () {
      test('keys use posix separators regardless of OS', () async {
        await Directory('pigeons').create();
        await File('pigeons/img_api.dart').writeAsString('''
          import 'package:pigeon/pigeon.dart';

          @HostApi()
          abstract class ImgApi {
            void send();
          }
        ''');

        final config = PigeonConfig.fromMap({});
        final builder = PigeonBuilder(config);

        expect(
          builder.buildExtensions.keys,
          everyElement(isNot(contains('\\'))),
        );
      });

      test('keys start with the inputs folder', () async {
        await Directory('pigeons').create();
        await File('pigeons/img_api.dart').writeAsString('''
          import 'package:pigeon/pigeon.dart';

          @HostApi()
          abstract class ImgApi {
            void send();
          }
        ''');

        final config = PigeonConfig.fromMap({});
        final builder = PigeonBuilder(config);

        expect(
          builder.buildExtensions.keys,
          everyElement(startsWith('pigeons/')),
        );
      });

      test('returns empty map when inputs directory does not exist', () {
        final config = PigeonConfig.fromMap({'inputs': 'nonexistent'});
        final builder = PigeonBuilder(config);

        expect(builder.buildExtensions, isEmpty);
      });
    });

    group('build', () {
      test(
        'skips inputs outside the configured inputs folder without crashing',
        () async {
          final config = PigeonConfig.fromMap({});
          final builder = PigeonBuilder(config);

          // Simulates the symlinked-schema path that triggered the crash:
          // example/.plugin_symlinks/<plugin>/pigeons/img_api.dart
          final foreignInput = AssetId(
            'my_pkg',
            'example/.plugin_symlinks/pkg/pigeons/img_api.dart',
          );

          // The guard must return before touching any other BuildStep member.
          // _StubBuildStep will throw UnimplementedError if anything beyond
          // inputId is accessed, so a clean completion proves the guard fired.
          await expectLater(
            builder.build(_StubBuildStep(foreignInput)),
            completes,
          );
        },
      );
    });
  });
}
