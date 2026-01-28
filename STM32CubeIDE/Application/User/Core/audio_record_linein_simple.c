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
 *   3. Poll HalfReady/FullReady flags in your task
 *   4. Copy RecordBuffer to PlayBuffer with cache management
 *   5. Call BSP_AUDIO_OUT_Play() once when first data is ready
 *
 * =============================================================================
 */

#include "main.h"
#include "audio_record.h"
#include <string.h>

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
/* State flags - set by callbacks, cleared by user task */
volatile uint8_t HalfReady = 0;
volatile uint8_t FullReady = 0;
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

    /* Configure audio INPUT (LINE_IN) */
    AudioInInit.Device        = AUDIO_IN_DEVICE_ANALOG_MIC;  /* LINE_IN jack */
    AudioInInit.ChannelsNbr   = 2;                             /* Stereo */
    AudioInInit.SampleRate    = AUDIO_FREQUENCY_48K;
    AudioInInit.BitsPerSample = AUDIO_RESOLUTION_16B;
    AudioInInit.Volume        = AUDIO_VOLUME;

    /* Instance 0 = SAI/LINE_IN (NOT Instance 2 which is DFSDM/digital mics) */
    if (BSP_AUDIO_IN_Init(0, &AudioInInit) != BSP_ERROR_NONE)
    {
        return -1;  /* Failed - check codec I2C connection */
    }
    //BSP_AUDIO_IN_GetState(2, &AudioInInit);

    /* Configure audio OUTPUT (Headphone) */
    AudioOutInit.Device        = AUDIO_OUT_DEVICE_HEADPHONE;
    AudioOutInit.ChannelsNbr   = 2;
    AudioOutInit.SampleRate    = AUDIO_FREQUENCY_48K;
    AudioOutInit.BitsPerSample = AUDIO_RESOLUTION_16B;
    AudioOutInit.Volume        = 70;

    if (BSP_AUDIO_OUT_Init(0, &AudioOutInit) != BSP_ERROR_NONE)
    {
        return -2;  /* Failed */
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
    //SCB_InvalidateDCache_by_Addr((uint32_t*)&RecordBuffer[0], (BUFFER_SIZE/2)*sizeof(int16_t));
    HalfReady = 1;
  }
}
/**
 * @brief Second half of record buffer filled (full buffer complete)
 */
void BSP_AUDIO_IN_TransferComplete_CallBack(uint32_t Instance)
{
  if (Instance == 0)
  {
    //SCB_InvalidateDCache_by_Addr((uint32_t*)&RecordBuffer[BUFFER_SIZE/2], (BUFFER_SIZE/2)*sizeof(int16_t));
    FullReady = 1;
  }
}

/**
 * @brief Audio input error
 */
void BSP_AUDIO_IN_Error_CallBack(uint32_t Instance)
{
    (void)Instance;
}

/* NOTE: BSP_AUDIO_OUT callbacks are defined in audio_play_simple.c */
