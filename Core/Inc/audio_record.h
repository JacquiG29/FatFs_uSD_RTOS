/**
 * =============================================================================
 * MINIMAL AUDIO LOOPBACK HEADER - STM32H735G-DK
 * =============================================================================
 *
 * Simple header for LINE_IN recording + headphone playback (loopback).
 * Based on minimal_loopback.c example.
 *
 * Usage in main.c:
 *   1. Call Audio_LoopbackInit() once
 *   2. Access RecordBuffer, PlayBuffer, HalfReady, FullReady, PlaybackStarted
 *   3. Process in your task loop (see Audio_Task example)
 *
 * =============================================================================
 */

#ifndef AUDIO_RECORD_H
#define AUDIO_RECORD_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include <stdint.h>

/* Configuration -------------------------------------------------------------*/
#define AUDIO_SAMPLE_RATE       48000   /* Hz */
#define AUDIO_VOLUME            30      /* Input gain 0-100 */
#define BUFFER_SIZE             4096    /* Samples (not bytes) */
#define BIG_BUFFER_SIZE  0 // 1 second of mono audio (or 0.5s stereo)

/* Buffers - defined in audio_loopback.c, placed in RAM_D3 for DMA */
extern int16_t RecordBuffer[BUFFER_SIZE];
extern int16_t PlayBuffer[BUFFER_SIZE];


/* State flags - set by DMA callbacks, clear in your task after processing */
extern volatile uint8_t HalfReady;      /* First half of buffer ready */
extern volatile uint8_t FullReady;      /* Second half of buffer ready */
extern volatile uint8_t PlaybackStarted;


/* Functions -----------------------------------------------------------------*/

/**
 * @brief  Initialize audio loopback (LINE_IN + headphone)
 * @retval 0 on success, negative on failure
 */
int Audio_LoopbackInit(void);
int Audio_FixLineInConfig(void);
int Audio_Unified_Init(uint32_t AudioFreq);

#ifdef __cplusplus
}
#endif

#endif /* AUDIO_RECORD_H */
