import 'package:emulator/configuration.dart';
import 'package:emulator/cpu/instructions.dart';
import 'package:emulator/cpu/registers.dart';
import 'package:emulator/graphics/ppu.dart';
import 'package:emulator/memory/cartridge.dart';
import 'package:emulator/memory/memory_registers.dart';
import 'package:emulator/memory/mmu/mmu.dart';

/// CPU class is responsible for the instruction execution, interrupts and timing of the system.
///
/// Sharp LR35902
class CPU {
  static const int PC = 0;
  static const int SP = 1;

  /// Frequency frequency (hz)
  static const int FREQUENCY = 4194304;

  /// Game cartridge memory data composes the lower 32kB of memory from (0x0000 to 0x8000).
  Cartridge cartridge;

  /// Memory control unit decides from where the addresses are read and written to
  late MMU mmu;

  /// Internal CPU registers
  late Registers registers;

  /// PPU handles the graphics display
  late PPU ppu;

  /// Whether the CPU is currently halted if so, it will still operate at 4MHz, but will not execute any instructions until an interrupt is cyclesExecutedThisSecond.
  /// This mode is used for power saving.
  bool halted = false;

  /// Whether the CPU should trigger interrupt handlers.
  bool interruptsEnabled = false;

  /// The current CPU clock cycle since the beginning of the emulation.
  int clocks = 0;

  /// The number of cycles elapsed since the last speed emulation sleep.
  int cyclesSinceLastSleep = 0;

  /// The number of cycles executed in the last second.
  int cyclesExecutedThisSecond = 0;

  /// Indicates if the emulator is running at double speed.
  bool doubleSpeed = false;

  /// The current cycle of the DIV register.
  int divCycle = 0;

  /// The current cycle of the TIMA register.
  int timerCycle = 0;

  /// Buttons of the gameboy the index stored in the Gamepad class corresponds to the position here
  List<bool> buttons = [];

  /// Current clock speed of the system (can be double on GBC hardware).
  int clockSpeed = 0;

  /// Stores the PC and SP pointers
  //List<int> pointers = List<int>.filled(8, 0);

  /// 16 bit Program Counter, the memory address of the next instruction to be fetched
  int pc = 0;

  /// 16 bit Stack Pointer, the memory address of the top of the stack
  int sp = 0;

  final Configuration configuration;

  CPU(this.cartridge, this.configuration) {
    mmu = cartridge.createController(this);
    ppu = PPU(this, configuration);
    registers = Registers(this);

    reset();
  }

  /// Reset the CPU, also resets the MMU, registers and PPU.
  void reset() {
    buttons = List<bool>.filled(8, false);
    buttons.fillRange(0, 8, false);

    clockSpeed = FREQUENCY;
    doubleSpeed = false;
    divCycle = 0;
    timerCycle = 0;
    sp = 0xFFFE;
    pc = 0x0100;

    halted = false;
    interruptsEnabled = false;

    clocks = 0;
    cyclesSinceLastSleep = 0;
    cyclesExecutedThisSecond = 0;

    registers.reset();
    ppu.reset();
    mmu.reset();
  }

  /// Read the next program byte and update the PC value
  int nextUnsignedBytePC() {
    return getUnsignedByte(pc++);
  }

  /// Read the next program byte and update the PC value
  int nextSignedBytePC() {
    return getSignedByte(pc++);
  }

  /// Read a unsiged byte value from memory.
  int getUnsignedByte(int address) {
    tick(4);
    return mmu.readByte(address) & 0xFF;
  }

  /// Read a byte from memory and update the clock count.
  int getSignedByte(int address) {
    tick(4);
    return (mmu.readByte(address) & 0xFF).toSigned(8);
  }

  /// Write a byte into memory (takes 4 clocks)
  void setByte(int address, int value) {
    tick(4);
    mmu.writeByte(address, value);
  }

  /// Push word into the temporary stack and update the stack pointer
  void pushWordSP(int value) {
    sp -= 2;
    mmu.writeByte(sp, value & 0xFF);
    mmu.writeByte(sp + 1, (value >> 8) & 0xFF);
  }

  ///Increase the clock cycles and trigger interrupts as needed.
  void tick(int delta) {
    clocks += delta;
    cyclesSinceLastSleep += delta;
    cyclesExecutedThisSecond += delta;

    updateInterrupts(delta);
  }

  /// Update interrupt counter, check for interruptions waiting.
  ///
  /// Trigger timer interrupts, LCD updates, and sound updates as needed.
  ///
  /// @param delta CPU cycles elapsed since the last call to this method
  void updateInterrupts(int delta) {
    if (doubleSpeed) {
      delta ~/= 2;
    }

    // The DIV register increments at 16KHz, and resets to 0 after
    divCycle += delta;

    if (divCycle >= 256) {
      divCycle -= 256;
      mmu.writeRegisterByte(MemoryRegisters.DIV, mmu.readRegisterByte(MemoryRegisters.DIV) + 1);
    }

    // The Timer is similar to DIV, except that when it overflows it triggers an interrupt
    final int tac = mmu.readRegisterByte(MemoryRegisters.TAC);

    // If timer 3 bit is set the timer should start
    if ((tac & 0x4) != 0) {
      timerCycle += delta;

      // The Timer has a settable frequency
      int timerPeriod = 0;

      switch (tac & 0x3) {
        // 4096 Hz
        case 0x0:
          timerPeriod = clockSpeed ~/ 4096;
        // 262144 Hz
        case 0x1:
          timerPeriod = clockSpeed ~/ 262144;
        // 65536 Hz
        case 0x2:
          timerPeriod = clockSpeed ~/ 65536;
        // 16384 Hz
        case 0x3:
          timerPeriod = clockSpeed ~/ 16384;
      }

      while (timerCycle >= timerPeriod) {
        timerCycle -= timerPeriod;

        // And it resets to a specific value
        int tima = (mmu.readRegisterByte(MemoryRegisters.TIMA) & 0xFF) + 1;

        if (tima > 0xFF) {
          tima = mmu.readRegisterByte(MemoryRegisters.TMA) & 0xFF;
          setInterruptTriggered(MemoryRegisters.TIMER_OVERFLOW_BIT);
        }

        mmu.writeRegisterByte(MemoryRegisters.TIMA, tima & 0xFF);
      }
    }

    ppu.tick(delta);
  }

  /// Triggers a particular interrupt by writing the correct interrupt bit to the interrupt register.
  ///
  /// @param interrupt The interrupt bit.
  void setInterruptTriggered(int interrupt) {
    mmu.writeRegisterByte(MemoryRegisters.TRIGGERED_INTERRUPTS, mmu.readRegisterByte(MemoryRegisters.TRIGGERED_INTERRUPTS) | interrupt);
  }

  /// Fires interrupts if interrupts are enabled.
  void fireInterrupts() {
    // Auxiliary method to check if an interruption was triggered.
    bool interruptTriggered(int interrupt) {
      return (mmu.readRegisterByte(MemoryRegisters.TRIGGERED_INTERRUPTS) & mmu.readRegisterByte(MemoryRegisters.ENABLED_INTERRUPTS) & interrupt) != 0;
    }

    // If interrupts are disabled (via the DI instruction), ignore this call
    if (!interruptsEnabled) {
      return;
    }

    // Flag of which interrupts should be triggered
    int triggeredInterrupts = mmu.readRegisterByte(MemoryRegisters.TRIGGERED_INTERRUPTS);

    // Which interrupts the program is actually interested in, these are the ones we will fire
    final int enabledInterrupts = mmu.readRegisterByte(MemoryRegisters.ENABLED_INTERRUPTS);

    // If this is nonzero, then some interrupt that we are checking for was triggered
    if ((triggeredInterrupts & enabledInterrupts) != 0) {
      pushWordSP(pc);

      // This is important
      interruptsEnabled = false;

      // Interrupt priorities are vblank > lcdc > tima overflow > serial transfer > hilo
      if (interruptTriggered(MemoryRegisters.VBLANK_BIT)) {
        pc = MemoryRegisters.VBLANK_HANDLER_ADDRESS;
        triggeredInterrupts &= ~MemoryRegisters.VBLANK_BIT;
      } else if (interruptTriggered(MemoryRegisters.LCDC_BIT)) {
        pc = MemoryRegisters.LCDC_HANDLER_ADDRESS;
        triggeredInterrupts &= ~MemoryRegisters.LCDC_BIT;
      } else if (interruptTriggered(MemoryRegisters.TIMER_OVERFLOW_BIT)) {
        pc = MemoryRegisters.TIMER_OVERFLOW_HANDLER_ADDRESS;
        triggeredInterrupts &= ~MemoryRegisters.TIMER_OVERFLOW_BIT;
      } else if (interruptTriggered(MemoryRegisters.SERIAL_TRANSFER_BIT)) {
        pc = MemoryRegisters.SERIAL_TRANSFER_HANDLER_ADDRESS;
        triggeredInterrupts &= ~MemoryRegisters.SERIAL_TRANSFER_BIT;
      } else if (interruptTriggered(MemoryRegisters.HILO_BIT)) {
        pc = MemoryRegisters.HILO_HANDLER_ADDRESS;
        triggeredInterrupts &= ~MemoryRegisters.HILO_BIT;
      }

      mmu.writeRegisterByte(MemoryRegisters.TRIGGERED_INTERRUPTS, triggeredInterrupts);
    }
  }

  /// Next step in the CPU processing, should be called at a fixed rate.
  void step() {
    execute();

    if (interruptsEnabled) {
      fireInterrupts();
    }
  }

  /// Puts the emulator in and out of double speed mode.
  ///
  /// @param doubleSpeed the new double speed state
  void setDoubleSpeed(bool doubleSpeed) {
    if (this.doubleSpeed != doubleSpeed) {
      this.doubleSpeed = doubleSpeed;
      clockSpeed = this.doubleSpeed ? (FREQUENCY * 2) : FREQUENCY;
    }
  }

  /// Returns a string with debug information on the current status of the CPU.
  ///
  /// Returns the current values of all registers, and a history of the instructions executed by the CPU.
  String getDebugString() {
    String data = 'Registers:\n';
    /* data += 'AF: 0x' + this.registers.af.toRadixString(16) + '\n';
    data += 'BC: 0x' + this.registers.bc.toRadixString(16) + '\n';
    data += 'DE: 0x' + this.registers.de.toRadixString(16) + '\n';
    data += 'HL: 0x' + this.registers.hl.toRadixString(16) + '\n';*/

    data += 'CPU:\n';
    data += 'PC: 0x${pc.toRadixString(16)}\n';
    data += 'SP: 0x${sp.toRadixString(16)}\n';
    data += 'Clocks: $clocks\n';

    return data;
  }

  /// Decode the instruction, execute it, update the CPU timer variables, check for interrupts.
  void execute() {
    if (halted) {
      if (mmu.readRegisterByte(MemoryRegisters.TRIGGERED_INTERRUPTS) == 0) {
        clocks += 4;
      }

      halted = false;
    }

    final int op = nextUnsignedBytePC();

    switch (op) {
      case 0x00:
        Instructions.NOP(this);
      case 0xC4:
      case 0xCC:
      case 0xD4:
      case 0xDC:
        Instructions.CALL_cc_nn(this, op);
      case 0xCD:
        Instructions.CALL_nn(this);
      case 0x01:
      case 0x11:
      case 0x21:
      case 0x31:
        Instructions.LD_dd_nn(this, op);
      case 0x06:
      case 0x0E:
      case 0x16:
      case 0x1E:
      case 0x26:
      case 0x2E:
      case 0x36:
      case 0x3E:
        Instructions.LD_r_n(this, op);
      case 0x0A:
        Instructions.LD_A_BC(this);
      case 0x1A:
        Instructions.LD_A_DE(this);
      case 0x02:
        Instructions.LD_BC_A(this);
      case 0x12:
        Instructions.LD_DE_A(this);
      case 0xF2:
        Instructions.LD_A_C(this);
      case 0xE8:
        Instructions.ADD_SP_n(this);
      case 0x37:
        Instructions.SCF(this);
      case 0x3F:
        Instructions.CCF(this);
      case 0x3A:
        Instructions.LD_A_n(this);
      case 0xEA:
        Instructions.LD_nn_A(this);
      case 0xF8:
        Instructions.LDHL_SP_n(this);
      case 0x2F:
        Instructions.CPL(this);
      case 0xE0:
        Instructions.LD_FFn_A(this);
      case 0xE2:
        Instructions.LDH_FFC_A(this);
      case 0xFA:
        Instructions.LD_A_nn(this);
      case 0x2A:
        Instructions.LD_A_HLI(this);
      case 0x22:
        Instructions.LD_HLI_A(this);
      case 0x32:
        Instructions.LD_HLD_A(this);
      case 0x10:
        Instructions.STOP(this);
      case 0xf9:
        Instructions.LD_SP_HL(this);
      case 0xc5: // BC
      case 0xd5: // DE
      case 0xe5: // HL
      case 0xf5: // AF
        Instructions.PUSH_rr(this, op);
      case 0xc1: // BC
      case 0xd1: // DE
      case 0xe1: // HL
      case 0xf1: // AF
        Instructions.POP_rr(this, op);
      case 0x08:
        Instructions.LD_a16_SP(this);
      case 0xd9:
        Instructions.RETI(this);
      case 0xc3:
        Instructions.JP_nn(this);
      case 0x07:
        Instructions.RLCA(this);
      case 0x3c: // A
      case 0x4: // B
      case 0xc: // C
      case 0x14: // D
      case 0x1c: // E
      case 0x24: // F
      case 0x34: // (HL)
      case 0x2c: // G
        Instructions.INC_r(this, op);
      case 0x3d: // A
      case 0x05: // B
      case 0x0d: // C
      case 0x15: // D
      case 0x1d: // E
      case 0x25: // H
      case 0x2d: // L
      case 0x35: // (HL)
        Instructions.DEC_r(this, op);
      case 0x03:
      case 0x13:
      case 0x23:
      case 0x33:
        Instructions.INC_rr(this, op);
      case 0xb8:
      case 0xb9:
      case 0xba:
      case 0xbb:
      case 0xbc:
      case 0xbd:
      case 0xbe:
      case 0xbf:
        Instructions.CP_rr(this, op);
      case 0xfe:
        Instructions.CP_n(this);
      case 0x09:
      case 0x19:
      case 0x29:
      case 0x39:
        Instructions.ADD_HL_rr(this, op);
      case 0xe9:
        Instructions.JP_HL(this);
      case 0xde:
        Instructions.SBC_n(this);
      case 0xd6:
        Instructions.SUB_n(this);
      case 0x90:
      case 0x91:
      case 0x92:
      case 0x93:
      case 0x94:
      case 0x95:
      case 0x96: // (HL)
      case 0x97:
        Instructions.SUB_r(this, op);
      case 0xc6:
        Instructions.ADD_n(this);
      case 0x87:
      case 0x80:
      case 0x81:
      case 0x82:
      case 0x83:
      case 0x84:
      case 0x85:
      case 0x86: // (HL)
        Instructions.ADD_r(this, op);
      case 0x88:
      case 0x89:
      case 0x8a:
      case 0x8b:
      case 0x8c:
      case 0x8e:
      case 0x8d:
      case 0x8f:
        Instructions.ADC_r(this, op);
      case 0xa0:
      case 0xa1:
      case 0xa2:
      case 0xa3:
      case 0xa4:
      case 0xa5:
      case 0xa6: // (HL)
      case 0xa7:
        Instructions.AND_r(this, op);
      case 0xa8:
      case 0xa9:
      case 0xaa:
      case 0xab:
      case 0xac:
      case 0xad:
      case 0xae:
      case 0xaf:
        Instructions.XOR_r(this, op);
      case 0xf6:
        Instructions.OR_n(this);
      case 0xb0:
      case 0xb1:
      case 0xb2:
      case 0xb3:
      case 0xb4:
      case 0xb5:
      case 0xb6: // (HL)
      case 0xb7:
        Instructions.OR_r(this, op);
      case 0x18:
        Instructions.JR_e(this);
      case 0x27:
        Instructions.DAA(this);
      case 0xca:
      case 0xc2: // NZ
      case 0xd2:
      case 0xda:
        Instructions.JP_c_nn(this, op);
      case 0x20: // NZ
      case 0x28:
      case 0x30:
      case 0x38:
        Instructions.JR_c_e(this, op);
      case 0xf0:
        Instructions.LDH_FFnn(this);
      case 0x76:
        Instructions.HALT(this);
      case 0xc0: // NZ non zero (Z)
      case 0xc8: // Z zero (Z)
      case 0xd0: // NC non carry (C)
      case 0xd8: // Carry (C)
        Instructions.RET_c(this, op);
      case 0xc7:
      case 0xcf:
      case 0xd7:
      case 0xdf:
      case 0xe7:
      case 0xef:
      case 0xf7:
      case 0xFF:
        Instructions.RST_p(this, op);
      case 0xf3:
        Instructions.DI(this);
      case 0xfb:
        Instructions.EI(this);
      case 0xE6:
        Instructions.AND_n(this);
      case 0xEE:
        Instructions.XOR_n(this);
      case 0xc9:
        Instructions.RET(this);
      case 0xce:
        Instructions.ADC_n(this);
      case 0x98:
      case 0x99:
      case 0x9a:
      case 0x9b:
      case 0x9c:
      case 0x9d:
      case 0x9e: // (HL)
      case 0x9f:
        Instructions.SBC_r(this, op);
      case 0x0F: // RRCA
        Instructions.RRCA(this);
      case 0x1f: // RRA
        Instructions.RRA(this);
      case 0x17: // RLA
        Instructions.RLA(this);
      case 0x0b:
      case 0x1b:
      case 0x2b:
      case 0x3b:
        Instructions.DEC_rr(this, op);
      case 0xcb:
        Instructions.CBPrefix(this);
      default:
        switch (op & 0xC0) {
          case 0x40: // LD r, r
            Instructions.LD_r_r(this, op);
          default:
            throw Exception('Unsupported operation, (OP: 0x${op.toRadixString(16)})');
        }
    }
  }
}
