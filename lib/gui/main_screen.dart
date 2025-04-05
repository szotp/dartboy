import 'dart:async';

import 'package:dartboy/gui/Modal.dart';
import 'package:dartboy/gui/button.dart';
import 'package:dartboy/gui/lcd.dart';
import 'package:emulator/emulator.dart';
import 'package:emulator/graphics/ppu.dart';
import 'package:emulator/memory/gamepad.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

String? preload = "pokemon.gb";

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.title});

  final String title;

  @override
  MainScreenState createState() {
    return MainScreenState();
  }
}

class MainScreenState extends State<MainScreen> {
  final emulator = Emulator();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final name = preload;
    if (name != null) {
      final data = await rootBundle.load("assets/$name");
      final list = data.buffer.asUint8List();

      setState(() {
        emulator.loadAndRun(list);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: const [Formats.fileUri],
      onDropOver: (x) {
        return DropOperation.link;
      },
      onPerformDrop: performDrop,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: <Widget>[
            // LCD
            AspectRatio(aspectRatio: PPU.LCD_WIDTH / PPU.LCD_HEIGHT, child: EmulatorScreenWidget(emulator: emulator)),
            Flexible(child: EmulatorButtonsWidget(emulator: emulator)),
          ],
        ),
      ),
    );
  }

  Future<void> performDrop(PerformDropEvent event) async {
    final item = event.session.items.first;

    final completer = Completer<Uint8List>();

    item.dataReader!.getFile(
      null,
      (x) async {
        if (!(x.fileName ?? "").endsWith("gb")) {
          completer.completeError("Not GB file");
          return;
        }

        final bytes = await x.readAll();
        completer.complete(bytes);
      },
      onError: (value) {
        completer.completeError(value);
      },
    );

    final bytes = await completer.future;

    setState(() {
      emulator.loadAndRun(bytes);
    });
  }
}

class EmulatorButtonsWidget extends StatelessWidget {
  static const int KEY_I = 73;
  static const int KEY_O = 79;
  static const int KEY_P = 80;

  final Emulator emulator;

  static Map<LogicalKeyboardKey, GamepadButton> keyMapping = {
    // Left arrow
    LogicalKeyboardKey.arrowLeft: GamepadButton.LEFT,
    // Right arrow
    LogicalKeyboardKey.arrowRight: GamepadButton.RIGHT,
    // Up arrow
    LogicalKeyboardKey.arrowUp: GamepadButton.UP,
    // Down arrow
    LogicalKeyboardKey.arrowDown: GamepadButton.DOWN,
    // Z
    LogicalKeyboardKey.keyZ: GamepadButton.A,
    // X
    LogicalKeyboardKey.keyX: GamepadButton.B,
    // Enter
    LogicalKeyboardKey.enter: GamepadButton.START,
    // C
    LogicalKeyboardKey.keyC: GamepadButton.SELECT,
  };

  const EmulatorButtonsWidget({super.key, required this.emulator});

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,

      onKeyEvent: _onKeyEvent,
      child: Container(
        constraints: const BoxConstraints(minHeight: 300),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // Buttons (DPAD + AB)
            _buildDpadAB(),
            // Button (SELECT + START)
            _buildSelectStart(),
            const Expanded(child: SizedBox()),
            // Button (Start + Pause + Load)
            _buildBottomButtons(context),
          ],
        ),
      ),
    );
  }

  Row _buildDpadAB() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        // DPAD
        Column(
          children: <Widget>[
            buildButton(button: GamepadButton.UP, color: Colors.blueAccent, label: "Top"),
            Row(
              children: <Widget>[
                buildButton(color: Colors.blueAccent, button: GamepadButton.LEFT, label: "Left"),
                const SizedBox(width: 50, height: 50),
                buildButton(color: Colors.blueAccent, button: GamepadButton.RIGHT, label: "Right"),
              ],
            ),
            buildButton(color: Colors.blueAccent, button: GamepadButton.DOWN, label: "Down"),
          ],
        ),
        // AB
        Column(
          children: <Widget>[
            buildButton(color: Colors.red, button: GamepadButton.A, label: "A"),
            const SizedBox(width: 20, height: 20),
            buildButton(color: Colors.green, button: GamepadButton.B, label: "B"),
          ],
        ),
      ],
    );
  }

  Row _buildSelectStart() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Button(
          color: Colors.orange,
          onPressed: () {
            emulator.setButtonDown(GamepadButton.START);
          },
          onReleased: () {
            emulator.seButtonUp(GamepadButton.START);
          },
          labelColor: Colors.black,
          label: "Start",
        ),
        Container(width: 20),
        Button(
          color: Colors.yellowAccent,
          onPressed: () {
            emulator.setButtonDown(GamepadButton.SELECT);
          },
          onReleased: () {
            emulator.seButtonUp(GamepadButton.SELECT);
          },
          labelColor: Colors.black,
          label: "Select",
        ),
      ],
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Wrap(
      children: <Widget>[
        MaterialButton(
          onPressed: () {
            if (emulator.state != EmulatorState.READY) {
              Modal.alert(context, 'Error', 'Not ready to run. Load ROM first.');
              return;
            }
            emulator.run();
          },
          color: Colors.black,
          child: const Text('Run', style: TextStyle(color: Colors.white)),
        ),
        MaterialButton(
          onPressed: () {
            if (emulator.state != EmulatorState.RUNNING) {
              Modal.alert(context, 'Error', 'Not running cant be paused.');
              return;
            }

            emulator.pause();
          },
          color: Colors.black,
          child: const Text('Pause', style: TextStyle(color: Colors.white)),
        ),
        MaterialButton(
          onPressed: () {
            emulator.reset();
          },
          color: Colors.black,
          child: const Text('Reset', style: TextStyle(color: Colors.white)),
        ),
        MaterialButton(
          onPressed: () {
            emulator.debugStep();
          },
          color: Colors.black,
          child: const Text('Step', style: TextStyle(color: Colors.white)),
        ),
        MaterialButton(
          onPressed: () async {
            if (emulator.state != EmulatorState.WAITING) {
              Modal.alert(context, 'Error', 'There is a ROM already loaded. Reset before loading new ROM.');
              return;
            }

            final result = await FilePicker.platform.pickFiles(dialogTitle: 'Choose ROM', withData: true);

            if (result == null) {
              return;
            }

            emulator.loadROM(result.files.single.bytes!);
          },
          color: Colors.black,
          child: const Text("Load", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Button buildButton({required GamepadButton button, required Color color, required String label}) {
    return Button(
      color: color,
      onPressed: () {
        emulator.setButtonDown(button);
      },
      onReleased: () {
        emulator.seButtonUp(button);
      },
      label: label,
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent value) {
    final mapped = keyMapping[value.logicalKey];

    if (mapped != null) {
      if (value is KeyUpEvent) {
        print("buttonUp");
        emulator.seButtonUp(mapped);
      } else {
        emulator.setButtonDown(mapped);
        print("buttonDown");
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
