import 'dart:io';
import 'dart:typed_data';

import 'package:emulator/memory/memory_addresses.dart';
import 'package:emulator/memory/mmu/mmu.dart';

/// Abstract implementation of features shared by all Memory Banking Chips.
///
/// Implements the battery load and save to and from file and the access to individual memory regions.
class MBC extends MMU {
  /// The size of a page of cartridge RAM, 8k in size for each page.
  static const int RAM_PAGESIZE = 0x2000;

  /// The current offset (page) into cart ram.
  int ramPageStart = 0;

  /// Whether or not accessing RAM is currently enabled.
  late bool ramEnabled;

  /// Raw cart ram, has to be initialized and reset by the implementations.
  late Uint8List cartRam;

  MBC(super.cpu);

  @override
  void reset() {
    super.reset();

    ramPageStart = 0;
    ramEnabled = false;
  }

  /// Load the state of the internal RAM of the cartridge from file.
  void load(File file) {
    if (!cpu.cartridge.hasBattery()) {
      throw Exception('Cartridge has no battery.');
    }

    final int length = cartRam.length;

    cartRam = file.readAsBytesSync();

    if (length != cartRam.length) {
      throw Exception('Loaded invalid cartridge RAM file.');
    }
  }

  /// Save the state of the internal RAM of the cartridge to file.
  void save(File file) {
    if (!cpu.cartridge.hasBattery()) {
      throw Exception('Cartridge has no battery.');
    }

    file.writeAsBytes(cartRam, flush: true);
  }

  @override
  int readByte(int address) {
    address &= 0xFFFF;

    if (address >= MemoryAddresses.SWITCHABLE_RAM_START &&
        address < MemoryAddresses.SWITCHABLE_RAM_END) {
      return ramEnabled
          ? cartRam[address -
              MemoryAddresses.SWITCHABLE_RAM_START +
              ramPageStart]
          : 0xFF;
    }

    return super.readByte(address);
  }
}
