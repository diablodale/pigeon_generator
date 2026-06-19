import 'dart:io';

import 'package:pigeon_generator/src/pigeon_config.dart';
import 'package:test/test.dart';

void main() {
  group('PigeonConfig', () {
    late Directory tempDir;
    late String originalDir;

    setUpAll(() async {
      originalDir = Directory.current.path;
      tempDir = await Directory.systemTemp.createTemp('pigeon_config_test_');
      Directory.current = tempDir;
    });

    tearDownAll(() async {
      Directory.current = originalDir;

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('fromMap', () {
      test('should create config with minimal map using defaults', () async {
        await Directory('pigeons').create();
        await File('pigeons/copyright.txt').writeAsString('Copyright © 2024');

        final config = PigeonConfig.fromMap({});

        expect(config.inputs, equals('pigeons'));
        expect(config.outTemplate, equals('name.g.extension'));
        expect(config.copyrightHeader, equals('pigeons/copyright.txt'));
        expect(config.debugGenerators, isNull);
        expect(config.basePath, isNull);
        expect(config.skipOutputs, isNull);
        expect(config.outFolder, isNull);
        expect(config.outTemplate, equals('name.g.extension'));
      });

      test('should create config from map configuration', () {
        final map = {
          'inputs': 'files',
          'copyright_header': 'files/copyright.txt',
          'debug_generators': true,
          'base_path': '/base',
          'out_folder': 'generated',
          'out_template': 'name.generated.extension',
        };

        final config = PigeonConfig.fromMap(map);

        expect(config.inputs, equals('files'));
        expect(config.copyrightHeader, equals('files/copyright.txt'));
        expect(config.debugGenerators, isTrue);
        expect(config.basePath, equals('/base'));
        expect(config.outFolder, equals('generated'));
        expect(config.outTemplate, equals('name.generated.extension'));
      });
    });

    group('getPigeonOptions', () {
      test('should return proper output paths', () async {
        final content = '''
          import 'package:pigeon/pigeon.dart';

          @HostApi()
          abstract class ApiFile {
            @async
            void sendMessage(String message);
          }
        ''';

        await Directory('pigeons').create();
        await File('pigeons/api_file.dart').writeAsString(content);

        final config = PigeonConfig.fromMap({'swift': true});
        final options = config.getPigeonOptions('pigeons/api_file.dart');

        expect(options.dartOut, equals('lib/api_file.g.dart'));
        expect(options.swiftOut, equals('ios/Runner/ApiFile.g.swift'));
      });

      test('should forward explicit copyright_header to PigeonOptions',
          () async {
        const pigeonInput = '''
          import 'package:pigeon/pigeon.dart';
          @HostApi()
          abstract class Api {
            void ping();
          }
        ''';
        await Directory('pigeons').create(recursive: true);
        await File('pigeons/api.dart').writeAsString(pigeonInput);
        await File('pigeons/copyright.txt')
            .writeAsString('Copyright 2024 Example Corp');

        final config = PigeonConfig.fromMap({
          'copyright_header': 'pigeons/copyright.txt',
        });
        final options = config.getPigeonOptions('pigeons/api.dart');

        expect(options.copyrightHeader, equals('pigeons/copyright.txt'));
      });

      test('should forward auto-discovered copyright.txt to PigeonOptions',
          () async {
        const pigeonInput = '''
          import 'package:pigeon/pigeon.dart';
          @HostApi()
          abstract class Api {
            void ping();
          }
        ''';
        await Directory('pigeons').create(recursive: true);
        await File('pigeons/api.dart').writeAsString(pigeonInput);
        await File('pigeons/copyright.txt')
            .writeAsString('Copyright 2024 Example Corp');

        final config = PigeonConfig.fromMap({});
        expect(config.copyrightHeader, equals('pigeons/copyright.txt'));

        final options = config.getPigeonOptions('pigeons/api.dart');
        expect(options.copyrightHeader, equals('pigeons/copyright.txt'));
      });

      test('should forward ignore_lints false to PigeonOptions', () async {
        const pigeonInput = '''
          import 'package:pigeon/pigeon.dart';
          @HostApi()
          abstract class Api {
            void ping();
          }
        ''';
        await Directory('pigeons').create(recursive: true);
        await File('pigeons/api.dart').writeAsString(pigeonInput);

        final config = PigeonConfig.fromMap({'ignore_lints': false});
        expect(config.ignoreLints, isFalse);

        final options = config.getPigeonOptions('pigeons/api.dart');
        expect(options.ignoreLints, isFalse);
      });

      test('should default ignoreLints to true when not configured', () async {
        const pigeonInput = '''
          import 'package:pigeon/pigeon.dart';
          @HostApi()
          abstract class Api {
            void ping();
          }
        ''';
        await Directory('pigeons').create(recursive: true);
        await File('pigeons/api.dart').writeAsString(pigeonInput);

        final config = PigeonConfig.fromMap({});
        expect(config.ignoreLints, isTrue);

        final options = config.getPigeonOptions('pigeons/api.dart');
        expect(options.ignoreLints, isTrue);
      });

      test('should leave copyrightHeader null when not configured', () async {
        const pigeonInput = '''
          import 'package:pigeon/pigeon.dart';
          @HostApi()
          abstract class Api {
            void ping();
          }
        ''';
        await Directory('pigeons').create(recursive: true);
        await File('pigeons/api_noheader.dart').writeAsString(pigeonInput);
        // Ensure no copyright.txt exists for this test case.
        final copyrightFile = File('pigeons/copyright.txt');
        if (copyrightFile.existsSync()) await copyrightFile.delete();

        final config = PigeonConfig.fromMap({});
        expect(config.copyrightHeader, isNull);

        final options = config.getPigeonOptions('pigeons/api_noheader.dart');
        expect(options.copyrightHeader, isNull);
      });
    });
  });
}
