import 'package:emulator/cpu/cpu.dart';
import 'package:emulator/memory/cartridge.dart';

/// CPU registers, each register has 8 bits
///
/// Represents in dart as int values (dart does not support byte).
///
class Registers {
  // The DMG has 4 flag registers, zero, subtract, half-carry and carry.
  static const int ZERO = 0x80;

  // Half-carry is only ever used for the DAA instruction. Half-carry is usually carry over lower nibble, and carry is over bit 7.
  static const int SUBTRACT = 0x40;
  static const int HALF_CARRY = 0x20;
  static const int CARRY = 0x10;

  // Register pair addressing
  static const int BC = 0x0;
  static const int DE = 0x1;
  static const int HL = 0x2;
  static const int AF = 0x3;
  static const int SP = 0x3;

  // Register addressing
  static const int B = 0x00;
  static const int C = 0x01;
  static const int D = 0x02;
  static const int E = 0x03;
  static const int H = 0x04;
  static const int L = 0x05;
  static const int F = 0x06;
  static const int A = 0x07;

  // CPU registers store temporally the result of the instructions.
  //
  // F is the flag register.
  List<int> registers = List<int>.filled(8, 0);

  int get a {
    return registers[A];
  }

  int get b {
    return registers[B];
  }

  int get c {
    return registers[C];
  }

  int get d {
    return registers[D];
  }

  int get e {
    return registers[E];
  }

  int get f {
    return registers[F];
  }

  int get h {
    return registers[H];
  }

  int get l {
    return registers[L];
  }

  set a(int value) {
    registers[A] = value;
  }

  set b(int value) {
    registers[B] = value;
  }

  set c(int value) {
    registers[C] = value;
  }

  set d(int value) {
    registers[D] = value;
  }

  set e(int value) {
    registers[E] = value;
  }

  set f(int value) {
    registers[F] = value;
  }

  set h(int value) {
    registers[H] = value;
  }

  set l(int value) {
    registers[L] = value;
  }

  /// Pointer to the CPU object
  CPU cpu;

  Registers(this.cpu);

  /// Fetches the byte value contained in a register, r is the register id as encoded by opcode.
  /// Returns the value of the register
  int getRegister(int r) {
    if (r == A) {
      return a;
    }
    if (r == B) {
      return b;
    }
    if (r == C) {
      return c;
    }
    if (r == D) {
      return d;
    }
    if (r == E) {
      return e;
    }
    if (r == H) {
      return h;
    }
    if (r == L) {
      return l;
    }
    if (r == 0x6) {
      return cpu.mmu.readByte(getRegisterPair(HL));
    }

    throw Exception('Unknown register address getRegister().');
  }

  /// Alters the byte value contained in a register, r is the register id as encoded by opcode.
  void setRegister(int r, int value) {
    value &= 0xFF;

    if (r == A) {
      a = value;
    } else if (r == B) {
      b = value;
    } else if (r == C) {
      c = value;
    } else if (r == D) {
      d = value;
    } else if (r == E) {
      e = value;
    } else if (r == H) {
      h = value;
    } else if (r == L) {
      l = value;
    } else if (r == 0x6) {
      cpu.mmu.writeByte(getRegisterPair(HL), value);
    }
  }

  /// Fetches the world value of a registers pair, r is the register id as encoded by opcode (PUSH_rr).
  /// Returns the value of the register
  int getRegisterPair(int r) {
    if (r == BC) {
      return (b << 8) | c;
    }
    if (r == DE) {
      return (d << 8) | e;
    }
    if (r == HL) {
      return (h << 8) | l;
    }
    if (r == AF) {
      return (a << 8) | f;
    }

    throw Exception('Unknown register pair address getRegisterPair().');
  }

  /// Fetches the world value of a registers pair, r is the register id as encoded by opcode.
  /// It can return a register pair or the CPU SP value.
  /// Returns the value of the register
  int getRegisterPairSP(int r) {
    if (r == BC) {
      return (b << 8) | c;
    }
    if (r == DE) {
      return (d << 8) | e;
    }
    if (r == HL) {
      return (h << 8) | l;
    }
    if (r == Registers.SP) {
      return cpu.sp;
    }

    throw Exception('Unknown register pair address getRegisterPairSP().');
  }

  /// Fetches the world value of a registers pair, r is the register id as encoded by opcode (PUSH_rr).
  /// Can be used with a single word value as the second argument.
  /// Returns the value of the register
  void setRegisterPair(int r, int hi, int lo) {
    hi &= 0xFF;
    lo &= 0xFF;

    if (r == BC) {
      b = hi;
      c = lo;
    } else if (r == DE) {
      d = hi;
      e = lo;
    } else if (r == HL) {
      h = hi;
      l = lo;
    } else if (r == AF) {
      a = hi;
      f = lo & 0xF;
    }
  }

  /// Fetches the world value of a registers pair, r is the register id as encoded by opcode (PUSH_rr).
  /// It can set a register pair or the CPU SP value.
  /// Returns the value of the register
  void setRegisterPairSP(int r, int value) {
    final int hi = (value >> 8) & 0xFF;
    final int lo = value & 0xFF;

    if (r == Registers.BC) {
      b = hi;
      c = lo;
    } else if (r == Registers.DE) {
      d = hi;
      e = lo;
    } else if (r == Registers.HL) {
      h = hi;
      l = lo;
    } else if (r == Registers.SP) {
      cpu.sp = (hi << 8) | lo;
    }
  }

  /// Reset the registers to default values
  ///
  /// (Check page 17 and 18 of the GB CPU manual)
  void reset() {
    //AF=$01-GB/SGB, $FF-GBP, $11-GBC
    a = cpu.cartridge.gameboyType == GameboyType.COLOR ? 0x11 : 0x01;
    f = 0xB0;
    b = 0x00;
    c = 0x13;
    d = 0x00;
    e = 0xD8;
    h = 0x01;
    l = 0x4D;
  }

  ///Checks a condition from an opcode.
  ///Returns a boolean based off the result of the conditional.
  bool getFlag(int flag) {
    flag &= 0x7;

    // Condition code is in last 3 bits
    if (flag == 0x4) {
      return (f & ZERO) == 0;
    }
    if (flag == 0x5) {
      return (f & ZERO) != 0;
    }
    if (flag == 0x6) {
      return (f & CARRY) == 0;
    }
    if (flag == 0x7) {
      return (f & CARRY) != 0;
    }

    return false;
  }

  /// Set the flags on the flag register.
  ///
  /// There are four values on the upper bits of the register that are set depending on the instruction being executed.
  void setFlags(bool zero, bool subtract, bool halfCarry, bool carry) {
    f = zero ? (f | ZERO) : (f & 0x7F);
    f = subtract ? (f | SUBTRACT) : (f & 0xBF);
    f = halfCarry ? (f | HALF_CARRY) : (f & 0xDF);
    f = carry ? (f | CARRY) : (f & 0xEF);
  }
}
