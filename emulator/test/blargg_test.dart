import 'dart:io';

import 'package:emulator/configuration.dart';
import 'package:emulator/cpu/cpu.dart';
import 'package:emulator/memory/cartridge.dart';
import 'package:test/test.dart';

import 'utils.dart';

void runRomTest(String relativePath) {
  final rom = File('test/gb-test-roms/$relativePath').readAsBytesSync();
  final emulator = CPU(Cartridge(rom), Configuration());
  bool? result;
  int i = 0;

  final output = <String>[];

  emulator.configuration.setSerialPortHandler((x) {
    if (x.startsWith("Failed")) {
      result = false;
    }
    if (x.startsWith("Passed")) {
      result = true;
    }
    output.add(x);
  });

  for (i = 0; i < 100_000_000 && result == null; i++) {
    emulator.step();
  }

  if (result == null) {
    fail("Timeout");
  }

  if (result == false) {
    fail(output.last);
  }
}

void main() {
  group('cgb_sound', () {
    test("cgb_sound/cgb_sound.gb", () => runRomTest("cgb_sound/cgb_sound.gb"));
    test("cgb_sound/rom_singles/01-registers.gb", () => runRomTest("cgb_sound/rom_singles/01-registers.gb"));
    test("cgb_sound/rom_singles/02-len ctr.gb", () => runRomTest("cgb_sound/rom_singles/02-len ctr.gb"));
    test("cgb_sound/rom_singles/03-trigger.gb", () => runRomTest("cgb_sound/rom_singles/03-trigger.gb"));
    test("cgb_sound/rom_singles/04-sweep.gb", () => runRomTest("cgb_sound/rom_singles/04-sweep.gb"));
    test("cgb_sound/rom_singles/05-sweep details.gb", () => runRomTest("cgb_sound/rom_singles/05-sweep details.gb"));
    test("cgb_sound/rom_singles/06-overflow on trigger.gb", () => runRomTest("cgb_sound/rom_singles/06-overflow on trigger.gb"));
    test("cgb_sound/rom_singles/07-len sweep period sync.gb", () => runRomTest("cgb_sound/rom_singles/07-len sweep period sync.gb"));
    test("cgb_sound/rom_singles/08-len ctr during power.gb", () => runRomTest("cgb_sound/rom_singles/08-len ctr during power.gb"));
    test("cgb_sound/rom_singles/09-wave read while on.gb", () => runRomTest("cgb_sound/rom_singles/09-wave read while on.gb"));
    test("cgb_sound/rom_singles/10-wave trigger while on.gb", () => runRomTest("cgb_sound/rom_singles/10-wave trigger while on.gb"));
    test("cgb_sound/rom_singles/11-regs after power.gb", () => runRomTest("cgb_sound/rom_singles/11-regs after power.gb"));
    test("cgb_sound/rom_singles/12-wave.gb", () => runRomTest("cgb_sound/rom_singles/12-wave.gb"));
  });

  group('cpu_instrs', () {
    test("cpu_instrs/cpu_instrs.gb", () => runRomTest("cpu_instrs/cpu_instrs.gb"));
    test("cpu_instrs/individual/01-special.gb", () => runRomTest("cpu_instrs/individual/01-special.gb"));
    test("cpu_instrs/individual/02-interrupts.gb", () => runRomTest("cpu_instrs/individual/02-interrupts.gb"));
    test("cpu_instrs/individual/03-op sp,hl.gb", () => runRomTest("cpu_instrs/individual/03-op sp,hl.gb"));
    test("cpu_instrs/individual/04-op r,imm.gb", () => runRomTest("cpu_instrs/individual/04-op r,imm.gb"));
    test("cpu_instrs/individual/05-op rp.gb", () => runRomTest("cpu_instrs/individual/05-op rp.gb"));
    test("cpu_instrs/individual/06-ld r,r.gb", () => runRomTest("cpu_instrs/individual/06-ld r,r.gb"));
    test("cpu_instrs/individual/07-jr,jp,call,ret,rst.gb", () => runRomTest("cpu_instrs/individual/07-jr,jp,call,ret,rst.gb"));
    test("cpu_instrs/individual/08-misc instrs.gb", () => runRomTest("cpu_instrs/individual/08-misc instrs.gb"));
    test("cpu_instrs/individual/09-op r,r.gb", () => runRomTest("cpu_instrs/individual/09-op r,r.gb"));
    test("cpu_instrs/individual/10-bit ops.gb", () => runRomTest("cpu_instrs/individual/10-bit ops.gb"));
    test("cpu_instrs/individual/11-op a,(hl).gb", () => runRomTest("cpu_instrs/individual/11-op a,(hl).gb"));
  });

  test("dmg_sound", () {
    test("dmg_sound/dmg_sound.gb", () => runRomTest("dmg_sound/dmg_sound.gb"));
    test("dmg_sound/rom_singles/01-registers.gb", () => runRomTest("dmg_sound/rom_singles/01-registers.gb"));
    test("dmg_sound/rom_singles/02-len ctr.gb", () => runRomTest("dmg_sound/rom_singles/02-len ctr.gb"));
    test("dmg_sound/rom_singles/03-trigger.gb", () => runRomTest("dmg_sound/rom_singles/03-trigger.gb"));
    test("dmg_sound/rom_singles/04-sweep.gb", () => runRomTest("dmg_sound/rom_singles/04-sweep.gb"));
    test("dmg_sound/rom_singles/05-sweep details.gb", () => runRomTest("dmg_sound/rom_singles/05-sweep details.gb"));
    test("dmg_sound/rom_singles/06-overflow on trigger.gb", () => runRomTest("dmg_sound/rom_singles/06-overflow on trigger.gb"));
    test("dmg_sound/rom_singles/07-len sweep period sync.gb", () => runRomTest("dmg_sound/rom_singles/07-len sweep period sync.gb"));
    test("dmg_sound/rom_singles/08-len ctr during power.gb", () => runRomTest("dmg_sound/rom_singles/08-len ctr during power.gb"));
    test("dmg_sound/rom_singles/09-wave read while on.gb", () => runRomTest("dmg_sound/rom_singles/09-wave read while on.gb"));
    test("dmg_sound/rom_singles/10-wave trigger while on.gb", () => runRomTest("dmg_sound/rom_singles/10-wave trigger while on.gb"));
    test("dmg_sound/rom_singles/11-regs after power.gb", () => runRomTest("dmg_sound/rom_singles/11-regs after power.gb"));
    test("dmg_sound/rom_singles/12-wave write while on.gb", () => runRomTest("dmg_sound/rom_singles/12-wave write while on.gb"));
  });

  group("mem_timing", () {
    test("mem_timing-2/mem_timing.gb", () => runRomTest("mem_timing-2/mem_timing.gb"));
    test("mem_timing-2/rom_singles/01-read_timing.gb", () => runRomTest("mem_timing-2/rom_singles/01-read_timing.gb"));
    test("mem_timing-2/rom_singles/02-write_timing.gb", () => runRomTest("mem_timing-2/rom_singles/02-write_timing.gb"));
    test("mem_timing-2/rom_singles/03-modify_timing.gb", () => runRomTest("mem_timing-2/rom_singles/03-modify_timing.gb"));
    test("mem_timing/individual/01-read_timing.gb", () => runRomTest("mem_timing/individual/01-read_timing.gb"));
    test("mem_timing/individual/02-write_timing.gb", () => runRomTest("mem_timing/individual/02-write_timing.gb"));
    test("mem_timing/individual/03-modify_timing.gb", () => runRomTest("mem_timing/individual/03-modify_timing.gb"));
    test("mem_timing/mem_timing.gb", () => runRomTest("mem_timing/mem_timing.gb"));
  });

  group("oam_bug", () {
    test("oam_bug/oam_bug.gb", () => runRomTest("oam_bug/oam_bug.gb"));
    test("oam_bug/rom_singles/1-lcd_sync.gb", () => runRomTest("oam_bug/rom_singles/1-lcd_sync.gb"));
    test("oam_bug/rom_singles/2-causes.gb", () => runRomTest("oam_bug/rom_singles/2-causes.gb"));
    test("oam_bug/rom_singles/3-non_causes.gb", () => runRomTest("oam_bug/rom_singles/3-non_causes.gb"));
    test("oam_bug/rom_singles/4-scanline_timing.gb", () => runRomTest("oam_bug/rom_singles/4-scanline_timing.gb"));
    test("oam_bug/rom_singles/5-timing_bug.gb", () => runRomTest("oam_bug/rom_singles/5-timing_bug.gb"));
    test("oam_bug/rom_singles/6-timing_no_bug.gb", () => runRomTest("oam_bug/rom_singles/6-timing_no_bug.gb"));
    test("oam_bug/rom_singles/7-timing_effect.gb", () => runRomTest("oam_bug/rom_singles/7-timing_effect.gb"));
    test("oam_bug/rom_singles/8-instr_effect.gb", () => runRomTest("oam_bug/rom_singles/8-instr_effect.gb"));
  });

  group("misc", () {
    test("halt_bug.gb", () => runRomTest("halt_bug.gb"));
    test("instr_timing/instr_timing.gb", () => runRomTest("instr_timing/instr_timing.gb"));
    test("interrupt_time/interrupt_time.gb", () => runRomTest("interrupt_time/interrupt_time.gb"));
  });
}
