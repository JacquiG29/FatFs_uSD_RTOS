/**
 * =============================================================================
 * MINIMAL AUDIO LOOPBACK - STM32H735G-DK
 * =============================================================================
 *
 * Records from LINE_IN and plays to headphone.
 * Based on minimal_loopback.c example - stripped down to essentials.
 *
 * Hardware path:
 *   LINE_IN jack -> WM8994 ADC -> SAI -> DMA -> RecordBuffer
 *   PlayBuffer -> DMA -> SAI -> WM8994 DAC -> Headphone jack
 *
 * Usage:
 *   1. Call Audio_LoopbackInit() to initialize both input and output
 *   2. Call BSP_AUDIO_IN_Record() to start recording
 *   3. Poll audio_rec_buffer_state in your task loop
 *   4. Copy RecordBuffer to PlayBuffer with cache management
 *   5. Call BSP_AUDIO_OUT_Play() once when first data is ready
 *
 * =============================================================================
 */

#include "main.h"
#include "audio_record.h"
#include "stm32h735g_discovery_bus.h"  /* For BSP_I2C4_WriteReg16 */
#include <string.h>
/* Add these includes if missing */
#include "stm32h735g_discovery_audio.h"
#include "../Components/wm8994/wm8994.h"
#include "stm32h735g_discovery_errno.h"
extern SAI_HandleTypeDef haudio_out_sai;
/* -----------------------------------------------------------------------------
 * BUFFERS - Must be in D3 SRAM for DMA access
 * -------------------------------------------------------------------------- */
/*#if defined(__GNUC__)
__attribute__((section(".RAM_D3")))
#endif
int16_t RecordBuffer[BUFFER_SIZE];

#if defined(__GNUC__)
__attribute__((section(".RAM_D3")))
#endif
int16_t PlayBuffer[BUFFER_SIZE];
*/

/* Add ALIGN_32BYTES macro if available, or use attribute */
#if defined(__GNUC__)
__attribute__((section(".RAM_D3"), aligned(32)))
#endif
int16_t RecordBuffer[BUFFER_SIZE];

#if defined(__GNUC__)
__attribute__((section(".RAM_D3"), aligned(32)))
#endif
int16_t PlayBuffer[BUFFER_SIZE];


/* State flag - single state variable */
/* Defined in main.c, extern here */
extern volatile uint32_t audio_rec_buffer_state;
/* Keep PlaybackStarted here since Audio_LoopbackInit is in this file */
volatile uint8_t PlaybackStarted = 0;

/* -----------------------------------------------------------------------------
 * INITIALIZATION
 * -------------------------------------------------------------------------- */
/**
 * @brief Initialize audio loopback (LINE_IN input + headphone output)
 * @retval 0 on success, negative on failure
 */
int Audio_LoopbackInit(void)
{
    BSP_AUDIO_Init_t AudioInInit;
    BSP_AUDIO_Init_t AudioOutInit;
    /* Configure audio OUTPUT (Headphone) */
    AudioOutInit.Device        = AUDIO_OUT_DEVICE_HEADPHONE;
    AudioOutInit.ChannelsNbr   = 2;
    AudioOutInit.SampleRate    = AUDIO_FREQUENCY_48K;
    AudioOutInit.BitsPerSample = AUDIO_RESOLUTION_16B;
    AudioOutInit.Volume        = 20;

    if (BSP_AUDIO_OUT_Init(0, &AudioOutInit) != BSP_ERROR_NONE)
    {
        return -2;  /* Failed */
    }


    /* Configure audio INPUT (LINE_IN) */
    AudioInInit.Device        = AUDIO_IN_DEVICE_ANALOG_LINE1;  /* LINE_IN jack */
    AudioInInit.ChannelsNbr   = 2;                             /* Stereo */
    AudioInInit.SampleRate    = AUDIO_FREQUENCY_48K;
    AudioInInit.BitsPerSample = AUDIO_RESOLUTION_16B;
    AudioInInit.Volume        = 100;

    /* Instance 0 = SAI/LINE_IN (NOT Instance 2 which is DFSDM/digital mics) */
    if (BSP_AUDIO_IN_Init(0, &AudioInInit) != BSP_ERROR_NONE)
    {
        return -1;  /* Failed - check codec I2C connection */
    }

    return 0;
}


/* -----------------------------------------------------------------------------
 * BSP CALLBACKS - Called from DMA interrupt
 * -------------------------------------------------------------------------- */

/**
 * @brief First half of record buffer filled by DMA
 */
void BSP_AUDIO_IN_HalfTransfer_CallBack(uint32_t Instance)
{
  if (Instance == 0)
  {
    audio_rec_buffer_state = 1;  /* BUFFER_OFFSET_HALF */
  }
}
/**
 * @brief Second half of record buffer filled (full buffer complete)
 */
void BSP_AUDIO_IN_TransferComplete_CallBack(uint32_t Instance)
{
  if (Instance == 0)
  {
    audio_rec_buffer_state = 2;  /* BUFFER_OFFSET_FULL */
  }
}

/**
 * @brief Audio input error
 */
void BSP_AUDIO_IN_Error_CallBack(uint32_t Instance)
{
    (void)Instance;
}
/* -----------------------------------------------------------------------------
 * WM8994 - Override some configurations of the original library
 * Not used for the moment, changes where done directly on the original file
 * -------------------------------------------------------------------------- */
/* WM8994 I2C address (7-bit shifted left = 0x34) */
#define WM8994_I2C_ADDR  0x34

/**
 * @brief  Helper to write a 16-bit value to WM8994 register
 *         Handles byte swapping required by codec
 */
static int WM8994_WriteReg(uint16_t reg, uint16_t value)
{
    /* WM8994 expects data in big-endian format (MSB first) */
    uint8_t data[2];
    data[0] = (value >> 8) & 0xFF;  /* MSB */
    data[1] = value & 0xFF;         /* LSB */

    if (BSP_I2C4_WriteReg16(WM8994_I2C_ADDR, reg, data, 2) != BSP_ERROR_NONE)
        return -1;

    return 0;
}


/**
 * @brief  Fixes Line-In configuration:
 * 1. Enables VMID (Critical for negative cycle)
 * 2. Enables Analog Input Mixers
 * 3. Disables the +30dB Microphone Boost
 */
int Audio_FixLineInConfig(void)
{
    // Enable VMID and Bias (Register 0x01) ---
    // Bit 2 (BIAS_ENA): 1 (Enable Master Bias)
    // Bits 1:0 (VMID_SEL): 11 (Enable VMID 2x5k divider for fast start)
    // Without this, the input pin sits at 0V and clips negative audio.
    if (WM8994_WriteReg(0x01, 0x0007) != 0) return -1;


    // Connect Line-In to Mixer & Disable Boost (Reg 0x29 & 0x2A) ---
    /* WM8994 INPUT_MIXER_3 (0x29) and INPUT_MIXER_4 (0x2A)
     * Current value: 0x0035 = IN1L_TO_MIXINL(bit5) + IN1L_MIXINL_VOL(bit4=+30dB) + mixer_vol(bits0-2)
     * New value: 0x0020 = IN1L_TO_MIXINL only (0dB boost)
     *
     * Bit 5: IN1L_TO_MIXINL - Route IN1L to MIXINL (must be 1)
     * Bit 4: IN1L_MIXINL_VOL - 0=0dB, 1=+30dB (set to 0 to disable boost)
     * Bits 0-2: MIXOUTL_MIXINL_VOL - Output mixer record volume
     */
	uint16_t line_in_cfg = 0x0020; // 0b0000_0000_0010_0000

	// Configure LEFT channel
	if (WM8994_WriteReg(0x0029, line_in_cfg) != 0) return -1;

	// Configure RIGHT channel (if recording stereo)
	if (WM8994_WriteReg(0x002A, line_in_cfg) != 0) return -1;

    /* Also disable DRC (Dynamic Range Compressor) which might be clipping
     * Register 0x440 = AIF1_DRC1 - set to 0x0098 to disable DRC
     * Default was 0x00DB which enables DRC with signal detect
     */
    if (WM8994_WriteReg(0x0440, 0x0098) != 0)
        return -3;

    /* Reduce LINE_IN PGA gain to prevent any remaining clipping
     * Register 0x18/0x1A: Set to 0x03 for -12dB (from 0dB default of 0x0B)
     */
    if (WM8994_WriteReg(0x0018, 0x0003) != 0)
        return -4;
    if (WM8994_WriteReg(0x001A, 0x0003) != 0)
        return -5;
    return 0; // Success
}

