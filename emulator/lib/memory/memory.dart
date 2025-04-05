import 'dart:math';
import 'dart:typed_data';

import 'package:emulator/configuration.dart';
import 'package:emulator/cpu/cpu.dart';
import 'package:emulator/memory/cartridge.dart';
import 'package:emulator/memory/dma.dart';
import 'package:emulator/memory/gamepad.dart';
import 'package:emulator/memory/memory_addresses.dart';
import 'package:emulator/memory/memory_registers.dart';

/// Generic memory container used to represent memory spaces in the gameboy system.
///
/// Contains all the memory spaces of the gameboy except for the cartridge data.
///
/// Can be used to represent booth ROM or RAM memory and provides Byte based access.
class Memory {
  /// Size of a page of Video RAM, in bytes. 8kb.
  static const int VRAM_PAGESIZE = 0x2000;

  /// Size of a page of Work RAM, in bytes. 4kb.
  static const int WRAM_PAGESIZE = 0x1000;

  /// Size of a page of ROM, in bytes. 16kb.
  static const int ROM_PAGESIZE = 0x4000;

  /// Register values contains mostly control flags, mapped from 0xFF00-0xFF7F + HRAM (0xFF80-0xFFFE) + Interrupt Enable Register (0xFFFF)
  late Uint8List registers;

  /// OAM (Object Attribute Memory) or (Sprite Attribute Table), mapped from 0xFE00-0xFE9F.
  late Uint8List oam;

  /// Video RAM, mapped from 0x8000-0x9FFF.
  /// On the GBC, this bank is switchable 0-1 by writing to 0xFF4F.
  late Uint8List vram;

  /// Work RAM, mapped from 0xC000-0xCFFF and 0xD000-0xDFFF.
  ///
  /// On the GBC, this bank is switchable 1-7 by writing to 0xFF07.
  late Uint8List wram;

  /// The current page of Video RAM, always multiples of VRAM_PAGESIZE.
  ///
  /// On non-GBC, this is always 0.
  int vramPageStart = 0;

  /// The current page of Work RAM, always multiples of WRAM_PAGESIZE.
  ///
  /// On non-GBC, this is always WRAM_PAGESIZE.
  int wramPageStart = 0;

  /// The current page of ROM, always multiples of ROM_PAGESIZE.
  int romPageStart = 0;

  /// CPU that is using the MMU, useful to trigger changes in other parts affected by memory changes.
  CPU cpu;

  /// DMA memory controller (only available on gameboy color games).
  ///
  /// Used for direct memory copy operations.
  DMA? dma;

  Memory(this.cpu) {
    dma = null;
  }

  /// Initialize the memory, create the data array with the defined size.
  ///
  /// Reset the memory to default boot values, Also sets all bytes in the memory space to 0 value.
  ///
  /// Should be used to reset the system state after loading new data.
  void reset() {
    vramPageStart = 0;
    wramPageStart = Memory.WRAM_PAGESIZE;
    romPageStart = Memory.ROM_PAGESIZE;

    registers = Uint8List(0x100);
    registers.fillRange(0, registers.length, 0);

    oam = Uint8List(0xA0);
    oam.fillRange(0, oam.length, 0);

    wram = Uint8List(Memory.WRAM_PAGESIZE * (cpu.cartridge.gameboyType == GameboyType.COLOR ? 8 : 2));
    wram.fillRange(0, wram.length, 0);

    vram = Uint8List(Memory.VRAM_PAGESIZE * (cpu.cartridge.gameboyType == GameboyType.COLOR ? 2 : 1));
    vram.fillRange(0, vram.length, 0);

    writeIO(0x04, 0xAB);
    writeIO(0x10, 0x80);
    writeIO(0x11, 0xBF);
    writeIO(0x12, 0xF3);
    writeIO(0x14, 0xBF);
    writeIO(0x16, 0x3F);
    writeIO(0x19, 0xBF);
    writeIO(0x1A, 0x7F);
    writeIO(0x1B, 0xFF);
    writeIO(0x1C, 0x9F);
    writeIO(0x1E, 0xBF);
    writeIO(0x20, 0xFF);
    writeIO(0x23, 0xBF);
    writeIO(0x24, 0x77);
    writeIO(0x25, 0xF3);
    writeIO(0x26, cpu.cartridge.superGameboy ? 0xF0 : 0xF1);
    writeIO(0x40, 0x91);
    writeIO(0x47, 0xFC);
    writeIO(0x48, 0xFF);
    writeIO(0x49, 0xFF);

    for (int i = 0; i < registers.length; i++) {
      if (registers[i] == 0) {
        writeIO(i, 0x0);
      }
    }
  }

  /// Write a byte into memory address.
  ///
  /// The memory is not directly accessed some addresses might be used for I/O or memory control operations.
  void writeByte(int address, int value) {
    address &= 0xFFFF;

    if (value > 0xFF) {
      throw Exception('Tring to write ${value.toRadixString(16)} (>0xFF) into ${address.toRadixString(16)}.');
    }

    // ROM
    if (address < MemoryAddresses.CARTRIDGE_ROM_END) {
      return;
    }
    // VRAM
    else if (address >= MemoryAddresses.VIDEO_RAM_START && address < MemoryAddresses.VIDEO_RAM_END) {
      vram[vramPageStart + address - MemoryAddresses.VIDEO_RAM_START] = value;
    }
    // Cartridge RAM
    else if (address >= MemoryAddresses.SWITCHABLE_RAM_START && address < MemoryAddresses.SWITCHABLE_RAM_END) {
      return;
    }
    // RAM A
    else if (address >= MemoryAddresses.RAM_A_START && address < MemoryAddresses.RAM_A_SWITCHABLE_START) {
      wram[address - MemoryAddresses.RAM_A_START] = value;
    } else if (address >= MemoryAddresses.RAM_A_SWITCHABLE_START && address < MemoryAddresses.RAM_A_END) {
      wram[address - MemoryAddresses.RAM_A_SWITCHABLE_START + wramPageStart] = value;
    }
    // RAM echo
    else if (address >= MemoryAddresses.RAM_A_ECHO_START && address < MemoryAddresses.RAM_A_ECHO_END) {
      writeByte(address - MemoryAddresses.RAM_A_ECHO_START, value);
    }
    // Empty
    else if (address >= MemoryAddresses.EMPTY_A_START && address < MemoryAddresses.EMPTY_A_END) {
      return;
    }
    // OAM
    else if (address >= MemoryAddresses.OAM_START && address < MemoryAddresses.EMPTY_A_END) {
      oam[address - MemoryAddresses.OAM_START] = value;
    }
    // IO
    else if (address >= MemoryAddresses.IO_START) {
      writeIO(address - MemoryAddresses.IO_START, value);
    }
  }

  /// Read a byte from memory address
  ///
  /// If the address falls into the cartridge addressing zone read directly from the cartridge object.
  int readByte(int address) {
    address &= 0xFFFF;

    // ROM
    if (address < MemoryAddresses.CARTRIDGE_ROM_SWITCHABLE_START) {
      return cpu.cartridge.data[address];
    }
    if (address >= MemoryAddresses.CARTRIDGE_ROM_SWITCHABLE_START && address < MemoryAddresses.CARTRIDGE_ROM_END) {
      return cpu.cartridge.data[romPageStart + address - MemoryAddresses.CARTRIDGE_ROM_SWITCHABLE_START];
    }
    // VRAM
    else if (address >= MemoryAddresses.VIDEO_RAM_START && address < MemoryAddresses.VIDEO_RAM_END) {
      return vram[vramPageStart + address - MemoryAddresses.VIDEO_RAM_START];
    }
    // Cartridge RAM
    else if (address >= MemoryAddresses.SWITCHABLE_RAM_START && address < MemoryAddresses.SWITCHABLE_RAM_END) {
      return 0x0;
    }
    // RAM A
    else if (address >= MemoryAddresses.RAM_A_START && address < MemoryAddresses.RAM_A_SWITCHABLE_START) {
      return wram[address - MemoryAddresses.RAM_A_START];
    } else if (address >= MemoryAddresses.RAM_A_SWITCHABLE_START && address < MemoryAddresses.RAM_A_END) {
      return wram[wramPageStart + address - MemoryAddresses.RAM_A_SWITCHABLE_START];
    }
    // RAM echo
    else if (address >= MemoryAddresses.RAM_A_ECHO_START && address < MemoryAddresses.RAM_A_ECHO_END) {
      return readByte(address - MemoryAddresses.RAM_A_ECHO_START);
    }
    // Empty A
    else if (address >= MemoryAddresses.EMPTY_A_START && address < MemoryAddresses.EMPTY_A_END) {
      return 0xFF;
    }
    // OAM
    else if (address >= MemoryAddresses.OAM_START && address < MemoryAddresses.EMPTY_A_END) {
      return oam[address - MemoryAddresses.OAM_START];
    }
    // IO
    else if (address >= MemoryAddresses.IO_START) {
      return readIO(address - MemoryAddresses.IO_START);
    }

    throw Exception('Trying to access invalid address.');
  }

  /// Write data into the IO section of memory space.
  void writeIO(int address, int value) {
    if (value > 0xFF) {
      throw Exception('Tring to write ${value.toRadixString(16)} (>0xFF) into ${address.toRadixString(16)}.');
    }
    if (address > 0xFF) {
      throw Exception('Tring to write register ${value.toRadixString(16)} into ${address.toRadixString(16)} (>0xFF).');
    }

    if (address == MemoryRegisters.DOUBLE_SPEED) {
      cpu.setDoubleSpeed((value & 0x01) != 0);
    }
    // Background Palette Data
    else if (address == MemoryRegisters.BACKGROUND_PALETTE_DATA) {
      if (cpu.cartridge.gameboyType == GameboyType.COLOR) {
        final int index = registers[MemoryRegisters.BACKGROUND_PALETTE_INDEX];
        int currentRegister = index & 0x3f;
        cpu.ppu.setBackgroundPalette(currentRegister, value);

        if ((index & 0x80) != 0) {
          currentRegister++;
          currentRegister %= 0x40;
          registers[MemoryRegisters.BACKGROUND_PALETTE_INDEX] = (0x80 | currentRegister) & 0xFF;
        }
      }
    }
    // Sprite Palette Data
    else if (address == MemoryRegisters.SPRITE_PALETTE_DATA) {
      if (cpu.cartridge.gameboyType == GameboyType.COLOR) {
        final int index = registers[MemoryRegisters.SPRITE_PALETTE_INDEX];
        int currentRegister = index & 0x3f;
        cpu.ppu.setSpritePalette(currentRegister, value);

        if ((index & 0x80) != 0) {
          currentRegister++;
          currentRegister %= 0x40;
          registers[MemoryRegisters.SPRITE_PALETTE_INDEX] = (0x80 | currentRegister) & 0xFF;
        }
      }
    }
    // Start H-DMA transfer
    else if (address == MemoryRegisters.HDMA) {
      if (cpu.cartridge.gameboyType != GameboyType.CLASSIC) {
        //print('Not possible to used H-DMA transfer on GB classic.');

        // Get the configuration of the H-DMA transfer
        final int length = ((value & 0x7f) + 1) * 0x10;
        final int source = ((registers[0x51] & 0xff) << 8) | (registers[0x52] & 0xF0);
        final int destination = ((registers[0x53] & 0x1f) << 8) | (registers[0x54] & 0xF0);

        // H-Blank DMA
        if ((value & 0x80) != 0) {
          dma = DMA(this, source, destination, length);
          registers[MemoryRegisters.HDMA] = (length ~/ 0x10 - 1) & 0xFF;
        } else {
          if (dma != null) {
            //print('Terminated DMA from ' + source.toString() + '-' + dest.toString() + ', ' + length.toString() + ' remaining.');
          }

          // General DMA
          for (int i = 0; i < length; i++) {
            vram[vramPageStart + destination + i] = readByte(source + i) & 0xFF;
          }
          registers[MemoryRegisters.HDMA] = 0xFF;
        }
      }
    } else if (address == MemoryRegisters.VRAM_BANK) {
      if (cpu.cartridge.gameboyType == GameboyType.COLOR) {
        vramPageStart = Memory.VRAM_PAGESIZE * (value & 0x3);
      }
    } else if (address == MemoryRegisters.WRAM_BANK) {
      if (cpu.cartridge.gameboyType == GameboyType.COLOR) {
        wramPageStart = Memory.WRAM_PAGESIZE * max(1, value & 0x7);
      }
    } else if (address == MemoryRegisters.NR14) {
      if ((registers[MemoryRegisters.NR14] & 0x80) != 0) {
        //this.cpu.sound.channel1.restart();
        value &= 0x7f;
      }
    } else if (address == MemoryRegisters.NR10 || address == MemoryRegisters.NR11 || address == MemoryRegisters.NR12 || address == MemoryRegisters.NR13) {
      //this.cpu.sound.channel1.update();
    } else if (address == MemoryRegisters.NR24) {
      if ((value & 0x80) != 0) {
        //this.cpu.sound.channel2.restart();
        value &= 0x7F;
      }
    } else if (address == MemoryRegisters.NR21 || address == MemoryRegisters.NR22 || address == MemoryRegisters.NR23) {
      //this.cpu.sound.channel2.update();
    } else if (address == MemoryRegisters.NR34) {
      if ((value & 0x80) != 0) {
        //this.cpu.sound.channel3.restart();
        value &= 0x7F;
      }
    } else if (address == MemoryRegisters.NR30 || address == MemoryRegisters.NR31 || address == MemoryRegisters.NR32 || address == MemoryRegisters.NR33) {
      //this.cpu.sound.channel3.update();
    } else if (address == MemoryRegisters.NR44) {
      if ((value & 0x80) != 0) {
        //this.cpu.sound.channel4.restart();
        value &= 0x7F;
      }
    } else if (address == MemoryRegisters.NR41 || address == MemoryRegisters.NR42 || address == MemoryRegisters.NR43) {
      //this.cpu.sound.channel4.update();
    }
    // OAM DMA transfer
    else if (address == MemoryRegisters.DMA) {
      final int addressBase = value * 0x100;

      for (int i = 0; i < 0xA0; i++) {
        writeByte(0xFE00 + i, readByte(addressBase + i));
      }
    } else if (address == MemoryRegisters.DIV) {
      value = 0;
    } else if (address == MemoryRegisters.TAC) {
      if (((registers[MemoryRegisters.TAC] ^ value) & 0x03) != 0) {
        cpu.timerCycle = 0;
        registers[MemoryRegisters.TIMA] = registers[MemoryRegisters.TMA];
      }
    } else if (address == MemoryRegisters.SERIAL_SC) {
      // Serial transfer starts if the 7th bit is set
      if (value == 0x81) {
        // Print data passed thought the serial port as character.
        if (Configuration.printSerialCharacters) {
          print(String.fromCharCode(registers[MemoryRegisters.SERIAL_SB]));
        }
      }
    } else if (0x30 <= address && address < 0x40) {
      //this.cpu.sound.channel3.updateSample(address - 0x30, (byte) value);
    }

    registers[address] = value;
  }

  /// Read IO address
  int readIO(int address) {
    if (address > 0xFF) {
      throw Exception('Tring to read register from ${address.toRadixString(16)} (>0xFF).');
    }

    if (address == MemoryRegisters.DOUBLE_SPEED) {
      return cpu.doubleSpeed ? 0x80 : 0x0;
    } else if (address == MemoryRegisters.GAMEPAD) {
      int reg = registers[MemoryRegisters.GAMEPAD];
      reg |= 0x0F;

      if (reg & 0x10 == 0) {
        if (cpu.buttons[GamepadButton.RIGHT.index]) {
          reg &= ~0x1;
        }
        if (cpu.buttons[GamepadButton.LEFT.index]) {
          reg &= ~0x2;
        }
        if (cpu.buttons[GamepadButton.UP.index]) {
          reg &= ~0x4;
        }
        if (cpu.buttons[GamepadButton.DOWN.index]) {
          reg &= ~0x8;
        }
      }

      if (reg & 0x20 == 0) {
        if (cpu.buttons[GamepadButton.A.index]) {
          reg &= ~0x1;
        }
        if (cpu.buttons[GamepadButton.B.index]) {
          reg &= ~0x2;
        }
        if (cpu.buttons[GamepadButton.SELECT.index]) {
          reg &= ~0x4;
        }
        if (cpu.buttons[GamepadButton.START.index]) {
          reg &= ~0x8;
        }
      }

      return reg;
    } else if (address == MemoryRegisters.NR52) {
      final int reg = registers[MemoryRegisters.NR52] & 0x80;

      //TODO <ADD CODE HERE>
      //if(this.cpu.sound.channel1.isPlaying){reg |= 0x01};
      //if(this.cpu.sound.channel2.isPlaying){reg |= 0x02};
      //if(this.cpu.sound.channel3.isPlaying){reg |= 0x04};
      //if(this.cpu.sound.channel4.isPlaying){reg |= 0x08};

      return reg;
    }

    return registers[address];
  }
}
