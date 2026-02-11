# STM32H735G-DK Audio Recorder & Player with SD Card Storage

## Overview

This project implements a **multi-mode audio system** on the STM32H735G-DK board with three selectable operating modes:

| Mode | `g_Mode` | Description |
|------|----------|-------------|
| **PASSTHROUGH** | `0` | Routes LINE_IN audio directly to headphone output (loopback) |
| **RECORD** | `1` | Records LINE_IN audio to SD card as `.WAV` files (headphone output is silent) |
| **PLAY** | `2` | Plays `TEST.WAV` from SD card to headphone output |

The mode is selected at compile time by setting `g_Mode` in `main.c` and reflashing. The USER button triggers the action for the selected mode. In all modes, the system uses **FreeRTOS** for multitasking, a **ring buffer** to decouple fast audio DMA from slower SD card I/O, and **FatFs** for the FAT32 file system.

---

## Hardware Path (Signal Flow)

### MODE_PASSTHROUGH
```
LINE_IN jack --> WM8994 (ADC) --> SAI RX DMA --> RecordBuffer
                                                      |
                                                      +--> memcpy --> PlayBuffer --> SAI TX DMA --> WM8994 (DAC) --> Headphone jack
```

### MODE_RECORD
```
LINE_IN jack --> WM8994 (ADC) --> SAI RX DMA --> RecordBuffer
                                                      |
                                                      +--> RB_Write() --> Ring Buffer (AXI_SRAM)
                                                      |                        |
                                                      |                        v
                                                      |                  SD_Write_Task --> SD Card (REC_XX.WAV)
                                                      |
                                                      +--> memset(0) --> PlayBuffer --> (silence on headphone)
```

### MODE_PLAY
```
SD Card (TEST.WAV) --> SD_Write_Task --> f_read() --> RB_Write() --> Ring Buffer (AXI_SRAM)
                                                                          |
                                                                          v
                           PlayBuffer <-- RB_Read() <-- Audio_Loopback_Task
                                |
                                v
                          SAI TX DMA --> WM8994 (DAC) --> Headphone jack
                          (zeros on underrun/end of file = silence)
```

---

## Memory Layout

| Region      | Address        | Size   | Contents                                            |
|-------------|----------------|--------|-----------------------------------------------------|
| **RAM_D3**  | `0x38000000`   | 16 KB  | `RecordBuffer`, `PlayBuffer` (DMA-accessible)       |
| **AXI_SRAM**| `0x24000000`   | 320 KB | `Audio_Ring_Buffer` (128 KB), `scratch_buf`, FatFs objects (`SDFatFs`, `AudioFile`) |
| **RAM**     | `0x20000000`   | 128 KB | Stack, heap, general variables                      |
| **ROM**     | `0x08000000`   | 1 MB   | Flash (program code)                                |

The linker script (`STM32H735IGKX_FLASH.ld`) defines custom sections `.RAM_D3` and `.axi_sram` to place buffers in the correct memory regions. The MPU is configured to make these regions **non-cacheable and shareable**, which is critical for DMA coherency.

---

## FreeRTOS Tasks

| Task                    | Priority          | Stack   | Role                                                  |
|-------------------------|-------------------|---------|-------------------------------------------------------|
| **Audio_Loopback_Task** | AboveNormal       | 8x min  | Processes DMA callbacks; routes audio based on `g_Mode` (passthrough copy, record to ring buffer, or playback from ring buffer) |
| **SD_Write_Task**       | Normal            | 4 KB    | Mounts SD, scans for existing files; in RECORD mode drains ring buffer to SD; in PLAY mode feeds ring buffer from SD |

---

## Source Files

| File | Location | Purpose |
|------|----------|---------|
| `main.c` | `Core/Src/` | Application entry point, task definitions, ring buffer, WAV header, SD recording logic |
| `audio_record.h` | `Core/Inc/` | Shared audio defines (`BUFFER_SIZE`, `AUDIO_SAMPLE_RATE`), extern declarations for buffers |
| `audio_record_linein_simple.c` | `STM32CubeIDE/Application/User/Core/` | Audio HW init (`Audio_LoopbackInit`), DMA callbacks, WM8994 codec configuration |
| `app_fatfs.c` | `FatFs/App/` | FatFs initialization (`MX_FATFS_Init`), SD driver linking |
| `main.h` | `Core/Inc/` | Shared defines (`LED_OK`, `APP_OK`, etc.), function prototypes |
| `stm32h7xx_it.c` | `Core/Src/` | Interrupt handlers (SysTick, DMA, EXTI) |

---

## Main Logic: Step by Step

### 1. Boot Sequence (`main()`)

```
HAL_Init() --> SystemClock_Config() --> BSP_LED_Init() --> BSP_PB_Init()
    --> BSP_SD_Init() --> MX_USART3_UART_Init() --> MX_GPIO_Init()
    --> MX_FATFS_Init() --> Audio_LoopbackInit()
    --> Create message queue (SDQueueHandle)
    --> Create semaphore (SDRemaphoreHandle)
    --> Create SD_Write_Task
    --> Create Audio_Loopback_Task
    --> osKernelStart()
```

### 2. Audio_Loopback_Task (runs continuously)

```
1. Clear RecordBuffer and PlayBuffer
2. BSP_AUDIO_OUT_Play()   --> starts SAI TX DMA (generates master clock)
3. BSP_AUDIO_IN_Record()  --> starts SAI RX DMA (begins capturing audio)
4. LOOP FOREVER:
   a. Wait on SDQueueHandle for DMA message (HALF or FULL)
   b. Determine which half of the buffer is ready (src/dst pointers)
   c. SWITCH on g_Mode:
      - MODE_PASSTHROUGH: memcpy(src --> dst) for audio loopback
      - MODE_RECORD:
          * memset(dst, 0) to silence headphone output
          * IF g_StartRecording AND not yet reached TARGET_BYTES:
            - RB_Write(src) into ring buffer
            - Release semaphore to wake SD_Write_Task
          * IF target reached: set g_RecordingComplete = 1
      - MODE_PLAY:
          * RB_Read(dst) to pull audio from ring buffer
          * If underrun (not enough data): zero-pad remainder (silence)
          * Release semaphore to wake SD_Write_Task for refill
```

### 3. SD_Write_Task (runs continuously)

```
1. Wait 500ms for DMA to stabilize
2. Check SD card is present
3. f_mount() the SD card
4. SCAN existing REC_XX.WAV files (01-99) to find next index
5. Print current mode and "Press USER button."
6. LOOP FOREVER:
   a. LED ON (solid = ready), wait for g_ButtonPressed

   === IF MODE_RECORD ===
   b. Build filename: "REC_XX.WAV"
   c. Reset all state (counters, ring buffer pointers, flags)
   d. f_open() new file, write placeholder WAV header (44 bytes)
   e. Set g_SDReady = 1, g_StartRecording = 1
   f. RECORDING LOOP:
      - Wait on semaphore (released by audio task)
      - If ring buffer has >= 4096 bytes: read chunk, f_write() to SD
      - If recording complete + leftover data: flush remainder
      - Break when g_RecordingComplete AND ring buffer drained
   g. Seek to file offset 0, write final WAV header with correct size
   h. f_close(), increment g_FileIndex, print summary

   === IF MODE_PLAY ===
   b. f_open("TEST.WAV", FA_READ)
   c. f_lseek() past 44-byte WAV header
   d. Reset ring buffer (head, tail, count = 0)
   e. PLAYBACK LOOP:
      - Wait on semaphore (released by audio task after consuming data)
      - If ring buffer has free space >= 4096 bytes:
        * f_read() from SD into scratch_buf
        * RB_Write() into ring buffer
      - If bytesRead < 4096 (end of file):
        * Wait until ring buffer drains below one DMA chunk
        * Break
   f. f_close(), print "Playback complete."

   === BOTH MODES ===
   i. Debounce delay (500ms), go back to step (a) for next button press
```

### 4. DMA Callbacks (interrupt context)

The SAI DMA triggers two callbacks defined in `audio_record_linein_simple.c`:

- **`BSP_AUDIO_IN_HalfTransfer_CallBack()`** - First half of `RecordBuffer` is filled. Posts `BUFFER_OFFSET_HALF (1)` to `SDQueueHandle`.
- **`BSP_AUDIO_IN_TransferComplete_CallBack()`** - Second half is filled. Posts `BUFFER_OFFSET_FULL (2)` to `SDQueueHandle`.

These wake up `Audio_Loopback_Task` which then processes the corresponding buffer half.

### 5. Button Press (interrupt context)

```
USER button press
    --> EXTI interrupt
    --> BSP_PB_Callback(BUTTON_USER)
    --> g_ButtonPressed = 1
    --> SD_Write_Task detects it in its polling loop
```

---

## Ring Buffer

The ring buffer decouples the fast, real-time audio DMA from the variable-latency SD card writes.

| Parameter | Value |
|-----------|-------|
| Size | 128 KB (`RB_SIZE`) |
| Location | AXI_SRAM (`.axi_sram` section) |
| Capacity | ~400 ms of stereo 48 kHz / 16-bit audio |

**In RECORD mode:**
- **Producer:** `Audio_Loopback_Task` via `RB_Write()` — writes DMA half-buffer chunks (mic data).
- **Consumer:** `SD_Write_Task` via `RB_Read()` — reads in 4 KB (`scratch_buf`) chunks to write to SD.

**In PLAY mode (roles reversed):**
- **Producer:** `SD_Write_Task` via `RB_Write()` — reads 4 KB chunks from SD file into ring buffer.
- **Consumer:** `Audio_Loopback_Task` via `RB_Read()` — pulls data into `PlayBuffer` for DAC output.

**Synchronization:**
- `rb_head` (write index), `rb_tail` (read index), `rb_count` (bytes available)
- `rb_count` updates are protected by `__disable_irq()` / `__enable_irq()` for atomicity
- A semaphore (`SDRemaphoreHandle`) wakes the SD task when new data is available
- Overflow detection: if ring buffer is full, `RB_Write()` drops the data and lights `LED_ERROR`

---

## WAV File Format

Each recording is saved as a standard PCM WAV file:

| Parameter       | Value              |
|-----------------|--------------------|
| Format          | PCM (uncompressed) |
| Sample Rate     | 48,000 Hz          |
| Bit Depth       | 16-bit             |
| Channels        | 2 (Stereo)         |
| Byte Rate       | 192,000 bytes/sec  |
| Duration        | 15 seconds (`RECORD_DURATION_SECONDS`) |
| File Size       | ~2.88 MB per recording |

The WAV header (44 bytes) is written as a placeholder at file open, then **rewritten with the correct data size** after recording completes (`f_lseek` to offset 0).

---

## File Index Persistence (SD Card Scan)

On boot, after mounting the SD card, `SD_Write_Task` scans for existing files `REC_01.WAV` through `REC_99.WAV` using `f_stat()`. It finds the highest existing index and sets `g_FileIndex = max_index + 1`. This ensures recordings are never overwritten after a reset.

Example: If SD card contains `REC_01.WAV`, `REC_02.WAV`, `REC_05.WAV` --> next recording will be `REC_06.WAV`.

---
## Clocks calculation for SAI
Digital Audio protocols (like SAI or I2S) need a "Master Clock" (MCLK) that is much faster than the sample rate to drive the internal logic of the audio chip (the WM8994). The standard multiplier is 512x.
$$\text{Target Frequency} = 48,000 \text{ Hz} \times 512 = \mathbf{24,576,000 \text{ Hz}} \text{ (24.576 MHz)}$$

The PLL (Phase Locked Loop) takes the Crystal clock (HSE) and transforms it according to the following Formula:
$$f_{out} = \text{Input} \times \frac{N}{M \times P}$$
Where:
- Input (HSE): Physical crystal (25 MHz).
- M (Divider): Pre-division to lower the input speed.
- N (Multiplier): Increases the speed massively (VCO).
- P (Divider): Final division to get the output.

### Specific calculations for the implementation
- The Input Divider (M)
  - Code: PLL2M = 5
  - Math: $25 \text{ MHz} / 5 = \mathbf{5 \text{ MHz}}$.
- The Multiplier (N) - The "VCO"
  - Code: PLL2M = 5
  - Math: $25 \text{ MHz} / 5 = \mathbf{5 \text{ MHz}}$.
---
## Important Variables Reference

### Mode & Control Flags

| Variable | Type | Set By | Purpose |
|----------|------|--------|---------|
| `g_Mode` | `volatile uint8_t` | Compile-time constant | Selects operating mode: `MODE_PASSTHROUGH` (0), `MODE_RECORD` (1), `MODE_PLAY` (2) |
| `g_ButtonPressed` | `volatile uint8_t` | Button ISR (`BSP_PB_Callback`) | Signals SD task that user pressed the button |
| `g_StartRecording` | `volatile uint8_t` | SD_Write_Task | Tells audio task to start filling ring buffer (RECORD mode only) |
| `g_RecordingComplete` | `volatile uint8_t` | Audio_Loopback_Task | Signals SD task that target size was reached (RECORD mode only) |
| `g_SDReady` | `volatile uint8_t` | SD_Write_Task | Indicates file is open and ready for data |
| `g_FileIndex` | `uint32_t` | SD_Write_Task (scan + increment) | Current file number for `REC_XX.WAV` naming |

### Buffer / Counter Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `total_bytes_recorded` | `uint32_t` | Bytes captured from DMA (audio task side) |
| `total_sd_bytes_written` | `uint32_t` | Bytes written to SD file (SD task side, local) |
| `TARGET_BYTES` | `const uint32_t` | Recording limit: `48000 * 2 * 2 * 15 = 2,880,000` bytes |
| `rb_head` | `volatile uint32_t` | Ring buffer write index (audio task writes here) |
| `rb_tail` | `volatile uint32_t` | Ring buffer read index (SD task reads from here) |
| `rb_count` | `volatile uint32_t` | Bytes currently in ring buffer |

### Audio Buffers

| Buffer | Size | Location | Purpose |
|--------|------|----------|---------|
| `RecordBuffer` | 4096 x `int16_t` (8 KB) | RAM_D3 | DMA fills this with ADC samples |
| `PlayBuffer` | 4096 x `int16_t` (8 KB) | RAM_D3 | DMA reads this for DAC output |
| `RB_Rec_Buffer` | 128 KB | AXI_SRAM | Ring buffer: mic-to-SD (RECORD) or SD-to-DAC (PLAY) |
| `scratch_buf` | 4 KB | AXI_SRAM | Temporary buffer for SD card reads/writes |
| `File_Rec` | FIL | AXI_SRAM | FatFs file object for recording (RECORD mode) |
| `File_Play` | FIL | AXI_SRAM | FatFs file object for playback (PLAY mode) |

### RTOS Synchronization Objects

| Object | Type | Purpose |
|--------|------|---------|
| `SDQueueHandle` | Message Queue (2 entries) | DMA callbacks post HALF/FULL state to audio task |
| `SDRemaphoreHandle` | Semaphore | Audio task releases it to wake SD task when data is ready |

---

## WM8994 Codec Configuration

The `Audio_LoopbackInit()` function in `audio_record_linein_simple.c` configures:

1. **Audio Output:** Headphone, stereo, 48 kHz, 16-bit, volume 20
2. **Audio Input:** LINE_IN (Analog Line 1), stereo, 48 kHz, 16-bit, volume 100

The `Audio_FixLineInConfig()` function applies direct I2C register writes to the WM8994:

| Register | Value  | Purpose |
|----------|--------|---------|
| `0x01`   | `0x0007` | Enable VMID + bias (critical for negative audio cycle) |
| `0x29`   | `0x0020` | Left channel: route IN1L to mixer, disable +30 dB boost |
| `0x2A`   | `0x0020` | Right channel: route IN1R to mixer, disable +30 dB boost |

---

## MPU Configuration

Three MPU regions are configured for DMA coherency:

| Region | Address | Size | Config | Purpose |
|--------|---------|------|--------|---------|
| 0 | `0x00000000` | 4 GB | No access (background) | Default deny |
| 1 | `0x38000000` | 64 KB | Non-cacheable, shareable | D3 SRAM (DMA audio buffers) |
| 2 | `0x24000000` | 512 KB | Non-cacheable, shareable | AXI SRAM (ring buffer, FatFs) |

Non-cacheable configuration is **critical** - without it, the CPU cache and DMA see different data, causing audio corruption.

---

## Build Configuration

- **Toolchain:** GCC (ARM) via STM32CubeIDE
- **RTOS:** FreeRTOS (CMSIS-RTOS v2 API)
- **DSP:** CMSIS-DSP (`arm_math.h`) - FFT initialized but not actively used in recording flow
- **File System:** FatFs (FAT32 on microSD)
- **HAL:** STM32H7 HAL + BSP drivers for STM32H735G-DK

---

## Quick Reference: What Activates What

| Trigger | Action |
|---------|--------|
| Power on / Reset | `main()` initializes HW, creates tasks, starts RTOS |
| RTOS starts | `Audio_Loopback_Task` begins processing DMA buffers based on `g_Mode` |
| RTOS starts | `SD_Write_Task` mounts SD, scans files, waits for button |
| DMA half-transfer IRQ | Posts `BUFFER_OFFSET_HALF` to `SDQueueHandle` |
| DMA full-transfer IRQ | Posts `BUFFER_OFFSET_FULL` to `SDQueueHandle` |
| Message in `SDQueueHandle` | Wakes `Audio_Loopback_Task` to process buffer half |
| USER button press | Sets `g_ButtonPressed = 1` via EXTI callback |

### MODE_PASSTHROUGH
| Trigger | Action |
|---------|--------|
| DMA callback | Audio task copies `RecordBuffer` to `PlayBuffer` (mic to headphone) |
| USER button press | No effect (passthrough runs continuously) |

### MODE_RECORD
| Trigger | Action |
|---------|--------|
| `g_ButtonPressed` detected | SD task opens `REC_XX.WAV`, sets `g_StartRecording = 1` |
| `g_StartRecording == 1` | Audio task writes mic data to ring buffer, outputs silence |
| Semaphore released | Wakes SD task to drain ring buffer to SD card |
| `total_bytes_recorded >= TARGET_BYTES` | Audio task sets `g_RecordingComplete = 1` |
| `g_RecordingComplete == 1` + buffer drained | SD task finalizes WAV header, closes file, waits for next button press |

### MODE_PLAY
| Trigger | Action |
|---------|--------|
| `g_ButtonPressed` detected | SD task opens `TEST.WAV`, skips header, resets ring buffer |
| SD task reads from file | `f_read()` into `scratch_buf`, then `RB_Write()` into ring buffer |
| DMA callback | Audio task pulls data from ring buffer into `PlayBuffer` via `RB_Read()` |
| Semaphore released | Wakes SD task to refill ring buffer from SD |
| End of file (`bytesRead < 4096`) | SD task waits for buffer to drain, then closes file |
| Playback complete | SD task waits for next button press to replay `TEST.WAV` |
