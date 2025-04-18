import 'dart:async';
import 'dart:typed_data';

import 'package:emulator/configuration.dart';
import 'package:emulator/cpu/cpu.dart';
import 'package:emulator/memory/cartridge.dart';
import 'package:emulator/memory/gamepad.dart';

/// Represents the state of the emulator.
///
/// If data is not loaded the emulator is in WAITING state, after loading data is get into READY state.
///
/// When the game starts running it goes to RUNNING state, on pause it returns to READY.
enum EmulatorState { WAITING, READY, RUNNING }

const _frequency = CPU.FREQUENCY ~/ 4;
const _periodCPU = 1e6 / _frequency;

const _fps = 30;
const _periodFPS = 1e6 ~/ _fps;

const _cycles = _periodFPS ~/ _periodCPU;
const Duration _period = Duration(microseconds: _periodFPS);

/// Main emulator object used to directly interact with the system.
///
/// GUI communicates with this object, it is responsible for providing image, handling key input and user interaction.
class Emulator {
  /// State of the emulator, indicates if there is data loaded, and the emulation state.
  EmulatorState state = EmulatorState.WAITING;

  /// CPU object
  CPU? cpu;

  final Configuration configuration;

  Emulator(this.configuration);

  /// Press a gamepad button down (update memory register).
  void setButtonDown(GamepadButton button) {
    cpu?.buttons[button.index] = true;
  }

  /// Release a gamepad button (update memory register).
  void seButtonUp(GamepadButton button) {
    cpu?.buttons[button.index] = false;
  }

  /// Load a ROM from a file and create the HW components for the emulator.
  void loadROM(Uint8List data) {
    if (state != EmulatorState.WAITING) {
      print('Emulator should be reset to load ROM.');
      return;
    }

    final Cartridge cartridge = Cartridge(data);
    cpu = CPU(cartridge, configuration);

    state = EmulatorState.READY;

    printCartridgeInfo();
  }

  /// Print some information about the ROM file loaded into the emulator.
  void printCartridgeInfo() {
    print('Catridge info');
    print('Type: ${cpu?.cartridge.type}');
    print('Name: ${cpu?.cartridge.name}');
    print('GB: ${cpu?.cartridge.gameboyType}');
    print('SGB: ${cpu?.cartridge.superGameboy}');
  }

  /// Reset the emulator, stop running the code and unload the cartridge
  void reset() {
    cpu = null;
    state = EmulatorState.WAITING;
  }

  /// Do a single step in the cpu, set it to debug mode, step and then reset.
  void debugStep() {
    if (state != EmulatorState.READY) {
      print('Emulator not ready, cannot step.');
      return;
    }

    final bool wasDebug = configuration.debugInstructions;
    configuration.debugInstructions = true;
    cpu?.step();
    configuration.debugInstructions = wasDebug;
  }

  /// Run the emulation all full speed.
  Future<void> run() async {
    if (state != EmulatorState.READY) {
      print('Emulator not ready, cannot run.');
      return;
    }

    state = EmulatorState.RUNNING;

    while (state == EmulatorState.RUNNING) {
      stepFrame();
      await Future.delayed(_period);
    }
  }

  void stepFrame() {
    for (var i = 0; i < _cycles; i++) {
      cpu!.step();
    }
  }

  /// Pause the emulation
  void pause() {
    if (state != EmulatorState.RUNNING) {
      print('Emulator not running cannot be paused');
      return;
    }

    state = EmulatorState.READY;
  }

  Future<void> loadAndRun(Uint8List bytes) {
    reset();
    loadROM(bytes);
    return run();
  }
}
