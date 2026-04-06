/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file    FatFs/FatFs_uSD_RTOS/Core/Inc/main.h
  * @author  MCD Application Team
  * @brief   Header for main.c module
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2019 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include "stm32h7xx_hal.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "stm32h735g_discovery.h"
#include "cmsis_os.h"
#include "stm32h735g_discovery_sd.h"
#include "stm32h7xx_hal_uart.h"
#include "stm32h735g_discovery_bus.h"
#include "stm32h735g_discovery_audio.h"
#include "stm32h735g_discovery_lcd.h"
#include "stm32_lcd.h"  // For UTIL_LCD_* drawing functions
#include "audio_record.h" /* Provides Audio_LoopbackInit() and buffers */
#include "rtc_functions.h"
#include "lcd_function.h"

#define ARD_D6_PIN    GPIO_PIN_15   /* PD15 - output */
#define ARD_D6_PORT   GPIOD
/* USER CODE END Includes */

/* Exported types ------------------------------------------------------------*/
/* USER CODE BEGIN ET */

/* USER CODE END ET */

/* Exported constants --------------------------------------------------------*/
/* USER CODE BEGIN EC */

/* USER CODE END EC */

/* Exported macro ------------------------------------------------------------*/
/* USER CODE BEGIN EM */

/* USER CODE END EM */

/* Exported functions prototypes ---------------------------------------------*/
void Error_Handler(void);

/* USER CODE BEGIN EFP */

/* USER CODE END EFP */

/* Private defines -----------------------------------------------------------*/
/* USER CODE BEGIN Private defines */
#define LED_OK                     LED1
#define LED_ERROR                  LED2
#define APP_OK                     0
#define APP_ERROR                  -1
#define APP_SD_UNPLUGGED           -2
#define APP_INIT                   1

/* Convenient defines for your project */
#define AUDIO_IN_INSTANCE_LINE_IN       0   /* SAI - for LINE_IN jack */
#define AUDIO_IN_INSTANCE_PDM_MIC       1   /* SAI4 - PDM digital mic */
#define AUDIO_IN_INSTANCE_DIGITAL_MIC   2   /* DFSDM - on-board digital mics */

#define AUDIO_OUT_INSTANCE_HEADPHONE    0   /* SAI - headphone output */
/* Count of elements in an array */
#define COUNT_OF_EXAMPLE(x)     (sizeof(x) / sizeof((x)[0]))
/* Button state - can be used with interrupt callback */
extern uint32_t ButtonState;

/* Audio update flag - set by touchscreen interrupt (not used in simplified version) */
extern uint32_t AudioUpdate;

typedef enum {
	BUFFER_OFFSET_NONE = 0, BUFFER_OFFSET_HALF = 1, BUFFER_OFFSET_FULL = 2,
} BUFFER_StateTypeDef;

typedef enum {
	MODE_PASSTHROUGH = 0, // ROUTE INPUT TO OUTPUT
	MODE_RECORD = 1,      // RECORD TO SD CARD
	MODE_PLAY = 2,        // PLAY FROM SD CARD
	MODE_FULL_DUPLEX = 3, // PLAY AND RECORD FROM SD CARD
} Operation_StateTypeDef;

typedef struct {
	uint8_t *buffer;         // Pointer to the actual data array (AXI SRAM)
	uint32_t size;           // Total size
	volatile uint32_t head;  // Write index
	volatile uint32_t tail;  // Read index
	volatile uint32_t count; // Available bytes
} RingBuffer_t;
/* =============================================================================
 * FUNCTION PROTOTYPES - AUDIO PLAYBACK (from audio_play_simple.c)
 * ============================================================================= */

/**
 * @brief  Initialize audio output hardware
 * @return 0 on success, non-zero on failure
 */
int Audio_Init(void);

/**
 * @brief  Start audio playback
 */
void Audio_StartPlayback(void);

/**
 * @brief  Stop audio playback
 */
void Audio_StopPlayback(void);

/**
 * @brief  Process audio playback - CALL IN MAIN LOOP
 */
void Audio_Process(void);

/* =============================================================================
 * FUNCTION PROTOTYPES - AUDIO RECORDING (from audio_record_linein_simple.c)
 * ============================================================================= */

/**
 * @brief  Initialize LINE_IN audio input
 * @return 0 on success, non-zero on failure
 */
int Audio_RecordInit(void);

/**
 * @brief  Start recording from LINE_IN
 */
void Audio_StartRecording(void);

/**
 * @brief  Stop recording
 */
void Audio_StopRecording(void);

/**
 * @brief  Process recording - CALL IN MAIN LOOP
 */
void Audio_RecordProcess(void);

/**
 * @brief  Check if capture is complete
 * @return 1 if complete, 0 if still recording
 */
uint8_t Audio_IsCaptureComplete(void);

/**
 * @brief  Get pointer to captured data
 * @param  pSize  Output: number of samples captured
 * @return Pointer to capture buffer
 */
int16_t* Audio_GetCapturedData(uint32_t* pSize);

/* =============================================================================
 * FUNCTION PROTOTYPES - FULL DUPLEX (from audio_record_linein_simple.c)
 * ============================================================================= */

/**
 * @brief  Initialize full-duplex audio (LINE_IN + headphone simultaneously)
 * @return 0 on success, non-zero on failure
 */
int Audio_FullDuplexInit(void);

/**
 * @brief  Start full-duplex loopback
 */
void Audio_FullDuplexStart(void);

/**
 * @brief  Process full-duplex - CALL IN MAIN LOOP
 */
void Audio_FullDuplexProcess(void);

/* =============================================================================
 * FUNCTION PROTOTYPES - UTILITY
 * ============================================================================= */

/**
 * @brief  Check for user button input
 * @return 1 if button pressed, 0 otherwise
 */
uint8_t CheckForUserInput(void);

/* USER CODE END Private defines */

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */

