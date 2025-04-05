import '../configuration.dart';
import '../cpu/cpu.dart';
import '../memory/cartridge.dart';
import '../memory/memory_addresses.dart';
import '../memory/memory_registers.dart';
import 'palette.dart';
import 'palette_colors.dart';

typedef NotifyListeners = void Function();

/// LCD class handles all the screen drawing tasks.
///
/// Is responsible for managing the sprites and background layers.
class PPU {
  /// Width in pixels of the physical gameboy LCD.
  static const int LCD_WIDTH = 160;

  /// Height in pixels of the physical gameboy LCD.
  static const int LCD_HEIGHT = 144;

  NotifyListeners? notifyListeners;

  /// Draw layer priority constants.
  ///
  /// We can only draw over pixels with equal or greater priority.
  static const int P_0 = 0 << 24;
  static const int P_1 = 1 << 24;
  static const int P_2 = 2 << 24;
  static const int P_3 = 3 << 24;
  static const int P_4 = 4 << 24;
  static const int P_5 = 5 << 24;
  static const int P_6 = 6 << 24;

  /// The Emulator on which to operate.
  CPU cpu;

  /// A buffer to hold the current rendered frame that can be directly copied to the canvas on the widget.
  ///
  /// Each position stores RGB encoded color value. The data is stored by rows.
  late List<int> buffer;

  /// Current rendered image to be displayed on screen.
  ///
  /// This buffer is swapped with the main drawing buffer.
  late List<int> current;

  /// Background palettes. On CGB, 0-7 are used. On GB, only 0 is used.
  late List<Palette> bgPalettes;

  /// Sprite palettes. 0-7 used on CGB, 0-1 used on GB.
  late List<Palette> spritePalettes;

  /// Background palette memory on the CGB, indexed through $FF69.
  late List<int> gbcBackgroundPaletteMemory;

  /// Sprite palette memory on the CGB, indexed through $FF6B.
  late List<int> gbcSpritePaletteMemory;

  /// Stores number of sprites drawn per each of the 144 scanlines this frame.
  ///
  /// Actual Gameboy hardware can only draw 10 sprites/line, so we artificially introduce this limitation using this array.
  late List<int> spritesDrawnPerLine;

  /// A counter for the number of cycles elapsed since the last LCD event.
  int lcdCycles = 0;

  /// Accumulator for how many VBlanks have been performed since the last reset.
  int currentVBlankCount = 0;

  /// The timestamp of the last second, in nanoseconds.
  int lastSecondTime = 0;

  /// The last measured Emulator.cycle.
  int lastCoreCycle = 0;

  PPU(this.cpu);

  /// Initializes all palette RAM to the default on Gameboy boot.
  void reset() {
    lcdCycles = 0;
    currentVBlankCount = 0;
    lastSecondTime = -1;

    bgPalettes = List<Palette>.filled(8, FakePalette());
    spritePalettes = List<Palette>.filled(8, FakePalette());
    gbcBackgroundPaletteMemory = List<int>.filled(0x40, 0);

    buffer = List<int>.filled(PPU.LCD_WIDTH * PPU.LCD_HEIGHT, 0);
    buffer.fillRange(0, buffer.length, 0);

    current = List<int>.filled(PPU.LCD_WIDTH * PPU.LCD_HEIGHT, 0);
    current.fillRange(0, current.length, 0);

    gbcSpritePaletteMemory = List<int>.filled(0x40, 0);
    gbcSpritePaletteMemory.fillRange(0, gbcSpritePaletteMemory.length, 0);

    spritesDrawnPerLine = List<int>.filled(PPU.LCD_HEIGHT, 0);
    spritesDrawnPerLine.fillRange(0, spritesDrawnPerLine.length, 0);

    if (cpu.cartridge.gameboyType == GameboyType.COLOR) {
      gbcBackgroundPaletteMemory.fillRange(0, gbcBackgroundPaletteMemory.length, 0x1f);

      for (int i = 0; i < spritePalettes.length; i++) {
        List<int> colors = List<int>.filled(4, 0);
        colors.fillRange(0, 4, 0);
        spritePalettes[i] = GBCPalette(colors);
      }

      for (int i = 0; i < bgPalettes.length; i++) {
        List<int> colors = List<int>.filled(4, 0);
        colors.fillRange(0, 4, 0);
        bgPalettes[i] = GBCPalette(colors);
      }

      // Load palettes from RAM
      loadPalettesFromMemory(gbcSpritePaletteMemory, spritePalettes);
      loadPalettesFromMemory(gbcBackgroundPaletteMemory, bgPalettes);
    } else {
      // Classic gameboy background palette data only
      // Initially all background colors are initialized as white.
      PaletteColors colors = PaletteColors.getByHash(cpu.cartridge.checksum);

      bgPalettes[0] = GBPalette(cpu, colors.bg, MemoryRegisters.BGP);
      spritePalettes[0] = GBPalette(cpu, colors.obj0, MemoryRegisters.OBP0);
      spritePalettes[1] = GBPalette(cpu, colors.obj1, MemoryRegisters.OBP1);
    }
  }

  /// Reloads all Gameboy Color palettes.
  ///
  /// @param from Palette RAM to load from.
  /// @param to Reference to an array of Palettes to populate.
  void loadPalettesFromMemory(List<int> from, List<Palette> to) {
    // 8 palettes
    for (int i = 0; i < 8; i++) {
      // 4 ints per palette
      for (int j = 0; j < 4; ++j) {
        updatePalette(from, to[i], i, j);
      }
    }
  }

  /// Performs an update to a int of palette RAM, the colors are stored in two bytes as:
  /// Bit 0-4 Red Intensity (00-1F)
  /// Bit 5-9 Green Intensity (00-1F)
  /// Bit 10-14 Blue Intensity (00-1F)
  ///
  /// @param from The palette RAM to read from.
  /// @param to Reference to an array of Palettes to update.
  /// @param i The palette index being updated.
  /// @param j The int index of the palette being updated.
  void updatePalette(List<int> from, Palette to, int i, int j) {
    // Read an RGB value from RAM
    int data = ((from[i * 8 + j * 2 + 1] & 0xff) << 8) | (from[i * 8 + j * 2] & 0xff);

    // Extract components
    int red = (data & 0x1f);
    int green = (data >> 5) & 0x1f;
    int blue = (data >> 10) & 0x1f;

    int r = ((red / 31.0 * 255 + 0.5).toInt() & 0xFF) << 16;
    int g = ((green / 31.0 * 255 + 0.5).toInt() & 0xFF) << 8;
    int b = (blue / 31.0 * 255 + 0.5).toInt() & 0xFF;

    // Convert from [0, 1Fh] to [0, FFh], and recombine
    to.colors[j] = (r | g | b);
  }

  /// Updates an entry of background palette RAM. Internal function for use in a Memory controller.
  ///
  /// @param reg  The register written to.
  /// @param data The data written.
  void setBackgroundPalette(int reg, int data) {
    gbcBackgroundPaletteMemory[reg] = data;

    int palette = reg >> 3;
    updatePalette(gbcBackgroundPaletteMemory, bgPalettes[palette], palette, (reg >> 1) & 0x3);
  }

  /// Updates an entry of sprite palette RAM. Internal function for use in a Memory controller.
  ///
  /// @param reg  The register written to.
  /// @param data The data written.
  void setSpritePalette(int reg, int data) {
    gbcSpritePaletteMemory[reg] = data;

    int palette = reg >> 3;
    updatePalette(gbcSpritePaletteMemory, spritePalettes[palette], palette, (reg >> 1) & 0x3);
  }

  /// Tick the LCD.
  ///
  /// @param cycles The number of CPU cycles elapsed since the last call to tick.
  void tick(int cycles) {
    // Accumulate to an internal counter
    lcdCycles += cycles;

    // At 4.194304MHz clock, 154 scanlines per frame, 59.7 frames/second = ~456 cycles / line
    if (lcdCycles >= 456) {
      lcdCycles -= 456;

      int ly = cpu.mmu.readRegisterByte(MemoryRegisters.LY) & 0xFF;

      // Draw the scanline
      bool displayEnabled = this.displayEnabled();

      // We may be running headlessly, so we must check before drawing
      if (displayEnabled) {
        draw(ly);
      }

      // Increment LY, and wrap at 154 lines
      cpu.mmu.writeRegisterByte(MemoryRegisters.LY, (((ly + 1) % 154) & 0xff));

      if (ly == 0) {
        if (lastSecondTime == -1) {
          lastSecondTime = DateTime.now().millisecondsSinceEpoch;
          lastCoreCycle = cpu.clocks;
        }

        currentVBlankCount++;

        if (currentVBlankCount == 60) {
          //print("Took " + ((DateTime.now().millisecondsSinceEpoch - lastSecondTime) / 1000.0) + " seconds for 60 frames - " + (core.clocks - lastCoreCycle) / 60 + " clks/frames");
          lastCoreCycle = cpu.clocks;
          currentVBlankCount = 0;
          lastSecondTime = DateTime.now().millisecondsSinceEpoch;
        }
      }

      bool isVBlank = 144 <= ly;
      if (!isVBlank) {
        cpu.mmu.dma?.tick();
      }

      cpu.mmu.writeRegisterByte(MemoryRegisters.LCD_STAT, cpu.mmu.readRegisterByte(MemoryRegisters.LCD_STAT) & ~0x03);

      int mode = 0;
      if (isVBlank) {
        mode = 0x01;
      }

      cpu.mmu.writeRegisterByte(MemoryRegisters.LCD_STAT, cpu.mmu.readRegisterByte(MemoryRegisters.LCD_STAT) | mode);

      int lcdStat = cpu.mmu.readRegisterByte(MemoryRegisters.LCD_STAT);

      if (displayEnabled && !isVBlank) {
        // LCDC Status Interrupt (To indicate to the user when the video hardware is about to redraw a given LCD line)
        if ((lcdStat & MemoryRegisters.LCD_STAT_COINCIDENCE_INTERRUPT_ENABLED_BIT) != 0) {
          int lyc = (cpu.mmu.readRegisterByte(MemoryRegisters.LYC) & 0xff);

          // Fire when LYC == LY
          if (lyc == ly) {
            cpu.setInterruptTriggered(MemoryRegisters.LCDC_BIT);
            cpu.mmu.writeRegisterByte(MemoryRegisters.LCD_STAT, cpu.mmu.readRegisterByte(MemoryRegisters.LCD_STAT) | MemoryRegisters.LCD_STAT_COINCIDENCE_BIT);
          } else {
            cpu.mmu.writeRegisterByte(MemoryRegisters.LCD_STAT, cpu.mmu.readRegisterByte(MemoryRegisters.LCD_STAT) & ~MemoryRegisters.LCD_STAT_COINCIDENCE_BIT);
          }
        }

        if ((lcdStat & MemoryRegisters.LCD_STAT_HBLANK_MODE_BIT) != 0) {
          cpu.setInterruptTriggered(MemoryRegisters.LCDC_BIT);
        }
      }

      // V-Blank Interrupt
      if (ly == 143) {
        // Trigger interrupts if the display is enabled
        if (displayEnabled) {
          // Trigger VBlank
          cpu.setInterruptTriggered(MemoryRegisters.VBLANK_BIT);

          // Trigger LCDC if enabled
          if ((lcdStat & MemoryRegisters.LCD_STAT_VBLANK_MODE_BIT) != 0) {
            cpu.setInterruptTriggered(MemoryRegisters.LCDC_BIT);
          }
        }
      }
    }
  }

  /// Draws a scanline.
  ///
  /// @param scanline The scanline to draw.
  void draw(int scanline) {
    // Don't even bother if the display is not enabled
    if (!displayEnabled()) {
      return;
    }

    // We still receive these calls for scanlines in vblank, but we can just ignore them
    if (scanline >= 144 || scanline < 0) {
      return;
    }

    // Reset our sprite counter
    spritesDrawnPerLine[scanline] = 0;

    // Start of a new frame
    if (scanline == 0) {
      // Swap buffer and current
      List<int> temp = buffer;
      buffer = current;
      current = temp;

      notifyListeners?.call();

      //Clear drawing buffer
      buffer.fillRange(0, buffer.length, 0);
    }

    // Draw the background if it's enabled
    if (backgroundEnabled()) {
      drawBackgroundTiles(buffer, scanline);
    }

    // If sprites are enabled, draw them.
    if (spritesEnabled()) {
      drawSprites(buffer, scanline);
    }

    // If the window appears in this scanline, draw it
    if (windowEnabled() && scanline >= getWindowPosY() && getWindowPosX() < LCD_WIDTH && getWindowPosY() >= 0) {
      drawWindow(buffer, scanline);
    }
  }

  /// Attempt to draw background tiles.
  ///
  /// @param data The raster to write to.
  /// @param scanline The current scanline.
  void drawBackgroundTiles(List<int> data, int scanline) {
    if (!Configuration.drawBackgroundLayer) {
      return;
    }

    // Local reference to save time
    int tileDataOffset = getTileDataOffset();

    // The background is scrollable
    int scrollY = getScrollY();
    int scrollX = getScrollX();

    int y = (scanline + scrollY % 8) ~/ 8;

    // Determine the offset into the VRAM tile bank
    int offset = getBackgroundTileMapOffset();

    // BG Map Tile Numbers
    //
    // An area of VRAM known as Background Tile Map contains the numbers of tiles to be displayed.
    // It is organized as 32 rows of 32 ints each. Each int contains a number of a tile to be displayed.

    // Tile patterns are taken from the Tile Data Table located either at $8000-8FFF or $8800-97FF.
    // In the first case, patterns are numbered with unsigned numbers from 0 to 255 (i.e. pattern #0 lies at address $8000).
    // In the second case, patterns have signed numbers from -128 to 127 (i.e. pattern #0 lies at address $9000).

    // 20 8x8 tiles fit in a 160px-wide screen
    for (int x = 0; x < 21; x++) {
      int addressBase = offset + ((y + scrollY ~/ 8) % 32 * 32) + ((x + scrollX ~/ 8) % 32);

      // Add 256 to jump into second tile pattern table
      int tile = tileDataOffset == 0 ? (cpu.mmu.readVRAM(addressBase) & 0xFF) : (cpu.mmu.readVRAM(addressBase) + 256);

      int gbcVramBank = 0;
      int gbcPalette = 0;
      bool flipX = false;
      bool flipY = false;

      // BG Map Attributes, in CGB Mode, an additional map of 32x32 ints is stored in VRAM Bank 1
      if (cpu.cartridge.gameboyType == GameboyType.COLOR) {
        int attributes = cpu.mmu.readVRAM(MemoryAddresses.VRAM_PAGESIZE + addressBase);

        // Tile VRAM Bank number
        if (attributes & 0x8 != 0) {
          gbcVramBank = 1;
        }

        // Horizontal Flip
        flipX = (attributes & 0x20) != 0;

        // Vertical Flip
        flipY = (attributes & 0x40) != 0;

        // Background Palette number
        gbcPalette = attributes & 0x7;
      }

      // Delegate tile drawing
      drawTile(bgPalettes[gbcPalette], data, -(scrollX % 8) + x * 8, -(scrollY % 8) + y * 8, tile, scanline, flipX, flipY, gbcVramBank, 0, false);
    }
  }

  /// Attempt to draw window tiles.
  ///
  /// @param data The raster to write to.
  /// @param scanline The current scanline.
  void drawWindow(List<int> data, int scanline) {
    int tileDataOffset = getTileDataOffset();

    // The window layer is offset-able from 0,0
    int posX = getWindowPosX();
    int posY = getWindowPosY();

    int tileMapOffset = getWindowTileMapOffset();

    int y = (scanline - posY) ~/ 8;

    for (int x = getWindowPosX() ~/ 8; x < 21; x++) {
      // 32 tiles a row
      int addressBase = tileMapOffset + (x + y * 32);

      // add 256 to jump into second tile pattern table
      int tile = tileDataOffset == 0 ? cpu.mmu.readVRAM(addressBase) & 0xff : cpu.mmu.readVRAM(addressBase) + 256;

      int gbcVramBank = 0;
      bool flipX = false;
      bool flipY = false;
      int gbcPalette = 0;

      // Same rules apply here as for background tiles.
      if (cpu.cartridge.gameboyType == GameboyType.COLOR) {
        int attributes = cpu.mmu.readVRAM(MemoryAddresses.VRAM_PAGESIZE + addressBase);

        if ((attributes & 0x8) != 0) {
          gbcVramBank = 1;
        }

        flipX = (attributes & 0x20) != 0;
        flipY = (attributes & 0x40) != 0;
        gbcPalette = attributes & 0x07;
      }

      drawTile(bgPalettes[gbcPalette], data, posX + x * 8, posY + y * 8, tile, scanline, flipX, flipY, gbcVramBank, PPU.P_6, false);
    }
  }

  /// Attempt to draw a single line of a tile.
  ///
  /// @param palette The palette currently in use.
  /// @param data An array of elements, representing the LCD raster.
  /// @param x The x-coordinate of the tile.
  /// @param y The y-coordinate of the tile.
  /// @param tile The tile id to draw.
  /// @param scanline The current LCD scanline.
  /// @param flipX Whether the tile should be flipped vertically.
  /// @param flipY Whether the tile should be flipped horizontally.
  /// @param bank The tile bank to use.
  /// @param basePriority The current priority for the given tile.
  /// @param sprite Whether the tile beints to a sprite or not.
  void drawTile(Palette palette, List<int> data, int x, int y, int tile, int scanline, bool flipX, bool flipY, int bank, int basePriority, bool sprite) {
    // Store a local copy to save a lot of load opcodes.
    int line = scanline - y;
    int addressBase = MemoryAddresses.VRAM_PAGESIZE * bank + tile * 16;

    // 8 pixel width
    for (int px = 0; px < 8; px++) {
      // Destination pixels
      int dx = x + px;

      // Skip if out of bounds
      if (dx < 0 || dx >= PPU.LCD_WIDTH || scanline >= PPU.LCD_HEIGHT) {
        continue;
      }

      // Check if our current priority should overwrite the current priority
      int index = dx + scanline * PPU.LCD_WIDTH;
      if (basePriority != 0 && basePriority < (data[index] & 0xFF000000)) {
        continue;
      }

      // Handle the x and y flipping by tweaking the indexes we are accessing
      int logicalLine = (flipY ? 7 - line : line);
      int logicalX = (flipX ? 7 - px : px);
      int address = addressBase + logicalLine * 2;

      // Upper bit of the color number
      int paletteUpper = (((cpu.mmu.readVRAM(address + 1) & (0x80 >> logicalX)) >> (7 - logicalX)) << 1);
      // lower bit of the color number
      int paletteLower = ((cpu.mmu.readVRAM(address) & (0x80 >> logicalX)) >> (7 - logicalX));

      int paletteIndex = paletteUpper | paletteLower;
      int priority = (basePriority == 0) ? (paletteIndex == 0 ? PPU.P_1 : PPU.P_3) : basePriority;

      if (sprite && paletteIndex == 0) {
        continue;
      }

      if (priority >= (data[index] & 0xFF000000)) {
        data[index] = priority | palette.getColor(paletteIndex);
      }
    }
  }

  /// Attempts to draw all sprites.
  ///
  /// GameBoy video controller can display up to 40 sprites, but only a maximum of 10 per line.
  ///
  /// @param data The raster to write to.
  /// @param scanline The current scanline.
  void drawSprites(List<int> data, int scanline) {
    if (!Configuration.drawSpriteLayer) {
      return;
    }

    // Hold local references to save a lot of load opcodes
    bool tall = isUsingTallSprites();
    bool isColorGB = cpu.cartridge.gameboyType == GameboyType.COLOR;

    // Actual GameBoy hardware can only handle drawing 10 sprites per line
    for (int i = 0; i < cpu.mmu.oam.length && spritesDrawnPerLine[scanline] < 10; i += 4) {
      // Specifies the sprites vertical position on the screen (minus 16). An offscreen value (for example, Y=0 or Y>=160) hides the sprite.
      int y = cpu.mmu.readOAM(i) & 0xff;

      // Have we exited our bounds
      if (!tall && !(y - 16 <= scanline && scanline < y - 8)) {
        continue;
      }

      // Specifies the sprites horizontal position on the screen (minus 8).
      // An offscreen value (X=0 or X>=168) hides the sprite, but the sprite still affects the priority ordering.
      int x = cpu.mmu.readOAM(i + 1) & 0xff;

      // Specifies the sprites Tile Number (00-FF). This (unsigned) value selects a tile from memory at 8000h-8FFFh.
      // In CGB Mode this could be either in VRAM Bank 0 or 1, depending on Bit 3 of the following int.
      int tile = cpu.mmu.readOAM(i + 2) & 0xff;

      int attributes = cpu.mmu.readOAM(i + 3);

      int vrambank = ((attributes & 0x8) != 0 && isColorGB) ? 1 : 0;
      int priority = ((attributes & 0x80) != 0) ? PPU.P_2 : PPU.P_5;
      bool flipX = (attributes & 0x20) != 0;
      bool flipY = (attributes & 0x40) != 0;

      // Palette selection
      Palette pal = spritePalettes[isColorGB ? (attributes & 0x7) : ((attributes >> 4) & 0x1)];

      // Handle drawing double sprites
      if (tall) {
        // If we're using tall sprites we actually have to flip the order that we draw the top/bottom tiles
        int hi = flipY ? (tile | 0x01) : (tile & 0xFE);
        int lo = flipY ? (tile & 0xFE) : (tile | 0x01);

        if (y - 16 <= scanline && scanline < y - 8) {
          drawTile(pal, data, x - 8, y - 16, hi, scanline, flipX, flipY, vrambank, priority, true);
          spritesDrawnPerLine[scanline]++;
        }

        if (y - 8 <= scanline && scanline < y) {
          drawTile(pal, data, x - 8, y - 8, lo, scanline, flipX, flipY, vrambank, priority, true);
          spritesDrawnPerLine[scanline]++;
        }
      } else {
        drawTile(pal, data, x - 8, y - 16, tile, scanline, flipX, flipY, vrambank, priority, true);
        spritesDrawnPerLine[scanline]++;
      }
    }
  }

  /// Determines whether the display is enabled from the LCDC register.
  ///
  /// @return The enabled state.
  bool displayEnabled() {
    return (cpu.mmu.readRegisterByte(MemoryRegisters.LCDC) & MemoryRegisters.LCDC_CONTROL_OPERATION_BIT) != 0;
  }

  /// Determines whether the background layer is enabled from the LCDC register.
  ///
  /// @return The enabled state.
  bool backgroundEnabled() {
    return (cpu.mmu.readRegisterByte(MemoryRegisters.LCDC) & MemoryRegisters.LCDC_BGWINDOW_DISPLAY_BIT) != 0;
  }

  /// Determines the window tile map offset from the LCDC register.
  ///
  /// @return The offset.
  int getWindowTileMapOffset() {
    if ((cpu.mmu.readRegisterByte(MemoryRegisters.LCDC) & MemoryRegisters.LCDC_WINDOW_TILE_MAP_DISPLAY_SELECT_BIT) != 0) {
      return 0x1c00;
    }

    return 0x1800;
  }

  /// Determines the background tile map offset from the LCDC register.
  ///
  /// @return The offset.
  int getBackgroundTileMapOffset() {
    if ((cpu.mmu.readRegisterByte(MemoryRegisters.LCDC) & MemoryRegisters.LCDC_BG_TILE_MAP_DISPLAY_SELECT_BIT) != 0) {
      return 0x1c00;
    }

    return 0x1800;
  }

  /// Determines whether tall sprites are enabled from the LCDC register.
  ///
  /// @return The enabled state.
  bool isUsingTallSprites() {
    return (cpu.mmu.readRegisterByte(MemoryRegisters.LCDC) & MemoryRegisters.LCDC_SPRITE_SIZE_BIT) != 0;
  }

  /// Determines whether sprites are enabled from the LCDC register.
  ///
  /// @return The enabled state.
  bool spritesEnabled() {
    return (cpu.mmu.readRegisterByte(MemoryRegisters.LCDC) & MemoryRegisters.LCDC_SPRITE_DISPLAY_BIT) != 0;
  }

  /// Determines whether the window is enabled from the LCDC register.
  ///
  /// @return The enabled state.
  bool windowEnabled() {
    return (cpu.mmu.readRegisterByte(MemoryRegisters.LCDC) & MemoryRegisters.LCDC_WINDOW_DISPLAY_BIT) != 0;
  }

  /// Tile patterns are taken from the Tile Data Table located either at $8000-8FFF or $8800-97FF.
  /// In the first case, patterns are numbered with unsigned numbers from 0 to 255 (i.e. pattern #0 lies at address $8000).
  /// In the second case, patterns have signed numbers from -128 to 127 (i.e. pattern #0 lies at address $9000).
  ///
  /// The Tile Data Table address for the background can be selected via LCDC register.
  int getTileDataOffset() {
    if ((cpu.mmu.readRegisterByte(MemoryRegisters.LCDC) & MemoryRegisters.LCDC_BGWINDOW_TILE_DATA_SELECT_BIT) != 0) {
      return 0x0;
    }

    return 0x0800;
  }

  /// Fetches the current background X-coordinate from the WX register.
  ///
  /// @return The signed offset.
  int getScrollX() {
    return cpu.mmu.readRegisterByte(MemoryRegisters.SCX) & 0xFF;
  }

  /// Fetches the current background Y-coordinate from the SCY register.
  ///
  /// @return The signed offset.
  int getScrollY() {
    return cpu.mmu.readRegisterByte(MemoryRegisters.SCY) & 0xff;
  }

  /// Fetches the current window X-coordinate from the WX register.
  ///
  /// @return The unsigned offset.
  int getWindowPosX() {
    return (cpu.mmu.readRegisterByte(MemoryRegisters.WX) & 0xFF) - 7;
  }

  /// Fetches the current window Y-coordinate from the WY register.
  ///
  /// @return The unsigned offset.
  int getWindowPosY() {
    return cpu.mmu.readRegisterByte(MemoryRegisters.WY) & 0xFF;
  }
}
