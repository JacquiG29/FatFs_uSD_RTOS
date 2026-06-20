# STM32H735G-DK Audio Recorder & Player with SD Card Storage

## Overview

This project implements a **multi-mode audio system** on the STM32H735G-DK board with four selectable operating modes and two system architectures:

| Mode | `g_Mode` | Description |
|------|----------|-------------|
| **PASSTHROUGH** | `0` | Routes LINE_IN audio directly to headphone/speaker output (loopback) |
| **RECORD** | `1` | Records LINE_IN audio to SD card as `.WAV` files (output is silent) |
| **PLAY** | `2` | Plays a WAV file from SD card to headphone/speaker output |
| **FULL_DUPLEX** | `3` | Records LINE_IN to SD **and** plays a WAV file simultaneously |

### System Modes

The system supports two operating architectures, selected via the LCD touchscreen at boot:

| System Mode | `system_mode` | Description |
|-------------|---------------|-------------|
| **Standalone** | `0` | Self-contained operation. RTC alarms trigger full-duplex recording/playback automatically. Alarm schedule managed via LCD touchscreen. |
| **Distributed Node** | `1` | Controlled by an external RF board. An EXTI signal on ARD_D8 triggers the operation, while ARD_D2/D4 pins select the mode (record, play, or full-duplex). |

The USER button triggers the action for the selected mode in manual operation. The system uses **FreeRTOS** for multitasking, **dual ring buffers** to decouple fast audio DMA from slower SD card I/O, **FatFs** for the FAT32 file system, an **RTC** with alarm support, and an **LCD touchscreen** for configuration.

---

## Hardware Path (Signal Flow)

### MODE_PASSTHROUGH
```
LINE_IN jack --> WM8994 (ADC) --> SAI RX DMA --> RecordBuffer
                                                      |
                                                      +--> memcpy --> PlayBuffer --> SAI TX DMA --> WM8994 (DAC) --> Speaker / Headphone
```

### MODE_RECORD
```
LINE_IN jack --> WM8994 (ADC) --> SAI RX DMA --> RecordBuffer
                                                      |
                                                      +--> RB_Write() --> RecRB (AXI_SRAM)
                                                      |                        |
                                                      |                        v
                                                      |                  SD_Write_Task --> SD Card (REC_XX.WAV)
                                                      |
                                                      +--> memset(0) --> PlayBuffer --> (silence on output)
```

### MODE_PLAY
```
SD Card (*.WAV) --> SD_Write_Task --> f_read() --> RB_Write() --> PlayRB (AXI_SRAM)
                                                                       |
                                                                       v
                           PlayBuffer <-- RB_Read() <-- Audio_Loopback_Task
                                |
                                v
                          SAI TX DMA --> WM8994 (DAC) --> Speaker / Headphone
                          (zeros on underrun/end of file = silence)
```

### MODE_FULL_DUPLEX
```
LINE_IN jack --> WM8994 (ADC) --> SAI RX DMA --> RecordBuffer
                                                      |
                                                      +--> RB_Write() --> RecRB -----> SD_Write_Task --> SD Card (REC_XX.WAV)
                                                      
SD Card (*.WAV) --> SD_Write_Task --> f_read() --> RB_Write() --> PlayRB
                                                                    |
                                                                    v
                           PlayBuffer <-- RB_Read() <-- Audio_Loopback_Task
                                |
                                v
                          SAI TX DMA --> WM8994 (DAC) --> Speaker / Headphone
```

In full-duplex mode, the playback ring buffer is pre-filled before `g_StartRecording` is set, to avoid initial glitches.

---

## Memory Layout

| Region      | Address        | Size   | Contents                                            |
|-------------|----------------|--------|-----------------------------------------------------|
| **RAM_D3**  | `0x38000000`   | 16 KB  | `RecordBuffer`, `PlayBuffer` (DMA-accessible)       |
| **AXI_SRAM**| `0x24000000`   | 320 KB | `RB_Rec_Buffer` (128 KB), `RB_Play_Buffer` (128 KB), `scratch_buf`, FatFs objects (`SDFatFs`, `File_Rec`, `File_Play`) |
| **OSPI RAM**| `0x70000000`   | 16 MB  | LCD framebuffer (LTDC) |
| **RAM**     | `0x20000000`   | 128 KB | Stack, heap, general variables                      |
| **ROM**     | `0x08000000`   | 1 MB   | Flash (program code)                                |

The linker script (`STM32H735IGKX_FLASH.ld`) defines custom sections `.RAM_D3` and `.axi_sram` to place buffers in the correct memory regions. The MPU is configured to make these regions **non-cacheable and shareable**, which is critical for DMA coherency.

---

## FreeRTOS Tasks

| Task                    | Priority          | Stack   | Role                                                  |
|-------------------------|-------------------|---------|-------------------------------------------------------|
| **Audio_Loopback_Task** | AboveNormal       | 8x min  | Processes DMA callbacks; routes audio based on `g_Mode` (passthrough copy, record to ring buffer, playback from ring buffer, or full-duplex simultaneous record+play) |
| **SD_Write_Task**       | Normal            | 4 KB    | Mounts SD, scans for existing files; in RECORD mode drains ring buffer to SD; in PLAY mode feeds ring buffer from SD; in FULL_DUPLEX mode does both simultaneously |
| **System_Controller_Task** | BelowNormal    | 2 KB    | Master state machine. In distributed mode: wakes on EXTI (ARD_D8) to set record/play/full-duplex. In standalone mode: wakes on RTC alarm to start full-duplex automatically. |

---

## Source Files

| File | Location | Purpose |
|------|----------|---------|
| `main.c` | `Core/Src/` | Application entry point, task definitions, dual ring buffers, WAV header, SD recording/playback/full-duplex logic |
| `audio_record.h` | `Core/Inc/` | Shared audio defines (`BUFFER_SIZE`, `AUDIO_SAMPLE_RATE`), extern declarations for buffers |
| `audio_record_linein_simple.c` | `STM32CubeIDE/Application/User/Core/` | Audio HW init (`Audio_LoopbackInit`), DMA callbacks, WM8994 codec configuration, Class AB enable / speaker-mode verify helpers |
| `rtc_functions.c` | `Core/Src/` | RTC initialization, time/date/alarm set/get, alarm file persistence (`ALARMS.TXT`), alarm event callback |
| `rtc_functions.h` | `Core/Inc/` | RTC function prototypes, alarm file I/O declarations |
| `lcd_functions.c` | `STM32CubeIDE/Application/User/Core/` | LCD touchscreen UI: start menu, date/time setup, mode selection, alarm workflow screens |
| `lcd_function.h` | `Core/Inc/` | LCD function prototypes, `TouchZone_t` struct, alarm workflow globals |
| `app_fatfs.c` | `FatFs/App/` | FatFs initialization (`MX_FATFS_Init`), SD driver linking |
| `main.h` | `Core/Inc/` | Shared defines, mode enums, `RingBuffer_t` struct, function prototypes |
| `stm32h7xx_it.c` | `Core/Src/` | Interrupt handlers (SysTick, DMA, EXTI) |

---

## Main Logic: Step by Step

### 1. Boot Sequence (`main()`)

```
HAL_Init() --> SystemClock_Config() --> MCO1 output (HSE)
    --> BSP_LED_Init() --> BSP_PB_Init() --> BSP_SD_Init()
    --> MX_USART3_UART_Init() --> Print version
    --> BSP_LCD_Init() --> StartMenu_LCD()
    --> MX_RTC_Init()
        (checks backup register 0xBEBE to preserve time across resets)
        (if Year == 0x00, forces date/time setup via LCD touchscreen)
    --> Set_DateTime_LCD() (if needed)
    --> Print_Date() / Print_Time() / Print_DateTime_LCD()
    --> MX_FATFS_Init()
    --> Audio_LoopbackInit()
        (configures WM8994 output to Speaker + Headphone/Line-Out, Class D by default)
    --> Audio_PrintSpeakerMode()
        (reads reg 0x23, prints active amplifier mode Class D/AB to UART)
    --> Set_Mode_LCD()
        (user picks Standalone or Distributed via touchscreen)
        (loads alarm list from SD if distributed mode)
    --> MX_GPIO_Init()
        (ARD_D6 output for alarm signaling)
        (ARD_D2/D4 inputs + ARD_D8 EXTI only in distributed mode)
    --> Create SDQueueHandle, SDRemaphoreHandle
    --> Create SD_Write_Task
    --> Create Audio_Loopback_Task
    --> Create System_Controller_Task
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
          * memset(dst, 0) to silence output
          * IF g_StartRecording AND not yet reached TARGET_BYTES:
            - RB_Write(src) into RecRB
            - Release semaphore to wake SD_Write_Task
          * IF target reached: set g_RecordingComplete = 1
      - MODE_PLAY:
          * RB_Read(dst) to pull audio from PlayRB
          * If underrun (not enough data): zero-pad remainder (silence)
          * Release semaphore to wake SD_Write_Task for refill
      - MODE_FULL_DUPLEX:
          * IF g_StartRecording:
            - PLAY PATH: RB_Read(PlayRB --> dst)
            - RECORD PATH: RB_Write(src --> RecRB)
            - If target reached: set g_RecordingComplete = 1
          * ELSE: output silence (SD still opening files)
          * Release semaphore
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
   b. Set g_Busy = 1

   === IF MODE_RECORD ===
   c. SD_Open_Rec() — build filename, reset state, open file, write placeholder WAV header
   d. RECORDING LOOP:
      - Wait on semaphore (released by audio task)
      - If RecRB has >= 4096 bytes: read chunk, f_write() to SD
      - If recording complete + leftover data: flush remainder
      - Break when g_RecordingComplete AND ring buffer drained
   e. Seek to file offset 0, write final WAV header with correct size
   f. f_close(), increment g_FileIndex

   === IF MODE_PLAY ===
   c. SD_Open_Play() — open WAV file, skip 44-byte header, reset PlayRB
   d. PLAYBACK LOOP:
      - Wait on semaphore (released by audio task after consuming data)
      - If PlayRB has free space >= 4096 bytes: f_read() + RB_Write()
      - If end of file: wait for buffer to drain, break
   e. f_close(), print "Playback complete."

   === IF MODE_FULL_DUPLEX ===
   c. SD_Open_Play() — open WAV, pre-fill PlayRB to avoid start glitches
   d. SD_Open_Rec() — open recording file
   e. FULL DUPLEX LOOP:
      - Wait on semaphore
      - PLAY: if PlayRB has space, f_read() from WAV into PlayRB
      - RECORD: if RecRB has data >= 4096 bytes, RB_Read() + f_write() to SD
      - If recording complete: flush leftover, break
   f. Finalize WAV header, f_close() both files
   g. Increment g_FileIndex

   === ALL MODES ===
   h. Check_Alarm() — if alarm was active, mark executed and reload alarm list
   i. Debounce delay (500ms), set g_Busy = 0, go back to step (a)
```

### 4. System_Controller_Task (runs continuously)

```
LOOP FOREVER:
  IF standalone mode AND not busy AND no alarm pending:
    Show "Set Alarm" button on LCD
    Display "Waiting for alarm..."

  Block on ExtiSemaphoreHandle (wakes on EXTI or RTC alarm)

  IF busy: ignore and continue

  IF distributed mode AND alarm flag AND EXTI flag:
    Read ARD_D2 and ARD_D4 pins to determine mode:
      D4=0, D2=1 (0b01) → MODE_RECORD
      D4=1, D2=0 (0b10) → MODE_PLAY
      D4=1, D2=1 (0b11) → MODE_FULL_DUPLEX
    Set g_ButtonPressed = 1 to trigger SD_Write_Task

  ELSE IF standalone mode AND alarm flag:
    Set g_Mode = MODE_FULL_DUPLEX
    Set g_ButtonPressed = 1 (auto-start)

  Clear g_ExtiFlag
```

### 5. DMA Callbacks (interrupt context)

The SAI DMA triggers two callbacks defined in `audio_record_linein_simple.c`:

- **`BSP_AUDIO_IN_HalfTransfer_CallBack()`** - First half of `RecordBuffer` is filled. Posts `BUFFER_OFFSET_HALF (1)` to `SDQueueHandle`.
- **`BSP_AUDIO_IN_TransferComplete_CallBack()`** - Second half is filled. Posts `BUFFER_OFFSET_FULL (2)` to `SDQueueHandle`.

These wake up `Audio_Loopback_Task` which then processes the corresponding buffer half.

### 6. Button Press (interrupt context)

```
USER button press
    --> EXTI interrupt
    --> BSP_PB_Callback(BUTTON_USER)
    --> g_ButtonPressed = 1
    --> SD_Write_Task detects it in its polling loop
```

### 7. EXTI from RF Board (distributed mode only)

```
ARD_D8 rising edge
    --> EXTI3 interrupt
    --> HAL_GPIO_EXTI_Callback()
    --> g_ExtiFlag = 1
    --> osSemaphoreRelease(ExtiSemaphoreHandle)
    --> System_Controller_Task reads ARD_D2/D4, sets g_Mode + g_ButtonPressed
```

---

## Ring Buffers

Two independent ring buffers decouple the fast, real-time audio DMA from the variable-latency SD card I/O:

| Ring Buffer | Variable | Size | Location | Purpose |
|-------------|----------|------|----------|---------|
| **RecRB** | `RB_Rec_Buffer` | 128 KB | AXI_SRAM | Mic/LINE_IN data to SD card |
| **PlayRB** | `RB_Play_Buffer` | 128 KB | AXI_SRAM | SD card data to DAC output |

Each ring buffer holds ~400 ms of stereo 48 kHz / 16-bit audio.

**In RECORD mode:**
- **Producer:** `Audio_Loopback_Task` via `RB_Write(&RecRB, ...)` — writes DMA half-buffer chunks (mic data).
- **Consumer:** `SD_Write_Task` via `RB_Read(&RecRB, ...)` — reads in 4 KB (`scratch_buf`) chunks to write to SD.

**In PLAY mode:**
- **Producer:** `SD_Write_Task` via `RB_Write(&PlayRB, ...)` — reads 4 KB chunks from SD file into ring buffer.
- **Consumer:** `Audio_Loopback_Task` via `RB_Read(&PlayRB, ...)` — pulls data into `PlayBuffer` for DAC output.

**In FULL_DUPLEX mode (both ring buffers active):**
- `RecRB`: Audio task writes mic data, SD task reads to file (same as RECORD).
- `PlayRB`: SD task writes from file, Audio task reads to DAC (same as PLAY).

**Synchronization:**
- Each `RingBuffer_t` struct contains `head` (write index), `tail` (read index), and `count` (bytes available)
- `count` updates are protected by `__disable_irq()` / `__enable_irq()` for atomicity
- A semaphore (`SDRemaphoreHandle`) wakes the SD task when new data is available
- Overflow detection: if ring buffer is full, `RB_Write()` drops the data and lights `LED_ERROR`
- `RB_GetFreeSpace()` used to check available space before writing

---

## RTC (Real-Time Clock)

The RTC is clocked by the LSE (32.768 kHz) crystal and persists across resets using the backup domain:

| Feature | Details |
|---------|---------|
| Clock Source | LSE (Low-Speed External, 32.768 kHz) |
| Format | 24-hour |
| Prescaler | Async=127, Sync=255 (gives 1 Hz tick) |
| Persistence | Backup register `RTC_BKP_DR1` stores `0xBEBE` magic value. On boot, if present, the RTC keeps its time and skips re-initialization. |
| First Boot | If `Year == 0x00`, the LCD touchscreen prompts the user to set date and time. |
| Alarm | Uses RTC Alarm A with interrupt. Supports match by weekday, date, or time only. |

### RTC Alarm Flow

1. User sets alarm via LCD touchscreen (standalone) or alarms are loaded from `ALARMS.TXT` (distributed).
2. When the RTC alarm fires, `HAL_RTC_AlarmAEventCallback()` sets `g_AlarmFlag = 1` and releases `ExtiSemaphoreHandle`.
3. `System_Controller_Task` wakes up and starts the appropriate operation (full-duplex in standalone, pin-selected mode in distributed).
4. After the operation completes, `Check_Alarm()` calls `FS_MarkAlarmExecuted()` to mark the alarm as done and `FS_ReadAlarmList()` to load the next pending alarm.
5. The alarm output pin ARD_D6 (PD15) is set HIGH when the alarm triggers and reset after the operation completes.

---

## Alarm File Persistence (ALARMS.TXT)

Alarms are persisted on the SD card in `ALARMS.TXT`. Each line has the format:

```
[STATUS] [TYPE] [WEEKDAY] [HH]:[MM]:[SS]
```

| Field | Values | Description |
|-------|--------|-------------|
| STATUS | `0` = Pending, `1` = Executed | Whether the alarm has already fired |
| TYPE | `0` = One-shot, `1` = Weekly | Alarm recurrence |
| WEEKDAY | `01`-`07` (Mon-Sun) | Day of the week |
| HH:MM:SS | `00:00:00`-`23:59:59` | Alarm time |

Example `ALARMS.TXT`:
```
1 0 05 08:00:00    <- Already executed
1 0 05 14:30:00    <- Already executed
0 0 05 09:15:00    <- Next to run
0 0 07 20:00:00    <- Pending
```

On boot (distributed mode), `FS_ReadAlarmList()` parses the file and programs the next pending alarm into RTC Alarm A. After each alarm fires, `FS_MarkAlarmExecuted()` updates the status field and `FS_ReadAlarmList()` reprograms the next one.

---

## Speaker Output & WM8994 Codec Configuration

The `Audio_LoopbackInit()` function in `audio_record_linein_simple.c` configures:

1. **Audio Output:** Speaker + Headphone/Line-Out (`AUDIO_OUT_DEVICE_SPK_HP`), stereo, 48 kHz, 16-bit, volume 80
2. **Amplifier Mode:** Class D (codec default). Class AB is available as an option — see below.
3. **Audio Input:** LINE_IN (Analog Line 1), stereo, 48 kHz, 16-bit, volume 80

### Simultaneous Speaker + Headphone/Line-Out (`AUDIO_OUT_DEVICE_SPK_HP`)

Using `AUDIO_OUT_DEVICE_SPK_HP` drives the **passive speaker pins (SPKOUTL/R)** and the
**headphone/line-out jack (HPOUT1L/R)** at the same time. Getting this working required
fixes at three layers — the stock STM32Cube WM8994 driver does **not** route speaker audio
correctly out of the box (a known issue discussed on the ST community forum).

**SAI TDM slot routing** (`stm32h735g_discovery_audio.c`) — each output device maps to a slot set:

| Device | SAI Slots | Feeds |
|--------|-----------|-------|
| `AUDIO_OUT_DEVICE_HEADPHONE` | `SLOT_02` | DAC1 → HPOUT1 only |
| `AUDIO_OUT_DEVICE_SPEAKER` | `SLOT_13` | DAC2 → SPKOUT only |
| `AUDIO_OUT_DEVICE_SPK_HP` | `SLOT_0123` | DAC1 (HP) **and** DAC2 (SPK) |

**Driver / BSP fixes required for `AUDIO_OUT_DEVICE_SPK_HP`:**

| Layer | File | Change | Why |
|-------|------|--------|-----|
| BSP | `stm32h735g_discovery_audio.c` | `AUDIO_OUT_DEVICE_SPK_HP` → `WM8994_OUT_BOTH` (was `WM8994_OUT_SPEAKER`) | The SAI sends all 4 slots, but the codec only configured the speaker path — the headphone/line-out DAC1 mixers were never enabled, leaving the jack silent. `WM8994_OUT_BOTH` enables both DAC1 (HP) and DAC2 (SPK) paths. |
| Codec | `wm8994.c` (Init + Play paths) | `WM8994_SPEAKER_MIXER` (reg `0x36`) `0x0300` → `0x0303` | Stock value only unmutes DAC2 → speaker mixers. `0x0303` also unmutes DAC1 (bits 0-1), so audio on SAI slots 0/2 actually reaches the speaker mixer. |

Register `0x36` (`WM8994_SPEAKER_MIXER`) bit map:

| Bit | Path | `0x0300` (stock) | `0x0303` (fixed) |
|-----|------|:----------------:|:----------------:|
| 9 | DAC2L → SPKMIXL | ✅ | ✅ |
| 8 | DAC2R → SPKMIXR | ✅ | ✅ |
| 1 | DAC1L → SPKMIXL | ❌ | ✅ |
| 0 | DAC1R → SPKMIXR | ❌ | ✅ |

### Class D vs Class AB Amplifier Mode

The WM8994 speaker amplifier mode is controlled by **bit 8 (`SPKOUT_CLASSAB`) of register `0x23`** (`WM8994_SPKMIXR_ATT`):

| Reg `0x23` value | Mode | Notes |
|------------------|------|-------|
| `0x0000` | **Class D** | Codec default (set by `WM8994_Init`). Higher efficiency. |
| `0x0100` | **Class AB** | Bit 8 set. Lower noise / better quality for passive speakers, higher power draw. |

- **To use Class D (current default):** leave the `Audio_EnableClassAB()` call commented out in `Audio_LoopbackInit()`. The codec init already writes `0x0000`, and nothing else overwrites it.
- **To use Class AB:** uncomment the `Audio_EnableClassAB()` call in `Audio_LoopbackInit()`. It read-modify-writes reg `0x23` to set bit 8, after `BSP_AUDIO_OUT_Init()` and before `BSP_AUDIO_IN_Init()`. No later codec call (`Play`, `Resume`, `SetVolume`, `SetMute`, input init) touches reg `0x23`, so the setting persists.

> **Note:** `Audio_EnableClassAB()` is currently **commented out**, so the board boots in **Class D**.

`Audio_PrintSpeakerMode()` reads reg `0x23` back over I2C and prints the active mode to UART
at boot (called from `main()` after `Audio_LoopbackInit()`), e.g.:

```
SPK reg 0x23=0x0000 -> Class D
SPK reg 0x23=0x0100 -> Class AB
```

### Line-In Configuration (optional helper)

`Audio_FixLineInConfig()` is an optional helper (defined but **not currently called** — the BSP
`WM8994_Init` LINE_IN path handles input routing) that applies direct I2C register writes to
force VMID/bias and disable the +30 dB input boost:

| Register | Value  | Purpose |
|----------|--------|---------|
| `0x01`   | `0x0007` | Enable VMID + bias (critical for negative audio cycle) |
| `0x29`   | `0x0020` | Left channel: route IN1L to mixer, disable +30 dB boost |
| `0x2A`   | `0x0020` | Right channel: route IN1R to mixer, disable +30 dB boost |

---

## LCD Touchscreen Interface

The 480x272 LCD with capacitive touch provides a full GUI for system configuration:

| Screen | Function |
|--------|----------|
| **Start Menu** | Displays firmware version on boot |
| **Date/Time Setup** | Touch-based date and time entry (shown on first boot or if RTC year is 0) |
| **Mode Selection** | Choose between Standalone and Distributed Node operation |
| **Standalone Menu** | Shows standalone mode info and version |
| **RF Menu** | Shows distributed mode info, loads alarm list from SD |
| **Set Alarm** | Touchscreen alarm workflow: pick time, weekday(s), repetition count and interval |
| **Waiting Screen** | Displays "Waiting for alarm..." in standalone idle state |

---

## GPIO Pin Mapping (Arduino Header)

| Pin Name | STM32 Pin | Direction | Purpose |
|----------|-----------|-----------|---------|
| **ARD_D2** | PG3 | Input (pull-down) | Mode selector bit 0 (from RF board) |
| **ARD_D4** | PG4 | Input (pull-down) | Mode selector bit 1 (from RF board) |
| **ARD_D6** | PD15 | Output | Alarm signaling pin (HIGH = alarm active) |
| **ARD_D8** | PE3 | EXTI rising edge (pull-down) | Trigger from RF board (dedicated EXTI3_IRQn) |

ARD_D2, D4, and D8 are only configured in distributed mode (`system_mode == 1`) to avoid spurious interrupts from floating pins in standalone mode. ARD_D6 is always configured as an output.

---

## MPU Configuration

Four MPU regions are configured for DMA and LCD coherency:

| Region | Address | Size | Config | Purpose |
|--------|---------|------|--------|---------|
| 0 | `0x00000000` | 4 GB | No access (background) | Default deny |
| 1 | `0x38000000` | 64 KB | Non-cacheable, shareable | D3 SRAM (DMA audio buffers) |
| 2 | `0x24000000` | 512 KB | Non-cacheable, shareable | AXI SRAM (ring buffers, FatFs) |
| 3 | `0x70000000` | 16 MB | Write-through, cacheable | OSPI RAM (LCD framebuffer) |

Non-cacheable configuration on regions 1 and 2 is **critical** - without it, the CPU cache and DMA see different data, causing audio corruption. Region 3 uses write-through caching so the LTDC can read the framebuffer correctly.

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

The playback WAV file is configurable via `audio_play` variable (e.g., `"PIANO1.WAV"`).

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
  - Code: PLL2N = varies
  - Math: $5 \text{ MHz} \times N = \text{VCO frequency}$.

---

## Important Variables Reference

### Mode & Control Flags

| Variable | Type | Set By | Purpose |
|----------|------|--------|---------|
| `g_Mode` | `volatile uint8_t` | Compile-time / System_Controller_Task | Selects operating mode: `MODE_PASSTHROUGH` (0), `MODE_RECORD` (1), `MODE_PLAY` (2), `MODE_FULL_DUPLEX` (3) |
| `system_mode` | `uint8_t` | LCD touchscreen (boot) | System architecture: Standalone (0), Distributed (1), Not set (2) |
| `g_ButtonPressed` | `volatile uint8_t` | Button ISR / System_Controller_Task | Signals SD task that user pressed the button or alarm/EXTI triggered |
| `g_StartRecording` | `volatile uint8_t` | SD_Write_Task | Tells audio task to start filling ring buffer (RECORD/FULL_DUPLEX) |
| `g_RecordingComplete` | `volatile uint8_t` | Audio_Loopback_Task | Signals SD task that target size was reached |
| `g_SDReady` | `volatile uint8_t` | SD_Write_Task | Indicates file is open and ready for data |
| `g_Busy` | `volatile uint8_t` | SD_Write_Task | 1 while recording/playing — blocks new commands from System_Controller |
| `g_ExtiFlag` | `volatile uint8_t` | EXTI3 ISR (ARD_D8) | Set to 1 when RF board triggers operation |
| `g_AlarmFlag` | `volatile uint8_t` | RTC Alarm ISR | Set to 1 when RTC alarm fires |
| `g_FileIndex` | `uint32_t` | SD_Write_Task (scan + increment) | Current file number for `REC_XX.WAV` naming |
| `flag_set_time` | `uint8_t` | Boot logic | Forces date/time setup via LCD if RTC is uninitialized |

### Buffer / Counter Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `total_bytes_recorded` | `uint32_t` | Bytes captured from DMA (audio task side) |
| `total_sd_bytes_written` | `uint32_t` | Bytes written to SD file (SD task side, local) |
| `TARGET_BYTES` | `const uint32_t` | Recording limit: `48000 * 2 * 2 * 15 = 2,880,000` bytes |
| `underrun_count` | `volatile uint32_t` | Tracks playback buffer underruns (full-duplex debugging) |
| `play_file_is_open` | `uint8_t` | Tracks whether the playback file is still open (full-duplex) |

### Audio Buffers

| Buffer | Size | Location | Purpose |
|--------|------|----------|---------|
| `RecordBuffer` | 4096 x `int16_t` (8 KB) | RAM_D3 | DMA fills this with ADC samples |
| `PlayBuffer` | 4096 x `int16_t` (8 KB) | RAM_D3 | DMA reads this for DAC output |
| `RB_Rec_Buffer` | 128 KB | AXI_SRAM | Ring buffer: mic-to-SD (RECORD / FULL_DUPLEX) |
| `RB_Play_Buffer` | 128 KB | AXI_SRAM | Ring buffer: SD-to-DAC (PLAY / FULL_DUPLEX) |
| `scratch_buf` | 4 KB | AXI_SRAM | Temporary buffer for SD card reads/writes |

### Ring Buffer Structs

| Struct | Members | Purpose |
|--------|---------|---------|
| `RecRB` | `RingBuffer_t` with `buffer = RB_Rec_Buffer` | Recording ring buffer instance |
| `PlayRB` | `RingBuffer_t` with `buffer = RB_Play_Buffer` | Playback ring buffer instance |

### RTOS Synchronization Objects

| Object | Type | Purpose |
|--------|------|---------|
| `SDQueueHandle` | Message Queue (2 entries) | DMA callbacks post HALF/FULL state to audio task |
| `SDRemaphoreHandle` | Semaphore | Audio task releases it to wake SD task when data is ready |
| `ExtiSemaphoreHandle` | Semaphore | EXTI and RTC alarm callbacks release it to wake System_Controller_Task |

---

## Build Configuration

- **Toolchain:** GCC (ARM) via STM32CubeIDE
- **RTOS:** FreeRTOS (CMSIS-RTOS v2 API)
- **DSP:** CMSIS-DSP (`arm_math.h`) - FFT initialized but not actively used in recording flow
- **File System:** FatFs (FAT32 on microSD)
- **HAL:** STM32H7 HAL + BSP drivers for STM32H735G-DK
- **LCD:** BSP LCD driver + UTIL_LCD drawing functions + touchscreen (FT5336/GT911)
- **RTC:** HAL RTC with LSE, Alarm A interrupt, backup domain persistence

---

## Quick Reference: What Activates What

| Trigger | Action |
|---------|--------|
| Power on / Reset | `main()` initializes HW, prompts for date/time if needed, selects system mode via LCD, creates tasks, starts RTOS |
| RTOS starts | `Audio_Loopback_Task` begins processing DMA buffers based on `g_Mode` |
| RTOS starts | `SD_Write_Task` mounts SD, scans files, waits for button |
| RTOS starts | `System_Controller_Task` enters idle loop, waits for EXTI or alarm |
| DMA half-transfer IRQ | Posts `BUFFER_OFFSET_HALF` to `SDQueueHandle` |
| DMA full-transfer IRQ | Posts `BUFFER_OFFSET_FULL` to `SDQueueHandle` |
| Message in `SDQueueHandle` | Wakes `Audio_Loopback_Task` to process buffer half |
| USER button press | Sets `g_ButtonPressed = 1` via EXTI callback |
| ARD_D8 EXTI (distributed) | Sets `g_ExtiFlag = 1`, releases `ExtiSemaphoreHandle` |
| RTC Alarm A | Sets `g_AlarmFlag = 1`, raises ARD_D6 pin, releases `ExtiSemaphoreHandle` |

### MODE_PASSTHROUGH
| Trigger | Action |
|---------|--------|
| DMA callback | Audio task copies `RecordBuffer` to `PlayBuffer` (mic to speaker/headphone) |
| USER button press | No effect (passthrough runs continuously) |

### MODE_RECORD
| Trigger | Action |
|---------|--------|
| `g_ButtonPressed` detected | SD task opens `REC_XX.WAV`, sets `g_StartRecording = 1` |
| `g_StartRecording == 1` | Audio task writes mic data to RecRB, outputs silence |
| Semaphore released | Wakes SD task to drain RecRB to SD card |
| `total_bytes_recorded >= TARGET_BYTES` | Audio task sets `g_RecordingComplete = 1` |
| `g_RecordingComplete == 1` + buffer drained | SD task finalizes WAV header, closes file, waits for next trigger |

### MODE_PLAY
| Trigger | Action |
|---------|--------|
| `g_ButtonPressed` detected | SD task opens WAV file, skips header, resets PlayRB |
| SD task reads from file | `f_read()` into `scratch_buf`, then `RB_Write()` into PlayRB |
| DMA callback | Audio task pulls data from PlayRB into `PlayBuffer` via `RB_Read()` |
| Semaphore released | Wakes SD task to refill PlayRB from SD |
| End of file (`bytesRead < 4096`) | SD task waits for buffer to drain, then closes file |
| Playback complete | SD task waits for next trigger to replay |

### MODE_FULL_DUPLEX
| Trigger | Action |
|---------|--------|
| `g_ButtonPressed` detected | SD task opens WAV for playback, pre-fills PlayRB, opens REC file |
| `g_StartRecording` set | Audio task simultaneously reads PlayRB to DAC and writes ADC to RecRB |
| Semaphore released | Wakes SD task to refill PlayRB from file AND drain RecRB to file |
| Playback file ends | SD task closes play file, continues recording only |
| `total_bytes_recorded >= TARGET_BYTES` | Audio task sets `g_RecordingComplete`, SD task finalizes both files |
| Operation complete | `Check_Alarm()` marks alarm as executed if applicable |
