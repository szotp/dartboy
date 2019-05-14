import 'dart:async';
import 'dart:io';

import 'cpu/cpu.dart';
import 'cartridge.dart';

enum EmulatorState
{
  WAITING,
  READY,
  RUNNING
}
/// Main emulator object used to directly interact with the system.
///
/// GUI communicates with this object, it is responsible for providing image, handling key input and user interaction.
class Emulator
{
  /// State of the emulator, indicates if there is data loaded, and the emulation state.
  EmulatorState state;

  /// CPU object
  CPU cpu;

  /// Game cartridge
  Cartridge cartridge;

  /// Callback function called on the end of each emulator step.
  Function onStep;

  /// Timer used to step the CPU.
  Timer timer;

  Emulator({Function onStep})
  {
    this.cpu = null;
    this.cartridge = null;
    this.state = EmulatorState.WAITING;
    this.onStep = onStep;
  }

  /// Load a ROM from a file and create the HW components for the emulator.
  void loadROM(File file)
  {
    if(this.state != EmulatorState.WAITING)
    {
      return;
    }

    List<int> data = file.readAsBytesSync();

    this.cartridge = new Cartridge();
    this.cartridge.load(data);

    this.cpu = new CPU(this.cartridge);

    this.printCartridgeInfo();

    this.state = EmulatorState.READY;
  }

  void printCartridgeInfo()
  {
    print('Catridge info');
    print('Type: ' + this.cpu.memory.cartridge.type.toString());
    print('Name: ' + this.cpu.memory.cartridge.name);
    print('GB: ' + this.cpu.memory.cartridge.gameboyType.toString());
    print('SGB: ' + this.cpu.memory.cartridge.superGameboy.toString());
  }

  /// Reset the emulator, stop running the code and unload the cartridge
  void reset()
  {
    this.cpu = null;
    this.cartridge = null;
    this.state = EmulatorState.WAITING;
  }

  /// Run the emulation
  void run()
  {
    if(this.state != EmulatorState.READY)
    {
      return;
    }

    this.state = EmulatorState.RUNNING;
    this.timer = new Timer.periodic(const Duration(microseconds: 1), (Timer t)
    {
      if(this.state != EmulatorState.RUNNING)
      {
        return;
      }

      this.cpu.step();

      if(this.onStep != null)
      {
        this.onStep();
      }
    });
  }

  /// Pause the emulation
  void pause()
  {
    if(this.state != EmulatorState.RUNNING)
    {
      return;
    }

    this.timer.cancel();
    this.state = EmulatorState.READY;
  }
}