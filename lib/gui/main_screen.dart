import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../emulator/configuration.dart';
import '../emulator/emulator.dart';
import '../emulator/memory/gamepad.dart';
import './Modal.dart';
import './button.dart';
import './lcd.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.title});

  final String title;

  /// Emulator instance
  static Emulator emulator = Emulator();

  static LCDState lcdState = LCDState();

  static bool keyboardHandlerCreated = false;
  @override
  MainScreenState createState() {
    return MainScreenState();
  }
}

class MainScreenState extends State<MainScreen> {
  static const int KEY_I = 73;
  static const int KEY_O = 79;
  static const int KEY_P = 80;

  static Map<int, int> keyMapping = {
    // Left arrow
    263: Gamepad.LEFT,
    // Right arrow
    262: Gamepad.RIGHT,
    // Up arrow
    265: Gamepad.UP,
    // Down arrow
    264: Gamepad.DOWN,
    // Z
    90: Gamepad.A,
    // X
    88: Gamepad.B,
    // Enter
    257: Gamepad.START,
    // C
    67: Gamepad.SELECT,
  };

  @override
  Widget build(BuildContext context) {
    if (!MainScreen.keyboardHandlerCreated) {
      MainScreen.keyboardHandlerCreated = true;

      RawKeyboard.instance.addListener((RawKeyEvent key) {
        // Get the keyCode from the object string description (keyCode does not seem to be exposed other way)
        String keyPress = key.data.toString();

        String value = keyPress.substring(keyPress.indexOf('keyCode: ') + 9, keyPress.indexOf(', scanCode:'));
        if (value.isEmpty) {
          return;
        }

        int keyCode = int.parse(value);

        // Debug functions
        if (MainScreen.emulator.state == EmulatorState.RUNNING) {
          if (key is RawKeyDownEvent) {
            if (keyCode == KEY_I) {
              print('Toogle background layer.');
              Configuration.drawBackgroundLayer = !Configuration.drawBackgroundLayer;
            } else if (keyCode == KEY_O) {
              print('Toogle sprite layer.');
              Configuration.drawSpriteLayer = !Configuration.drawSpriteLayer;
            }
          }
        }

        if (!keyMapping.containsKey(keyCode)) {
          return;
        }

        if (key is RawKeyUpEvent) {
          MainScreen.emulator.buttonUp(keyMapping[keyCode]!);
        } else if (key is RawKeyDownEvent) {
          MainScreen.emulator.buttonDown(keyMapping[keyCode]!);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // LCD
          Expanded(child: LCDWidget()),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Buttons (DPAD + AB)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    // DPAD
                    Column(
                      children: <Widget>[
                        Button(
                          color: Colors.blueAccent,
                          onPressed: () {
                            MainScreen.emulator.buttonDown(Gamepad.UP);
                          },
                          onReleased: () {
                            MainScreen.emulator.buttonUp(Gamepad.UP);
                          },
                          label: "Up",
                        ),
                        Row(
                          children: <Widget>[
                            Button(
                              color: Colors.blueAccent,
                              onPressed: () {
                                MainScreen.emulator.buttonDown(Gamepad.LEFT);
                              },
                              onReleased: () {
                                MainScreen.emulator.buttonUp(Gamepad.LEFT);
                              },
                              label: "Left",
                            ),
                            SizedBox(width: 50, height: 50),
                            Button(
                              color: Colors.blueAccent,
                              onPressed: () {
                                MainScreen.emulator.buttonDown(Gamepad.RIGHT);
                              },
                              onReleased: () {
                                MainScreen.emulator.buttonUp(Gamepad.RIGHT);
                              },
                              label: "Right",
                            ),
                          ],
                        ),
                        Button(
                          color: Colors.blueAccent,
                          onPressed: () {
                            MainScreen.emulator.buttonDown(Gamepad.DOWN);
                          },
                          onReleased: () {
                            MainScreen.emulator.buttonUp(Gamepad.DOWN);
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
                            MainScreen.emulator.buttonDown(Gamepad.A);
                          },
                          onReleased: () {
                            MainScreen.emulator.buttonUp(Gamepad.A);
                          },
                          label: "A",
                        ),
                        Button(
                          color: Colors.green,
                          onPressed: () {
                            MainScreen.emulator.buttonDown(Gamepad.B);
                          },
                          onReleased: () {
                            MainScreen.emulator.buttonUp(Gamepad.B);
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Button(
                      color: Colors.orange,
                      onPressed: () {
                        MainScreen.emulator.buttonDown(Gamepad.START);
                      },
                      onReleased: () {
                        MainScreen.emulator.buttonUp(Gamepad.START);
                      },
                      labelColor: Colors.black,
                      label: "Start",
                    ),
                    Container(width: 20),
                    Button(
                      color: Colors.yellowAccent,
                      onPressed: () {
                        MainScreen.emulator.buttonDown(Gamepad.SELECT);
                      },
                      onReleased: () {
                        MainScreen.emulator.buttonUp(Gamepad.SELECT);
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
                          if (MainScreen.emulator.state != EmulatorState.READY) {
                            Modal.alert(context, 'Error', 'Not ready to run. Load ROM first.');
                            return;
                          }
                          MainScreen.emulator.run();
                        },
                        color: Colors.black,
                        child: Text('Run', style: const TextStyle(color: Colors.white)),
                      ),
                      MaterialButton(
                        onPressed: () {
                          if (MainScreen.emulator.state != EmulatorState.RUNNING) {
                            Modal.alert(context, 'Error', 'Not running cant be paused.');
                            return;
                          }

                          MainScreen.emulator.pause();
                        },
                        color: Colors.black,
                        child: Text('Pause', style: const TextStyle(color: Colors.white)),
                      ),
                      MaterialButton(
                        onPressed: () {
                          MainScreen.emulator.reset();
                        },
                        color: Colors.black,
                        child: Text('Reset', style: const TextStyle(color: Colors.white)),
                      ),
                      MaterialButton(
                        onPressed: () {
                          MainScreen.emulator.debugStep();
                        },
                        color: Colors.black,
                        child: Text('Step', style: const TextStyle(color: Colors.white)),
                      ),
                      MaterialButton(
                        onPressed: () async {
                          if (MainScreen.emulator.state != EmulatorState.WAITING) {
                            Modal.alert(context, 'Error', 'There is a ROM already loaded. Reset before loading new ROM.');
                            return;
                          }

                          final result = await FilePicker.platform.pickFiles(dialogTitle: 'Choose ROM', withData: true);

                          if (result == null) {
                            return;
                          }

                          MainScreen.emulator.loadROM(result.files.single.bytes!);
                        },
                        color: Colors.black,
                        child: Text("Load", style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show a text input dialog to introduce string values.
  textInputDialog({String? hint, Function? onOpen}) async {
    TextEditingController controller = TextEditingController();
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
                onOpen?.call(controller.text);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
