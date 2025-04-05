import '../memory.dart';

/// The MMU (memory management unit) is used to access memory.
///
/// Depending on the cartridge type it may select different data sources and switch memory banks as required.
///
/// This is the base implementation that considers only a single ROM bank in the cartridge and a access to the system memory.
///
/// From address 0x0000 to index 0x00FF is the bootstrap code the cartridge content only starts at 0x0100.
///
/// Address 0x100 until index 0x3FFF include the contents of the cartridge (depending on the cartridge size this memory bank can change totally)
class MMU extends Memory {
  MMU(super.cpu);

  /// Read a value from the OAM sprite memory.
  ///
  /// The OAM start address is added to the address received as parameter.
  int readOAM(int address) {
    return oam[address];
  }

  /// Write a value into the OAM sprite memory.
  ///
  /// The OAM start address is added to the address received as parameter.
  void writeOAM(int address, int value) {
    oam[address] = value;
  }

  /// Read a value from the Video RAM.
  ///
  /// The video RAM start address is added to the address received as parameter.
  int readVRAM(int address) {
    return vram[address];
  }

  /// Write a value into the Video RAM.
  ///
  /// The video RAM start address is added to the address received as parameter.
  void writeVRAM(int address, int value) {
    vram[address] = value;
  }

  /// Read a register value, register values are mapped between 0xFF00 to 0xFFFF
  ///
  /// Meaning of the values is stored in the MemoryRegisters class
  int readRegisterByte(int address) {
    return registers[address];
  }

  /// Read a register value, register values are mapped between 0xFF00 to 0xFFFF
  ///
  /// Meaning of the values is stored in the MemoryRegisters class
  void writeRegisterByte(int address, int value) {
    registers[address] = value;
  }
}
