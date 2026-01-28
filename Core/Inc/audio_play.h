/**
 * =============================================================================
 * AUDIO PLAYBACK HEADER - STM32H735G-DK (OPTIONAL)
 * =============================================================================
 *
 * Optional header for standalone audio playback.
 * For loopback, use audio_record.h instead - it includes both input and output.
 *
 * This file is kept for future use if you need playback-only functionality.
 *
 * =============================================================================
 */

#ifndef AUDIO_PLAY_H
#define AUDIO_PLAY_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/* NOTE: For loopback, use Audio_LoopbackInit() from audio_record.h instead.
 *       These functions are for standalone playback only.
 */

/**
 * @brief  Initialize audio output only (headphone)
 * @retval 0 on success, non-zero on failure
 */
int Audio_PlaybackInit(void);

#ifdef __cplusplus
}
#endif

#endif /* AUDIO_PLAY_H */
