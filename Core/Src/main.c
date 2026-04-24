/* USER CODE BEGIN Header */
/**
 ******************************************************************************
 * @file    FatFs/FatFs_uSD_RTOS/Core/Src/main.c
 * @author  MCD Application Team
 * @brief   Main program body
 *          This sample code shows how to use FatFs with RAM disk drive.
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

/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "app_fatfs.h"
#include "cmsis_os.h"
#include <string.h>
#include "stdio.h"
#include "arm_math.h"
/* Private includes --------------
 * --------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */
/* Defines */
char version[10] = "1.3.7";
uint8_t system_mode = 2; //Standalone: 0, Distributed node: 1, Not set: 2
UART_HandleTypeDef huart3;
RTC_HandleTypeDef hrtc;
uint8_t flag_set_time = 1;
#define SD_SAMPLE_RATE 48000

/* ===== SET THIS BEFORE FLASHING TO SELECT MODE ===== */
volatile uint8_t g_Mode = MODE_PLAY; /* Change to MODE_PASSTHROUGH, MODE_RECORD, or MODE_PLAY */
#define RECORD_DURATION_SECONDS 15
const TCHAR *audio_play = "PIANO1.WAV";
/* WAV FILES NAMES:
 * ESS_F
 * SIN_1KL
 * SIN_1KR
 * SIN_1K
 * PIANO1
 * */
/* WAV Header Structure */
typedef struct {
	char chunkId[4];        // "RIFF"
	uint32_t chunkSize;     // Total file size - 8
	char format[4];         // "WAVE"
	char subchunk1Id[4];    // "fmt "
	uint32_t subchunk1Size; // 16 for PCM
	uint16_t audioFormat;   // 1 for PCM
	uint16_t numChannels;   // 2 for Stereo
	uint32_t sampleRate;    // 48000
	uint32_t byteRate;      // sampleRate * numChannels * bitsPerSample/8
	uint16_t blockAlign;    // numChannels * bitsPerSample/8
	uint16_t bitsPerSample; // 16
	char subchunk2Id[4];    // "data"
	uint32_t subchunk2Size; // Data size (bytes)
} __attribute__((packed)) WavHeader;

/* Helper to prepare header */
void Create_WAV_Header(WavHeader *header, uint32_t waveDataSize) {
	memcpy(header->chunkId, "RIFF", 4);
	header->chunkSize = waveDataSize + 36; // 36 + dataSize
	memcpy(header->format, "WAVE", 4);
	memcpy(header->subchunk1Id, "fmt ", 4);
	header->subchunk1Size = 16;
	header->audioFormat = 1; // PCM
	header->numChannels = 2; // Stereo
	header->sampleRate = SD_SAMPLE_RATE;
	header->byteRate = SD_SAMPLE_RATE * 2 * 2; // 192000
	header->blockAlign = 4;
	header->bitsPerSample = 16;
	memcpy(header->subchunk2Id, "data", 4);
	header->subchunk2Size = waveDataSize;
}

/* Ring Buffer Settings */
#define RB_SIZE (128 * 1024)  // 128KB Buffer (Approx 400ms of stereo audio at 48kHz)
#define SD_CHUNK_SIZE (4 * 1024)  // 4KB
__attribute__((section(".axi_sram")))    uint8_t RB_Rec_Buffer[RB_SIZE];  // From Mic
__attribute__((section(".axi_sram")))    uint8_t RB_Play_Buffer[RB_SIZE]; // To Speaker
/* Create a temporary buffer for SD writing to avoid reading 1 byte at a time */
__attribute__((section(".axi_sram")))    uint8_t scratch_buf[SD_CHUNK_SIZE]; // Shared temp buffer
__attribute__((section(".axi_sram")))    FATFS SDFatFs;
__attribute__((section(".axi_sram")))    FIL File_Rec;
__attribute__((section(".axi_sram")))    FIL File_Play;
/* Global variable to track total bytes recorded */
static uint32_t total_bytes_recorded = 0;
RingBuffer_t RecRB = { .buffer = RB_Rec_Buffer, .size = RB_SIZE, .head = 0,
		.tail = 0, .count = 0 };
RingBuffer_t PlayRB = { .buffer = RB_Play_Buffer, .size = RB_SIZE, .head = 0,
		.tail = 0, .count = 0 };

const uint32_t TARGET_BYTES = (SD_SAMPLE_RATE * 2 * 2 * RECORD_DURATION_SECONDS); // 48kHz * 16bit * Stereo * 5 seconds

/* Audio recording to SD card variables */
volatile uint8_t g_StartRecording = 0; /* Set to 1 to start recording */
volatile uint8_t g_RecordingComplete = 0;
volatile uint8_t g_SDReady = 0; /* Set to 1 when SD file is open and ready */
volatile uint8_t g_ButtonPressed = 0; /* Set to 1 by button ISR */
volatile uint8_t g_ExtiFlag = 0; /* Set to 1 by ARD_D8 (PE3) EXTI */
volatile uint8_t g_Busy = 0;    /* 1 while recording/playing — blocks new commands */
volatile uint8_t g_AlarmFlag = 0;
/* ---- Arduino header GPIO pin definitions ---- */
#define ARD_D2_PIN    GPIO_PIN_3   /* PG3 - input */
#define ARD_D4_PIN    GPIO_PIN_4   /* PG4 - input */
#define ARD_D2D4_PORT GPIOG

#define ARD_D8_PIN    GPIO_PIN_3   /* PE3 - EXTI (dedicated EXTI3_IRQn) */
#define ARD_D8_PORT   GPIOE
static uint32_t g_FileIndex = 1; /* Increments per recording: REC_01, REC_02, ... */

static uint32_t msg_count = 2;
static uint32_t msg_size = sizeof(uint32_t);

volatile uint32_t underrun_count = 0;
uint8_t play_file_is_open = 0;

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */
/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
/*Queue will notify when half and full ready are done to not overqrite data*/
osMessageQueueId_t SDQueueHandle;
/* Semaphore to wake up SD thread */
osSemaphoreId_t SDRemaphoreHandle;

osThreadId_t AudioTaskHandle;
static osThreadAttr_t audio_attr = { .priority = osPriorityAboveNormal,
		.stack_size = 8 * configMINIMAL_STACK_SIZE, /* Needs room for FatFs + audio */
};

osThreadId_t SEM_SDHandle;
static osThreadAttr_t sd_task_attr = { .stack_size = 4096, // FatFS needs a healthy stack size!
		.priority = (osPriority_t) osPriorityNormal, };

osThreadId_t SysCtrlTaskHandle;
static osThreadAttr_t sysctrl_attr = { .stack_size = 2048, .priority =
		(osPriority_t) osPriorityBelowNormal, }; /* Lowest of the 3 tasks */
osSemaphoreId_t ExtiSemaphoreHandle;

/* Audio_Record_To_SD_Task removed — SD recording merged into Audio_Loopback_Task */

/* USER CODE BEGIN PV */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
static void MPU_Config(void);
#ifdef __GNUC__
/* With GCC, small printf (option LD Linker->Libraries->Small printf
 set to 'Yes') calls __io_putchar() */
#define PUTCHAR_PROTOTYPE int __io_putchar(int ch)
#else
#define PUTCHAR_PROTOTYPE int fputc(int ch, FILE *f)
#endif /* __GNUC__ */
static void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void Audio_Loopback_Task(void *argument);
static void MX_USART3_UART_Init(void);
static void SD_Write_Task(void *argument);
static void System_Controller_Task(void *argument);
static int SD_Open_Play(void);
static int SD_Open_Rec(char *rec_filename, uint32_t FileIndex);
void RB_Write(RingBuffer_t *rb, uint8_t *data, uint32_t len);
uint32_t RB_Read(RingBuffer_t *rb, uint8_t *buffer, uint32_t len);
void Check_Alarm();
uint32_t RB_GetFreeSpace(RingBuffer_t *rb);
/* USER CODE BEGIN PFP */
/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
void UART_Print(const char *str);

/* USER CODE END 0 */

/**
 * @brief  The application entry point.
 * @retval int
 */
int main(void) {
	/* USER CODE BEGIN 1 */

	/* USER CODE END 1 */

	/* MCU Configuration--------------------------------------------------------*/

	/* Configure the MPU attributes */
	MPU_Config();
	// CPU_CACHE_Enable();

	/* Reset of all peripherals, Initializes the Flash interface and the Systick. */
	HAL_Init();

	/* USER CODE BEGIN Init */

	/* USER CODE END Init */

	/* Configure the system clock */
	SystemClock_Config();
	HAL_RCC_MCOConfig(RCC_MCO1, RCC_MCO1SOURCE_HSE, RCC_MCODIV_1);
	/* USER CODE BEGIN SysInit */
	/* Configure LED_OK and LED_ERROR */
	BSP_LED_Init(LED_OK);
	BSP_LED_Init(LED_ERROR);
	BSP_PB_Init(BUTTON_USER, BUTTON_MODE_EXTI);
	BSP_SD_Init(0);
	BSP_SD_DetectITConfig(0);

	MX_USART3_UART_Init();
	static char message[64];
	sprintf(message, "\r\nVersion: %s\r\n", version);
	UART_Print(message);

	/* Initialize the LCD */
	if (BSP_LCD_Init(0, LCD_ORIENTATION_LANDSCAPE) != BSP_ERROR_NONE) {
		Error_Handler();
	}
	UTIL_LCD_SetFuncDriver(&LCD_Driver);

	/* Example: draw something on screen */
	StartMenu_LCD(version);

	//Init RTC
	MX_RTC_Init();
	HAL_Delay(200); //give it time to init correctly
	RTC_DateTypeDef sDate;
	HAL_RTC_GetDate(&hrtc, &sDate, RTC_FORMAT_BIN);
	if (sDate.Year == 0x00) {
		flag_set_time = 1;
	} else {
		flag_set_time = 0;
	}
	while (flag_set_time > 0) {
		if (Set_DateTime_LCD() == 1) {
			flag_set_time--;
		}
	}
	HAL_Delay(200);

	Print_Date();
	Print_Time();
	Print_DateTime_LCD();
	/* USER CODE END SysInit */

	if (MX_FATFS_Init() != APP_OK) {
		Error_Handler();
	}

	osKernelInitialize();

	UART_Print("Audio config\r\n");
	if (Audio_LoopbackInit() != 0) {
		UART_Print("ERROR AUDIO\r\n");
		while (1) {
			BSP_LED_Toggle(LED_ERROR);
			HAL_Delay(100);
		}
	}

	/* NOTE: Audio_DisableInputBoost() removed - was causing noise issues */

	UART_Print("End config\r\n");

	//Define operation mode
	while (system_mode == 2) {
		if (Set_Mode_LCD() == 0) {
			Standalone_Menu(version);
		} else if ((Set_Mode_LCD() == 1)) {
			RF_Menu(version);
			FS_ReadAlarmList();//set alarms according to SD file
		}
	}

	/* Initialize ARD GPIOs + EXTI — now that system_mode is known.
	 * Skipped entirely in standalone mode (pins unconnected). */
	MX_GPIO_Init();
	HAL_GPIO_WritePin(ARD_D6_PORT, ARD_D6_PIN, GPIO_PIN_SET);
	UART_Print("Entering main loop...\r\n");

	SDQueueHandle = osMessageQueueNew(msg_count, msg_size, NULL);
	SDRemaphoreHandle = osSemaphoreNew(1U, 0, NULL);
	SEM_SDHandle = osThreadNew(SD_Write_Task, NULL, &sd_task_attr);
	UART_Print("Semaphore Init \r\n");
	/* USER CODE BEGIN 2 */

	/* USER CODE END 2 */

	/* Infinite loop */

	// In main.c - Start audio loopback (needed to generate SAI clock for recording)
	AudioTaskHandle = osThreadNew(Audio_Loopback_Task, NULL, &audio_attr);

	/* SD recording now handled inside Audio_Loopback_Task */

	/* System Controller Task — master state machine for all modes.
	 * Distributed mode: wakes on EXTI (ARD_D8) to set record/play.
	 * Standalone mode:  will wake on RTC alarm to start full-duplex (TODO). */
	ExtiSemaphoreHandle = osSemaphoreNew(1U, 0, NULL);
	SysCtrlTaskHandle = osThreadNew(System_Controller_Task, NULL,
			&sysctrl_attr);

	/* Start scheduler */
	osKernelStart();

	/* We should never get here as control is now taken by the scheduler */
	for (;;)
		;
}

/**
 * @brief  System Clock Configuration
 *         The system Clock is configured as follow :
 *            System Clock source            = PLL (HSE)
 *            SYSCLK(Hz)                     = 520000000 (CPU Clock)
 *            HCLK(Hz)                       = 260000000 (AXI and AHBs Clock)
 *            AHB Prescaler                  = 2
 *            D1 APB3 Prescaler              = 2 (APB3 Clock  130MHz)
 *            D2 APB1 Prescaler              = 2 (APB1 Clock  130MHz)
 *            D2 APB2 Prescaler              = 2 (APB2 Clock  130MHz)
 *            D3 APB4 Prescaler              = 2 (APB4 Clock  130MHz)
 *            HSE Frequency(Hz)              = 25000000
 *            PLL_M                          = 5
 *            PLL_N                          = 104
 *            PLL_P                          = 1
 *            PLL_Q                          = 4
 *            PLL_R                          = 2
 *            VDD(V)                         = 3.3
 *            Flash Latency(WS)              = 3
 * @param  None
 * @retval None
 */
static void SystemClock_Config(void) {
	RCC_ClkInitTypeDef RCC_ClkInitStruct = { 0 };
	RCC_OscInitTypeDef RCC_OscInitStruct = { 0 };
	RCC_PeriphCLKInitTypeDef PeriphClkInitStruct = { 0 };
	HAL_StatusTypeDef ret = HAL_OK;

	/* The voltage scaling allows optimizing the power consumption when the device is
	 clocked below the maximum system frequency, to update the voltage scaling value
	 regarding system frequency refer to product datasheet.  */
	__HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE0);

	while (!__HAL_PWR_GET_FLAG(PWR_FLAG_VOSRDY)) {
	}

	/* Enable HSE Oscillator and activate PLL with HSE as source */
	RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE
			| RCC_OSCILLATORTYPE_LSE;
	RCC_OscInitStruct.HSEState = RCC_HSE_ON;
	RCC_OscInitStruct.LSEState = RCC_LSE_ON;
	RCC_OscInitStruct.HSIState = RCC_HSI_OFF;
	RCC_OscInitStruct.CSIState = RCC_CSI_OFF;
	RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
	RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;

	RCC_OscInitStruct.PLL.PLLM = 5;
	RCC_OscInitStruct.PLL.PLLN = 104;
	RCC_OscInitStruct.PLL.PLLFRACN = 0;
	RCC_OscInitStruct.PLL.PLLP = 1;
	RCC_OscInitStruct.PLL.PLLR = 2;
	RCC_OscInitStruct.PLL.PLLQ = 4;

	RCC_OscInitStruct.PLL.PLLVCOSEL = RCC_PLL1VCOWIDE;
	RCC_OscInitStruct.PLL.PLLRGE = RCC_PLL1VCIRANGE_2;
	ret = HAL_RCC_OscConfig(&RCC_OscInitStruct);
	if (ret != HAL_OK) {
		while (1) {
		};
	}

	/* Select PLL as system clock source and configure  bus clocks dividers */
	RCC_ClkInitStruct.ClockType = (RCC_CLOCKTYPE_SYSCLK | RCC_CLOCKTYPE_HCLK
			| RCC_CLOCKTYPE_D1PCLK1 | RCC_CLOCKTYPE_PCLK1 |
			RCC_CLOCKTYPE_PCLK2 | RCC_CLOCKTYPE_D3PCLK1);

	RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
	RCC_ClkInitStruct.SYSCLKDivider = RCC_SYSCLK_DIV1;
	RCC_ClkInitStruct.AHBCLKDivider = RCC_HCLK_DIV2;
	RCC_ClkInitStruct.APB3CLKDivider = RCC_APB3_DIV2;
	RCC_ClkInitStruct.APB1CLKDivider = RCC_APB1_DIV2;
	RCC_ClkInitStruct.APB2CLKDivider = RCC_APB2_DIV2;
	RCC_ClkInitStruct.APB4CLKDivider = RCC_APB4_DIV2;
	ret = HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_3);
	if (ret != HAL_OK) {
		while (1) {
		};
	}

	if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInitStruct) != HAL_OK) {
		Error_Handler();
	}
}

/**
 * @brief GPIO Initialization Function
 * @param None
 * @retval None
 */
static void MX_GPIO_Init(void) {
	/* Alarm pin */
	GPIO_InitTypeDef GPIO_InitStruct = { 0 };
	/* ----- ARD_D6 (PD15) as output -----*/
	__HAL_RCC_GPIOD_CLK_ENABLE();

	GPIO_InitStruct.Pin = ARD_D6_PIN;
	GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
	GPIO_InitStruct.Pull = GPIO_NOPULL;
	GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
	HAL_GPIO_Init(ARD_D6_PORT, &GPIO_InitStruct);

	/* Only configure ARD pins in distributed-node mode (system_mode == 1).
	 * In standalone mode the pins are unconnected — leaving them
	 * unconfigured avoids spurious EXTI3 interrupts from noise.       */
	if (system_mode != 1)
		return;


	/* Enable GPIOG and GPIOE clocks */
	__HAL_RCC_GPIOG_CLK_ENABLE();
	__HAL_RCC_GPIOE_CLK_ENABLE();

	/* ----- ARD_D2 (PG3) and ARD_D4 (PG4) as inputs, pull-down ----- */
	GPIO_InitStruct.Pin = ARD_D2_PIN | ARD_D4_PIN;
	GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
	GPIO_InitStruct.Pull = GPIO_PULLDOWN;
	GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
	HAL_GPIO_Init(ARD_D2D4_PORT, &GPIO_InitStruct);

	/* ----- ARD_D8 (PE3) as EXTI, rising edge -----
	 * Uses dedicated EXTI3_IRQn — no conflict with SD detect (PF5/EXTI5) */
	GPIO_InitStruct.Pin = ARD_D8_PIN;
	GPIO_InitStruct.Mode = GPIO_MODE_IT_RISING;
	GPIO_InitStruct.Pull = GPIO_PULLDOWN;
	GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
	HAL_GPIO_Init(ARD_D8_PORT, &GPIO_InitStruct);

	HAL_NVIC_SetPriority(EXTI3_IRQn, 6, 0);
	HAL_NVIC_EnableIRQ(EXTI3_IRQn);
}

static void Audio_Loopback_Task(void *argument) {
	UART_Print("Audio task init \r\n");

	/* Clear buffers to ensure we play silence initially */
	memset(RecordBuffer, 0, sizeof(RecordBuffer));
	memset(PlayBuffer, 0, sizeof(PlayBuffer));

	/* Start Playback FIRST to generate the SAI Clock */
	if (BSP_AUDIO_OUT_Play(0, (uint8_t*) PlayBuffer,
			BUFFER_SIZE * sizeof(int16_t)) != 0) {
		UART_Print("Audio Play Init Error\r\n");
		Error_Handler();
	}
	PlaybackStarted = 1;

	/* Start Recording */
	if (BSP_AUDIO_IN_Record(0, (uint8_t*) RecordBuffer,
			BUFFER_SIZE * sizeof(int16_t)) != 0) {
		UART_Print("Audio Record Init Error\r\n");
		Error_Handler();
	}
	UART_Print("Audio Recording Started\r\n");

	/* ---------- Main loop  ---------- */
	while (1) {
		uint32_t state;
		osStatus_t status = osMessageQueueGet(SDQueueHandle, &state, NULL,
		osWaitForever);

		if (status == osOK) // check if message was received
				{
			/* Define Pointers for readability */
			int16_t *src; // source (ADC from codec)
			int16_t *dst; // destiny (DAC from codec)
			uint32_t bytes_to_process = (BUFFER_SIZE / 2) * sizeof(int16_t);
			/* Assign Pointers based on State */
			if (state == BUFFER_OFFSET_HALF) {
				/* First Half Ready (0 to Half) */
				src = &RecordBuffer[0];
				dst = &PlayBuffer[0];
			} else /* BUFFER_OFFSET_FULL */
			{
				/* Second Half Ready (Half to End) */
				src = &RecordBuffer[BUFFER_SIZE / 2];
				dst = &PlayBuffer[BUFFER_SIZE / 2];
			}

			if (g_Mode == MODE_PLAY) {
				/* Pull data from Ring Buffer */
				uint32_t bytes_fetched = RB_Read(&PlayRB, (uint8_t*) dst,
						bytes_to_process);

				/* If buffer empty (Underrun or finished), play silence */
				if (bytes_fetched < bytes_to_process) {
					memset(((uint8_t*) dst) + bytes_fetched, 0,
							bytes_to_process - bytes_fetched);
				}
				osSemaphoreRelease(SDRemaphoreHandle);
			} else if (g_Mode == MODE_PASSTHROUGH) {
				/* Audio Loopback (Copy Record -> Play) */
				memcpy(dst, src, bytes_to_process);
			} else if (g_Mode == MODE_RECORD) {
				/* Output silence — don't route mic to headphone during recording */
				memset(dst, 0, bytes_to_process);

				/* SD Card Recording (Write to Ring Buffer) */
				if (g_StartRecording && (total_bytes_recorded < TARGET_BYTES)) {
					RB_Write(&RecRB, (uint8_t*) src, bytes_to_process); // write to RAM ADC data

					total_bytes_recorded += bytes_to_process;
					osSemaphoreRelease(SDRemaphoreHandle);

					/* Visual Heartbeat */
					static int toggle_cnt = 0;
					if (++toggle_cnt > 48) {
						BSP_LED_Toggle(LED_OK);
						toggle_cnt = 0;
					}
				} else if (g_StartRecording
						&& (total_bytes_recorded >= TARGET_BYTES)) {
					/* Recording Finished */
					g_StartRecording = 0;
					g_RecordingComplete = 1;
					UART_Print("Audio Task: Target Size Reached\r\n");
					BSP_LED_Off(LED_OK);
				}
			} else if (g_Mode == MODE_FULL_DUPLEX) {
				if (g_StartRecording) {
					/*PLAYBACK PATH: RingBuffer -> DAC*/
					/* Pull data from Ring Buffer */
					uint32_t bytes_fetched = RB_Read(&PlayRB, (uint8_t*) dst,
							bytes_to_process);

					/* Underrun protection: Fill with 0 if buffer empty */
					if (bytes_fetched < bytes_to_process) {
						memset(((uint8_t*) dst) + bytes_fetched, 0,
								bytes_to_process - bytes_fetched);
						//BSP_LED_On(LED_ERROR);
						//underrun_count++;
					}
					/*RECORD PATH: ADC -> RingBuffer*/
					if (total_bytes_recorded < TARGET_BYTES) {
						RB_Write(&RecRB, (uint8_t*) src, bytes_to_process); // write to RAM ADC data
						total_bytes_recorded += bytes_to_process;
					} else {
						g_StartRecording = 0;
						g_RecordingComplete = 1;
					}
				} else {
					/* If SD card is still opening files, output pure silence. */
					memset((uint8_t*) dst, 0, bytes_to_process);
				}
				/* Signal SD Manag
				 * er to run */
				osSemaphoreRelease(SDRemaphoreHandle);
			}
		} // osOK
	} // end while(1)
}

static void SD_Write_Task(void *argument) {
	char msg[64];
	char filename[16];
	UINT bytesWritten;
	FRESULT fres;
	uint32_t total_sd_bytes_written = 0;
	WavHeader myWavHeader;

	/* ---------- SD card setup ---------- */
	osDelay(500); /* Let audio DMA stabilize */

	if (BSP_SD_IsDetected(0) != SD_PRESENT) {
		UART_Print("No SD card - loopback only\r\n");
		osThreadTerminate(osThreadGetId());
	}

	fres = f_mount(&SDFatFs, "", 1);
	if (fres != FR_OK) {
		sprintf(msg, "f_mount failed: %d\r\n", fres);
		UART_Print(msg);
		osThreadTerminate(osThreadGetId());
	}

	/* --- Scan SD card for existing REC_XX.WAV files to resume numbering --- */
	{
		FILINFO fno;
		uint32_t max_index = 0;
		char probe[16];

		for (uint32_t i = 1; i <= 99; i++) {
			sprintf(probe, "REC_%02lu.WAV", i);
			if (f_stat(probe, &fno) == FR_OK) {
				max_index = i;
			}
		}
		g_FileIndex = max_index + 1;
		sprintf(msg, "Next file index: REC_%02lu.WAV\r\n", g_FileIndex);
		UART_Print(msg);
	}

	sprintf(msg, "SD mounted. Mode=%d. Press USER button.\r\n", g_Mode);
	UART_Print(msg);

	/* ========== Main loop: wait for button -> record -> repeat ========== */
	while (1) {
		/* --- Idle: wait for button press --- */
		g_Busy = 0;         /* Signal: ready for new commands */
		BSP_LED_On(LED_OK); /* Solid LED = ready */
		while (!g_ButtonPressed) {
			osDelay(50);
		}
		g_ButtonPressed = 0;
		g_Busy = 1;         /* Signal: operation in progress */

		/* ================= RECORD MODE ================= */
		if (g_Mode == MODE_RECORD) {
			total_sd_bytes_written = 0;
			if (SD_Open_Rec(filename, g_FileIndex) != 0) {
				continue;
			}
			/* --- Recording loop: drain ring buffer to SD --- */
			while (1) {
				osSemaphoreAcquire(SDRemaphoreHandle, 100);

				if (RecRB.count >= SD_CHUNK_SIZE
						&& total_sd_bytes_written < TARGET_BYTES) {
					uint32_t chunk = SD_CHUNK_SIZE;
					if (total_sd_bytes_written + chunk > TARGET_BYTES)
						chunk = TARGET_BYTES - total_sd_bytes_written;
					RB_Read(&RecRB, scratch_buf, chunk);
					f_write(&File_Rec, scratch_buf, chunk, &bytesWritten);
					total_sd_bytes_written += bytesWritten;
				} else if (g_RecordingComplete == 1 && RecRB.count > 0
						&& total_sd_bytes_written < TARGET_BYTES) {
					uint32_t remaining = RecRB.count;
					if (total_sd_bytes_written + remaining > TARGET_BYTES)
						remaining = TARGET_BYTES - total_sd_bytes_written;
					RB_Read(&RecRB, scratch_buf, remaining);
					f_write(&File_Rec, scratch_buf, remaining, &bytesWritten);
					total_sd_bytes_written += bytesWritten;
					RecRB.count = 0;
				}

				/* Check if recording is done */
				if (g_RecordingComplete == 1
						&& (RecRB.count == 0
								|| total_sd_bytes_written >= TARGET_BYTES))
					break;
			}

			/* --- Finalize WAV header and close file --- */
			UART_Print("Finalizing WAV Header...\r\n");
			f_lseek(&File_Rec, 0);
			Create_WAV_Header(&myWavHeader, total_sd_bytes_written);
			memcpy(scratch_buf, &myWavHeader, sizeof(WavHeader));
			f_write(&File_Rec, scratch_buf, sizeof(WavHeader), &bytesWritten);
			f_close(&File_Rec);

			sprintf(msg, "Saved %s (%lu bytes)\r\n", filename,
					total_sd_bytes_written);
			UART_Print(msg);
			BSP_LED_On(LED_OK);
			//if it was activated from alarm proceed to mark done and reset alarm flag


			g_FileIndex++;
			g_SDReady = 0;
		}
		/* ================= PLAYBACK MODE ================= */
		else if (g_Mode == MODE_PLAY) {
			UINT bytesRead;
			if (SD_Open_Play() != 0) {
				continue;
			}

			/* --- Playback loop: feed ring buffer from SD --- */
			while (1) {
				osSemaphoreAcquire(SDRemaphoreHandle, 100);

				if (RB_GetFreeSpace(&PlayRB) >= SD_CHUNK_SIZE) {
					fres = f_read(&File_Play, scratch_buf, SD_CHUNK_SIZE,
							&bytesRead);

					if (fres == FR_OK && bytesRead > 0) {
						RB_Write(&PlayRB, scratch_buf, bytesRead);

						/* Visual Heartbeat */
						static int play_toggle = 0;
						if (++play_toggle > 48) {
							BSP_LED_Toggle(LED_OK);
							play_toggle = 0;
						}
					}

					if (bytesRead < SD_CHUNK_SIZE) {
						/* End of file — let audio task consume what's left */
						uint32_t drain_bytes = (BUFFER_SIZE / 2)
								* sizeof(int16_t);
						UART_Print("End of file reached, draining...\r\n");
						while (PlayRB.count >= drain_bytes) {
							osDelay(10);
						}
						/* Remaining bytes < one DMA chunk, audio task will zero-pad */
						osDelay(100); /* Let last chunk play out */
						break;
					}
				}
			}

			f_close(&File_Play);
			UART_Print("Playback complete.\r\n");
			BSP_LED_On(LED_OK);
		} /* ================= FULL DUPLEX MODE ================= */
		else if (g_Mode == MODE_FULL_DUPLEX) {
			UINT bytesRead;

			/*Open play file*/
			if (SD_Open_Play() == 0) {
				play_file_is_open = 1;

				/* Pre-fill buffer to avoid start glitches */
				while ((PlayRB.size - PlayRB.count) >= SD_CHUNK_SIZE) {
					f_read(&File_Play, scratch_buf, SD_CHUNK_SIZE, &bytesRead);
					if (bytesRead == 0)
						break;
					RB_Write(&PlayRB, scratch_buf, bytesRead);
				}
			} else {
				play_file_is_open = 0; // Failed to open
			}

			/*Open record file*/
			total_sd_bytes_written = 0;
			if (SD_Open_Rec(filename, g_FileIndex) != 0)
				continue;

			UART_Print("Starting Full Duplex \r\n");
			while (1) {
				osSemaphoreAcquire(SDRemaphoreHandle, 10);

				/*Start filling the playback*/
				if (play_file_is_open == 1) {
					if (RB_GetFreeSpace(&PlayRB) >= SD_CHUNK_SIZE) {
						/*Read from SD File */
						fres = f_read(&File_Play, scratch_buf, SD_CHUNK_SIZE,
								&bytesRead);

						if (fres == FR_OK && bytesRead > 0) {
							/*Push to Play Ring Buffer */
							RB_Write(&PlayRB, scratch_buf, bytesRead);
						}
						if (fres != FR_OK || bytesRead < SD_CHUNK_SIZE) {

							UART_Print("End of file play reached\r\n");
							f_close(&File_Play);
							play_file_is_open = 0; /* Stop trying to read */
						}
					}
				}
				/*Recording*/
				if (RecRB.count >= SD_CHUNK_SIZE
						&& total_sd_bytes_written < TARGET_BYTES) {
					uint32_t chunk = SD_CHUNK_SIZE;

					/* Cap chunk size if we the target limit is near*/
					if (total_sd_bytes_written + chunk > TARGET_BYTES)
						chunk = TARGET_BYTES - total_sd_bytes_written;

					RB_Read(&RecRB, scratch_buf, chunk);
					f_write(&File_Rec, scratch_buf, chunk, &bytesWritten);
					total_sd_bytes_written += bytesWritten;
				}
				/* Drain the leftover bytes when the audio task finishes */
				else if (g_RecordingComplete == 1 && RecRB.count > 0
						&& total_sd_bytes_written < TARGET_BYTES) {
					uint32_t remaining = RecRB.count;

					if (total_sd_bytes_written + remaining > TARGET_BYTES)
						remaining = TARGET_BYTES - total_sd_bytes_written;

					RB_Read(&RecRB, scratch_buf, remaining);
					f_write(&File_Rec, scratch_buf, remaining, &bytesWritten);
					total_sd_bytes_written += bytesWritten;
					RecRB.count = 0;
				}

				if (total_sd_bytes_written >= TARGET_BYTES) {
					UART_Print("Recodring time reached. Stopping.\r\n");
					sprintf(msg, "Underrun count: %d\r\n", underrun_count);
					break;

				}
			}
			/* --- Finalize WAV header and close file --- */

			f_lseek(&File_Rec, 0);
			Create_WAV_Header(&myWavHeader, total_sd_bytes_written);
			memcpy(scratch_buf, &myWavHeader, sizeof(WavHeader));
			f_write(&File_Rec, scratch_buf, sizeof(WavHeader), &bytesWritten);
			f_close(&File_Rec);

			/* Close Play File (If it wasn't closed yet) */
			if (play_file_is_open == 1) {
				f_close(&File_Play);
				play_file_is_open = 0;
			}

			UART_Print(msg);
			BSP_LED_On(LED_OK);
			g_FileIndex++;
			g_SDReady = 0;
		}
		/* Small delay to debounce before accepting next button press */
		Check_Alarm();
		osDelay(500);
	}
}

static int SD_Open_Play(void) {
	char msg[48];
	FRESULT fres;

	fres = f_open(&File_Play, audio_play, FA_READ);
	if (fres != FR_OK) {
		sprintf(msg, "Cannot open %s: %d\r\n", audio_play, fres);
		UART_Print(msg);
		return -1;
	}

	/* Skip WAV header (44 bytes) */
	f_lseek(&File_Play, 44);

	/* Reset Ring Buffer */
	PlayRB.count = 0;
	PlayRB.head = 0;
	PlayRB.tail = 0;

	sprintf(msg, "Playing %s ...\r\n", audio_play);
	UART_Print(msg);
	BSP_LED_Off(LED_OK);
	return 0;
}

static int SD_Open_Rec(char *rec_filename, uint32_t FileIndex) {
	char msg[48];
	FRESULT fres;
	UINT bytesWritten;

	/* --- Build filename: REC_01.WAV, REC_02.WAV, ... --- */
	sprintf(rec_filename, "REC_%02lu.WAV", FileIndex);
	sprintf(msg, "Recording %s ...\r\n", rec_filename);
	UART_Print(msg);

	/* --- Reset state for new recording --- */
	total_bytes_recorded = 0;
	g_RecordingComplete = 0;
	g_StartRecording = 0;
	g_SDReady = 0;
	RecRB.count = 0;
	RecRB.head = 0;
	RecRB.tail = 0;

	fres = f_open(&File_Rec, rec_filename, FA_CREATE_ALWAYS | FA_WRITE);
	if (fres != FR_OK) {
		g_StartRecording = 0; /* Abort capture on failure */
		sprintf(msg, "f_open failed: %d\r\n", fres);
		UART_Print(msg);
		return -1;
	} else {
		g_StartRecording = 1;
	}

	memset(scratch_buf, 0, sizeof(WavHeader));
	fres = f_write(&File_Rec, scratch_buf, sizeof(WavHeader), &bytesWritten);
	g_SDReady = 1;

	BSP_LED_Off(LED_OK); /* LED off during recording (heartbeat will toggle it) */
	return 0;
}

/* Write data to Ring Buffer (Called by Audio Loopback Task) */
void RB_Write(RingBuffer_t *rb, uint8_t *data, uint32_t len) {
	uint32_t error_count = 0;
	if ((rb->count + len) > rb->size) {
		// UART_Print("Buffer Overflow!\r\n"); // SD card is too slow
		error_count++;
		BSP_LED_Toggle(LED_ERROR);
		return;
	}
	/* Calculate contiguous bytes until end of buffer */
	uint32_t bytes_to_end = rb->size - rb->head;

	if (len <= bytes_to_end) {
		/* Case A: Data fits in the remaining space */
		memcpy(&rb->buffer[rb->head], data, len);
		rb->head += len;
	} else {
		/* Case B: Data wraps around */
		memcpy(&rb->buffer[rb->head], data, bytes_to_end);
		memcpy(&rb->buffer[0], &data[bytes_to_end], len - bytes_to_end);
		rb->head = len - bytes_to_end;
	}

	/* Handle wrap-around of head index if it exactly matches size */
	if (rb->head == rb->size)
		rb->head = 0;

	/*Atomic Update */
	__disable_irq();
	rb->count += len;
	__enable_irq();
}

/* Read data from Ring Buffer (Called by SD Task) */
uint32_t RB_Read(RingBuffer_t *rb, uint8_t *buffer, uint32_t len) {
	if (rb->count < len)
		return 0; // Not enough data yet

	uint32_t bytes_to_end = rb->size - rb->tail;

	if (len <= bytes_to_end) {
		/* Case A: Contiguous read */
		memcpy(buffer, &rb->buffer[rb->tail], len);
		rb->tail += len;
	} else {
		/* Case B: Wrap around read */
		memcpy(buffer, &rb->buffer[rb->tail], bytes_to_end);
		memcpy(&buffer[bytes_to_end], &rb->buffer[0], len - bytes_to_end);
		rb->tail = len - bytes_to_end;
	}

	if (rb->tail == rb->size)
		rb->tail = 0;

	__disable_irq();
	rb->count -= len;
	__enable_irq();

	return len;
}

uint32_t RB_GetFreeSpace(RingBuffer_t *rb) {
	return rb->size - rb->count;
}
/* USER CODE BEGIN 4 */
void BSP_PB_Callback(Button_TypeDef Button) {
	if (Button == BUTTON_USER) {
		g_ButtonPressed = 1;
	}
}

void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
	if (GPIO_Pin == ARD_D8_PIN) {
		g_ExtiFlag = 1;
		osSemaphoreRelease(ExtiSemaphoreHandle);
	}
}

/**
 * @brief  System Controller Task — master state machine (lowest priority).
 *         Sleeps until ARD_D8 (PE3) EXTI fires, then reads ARD_D2/D4
 *         to determine the operation mode.
 *
 *         Pin combination (ARD_D2 = bit0, ARD_D4 = bit1):
 *         ARD_D4=0  ARD_D2=1  (0b01) → MODE_RECORD
 *         ARD_D4=1  ARD_D2=0  (0b10) → MODE_PLAY
 */
void Check_Alarm(void){
	if (g_AlarmFlag){
		//Turn off alarm pin when communication is set
		HAL_GPIO_WritePin(ARD_D6_PORT, ARD_D6_PIN, GPIO_PIN_SET);
		g_AlarmFlag = 0;
		FS_MarkAlarmExecuted();//mark alarm executed
		FS_ReadAlarmList();//set next alarm after the current alarm was executed
	}
}
static void System_Controller_Task(void *argument) {
	(void) argument;

	for (;;) {
        if (system_mode == 0 && !g_Busy && !g_AlarmFlag) {
            Set_Alarm_button_LCD();
            UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
            UTIL_LCD_SetFont(&Font16);
            UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
            UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
            UTIL_LCD_DisplayStringAt(0, 120,
                (uint8_t*)"Waiting for alarm...", CENTER_MODE);
        }

		/* Block until EXTI or RTC alarm releases the semaphore */
		osSemaphoreAcquire(ExtiSemaphoreHandle, osWaitForever);

		/* Ignore commands while recording/playing is in progress */
		if (g_Busy) {
			g_ExtiFlag = 0;
			continue;
		}

		if ((system_mode == 1)&&(g_AlarmFlag)&&(g_ExtiFlag)){
			/* Read the two selector pins */
			uint8_t d2 = HAL_GPIO_ReadPin(ARD_D2D4_PORT, ARD_D2_PIN); /* bit 0 */
			uint8_t d4 = HAL_GPIO_ReadPin(ARD_D2D4_PORT, ARD_D4_PIN); /* bit 1 */
			uint8_t config = (d4 << 1) | d2;

			switch (config) {
			case 0x01: /* ARD_D4=0, ARD_D2=1 → RECORD */
				UART_Print("EXTI: Start recording\r\n");
				g_Mode = MODE_RECORD;
				g_ButtonPressed = 1;
				break;

			case 0x02: /* ARD_D4=1, ARD_D2=0 → PLAY */
				UART_Print("EXTI: Start Playing\r\n");
				g_Mode = MODE_PLAY;
				g_ButtonPressed = 1;
				break;
			case 0x03: /* ARD_D4=1, ARD_D2=1 → FULL_DUPLEX */
				UART_Print("EXTI: Start fullduplex\r\n");
				g_Mode = MODE_FULL_DUPLEX;
				g_ButtonPressed = 1;
				break;

			default:
				/* Unknown combination — keep current mode */
				UART_Print(
						"EXTI: Unknown pin configuration, mode unchanged\r\n");
				break;
			}
		} else if (system_mode == 0 && g_AlarmFlag) {
			    g_Mode = MODE_FULL_DUPLEX;
			    g_ButtonPressed = 1;//start recording and playing
		}
		g_ExtiFlag = 0;
	}
}
/* USER CODE END 4 */

/**
 * @brief  This function is executed in case of error occurrence.
 * @retval None
 */
void Error_Handler(void) {
	/* USER CODE BEGIN Error_Handler_Debug */
	/* User can add his own implementation to report the HAL error return state */
	BSP_LED_Off(LED_OK);
	BSP_LED_On(LED_ERROR);
	while (1) {
	}
	/* USER CODE END Error_Handler_Debug */
}

/**
 * @brief  Configure the MPU attributes
 * @param  None
 * @retval None
 */
static void MPU_Config(void) {
	MPU_Region_InitTypeDef MPU_InitStruct;

	/* Disable the MPU */
	HAL_MPU_Disable();

	/* ============================================================
	 REGION 0:
	 ============================================================ */
	/* Configure the MPU as Strongly ordered for not defined regions */
	MPU_InitStruct.Enable = MPU_REGION_ENABLE;
	MPU_InitStruct.BaseAddress = 0x00;
	MPU_InitStruct.Size = MPU_REGION_SIZE_4GB;
	MPU_InitStruct.AccessPermission = MPU_REGION_NO_ACCESS;
	MPU_InitStruct.IsBufferable = MPU_ACCESS_NOT_BUFFERABLE;
	MPU_InitStruct.IsCacheable = MPU_ACCESS_NOT_CACHEABLE;
	MPU_InitStruct.IsShareable = MPU_ACCESS_SHAREABLE;
	MPU_InitStruct.Number = MPU_REGION_NUMBER0;
	MPU_InitStruct.TypeExtField = MPU_TEX_LEVEL0;
	MPU_InitStruct.SubRegionDisable = 0x87;
	MPU_InitStruct.DisableExec = MPU_INSTRUCTION_ACCESS_DISABLE;
	HAL_MPU_ConfigRegion(&MPU_InitStruct);

	/* ============================================================
	 REGION 1: D3 SRAM for AUDIO (Critical for DMA)
	 ============================================================ */
	MPU_InitStruct.Enable = MPU_REGION_ENABLE;
	MPU_InitStruct.Number = MPU_REGION_NUMBER1; // <--- Region 1 (Must be different)
	MPU_InitStruct.BaseAddress = 0x38000000;    // D3 SRAM Address
	MPU_InitStruct.Size = MPU_REGION_SIZE_64KB;
	MPU_InitStruct.AccessPermission = MPU_REGION_FULL_ACCESS;
	MPU_InitStruct.IsBufferable = MPU_ACCESS_NOT_BUFFERABLE;
	MPU_InitStruct.IsCacheable = MPU_ACCESS_NOT_CACHEABLE; // Non-cacheable for DMA
	MPU_InitStruct.IsShareable = MPU_ACCESS_SHAREABLE;
	MPU_InitStruct.TypeExtField = MPU_TEX_LEVEL0;
	MPU_InitStruct.SubRegionDisable = 0x00;
	MPU_InitStruct.DisableExec = MPU_INSTRUCTION_ACCESS_ENABLE;

	HAL_MPU_ConfigRegion(&MPU_InitStruct);

	/* ============================================================
	 REGION 2: AXI SRAM (0x24000000) for Audio Buffers
	 ============================================================ */
	MPU_InitStruct.Enable = MPU_REGION_ENABLE;
	MPU_InitStruct.Number = MPU_REGION_NUMBER2;

	/* CHANGE THIS ADDRESS to match your .axi_sram section */
	MPU_InitStruct.BaseAddress = 0x24000000;

	/* AXI SRAM is 320KB, so we cover it with a larger region (e.g., 512KB)
	 or just enough for your buffers. 256KB or 512KB is safe. */
	MPU_InitStruct.Size = MPU_REGION_SIZE_512KB;

	MPU_InitStruct.AccessPermission = MPU_REGION_FULL_ACCESS;
	MPU_InitStruct.IsBufferable = MPU_ACCESS_NOT_BUFFERABLE;
	MPU_InitStruct.IsCacheable = MPU_ACCESS_NOT_CACHEABLE; // Critical for DMA
	MPU_InitStruct.IsShareable = MPU_ACCESS_SHAREABLE;
	MPU_InitStruct.TypeExtField = MPU_TEX_LEVEL0;
	MPU_InitStruct.SubRegionDisable = 0x00;
	MPU_InitStruct.DisableExec = MPU_INSTRUCTION_ACCESS_ENABLE;

	HAL_MPU_ConfigRegion(&MPU_InitStruct);
	/* ============================================================
	 REGION 3: OSPI RAM (0x70000000) for LCD Framebuffer
	 Write-Through so LTDC can read the framebuffer from memory.
	 ============================================================ */
	MPU_InitStruct.Enable = MPU_REGION_ENABLE;
	MPU_InitStruct.Number = MPU_REGION_NUMBER3;
	MPU_InitStruct.BaseAddress = 0x70000000;
	MPU_InitStruct.Size = MPU_REGION_SIZE_16MB;
	MPU_InitStruct.AccessPermission = MPU_REGION_FULL_ACCESS;
	MPU_InitStruct.IsBufferable = MPU_ACCESS_NOT_BUFFERABLE;
	MPU_InitStruct.IsCacheable = MPU_ACCESS_CACHEABLE; /* Write-Through */
	MPU_InitStruct.IsShareable = MPU_ACCESS_NOT_SHAREABLE;
	MPU_InitStruct.TypeExtField = MPU_TEX_LEVEL0;
	MPU_InitStruct.SubRegionDisable = 0x00;
	MPU_InitStruct.DisableExec = MPU_INSTRUCTION_ACCESS_DISABLE;

	HAL_MPU_ConfigRegion(&MPU_InitStruct);

	/* Enable the MPU */
	HAL_MPU_Enable(MPU_PRIVILEGED_DEFAULT);
}

static void MX_USART3_UART_Init(void) {

	/* USER CODE BEGIN USART3_Init 0 */

	/* USER CODE END USART3_Init 0 */

	/* USER CODE BEGIN USART3_Init 1 */

	/* USER CODE END USART3_Init 1 */
	huart3.Instance = USART3;
	huart3.Init.BaudRate = 115200;
	huart3.Init.WordLength = UART_WORDLENGTH_8B;
	huart3.Init.StopBits = UART_STOPBITS_1;
	huart3.Init.Parity = UART_PARITY_NONE;
	huart3.Init.Mode = UART_MODE_TX_RX;
	huart3.Init.HwFlowCtl = UART_HWCONTROL_NONE;
	huart3.Init.OverSampling = UART_OVERSAMPLING_16;
	huart3.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
	huart3.Init.ClockPrescaler = UART_PRESCALER_DIV1;
	huart3.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
	if (HAL_UART_Init(&huart3) != HAL_OK) {
		Error_Handler();
	}
	if (HAL_UARTEx_SetTxFifoThreshold(&huart3, UART_TXFIFO_THRESHOLD_1_8)
			!= HAL_OK) {
		Error_Handler();
	}
	if (HAL_UARTEx_SetRxFifoThreshold(&huart3, UART_RXFIFO_THRESHOLD_1_8)
			!= HAL_OK) {
		Error_Handler();
	}
	if (HAL_UARTEx_DisableFifoMode(&huart3) != HAL_OK) {
		Error_Handler();
	}
	/* USER CODE BEGIN USART3_Init 2 */

	/* USER CODE END USART3_Init 2 */
}

void HAL_UART_MspInit(UART_HandleTypeDef *huart) {
	GPIO_InitTypeDef GPIO_InitStruct = { 0 };
	RCC_PeriphCLKInitTypeDef PeriphClkInitStruct = { 0 };

	if (huart->Instance == USART3) {
		/* Enable HSI oscillator for USART3 clock */
		__HAL_RCC_HSI_ENABLE();
		while (__HAL_RCC_GET_FLAG(RCC_FLAG_HSIRDY) == 0) {
		}

		/* Configure USART3 clock source as HSI (64 MHz) */
		PeriphClkInitStruct.PeriphClockSelection = RCC_PERIPHCLK_USART3;
		PeriphClkInitStruct.Usart234578ClockSelection =
		RCC_USART234578CLKSOURCE_HSI;
		if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInitStruct) != HAL_OK) {
			Error_Handler();
		}

		/* Enable USART3 clock */
		__HAL_RCC_USART3_CLK_ENABLE();

		/* Enable GPIOD clock */
		__HAL_RCC_GPIOD_CLK_ENABLE();

		/* USART3 GPIO Configuration
		 PD8 ------> USART3_TX
		 PD9 ------> USART3_RX
		 */

		GPIO_InitStruct.Pin = GPIO_PIN_8 | GPIO_PIN_9;
		GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
		GPIO_InitStruct.Pull = GPIO_NOPULL;
		GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
		GPIO_InitStruct.Alternate = GPIO_AF7_USART3;
		HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);
	}
}

/**
 * @brief  Retargets the C library printf function to the USART.
 * @param  None
 * @retval None
 */
PUTCHAR_PROTOTYPE {
	/* Place your implementation of fputc here */
	/* e.g. write a character to the USART1 and Loop until the end of transmission */
	HAL_UART_Transmit(&huart3, (uint8_t*) &ch, 1, 0xFFFF);

	return ch;
}

/* Simple UART print function */
void UART_Print(const char *str) {
	HAL_UART_Transmit(&huart3, (uint8_t*) str, strlen(str), HAL_MAX_DELAY);
}
#ifdef USE_FULL_ASSERT
  /**
   * @brief  Reports the name of the source file and the source line number
   *         where the assert_param error has occurred.
   * @param  file: pointer to the source file name
   * @param  line: assert_param error line source number
   * @retval None
   */
  void assert_failed(uint8_t *file, uint32_t line)
  {
    /* USER CODE BEGIN 6 */
    /* User can add his own implementation to report the file name and line number,
       ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */

    /* Infinite loop */
    while (1)
    {
    }
    /* USER CODE END 6 */
  }
#endif /* USE_FULL_ASSERT */
