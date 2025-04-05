import 'package:dartboy/gui/Modal.dart';
import 'package:dartboy/gui/button.dart';
import 'package:dartboy/gui/lcd.dart';
import 'package:emulator/emulator.dart';
import 'package:emulator/memory/gamepad.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String? preload = "sprite_priority.gb";

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.title});

  final String title;

  @override
  MainScreenState createState() {
    return MainScreenState();
  }
}

class MainScreenState extends State<MainScreen> {
  static const int KEY_I = 73;
  static const int KEY_O = 79;
  static const int KEY_P = 80;

  final emulator = Emulator();

  static Map<LogicalKeyboardKey, int> keyMapping = {
    // Left arrow
    LogicalKeyboardKey.arrowLeft: Gamepad.LEFT,
    // Right arrow
    LogicalKeyboardKey.arrowRight: Gamepad.RIGHT,
    // Up arrow
    LogicalKeyboardKey.arrowUp: Gamepad.UP,
    // Down arrow
    LogicalKeyboardKey.arrowDown: Gamepad.DOWN,
    // Z
    LogicalKeyboardKey.keyZ: Gamepad.A,
    // X
    LogicalKeyboardKey.keyX: Gamepad.B,
    // Enter
    LogicalKeyboardKey.enter: Gamepad.START,
    // C
    LogicalKeyboardKey.keyC: Gamepad.SELECT,
  };

  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final name = preload;
    if (name != null) {
      final data = await rootBundle.load("assets/$name");
      emulator.loadROM(data.buffer.asUint8List());
      emulator.run();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        focusNode: focusNode,
        onKeyEvent: _onKeyEvent,
        child: Column(
          children: <Widget>[
            // LCD
            Expanded(child: LCDWidget(emulator: emulator)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Buttons (DPAD + AB)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      // DPAD
                      Column(
                        children: <Widget>[
                          Button(
                            color: Colors.blueAccent,
                            onPressed: () {
                              emulator.buttonDown(Gamepad.UP);
                            },
                            onReleased: () {
                              emulator.buttonUp(Gamepad.UP);
                            },
                            label: "Up",
                          ),
                          Row(
                            children: <Widget>[
                              Button(
                                color: Colors.blueAccent,
                                onPressed: () {
                                  emulator.buttonDown(Gamepad.LEFT);
                                },
                                onReleased: () {
                                  emulator.buttonUp(Gamepad.LEFT);
                                },
                                label: "Left",
                              ),
                              const SizedBox(width: 50, height: 50),
                              Button(
                                color: Colors.blueAccent,
                                onPressed: () {
                                  emulator.buttonDown(Gamepad.RIGHT);
                                },
                                onReleased: () {
                                  emulator.buttonUp(Gamepad.RIGHT);
                                },
                                label: "Right",
                              ),
                            ],
                          ),
                          Button(
                            color: Colors.blueAccent,
                            onPressed: () {
                              emulator.buttonDown(Gamepad.DOWN);
                            },
                            onReleased: () {
                              emulator.buttonUp(Gamepad.DOWN);
                            },
                            label: "Down",
                          ),
                        ],
                      ),
                      // AB
                      Column(
                        children: <Widget>[
                          Button(
                            color: Colors.red,
                            onPressed: () {
                              emulator.buttonDown(Gamepad.A);
                            },
                            onReleased: () {
                              emulator.buttonUp(Gamepad.A);
                            },
                            label: "A",
                          ),
                          Button(
                            color: Colors.green,
                            onPressed: () {
                              emulator.buttonDown(Gamepad.B);
                            },
                            onReleased: () {
                              emulator.buttonUp(Gamepad.B);
                            },
                            label: "B",
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Button (SELECT + START)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Button(
                        color: Colors.orange,
                        onPressed: () {
                          emulator.buttonDown(Gamepad.START);
                        },
                        onReleased: () {
                          emulator.buttonUp(Gamepad.START);
                        },
                        labelColor: Colors.black,
                        label: "Start",
                      ),
                      Container(width: 20),
                      Button(
                        color: Colors.yellowAccent,
                        onPressed: () {
                          emulator.buttonDown(Gamepad.SELECT);
                        },
                        onReleased: () {
                          emulator.buttonUp(Gamepad.SELECT);
                        },
                        labelColor: Colors.black,
                        label: "Select",
                      ),
                    ],
                  ),
                  // Button (Start + Pause + Load)
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(left: 10.0, right: 10.0),
                      scrollDirection: Axis.horizontal,
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
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show a text input dialog to introduce string values.
  Future<void> textInputDialog({String? hint, VoidCallback? onOpen}) async {
    final TextEditingController controller = TextEditingController();
    controller.text = hint ?? '';

    await showDialog<String>(
      context: context,
      builder: (BuildContext cx) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(16.0),
          content: Row(
            children: <Widget>[
              Expanded(child: TextField(autofocus: true, controller: controller, decoration: InputDecoration(labelText: 'File Name', hintText: hint ?? ''))),
            ],
          ),
          actions: <Widget>[
            MaterialButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            MaterialButton(
              child: const Text('Open'),
              onPressed: () {
                onOpen?.call();
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent value) {
    final mapped = keyMapping[value.logicalKey];

    if (mapped != null) {
      if (value is KeyUpEvent) {
        print("buttonUp");
        emulator.buttonUp(mapped);
      } else {
        emulator.buttonDown(mapped);
        print("buttonDown");
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;

    // if (!MainScreen.keyboardHandlerCreated) {
    //   MainScreen.keyboardHandlerCreated = true;

    //   RawKeyboard.instance.addListener((RawKeyEvent key) {
    //     // Get the keyCode from the object string description (keyCode does not seem to be exposed other way)
    //     String keyPress = key.data.toString();

    //     String value = keyPress.substring(keyPress.indexOf('keyCode: ') + 9, keyPress.indexOf(', scanCode:'));
    //     if (value.isEmpty) {
    //       return;
    //     }

    //     int keyCode = int.parse(value);

    //     // Debug functions
    //     if (MainScreen.emulator.state == EmulatorState.RUNNING) {
    //       if (key is RawKeyDownEvent) {
    //         if (keyCode == KEY_I) {
    //           print('Toogle background layer.');
    //           Configuration.drawBackgroundLayer = !Configuration.drawBackgroundLayer;
    //         } else if (keyCode == KEY_O) {
    //           print('Toogle sprite layer.');
    //           Configuration.drawSpriteLayer = !Configuration.drawSpriteLayer;
    //         }
    //       }
    //     }

    //     if (!keyMapping.containsKey(keyCode)) {
    //       return;
    //     }

    //     if (key is RawKeyUpEvent) {
    //       MainScreen.emulator.buttonUp(keyMapping[keyCode]!);
    //     } else if (key is RawKeyDownEvent) {
    //       MainScreen.emulator.buttonDown(keyMapping[keyCode]!);
    //     }
    //   });
    // }
  }
}
