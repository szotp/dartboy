import 'package:dartboy/emulator/cpu/registers.dart';

import 'cpu.dart';
import 'tables.dart';

/// Class to handle instruction implementation, instructions run on top of the CPU object.
///
/// This class is just an abstraction to make the CPU structure cleaner.
class Instructions
{
  static void NOP(CPU cpu){}

  static void CALL_cc_nn(CPU cpu, int op)
  {
    int jmp = (cpu.nextUBytePC()) | (cpu.nextUBytePC() << 8);

    if(cpu.registers.getFlag(0x4 | ((op >> 3) & 0x7)))
    {
      cpu.pushWordSP(cpu.pc);
      cpu.pc = jmp;
      cpu.clocks += 4;
    }
  }

  static void CALL_nn(CPU cpu)
  {
    int jmp = (cpu.nextUBytePC()) | (cpu.nextUBytePC() << 8);
    cpu.pushWordSP(cpu.pc);
    cpu.pc = jmp;
    cpu.clocks += 4;
  }

  static void LD_dd_nn(CPU cpu, int op)
  {
    cpu.setRegisterPairSP((op >> 4) & 0x3, cpu.nextUBytePC() | (cpu.nextUBytePC() << 8));
  }

  static void LD_r_n(CPU cpu, int op)
  {
    int to = (op >> 3) & 0x7;
    int n = cpu.nextUBytePC();
    cpu.registers.setRegister(to, n);
  }

  static void LD_A_BC(CPU cpu)
  {
    cpu.registers.a = cpu.getUByte(cpu.registers.bc);
  }

  static void LD_A_DE(CPU cpu)
  {
    cpu.registers.a = cpu.getUByte(cpu.registers.de);
  }

  static void LD_BC_A(CPU cpu)
  {
    cpu.memory.writeByte(cpu.registers.bc, cpu.registers.a);
  }

  static void LD_DE_A(CPU cpu)
  {
    cpu.memory.writeByte(cpu.registers.de, cpu.registers.a);
  }

  static void LD_A_C(CPU cpu)
  {
    cpu.registers.a = cpu.getUByte(0xFF00 | cpu.registers.c);
  }

  static void ADD_SP_n(CPU cpu)
  {
    int offset = cpu.nextBytePC();
    int nsp = (cpu.sp + offset);

    cpu.registers.f = 0;
    int carry = nsp ^ cpu.sp ^ offset;
    
    if((carry & 0x100) != 0) cpu.registers.f |= Registers.F_CARRY;
    if((carry & 0x10) != 0) cpu.registers.f |= Registers.F_HALF_CARRY;

    nsp &= 0xffff;

    cpu.sp = nsp;
    cpu.clocks += 4;
}

  static void SCF(CPU cpu)
  {
    cpu.registers.f &= Registers.F_ZERO;
    cpu.registers.f |= Registers.F_CARRY;
  }

  static void CCF(CPU cpu)
  {
    cpu.registers.f = (cpu.registers.f & Registers.F_CARRY) != 0 ? (cpu.registers.f & Registers.F_ZERO) : ((cpu.registers.f & Registers.F_ZERO) | Registers.F_CARRY);
  }

  static void LD_A_n(CPU cpu)
  {
    cpu.registers.a = cpu.getUByte(cpu.registers.hl & 0xffff);

    cpu.registers.hl = (cpu.registers.hl - 1) & 0xFFFF;
  }

  static void LD_nn_A(CPU cpu)
  {
    cpu.memory.writeByte(cpu.nextUBytePC() | (cpu.nextUBytePC() << 8), cpu.registers.a);
  }

  static void LDHL_SP_n(CPU cpu)
  {
    int offset = cpu.nextBytePC();
    int nsp = (cpu.sp + offset);

    cpu.registers.f = 0; // (short) (cpu.registers.f & Registers.F_ZERO);
    int carry = nsp ^ cpu.sp ^ offset;

    if((carry & 0x100) != 0) cpu.registers.f |= Registers.F_CARRY;
    if((carry & 0x10) != 0) cpu.registers.f |= Registers.F_HALF_CARRY;

    nsp &= 0xffff;

    cpu.registers.hl =  nsp;
  }

  static void CPL(CPU cpu)
  {
    cpu.registers.a = (~cpu.registers.a) & 0xFF;
    cpu.registers.f = (cpu.registers.f & (Registers.F_CARRY | Registers.F_ZERO)) | Registers.F_HALF_CARRY | Registers.F_SUBTRACT;
  }

  static void LD_FFn_A(CPU cpu)
  {
    cpu.memory.writeByte(0xff00 | cpu.nextUBytePC(), cpu.registers.a);
  }

  static void LDH_FFC_A(CPU cpu)
  {
    cpu.memory.writeByte(0xFF00 | (cpu.registers.c & 0xFF), cpu.registers.a);
  }

  static void LD_A_nn(CPU cpu)
  {
    int nn = cpu.nextUBytePC() | (cpu.nextUBytePC() << 8);
    cpu.registers.a = cpu.getUByte(nn);
  }

  static void LD_A_HLI(CPU cpu)
  {
    cpu.registers.a = cpu.getUByte(cpu.registers.hl & 0xffff);
    cpu.registers.hl =  (cpu.registers.hl + 1) & 0xffff;
  }

  static void LD_HLI_A(CPU cpu)
  {
    cpu.memory.writeByte(cpu.registers.hl & 0xFFFF, cpu.registers.a);
    cpu.registers.hl =  (cpu.registers.hl + 1) & 0xffff;
  }

  static void LD_HLD_A(CPU cpu)
  {
    int hl = cpu.registers.hl;
    cpu.memory.writeByte(hl, cpu.registers.a);
    cpu.registers.hl = (hl - 1) & 0xFFFF;

  }

  static void STOP(CPU cpu)
  {
    return NOP(cpu);
  }

  static void LD_r_r(CPU cpu, int op)
  {
    int from = op & 0x7;
    int to = (op >> 3) & 0x7;

    // important note: getIO(6) fetches (HL)
    cpu.registers.setRegister(to, cpu.registers.getRegister(from) & 0xFF);
  }

  static void CBPrefix(CPU cpu)
  {
    int x = cpu.pc++;
    int cbop = cpu.getUByte(x);
    int r = cbop & 0x7;
    int d = cpu.registers.getRegister(r) & 0xff;

    switch(cbop & 0xC0)
    {
      case 0x80:
        {
          // RES b, r
          // 1 0 b b b r r r
          cpu.registers.setRegister(r, d & ~(0x1 << (cbop >> 3 & 0x7)));
          return;
        }
      case 0xc0:
        {
          // SET b, r
          // 1 1 b b b r r r
          cpu.registers.setRegister(r, d | (0x1 << (cbop >> 3 & 0x7)));
          return;
        }
      case 0x40:
        {
          // BIT b, r
          // 0 1 b b b r r r
          cpu.registers.f &= Registers.F_CARRY;
          cpu.registers.f |= Registers.F_HALF_CARRY;
          if((d & (0x1 << (cbop >> 3 & 0x7))) == 0) cpu.registers.f |= Registers.F_ZERO;
          return;
        }
      case 0x0:
        {
          switch(cbop & 0xf8)
          {
            case 0x00: // RLcpu.registers.c m
              {
                cpu.registers.f = 0;
                if((d & 0x80) != 0) cpu.registers.f |= Registers.F_CARRY;
                d <<= 1;

                // we're shifting circular left, add back bit 7
                if((cpu.registers.f & Registers.F_CARRY) != 0) d |= 0x01;
                d &= 0xff;
                if(d == 0) cpu.registers.f |= Registers.F_ZERO;
                cpu.registers.setRegister(r, d);
                return;
              }
            case 0x08: // RRcpu.registers.c m
              {
                cpu.registers.f = 0;
                if((d & 0x1) != 0) cpu.registers.f |= Registers.F_CARRY;
                d >>= 1;

                // we're shifting circular right, add back bit 7
                if((cpu.registers.f & Registers.F_CARRY) != 0) d |= 0x80;
                d &= 0xff;
                if(d == 0) cpu.registers.f |= Registers.F_ZERO;
                cpu.registers.setRegister(r, d);
                return;
              }
            case 0x10: // Rcpu.registers.l m
              {
                bool carryflag = (cpu.registers.f & Registers.F_CARRY) != 0;
                cpu.registers.f = 0;

                // we'll be shifting left, so if bit 7 is set we set carry
                if((d & 0x80) == 0x80) cpu.registers.f |= Registers.F_CARRY;
                d <<= 1;
                d &= 0xff;

                // move old cpu.registers.c into bit 0
                if(carryflag) d |= 0x1;
                if(d == 0) cpu.registers.f |= Registers.F_ZERO;
                cpu.registers.setRegister(r, d);
                return;
              }
            case 0x18: // RR m
              {
                bool carryflag = (cpu.registers.f & Registers.F_CARRY) != 0;
                cpu.registers.f = 0;

                // we'll be shifting right, so if bit 1 is set we set carry
                if((d & 0x1) == 0x1) cpu.registers.f |= Registers.F_CARRY;
                d >>= 1;

                // move old cpu.registers.c into bit 7
                if(carryflag) d |= 0x80;

                if(d == 0) cpu.registers.f |= Registers.F_ZERO;
                
                cpu.registers.setRegister(r, d);
                
                return;
              }
            case 0x38: // SRcpu.registers.l m
              {
                cpu.registers.f = 0;

                // we'll be shifting right, so if bit 1 is set we set carry
                if((d & 0x1) != 0) cpu.registers.f |= Registers.F_CARRY;
                d >>= 1;
                if(d == 0) cpu.registers.f |= Registers.F_ZERO;
                cpu.registers.setRegister(r, d);
                return;
              }
            case 0x20: // SLcpu.registers.a m
              {
                cpu.registers.f = 0;

                // we'll be shifting right, so if bit 1 is set we set carry
                if((d & 0x80) != 0) cpu.registers.f |= Registers.F_CARRY;
                d <<= 1;
                d &= 0xff;
                if(d == 0) cpu.registers.f |= Registers.F_ZERO;
                cpu.registers.setRegister(r, d);
                return;
              }
            case 0x28: // SRcpu.registers.a m
              {
                bool bit7 = (d & 0x80) != 0;
                cpu.registers.f = 0;
                if((d & 0x1) != 0) cpu.registers.f |= Registers.F_CARRY;
                d >>= 1;
                if(bit7) d |= 0x80;
                if(d == 0) cpu.registers.f |= Registers.F_ZERO;
                cpu.registers.setRegister(r, d);
                return;
              }
            case 0x30: // SWAP m
              {
                d = ((d & 0xF0) >> 4) | ((d & 0x0F) << 4);
                cpu.registers.f = d == 0 ? Registers.F_ZERO : 0;
                cpu.registers.setRegister(r, d);
                return;
              }
            default:
              throw new Exception("cb-&f8-" + cbop.toRadixString(16));
          }
          break;
        }
      default:
        throw new Exception("cb-" + cbop.toRadixString(16));
    }
  }

  static void DEC_rr(CPU cpu, int op)
  {
    int p = (op >> 4) & 0x3;
    int o = cpu.getRegisterPairSP(p);
    cpu.setRegisterPairSP(p, o - 1);
  }

  static void RLA(CPU cpu)
  {
    bool carryflag = (cpu.registers.f & Registers.F_CARRY) != 0;
    cpu.registers.f = 0; // &= Registers.F_ZERO;?

    // we'll be shifting left, so if bit 7 is set we set carry
    if((cpu.registers.a & 0x80) == 0x80)
    {
      cpu.registers.f |= Registers.F_CARRY;
    }
    cpu.registers.a <<= 1;
    cpu.registers.a &= 0xff;

    // move old cpu.registers.c into bit 0
    if(carryflag)
    {
      cpu.registers.a |= 1;
    }
  }

  static void RRA(CPU cpu)
  {
    bool carryflag = (cpu.registers.f & Registers.F_CARRY) != 0;
    cpu.registers.f = 0;

    // we'll be shifting right, so if bit 1 is set we set carry
    if((cpu.registers.a & 0x1) == 0x1)
    {
      cpu.registers.f |= Registers.F_CARRY;
    }
    cpu.registers.a >>= 1;

    // move old cpu.registers.c into bit 7
    if(carryflag){cpu.registers.a |= 0x80;}
  }

  static void RRCA(CPU cpu)
  {
    cpu.registers.f = 0;//Registers.F_ZERO;
    if((cpu.registers.a & 0x1) == 0x1)
    {
      cpu.registers.f |= Registers.F_CARRY;
    }
    cpu.registers.a >>= 1;

    // we're shifting circular right, add back bit 7
    if((cpu.registers.f & Registers.F_CARRY) != 0)
    {
      cpu.registers.a |= 0x80;
    }
  }

  static void SBC_r(CPU cpu, int op)
  {
    int carry = (cpu.registers.f & Registers.F_CARRY) != 0 ? 1 : 0;
    int reg = cpu.registers.getRegister(op & 0x7) & 0xff;

    cpu.registers.f = Registers.F_SUBTRACT;
    if((cpu.registers.a & 0x0f) - (reg & 0x0f) - carry < 0)
    {
      cpu.registers.f |= Registers.F_HALF_CARRY;
    }

    cpu.registers.a -= reg + carry;
    if(cpu.registers.a < 0)
    {
      cpu.registers.f |= Registers.F_CARRY;
      cpu.registers.a &= 0xFF;
    }

    if(cpu.registers.a == 0)
    {
      cpu.registers.f |= Registers.F_ZERO;
    }
  }

  static void ADC_n(CPU cpu)
  {
    int val = cpu.nextUBytePC();
    int carry = ((cpu.registers.f & Registers.F_CARRY) != 0 ? 1 : 0);
    int n = val + carry;

    cpu.registers.f = 0;
    if((((cpu.registers.a & 0xf) + (val & 0xf)) + carry & 0xF0) != 0) cpu.registers.f |= Registers.F_HALF_CARRY;
    cpu.registers.a += n;
    if(cpu.registers.a > 0xFF)
    {
      cpu.registers.f |= Registers.F_CARRY;
      cpu.registers.a &= 0xFF;
    }
    if(cpu.registers.a == 0){cpu.registers.f |= Registers.F_ZERO;}
  }

  static void RET(CPU cpu)
  {
    cpu.pc = (cpu.getUByte(cpu.sp + 1) << 8) | cpu.getUByte(cpu.sp);
    cpu.sp += 2;
    cpu.clocks += 4;
}

  static void XOR_n(CPU cpu)
  {
    cpu.registers.a ^= cpu.nextUBytePC();
    cpu.registers.f = 0;
    if(cpu.registers.a == 0)
    {
      cpu.registers.f |= Registers.F_ZERO;
    }
  }

  static void AND_n(CPU cpu)
  {
    cpu.registers.a &= cpu.nextUBytePC();
    cpu.registers.f = Registers.F_HALF_CARRY;
    if(cpu.registers.a == 0)
    {
      cpu.registers.f |= Registers.F_ZERO;
    }
  }

  static void EI(CPU cpu)
  {
    cpu.interruptsEnabled = true;

    // Note that during the execution of this instruction and the following instruction, maskable interrupts are disabled.
    cpu.tick(4);

    cpu.execute();
  }

  static void DI(CPU cpu)
  {
    cpu.interruptsEnabled = false;
  }

  static void RST_p(CPU cpu, int op)
  {
    cpu.pushWordSP(cpu.pc);
    cpu.pc = op & 0x38;
    cpu.clocks += 4;
}

  static void RET_c(CPU cpu, int op)
  {
    if(cpu.registers.getFlag(0x4 | ((op >> 3) & 0x7)))
    {
      cpu.pc = (cpu.getUByte(cpu.sp + 1) << 8) | cpu.getUByte(cpu.sp);
      cpu.sp += 2;
    }
    cpu.clocks += 4;
}

  static void HALT(CPU cpu)
  {
    cpu.halted = true;
  }

  static void LDH_FFnn(CPU cpu)
  {
    cpu.registers.a = cpu.getUByte(0xFF00 | cpu.nextUBytePC());
  }

  static void JR_c_e(CPU cpu, int op)
  {
    int e = cpu.nextBytePC();

    if(cpu.registers.getFlag((op >> 3) & 0x7))
    {
      cpu.pc += e;
      cpu.clocks += 4;
    }
  }

  static void JP_c_nn(CPU cpu, int op)
  {
    int npc = cpu.nextUBytePC() | (cpu.nextUBytePC() << 8);

    if(cpu.registers.getFlag(0x4 | ((op >> 3) & 0x7)))
    {
      cpu.pc = npc;
      cpu.clocks += 4;
    }
  }

  static void DAA(CPU cpu)
  {
    // TODO warning: this might be implemented wrong!
    /**
     * <code><pre>tmp := a,
     * if nf then
     *      if hf or [a ANcpu.registers.d 0x0f > 9] then tmp -= 0x06
     *      if cf or [a > 0x99] then tmp -= 0x60
     * else
     *      if hf or [a ANcpu.registers.d 0x0f > 9] then tmp += 0x06
     *      if cf or [a > 0x99] then tmp += 0x60
     * endif,
     * tmp => flags, cf := cf OR [a > 0x99],
     * hf := a.4 XOR tmp.4, a := tmp
     * </pre>
     * </code>
     * @see http://wikiti.brandonw.net/?title=Z80_Instruction_Set
     */
    
    int tmp = cpu.registers.a;

    if((cpu.registers.f & Registers.F_SUBTRACT) == 0)
    {
      if((cpu.registers.f & Registers.F_HALF_CARRY) != 0 || ((tmp & 0x0f) > 9))
      {
        tmp += 0x06;
      }
      if((cpu.registers.f & Registers.F_CARRY) != 0 || ((tmp > 0x9f)))
      {
        tmp += 0x60;
      }
    }
    else
    {
      if((cpu.registers.f & Registers.F_HALF_CARRY) != 0)
      {
        tmp = ((tmp - 6) & 0xff);
      }
      if((cpu.registers.f & Registers.F_CARRY) != 0)
      {
        tmp -= 0x60;
      }
    }

    cpu.registers.f &= Registers.F_SUBTRACT | Registers.F_CARRY;

    if(tmp > 0xff)
    {
      cpu.registers.f |= Registers.F_CARRY;
      tmp &= 0xff;
    }

    if(tmp == 0){cpu.registers.f |= Registers.F_ZERO;}

    cpu.registers.a = tmp;
  }

  static void JR_e(CPU cpu)
  {
    int e = cpu.nextBytePC();
    cpu.pc += e;
    cpu.clocks += 4;
}

  static void OR(CPU cpu, int n)
  {
    cpu.registers.a |= n;
    cpu.registers.f = 0;
    if(cpu.registers.a == 0){cpu.registers.f |= Registers.F_ZERO;}
  }

  static void OR_r(CPU cpu, int op)
  {
    OR(cpu, cpu.registers.getRegister(op & 0x7) & 0xff);
  }

  static void OR_n(CPU cpu)
  {
    int n = cpu.nextUBytePC();
    OR(cpu, n);
  }

  static void XOR_r(CPU cpu, int op)
  {
    cpu.registers.a = (cpu.registers.a ^ cpu.registers.getRegister(op & 0x7)) & 0xff;
    cpu.registers.f = 0;
    if(cpu.registers.a == 0){cpu.registers.f |= Registers.F_ZERO;}
  }

  static void AND_r(CPU cpu, int op)
  {
    cpu.registers.a = (cpu.registers.a & cpu.registers.getRegister(op & 0x7)) & 0xff;
    cpu.registers.f = Registers.F_HALF_CARRY;
    if(cpu.registers.a == 0) cpu.registers.f |= Registers.F_ZERO;
  }

  static void ADC_r(CPU cpu, int op)
  {
    int carry = ((cpu.registers.f & Registers.F_CARRY) != 0 ? 1 : 0);
    int reg = (cpu.registers.getRegister(op & 0x7) & 0xff);

    int d = carry + reg;
    cpu.registers.f = 0;
    if((((cpu.registers.a & 0xf) + (reg & 0xf) + carry) & 0xF0) != 0){cpu.registers.f |= Registers.F_HALF_CARRY;}

    cpu.registers.a += d;
    if(cpu.registers.a > 0xFF)
    {
      cpu.registers.f |= Registers.F_CARRY;
      cpu.registers.a &= 0xFF;
    }
    if(cpu.registers.a == 0){cpu.registers.f |= Registers.F_ZERO;}
  }

  static void ADD(CPU cpu, int n)
  {
    cpu.registers.f = 0;
    if((((cpu.registers.a & 0xf) + (n & 0xf)) & 0xF0) != 0){cpu.registers.f |= Registers.F_HALF_CARRY;}

    cpu.registers.a += n;
    if(cpu.registers.a > 0xFF)
    {
      cpu.registers.f |= Registers.F_CARRY;
      cpu.registers.a &= 0xFF;
    }

    if(cpu.registers.a == 0){cpu.registers.f |= Registers.F_ZERO;}
  }

  static void ADD_r(CPU cpu, int op)
  {
    int n = cpu.registers.getRegister(op & 0x7) & 0xff;
    ADD(cpu, n);
  }

  static void ADD_n(CPU cpu)
  {
    int n = cpu.nextUBytePC();
    ADD(cpu, n);
  }

  static void SUB(CPU cpu, int n)
  {
    cpu.registers.f = Registers.F_SUBTRACT;
    if((cpu.registers.a & 0xf) - (n & 0xf) < 0){cpu.registers.f |= Registers.F_HALF_CARRY;}

    cpu.registers.a -= n;
    if((cpu.registers.a & 0xFF00) != 0){cpu.registers.f |= Registers.F_CARRY;}

    cpu.registers.a &= 0xFF;
    if(cpu.registers.a == 0){cpu.registers.f |= Registers.F_ZERO;}
  }

  static void SUB_r(CPU cpu, int op)
  {
    int n = cpu.registers.getRegister(op & 0x7) & 0xff;
    SUB(cpu, n);
  }

  static void SUB_n(CPU cpu)
  {
    int n = cpu.nextUBytePC();
    SUB(cpu, n);
  }

  static void SBC_n(CPU cpu)
  {
    int val = cpu.nextUBytePC();
    int carry = ((cpu.registers.f & Registers.F_CARRY) != 0 ? 1 : 0);
    int n = val + carry;

    cpu.registers.f = Registers.F_SUBTRACT;

    if((cpu.registers.a & 0xf) - (val & 0xf) - carry < 0){cpu.registers.f |= Registers.F_HALF_CARRY;}

    cpu.registers.a -= n;
    if(cpu.registers.a < 0)
    {
      cpu.registers.f |= Registers.F_CARRY;
      cpu.registers.a &= 0xff;
    }
    if(cpu.registers.a == 0) cpu.registers.f |= Registers.F_ZERO;
  }

  static void JP_HL(CPU cpu)
  {
    cpu.pc = cpu.registers.hl & 0xFFFF;
  }

  static void ADD_HL_rr(CPU cpu, int op)
  {
    /**
     * Z is not affected
     * cpu.registers.h is set if carry out of bit 11; reset otherwise
     * N is reset
     * cpu.registers.c is set if carry from bit 15; reset otherwise
     */
    int ss = cpu.getRegisterPairSP((op >> 4) & 0x3);
    int hl = cpu.registers.hl;

    cpu.registers.f &= Registers.F_ZERO;

    if(((hl & 0xFFF) + (ss & 0xFFF)) > 0xFFF)
    {
      cpu.registers.f |= Registers.F_HALF_CARRY;
    }

    hl += ss;

    if(hl > 0xFFFF)
    {
      cpu.registers.f |= Registers.F_CARRY;
      hl &= 0xFFFF;
    }

    cpu.registers.hl =  hl;
  }

  static void CP(CPU cpu, int n)
  {
    cpu.registers.f = Registers.F_SUBTRACT;

    if(cpu.registers.a < n){cpu.registers.f |= Registers.F_CARRY;}
    if(cpu.registers.a == n){cpu.registers.f |= Registers.F_ZERO;}
    if((cpu.registers.a & 0xf) < ((cpu.registers.a - n) & 0xf)){cpu.registers.f |= Registers.F_HALF_CARRY;}
  }

  static void CP_n(CPU cpu)
  {
    int n = cpu.nextUBytePC();
    CP(cpu, n);
  }

  static void CP_rr(CPU cpu, int op)
  {
    int n = cpu.registers.getRegister(op & 0x7) & 0xFF;
    CP(cpu, n);
  }

  static void INC_rr(CPU cpu, int op)
  {
    int pair = (op >> 4) & 0x3;
    int o = cpu.getRegisterPairSP(pair) & 0xffff;
    cpu.setRegisterPairSP(pair, o + 1);
  }

  static void DEC_r(CPU cpu, int op)
  {
    int reg = (op >> 3) & 0x7;
    int a = cpu.registers.getRegister(reg) & 0xff;

    cpu.registers.f = (cpu.registers.f & Registers.F_CARRY) | Tables.DEC[a];

    a = (a - 1) & 0xff;

    cpu.registers.setRegister(reg, a);
  }

  static void INC_r(CPU cpu, int op)
  {
    int reg = (op >> 3) & 0x7;
    int a = cpu.registers.getRegister(reg) & 0xff;

    cpu.registers.f = (cpu.registers.f & Registers.F_CARRY) | Tables.INC[a];

    a = (a + 1) & 0xff;

    cpu.registers.setRegister(reg, a);
  }

  static void RLCA(CPU cpu)
  {
    bool carry = (cpu.registers.a & 0x80) != 0;
    cpu.registers.a <<= 1;
    cpu.registers.f = 0; // &= Registers.F_ZERO?

    if(carry)
    {
      cpu.registers.f |= Registers.F_CARRY;
      cpu.registers.a |= 1;
    } else cpu.registers.f = 0;

    cpu.registers.a &= 0xff;
  }

  static void JP_nn(CPU cpu)
  {
    cpu.pc = (cpu.nextUBytePC()) | (cpu.nextUBytePC() << 8);
    cpu.clocks += 4;
  }

  static void RETI(CPU cpu)
  {
    cpu.interruptsEnabled = true;
    cpu.pc = (cpu.getUByte(cpu.sp + 1) << 8) | cpu.getUByte(cpu.sp);
    cpu.sp += 2;
    cpu.clocks += 4;
  }

  static void LD_a16_SP(CPU cpu)
  {
    int pos = ((cpu.nextUBytePC()) | (cpu.nextUBytePC() << 8));
    cpu.memory.writeByte(pos + 1, (cpu.sp & 0xFF00) >> 8);
    cpu.memory.writeByte(pos, (cpu.sp & 0x00FF));
  }

  static void POP_rr(CPU cpu, int op)
  {
    cpu.registers.setRegisterPair((op >> 4) & 0x3, cpu.getByte(cpu.sp + 1), lo: cpu.getByte(cpu.sp));
    cpu.sp += 2;
  }

  static void PUSH_rr(CPU cpu, int op)
  {
    int val = cpu.registers.getRegisterPair((op >> 4) & 0x3);
    cpu.pushWordSP(val);
    cpu.clocks += 4;
  }
}