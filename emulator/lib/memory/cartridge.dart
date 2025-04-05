import 'dart:math';

import 'package:emulator/cpu/cpu.dart';
import 'package:emulator/memory/mmu/mbc1.dart';
import 'package:emulator/memory/mmu/mbc2.dart';
import 'package:emulator/memory/mmu/mbc3.dart';
import 'package:emulator/memory/mmu/mbc5.dart';
import 'package:emulator/memory/mmu/mmu.dart';

/// Stores the cartridge information and data.
///
/// Also manages the cartridge type and is responsible for the memory bank switching.
class Cartridge {
  /// Data stored in the cartridge (directly loaded from a ROM file).
  late List<int> data;

  /// Size of the memory in bytes
  int size = 0;

  /// Cartridge name read from the
  late String name;

  /// Cartridge type, there are 16 different types.
  ///
  /// Read from memory address 0x147 (Check page 11 of the GB CPU manual for details)
  int type = 0;

  /// In cartridge ROM configuration. Read from the address 0x148.
  ///
  /// (Check page 12 of the GB CPU manual for details)
  int romType = 0;

  /// Indicates how many rom banks there are available.
  ///
  /// Each ROM bank has 32KB in size
  int romBanks = 0;

  /// In cartridge RAM configuration. Read from the address 0x149.
  ///
  /// (Check page 12 of the GB CPU manual for details)
  int ramType = 0;

  /// Indicates how many RAM banks are available in the cartridge.
  ///
  /// Each bank has 8KBytes in size.
  int ramBanks = 0;

  /// Cartridge checksum, used to check if the data of the game is good, and also used to select the better color palette in classic gb games.
  int checksum = 0;

  /// In CGB cartridges the upper bit is used to enable CGB functions. This is required, otherwise the CGB switches itself into Non-CGB-Mode.
  ///
  /// There are two different CGB modes 80h Game supports CGB functions, but works on old gameboys also, C0h Game works on CGB only.
  late GameboyType gameboyType;

  /// SGB mode indicates if the game has super gameboy features
  late bool superGameboy;

  Cartridge();

  /// Load cartridge byte data
  void load(List<int> data) {
    size = data.length;
    this.data = data;

    type = readByte(0x147);
    name = String.fromCharCodes(readBytes(0x134, 0x142));
    romType = readByte(0x148);
    ramType = readByte(0x149);
    gameboyType = readByte(0x143) == 0x80 ? GameboyType.COLOR : GameboyType.CLASSIC;
    superGameboy = readByte(0x146) == 0x3;

    // Calculate the special value used by the CGB boot ROM to colorize some monochrome games.
    int chk = 0;
    for (int i = 0; i < 16; i++) {
      chk += this.data[0x134 + i];
    }
    checksum = chk & 0xFF;

    setBankSizeRAM();
    setBankSizeROM();
  }

  /// Create a the memory controller of the cartridge.
  MMU createController(CPU cpu) {
    if (type == CartridgeType.ROM) {
      print('Created basic MMU unit.');
      return MMU(cpu);
    } else if (type == CartridgeType.MBC1 || type == CartridgeType.MBC1_RAM || type == CartridgeType.MBC1_RAM_BATT) {
      print('Created MBC1 unit.');
      return MBC1(cpu);
    } else if (type == CartridgeType.MBC2 || type == CartridgeType.MBC2_BATT) {
      print('Created MBC2 unit.');
      return MBC2(cpu);
    } else if (type == CartridgeType.MBC3 ||
        type == CartridgeType.MBC3_RAM ||
        type == CartridgeType.MBC3_RAM_BATT ||
        type == CartridgeType.MBC3_TIMER_BATT ||
        type == CartridgeType.MBC3_TIMER_RAM_BATT) {
      print('Created MBC3 unit.');
      return MBC3(cpu);
    } else if (type == CartridgeType.MBC5 ||
        type == CartridgeType.MBC5_RAM ||
        type == CartridgeType.MBC5_RAM_BATT ||
        type == CartridgeType.MBC5_RUMBLE ||
        type == CartridgeType.MBC5_RUMBLE_SRAM ||
        type == CartridgeType.MBC5_RUMBLE_SRAM_BATT) {
      print('Created MBC5 unit.');
      return MBC5(cpu);
    }

    throw "unknown";
  }

  /// Checks if the cartridge has a internal battery to keep the RAM state.
  bool hasBattery() {
    return type == CartridgeType.ROM_RAM_BATT ||
        type == CartridgeType.ROM_MMM01_SRAM_BATT ||
        type == CartridgeType.MBC1_RAM_BATT ||
        type == CartridgeType.MBC3_TIMER_BATT ||
        type == CartridgeType.MBC3_TIMER_RAM_BATT ||
        type == CartridgeType.MBC3_RAM_BATT ||
        type == CartridgeType.MBC5_RAM_BATT ||
        type == CartridgeType.MBC5_RUMBLE_SRAM_BATT;
  }

  /// Set how many ROM banks exist based on the ROM type.
  void setBankSizeROM() {
    if (romType == 52) {
      romBanks = 72;
    } else if (romType == 53) {
      romBanks = 80;
    } else if (romType == 54) {
      romBanks = 96;
    } else {
      romBanks = pow(2, romType + 1).toInt();
    }
  }

  /// Set how many RAM banks exist in the cartridge based on the RAM type.
  void setBankSizeRAM() {
    if (ramType == 0) {
      ramBanks = 0;
    } else if (ramType == 1) {
      ramBanks = 1;
    } else if (ramType == 2) {
      ramBanks = 1;
    } else if (ramType == 3) {
      ramBanks = 4;
    } else if (ramType == 4) {
      ramBanks = 16;
    }
  }

  /// Read a range of bytes from the cartridge.
  List<int> readBytes(int initialAddress, int finalAddress) {
    return data.sublist(initialAddress, finalAddress);
  }

  /// Read a single byte from cartridge
  int readByte(int address) {
    return data[address] & 0xFF;
  }
}

/// Enum to indicate the gameboy type present in the cartridge.
enum GameboyType { CLASSIC, COLOR }

/// List of all cartridge types available in the game boy.
///
/// Cartridges have different memory configurations.
class CartridgeType {
  static const int ROM = 0x00;
  static const int ROM_RAM = 0x08;
  static const int ROM_RAM_BATT = 0x09;
  static const int ROM_MMM01 = 0x0B;
  static const int ROM_MMM01_SRAM = 0x0C;
  static const int ROM_MMM01_SRAM_BATT = 0x0D;

  static const int MBC1 = 0x01;
  static const int MBC1_RAM = 0x02;
  static const int MBC1_RAM_BATT = 0x03;

  static const int MBC2 = 0x05;
  static const int MBC2_BATT = 0x06;

  static const int MBC3_TIMER_BATT = 0x0F;
  static const int MBC3_TIMER_RAM_BATT = 0x10;
  static const int MBC3 = 0x11;
  static const int MBC3_RAM = 0x12;
  static const int MBC3_RAM_BATT = 0x13;

  static const int MBC5 = 0x19;
  static const int MBC5_RAM = 0x1A;
  static const int MBC5_RAM_BATT = 0x1B;
  static const int MBC5_RUMBLE = 0x1C;
  static const int MBC5_RUMBLE_SRAM = 0x1D;
  static const int MBC5_RUMBLE_SRAM_BATT = 0x1E;

  static const int POCKETCAM = 0x1F;
  static const int BANDAI_TAMA5 = 0xFD;
  static const int HUDSON_HUC3 = 0xFE;
  static const int HUDSON_HUC1 = 0xFF;
}
