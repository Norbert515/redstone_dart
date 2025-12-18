/// Commands API tests.
///
/// Tests for the command registration and execution system.
import 'package:dart_mc/api/api.dart';
import 'package:dart_mc/api/commands.dart';
import 'package:redstone_test/redstone_test.dart';
import 'package:test/test.dart' as dart_test;

Future<void> main() async {
  await group('Command registration', () async {
    await testMinecraft('can register a simple command', (game) async {
      Commands.register(
        'testcmd',
        execute: (ctx) {
          return 1;
        },
      );

      // Command should be registered without error
      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('can register command with description', (game) async {
      Commands.register(
        'helpcmd',
        execute: (ctx) => 1,
        description: 'A helpful command',
      );

      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('can register command with arguments', (game) async {
      Commands.register(
        'greetcmd',
        execute: (ctx) {
          final name = ctx.getArgument<String>('name');
          ctx.sendFeedback('Hello, $name!');
          return 1;
        },
        arguments: [
          CommandArgument('name', ArgumentType.string),
        ],
      );

      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('can register command with multiple arguments', (game) async {
      Commands.register(
        'teleportcmd',
        execute: (ctx) {
          final x = ctx.getArgument<String>('x');
          final y = ctx.getArgument<String>('y');
          final z = ctx.getArgument<String>('z');
          ctx.sendFeedback('Teleporting to $x, $y, $z');
          return 1;
        },
        arguments: [
          CommandArgument('x', ArgumentType.integer),
          CommandArgument('y', ArgumentType.integer),
          CommandArgument('z', ArgumentType.integer),
        ],
      );

      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('can register command with permission level', (game) async {
      Commands.register(
        'admincmd',
        execute: (ctx) => 1,
        permission: 4, // Op level 4
      );

      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('can register command with optional arguments', (game) async {
      Commands.register(
        'optcmd',
        execute: (ctx) {
          // Optional argument can be retrieved with default
          ctx.getArgument<String>('count') ?? '1';
          return 1;
        },
        arguments: [
          CommandArgument('count', ArgumentType.integer, required: false),
        ],
      );

      expect(Commands.commandCount, greaterThan(0));
    });
  });

  await group('Argument types', () async {
    await testMinecraft('supports string argument', (game) async {
      Commands.register(
        'stringarg',
        execute: (ctx) => 1,
        arguments: [CommandArgument('text', ArgumentType.string)],
      );
      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('supports integer argument', (game) async {
      Commands.register(
        'intarg',
        execute: (ctx) => 1,
        arguments: [CommandArgument('num', ArgumentType.integer)],
      );
      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('supports double argument', (game) async {
      Commands.register(
        'doublearg',
        execute: (ctx) => 1,
        arguments: [CommandArgument('value', ArgumentType.double_)],
      );
      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('supports boolean argument', (game) async {
      Commands.register(
        'boolarg',
        execute: (ctx) => 1,
        arguments: [CommandArgument('flag', ArgumentType.bool_)],
      );
      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('supports player argument', (game) async {
      Commands.register(
        'playerarg',
        execute: (ctx) => 1,
        arguments: [CommandArgument('target', ArgumentType.player)],
      );
      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('supports position argument', (game) async {
      Commands.register(
        'posarg',
        execute: (ctx) => 1,
        arguments: [CommandArgument('pos', ArgumentType.position)],
      );
      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('supports greedy string argument', (game) async {
      Commands.register(
        'greedyarg',
        execute: (ctx) => 1,
        arguments: [CommandArgument('message', ArgumentType.greedyString)],
      );
      expect(Commands.commandCount, greaterThan(0));
    });
  });

  await group('CommandContext', () async {
    await testMinecraft('context provides sendFeedback', (game) async {
      Commands.register(
        'feedbackcmd',
        execute: (ctx) {
          ctx.sendFeedback('Operation successful');
          return 1;
        },
      );
      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('context provides sendError', (game) async {
      Commands.register(
        'errorcmd',
        execute: (ctx) {
          ctx.sendError('Something went wrong');
          return 0;
        },
      );
      expect(Commands.commandCount, greaterThan(0));
    });

    await testMinecraft('context provides requireArgument', (game) async {
      Commands.register(
        'requirecmd',
        execute: (ctx) {
          try {
            ctx.requireArgument<String>('name');
            return 1;
          } catch (e) {
            return 0;
          }
        },
        arguments: [CommandArgument('name', ArgumentType.string)],
      );
      expect(Commands.commandCount, greaterThan(0));
    });
  });

  // Pure Dart unit tests
  await group('CommandArgument', () async {
    dart_test.test('toJson includes required fields', () {
      final arg = CommandArgument('test', ArgumentType.string);
      final json = arg.toJson();

      expect(json['name'], equals('test'));
      expect(json['type'], equals('string'));
      expect(json['required'], isTrue);
    });

    dart_test.test('toJson includes default value when present', () {
      final arg = CommandArgument(
        'count',
        ArgumentType.integer,
        required: false,
        defaultValue: 1,
      );
      final json = arg.toJson();

      expect(json['required'], isFalse);
      expect(json['default'], equals(1));
    });
  });

  await group('ArgumentType', () async {
    dart_test.test('all types have unique names', () {
      final names = ArgumentType.values.map((t) => t.name).toSet();
      expect(names.length, equals(ArgumentType.values.length));
    });
  });
}
