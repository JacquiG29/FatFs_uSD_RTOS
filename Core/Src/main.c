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
#include "audio_record.h" /* Provides Audio_LoopbackInit() and buffers */
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */
/* Defines */
#define FFT_SIZE  1024  // Size of FFT (must be power of 2: 256, 512, 1024, 2048)
#define SAMPLE_RATE 48000

/* Global FFT Variables */
arm_rfft_fast_instance_f32 fft_handler;
float32_t fft_input_buffer[FFT_SIZE];   // Input for FFT (Float)
float32_t fft_output_buffer[FFT_SIZE];  // Output of FFT
float32_t fft_magnitude[FFT_SIZE / 2];  // Magnitude result

/* Initialization Function (Call this once in main or task init) */
void DSP_Init(void) {
    arm_rfft_fast_init_f32(&fft_handler, FFT_SIZE);
}

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */
/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

osThreadId_t FatFsThreadHandle, StatusThreadHandle;
static osThreadAttr_t fatfs_attr = {
    .priority = osPriorityNormal,
    .stack_size = 2 * configMINIMAL_STACK_SIZE,
};

osThreadId_t AudioTaskHandle;
static osThreadAttr_t audio_attr = {
    .priority = osPriorityAboveNormal,
    .stack_size = 2 * configMINIMAL_STACK_SIZE,
};

osThreadId_t AudioAnalysisTaskHandle;
static osThreadAttr_t audio_analysis_attr = {
    .priority = osPriorityLow,
    .stack_size = 2 * configMINIMAL_STACK_SIZE,
};

osThreadId_t AudioRecordToSDTaskHandle;
static osThreadAttr_t audio_record_sd_attr = {
    .priority = osPriorityNormal,
    .stack_size = 4 * configMINIMAL_STACK_SIZE,  /* Larger stack for FatFs */
};

/* USER CODE BEGIN PV */
int32_t ProcessStatus = 0;
UART_HandleTypeDef huart3;

/* Audio recording to SD card variables */
#define RECORD_DURATION_SECONDS  5
#define SAMPLES_TO_RECORD  (AUDIO_SAMPLE_RATE * RECORD_DURATION_SECONDS * 2)  /* *2 for stereo */
volatile uint8_t g_StartRecording = 0;  /* Set to 1 to start recording */
volatile uint8_t g_RecordingComplete = 0;
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
static void CPU_CACHE_Enable(void);
static void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void STATUS_Thread(void *argument);
static void Audio_Loopback_Task(void *argument);
static void Audio_Play_Task(void *argument);
static void Audio_Record_Task(void *argument);
static void MX_USART3_UART_Init(void);
static void Audio_Analysis_Task(void *argument);
static void Audio_Record_To_SD_Task(void *argument);
/* USER CODE BEGIN PFP */
uint32_t loop_count = 0;
/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
void UART_Print(const char *str);

/* Simple UART print function */
void UART_Print(const char *str)
{
  HAL_UART_Transmit(&huart3, (uint8_t *)str, strlen(str), HAL_MAX_DELAY);
}
/* USER CODE END 0 */

/**
 * @brief  The application entry point.
 * @retval int
 */
int main(void)
{
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
  BSP_SD_Init(0);
  BSP_SD_DetectITConfig(0);
  MX_USART3_UART_Init();
  UART_Print("\r\n UART SET\r\n");

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();

  if (MX_FATFS_Init() != APP_OK)
  {
    Error_Handler();
  }
  ProcessStatus = APP_INIT;
  osKernelInitialize();

  UART_Print("\r\n AUDIO CONFIG\r\n");
  if(Audio_LoopbackInit() != 0)
  {
    UART_Print("\r\n ERROR AUDIO\r\n");
    while (1)
    {
      BSP_LED_Toggle(LED_ERROR);
      HAL_Delay(100);
    }
  }

  /* NOTE: Audio_DisableInputBoost() removed - was causing noise issues */

  UART_Print("\r\n END CONFIG\r\n");

  UART_Print("Entering main loop...\r\n");
  loop_count = 0;
  /* USER CODE BEGIN 2 */

  /* USER CODE END 2 */

  /* Infinite loop */

  /*fatfs_attr.name = "FATFS";
  FatFsThreadHandle = osThreadNew(MX_FATFS_Process, NULL, (const osThreadAttr_t *)&fatfs_attr);

  fatfs_attr.name = "STATUS";
  StatusThreadHandle = osThreadNew(STATUS_Thread, NULL, (const osThreadAttr_t *)&fatfs_attr);
*/
  // In main.c - Start audio loopback (needed to generate SAI clock for recording)
  AudioTaskHandle = osThreadNew(Audio_Loopback_Task, NULL, &audio_attr);

  // Start SD card recording task - will record 5 seconds of raw audio
  AudioRecordToSDTaskHandle = osThreadNew(Audio_Record_To_SD_Task, NULL, &audio_record_sd_attr);

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
static void SystemClock_Config(void)
{
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  HAL_StatusTypeDef ret = HAL_OK;

  /* The voltage scaling allows optimizing the power consumption when the device is
     clocked below the maximum system frequency, to update the voltage scaling value
     regarding system frequency refer to product datasheet.  */
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE0);

  while (!__HAL_PWR_GET_FLAG(PWR_FLAG_VOSRDY))
  {
  }

  /* Enable HSE Oscillator and activate PLL with HSE as source */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_ON;
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
  if (ret != HAL_OK)
  {
    while (1)
    {
    };
  }

  /* Select PLL as system clock source and configure  bus clocks dividers */
  RCC_ClkInitStruct.ClockType = (RCC_CLOCKTYPE_SYSCLK | RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_D1PCLK1 | RCC_CLOCKTYPE_PCLK1 |
                                 RCC_CLOCKTYPE_PCLK2 | RCC_CLOCKTYPE_D3PCLK1);

  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.SYSCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_HCLK_DIV2;
  RCC_ClkInitStruct.APB3CLKDivider = RCC_APB3_DIV2;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_APB1_DIV2;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_APB2_DIV2;
  RCC_ClkInitStruct.APB4CLKDivider = RCC_APB4_DIV2;
  ret = HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_3);
  if (ret != HAL_OK)
  {
    while (1)
    {
    };
  }
}

/**
 * @brief GPIO Initialization Function
 * @param None
 * @retval None
 */
static void MX_GPIO_Init(void)
{

  /* GPIO Ports Clock Enable */
}

/**
 * @brief  Toggle LED_GREEN thread
 * @param  thread not used
 * @retval None
 */
static void STATUS_Thread(void *argument)
{
  /* USER CODE BEGIN STATUS_Thread */
  (void)argument;

  for (;;)
  {
    if (ProcessStatus == APP_SD_UNPLUGGED)
    {
      BSP_LED_Off(LED_OK);
      BSP_LED_Toggle(LED_ERROR);
      osDelay(200);
    }
    else if (ProcessStatus == APP_ERROR)
    {
      Error_Handler();
    }
    else if (ProcessStatus == APP_OK)
    {
      BSP_LED_Off(LED_ERROR);
      BSP_LED_Toggle(LED_OK);
      osDelay(200);
    }
    else
    {
      BSP_LED_Off(LED_ERROR);
      BSP_LED_On(LED_OK);
    }
  }
  /* USER CODE END STATUS_Thread */
}

static void Audio_Loopback_Task(void *argument)
{
  UART_Print("Audio task init \r\n");

  // Clear buffers to ensure we play silence initially
  memset(RecordBuffer, 0, sizeof(RecordBuffer));
  memset(PlayBuffer, 0, sizeof(PlayBuffer));

  /* Start Playback FIRST to generate the SAI Clock */
  // This starts the SAI Master, which sends the Clock to the SAI Slave (Record)
  if (BSP_AUDIO_OUT_Play(0, (uint8_t *)PlayBuffer, BUFFER_SIZE * sizeof(int16_t)) != 0)
  {
    UART_Print("Audio Play Init Error\r\n");
    Error_Handler();
  }
  PlaybackStarted = 1;

  /* Start Recording */
  if (BSP_AUDIO_IN_Record(0, (uint8_t *)RecordBuffer, BUFFER_SIZE * sizeof(int16_t)) != 0)
  {
    UART_Print("Audio Record Init Error\r\n");
    Error_Handler();
  }

  UART_Print("Audio Recording Started - SD task will handle data\r\n");

  /* This task just keeps audio running, SD task handles the data */
  while (1)
  {
    osDelay(100);  /* Just keep task alive */
  }
}


static void Audio_Analysis_Task(void *argument)
{
    DSP_Init();
    uint32_t buffer_offset = 0;

    while (1)
    {
        // Wait for DMA to fill half the buffer
        if (HalfReady || FullReady)
        {
            // Determine which half of the DMA buffer to read
            int16_t *src_buffer = (HalfReady) ? &RecordBuffer[0] : &RecordBuffer[BUFFER_SIZE/2];

            // 1. Convert INT16 audio to FLOAT for FFT
            // We also take only the LEFT channel (stride of 2)
            for (int i = 0; i < FFT_SIZE; i++) {
                // Normalize to -1.0 to 1.0 range usually, or just cast
                if ((i * 2) < (BUFFER_SIZE / 2)) {
                   fft_input_buffer[i] = (float32_t)src_buffer[i * 2];
                } else {
                   fft_input_buffer[i] = 0.0f; // Zero padding if buffer too small
                }
            }

            // 2. Perform FFT
            arm_rfft_fast_f32(&fft_handler, fft_input_buffer, fft_output_buffer, 0);

            // 3. Calculate Magnitude
            // Complex magnitude: sqrt(real^2 + imag^2)
            arm_cmplx_mag_f32(fft_output_buffer, fft_magnitude, FFT_SIZE / 2);

            // 4. Find Dominant Frequency (Peak)
            // Ignore DC component (index 0)
            fft_magnitude[0] = 0;

            float32_t maxVal;
            uint32_t maxIndex;
            arm_max_f32(fft_magnitude, FFT_SIZE / 2, &maxVal, &maxIndex);

            // 5. Calculate Hz
            // Resolution = SampleRate / FFT_SIZE
            float frequency = (float)maxIndex * ((float)SAMPLE_RATE / (float)FFT_SIZE);

            // Print Result
            if (maxVal > 1000.0f) { // Noise gate
            	//UART_Print("Detected Freq: \r\n");
            	float new_frequency = frequency;
            	//UART_Print(frequency);
                //printf("Detected Freq: %.2f Hz (Mag: %.0f)\r\n", frequency, maxVal);
            }

            // Clear flags
            if (HalfReady) HalfReady = 0;
            if (FullReady) FullReady = 0;
        }
        //osDelay(10); // Yield
    }
}

/**
 * @brief  Task to record raw audio data to SD card for analysis
 *         Records 5 seconds of raw PCM data to "AUDIO.RAW"
 *         Format: 16-bit signed, stereo, 48kHz
 * @param  argument: Not used
 * @retval None
 */
static void Audio_Record_To_SD_Task(void *argument)
{
    FATFS SDFatFs;
    FIL AudioFile;
    FRESULT fres;
    UINT bytesWritten;
    uint32_t totalSamplesWritten = 0;
    uint32_t targetSamples = SAMPLES_TO_RECORD;
    char msg[64];

    UART_Print("SD Record Task Started\r\n");

    /* Wait a bit for system to stabilize */
    osDelay(1000);

    /* Check if SD card is present */
    if (BSP_SD_IsDetected(0) != SD_PRESENT)
    {
        UART_Print("ERROR: No SD card detected!\r\n");
        while(1) {
        	BSP_LED_Toggle(LED_ERROR);
        	      osDelay(200);}
    }

    /* Mount the file system */
    fres = f_mount(&SDFatFs, "", 1);
    if (fres != FR_OK)
    {
        sprintf(msg, "ERROR: f_mount failed: %d\r\n", fres);
        UART_Print(msg);
        while(1) { osDelay(1000); }
    }
    UART_Print("SD card mounted OK\r\n");

    /* Create/Open file for writing */
    fres = f_open(&AudioFile, "AUDIO.RAW", FA_CREATE_ALWAYS | FA_WRITE);
    if (fres != FR_OK)
    {
        sprintf(msg, "ERROR: f_open failed: %d\r\n", fres);
        UART_Print(msg);
        f_mount(NULL, "", 0);
        while(1) { osDelay(1000); }
    }
    UART_Print("File AUDIO.RAW created\r\n");
    UART_Print("Recording 5 seconds of audio...\r\n");

    /* Main recording loop */
    while (totalSamplesWritten < targetSamples)
    {
        if (HalfReady)
        {
            /* Write first half of buffer */
            fres = f_write(&AudioFile, &RecordBuffer[0],
                          (BUFFER_SIZE / 2) * sizeof(int16_t), &bytesWritten);
            if (fres != FR_OK)
            {
                sprintf(msg, "Write error: %d\r\n", fres);
                UART_Print(msg);
                break;
            }
            totalSamplesWritten += BUFFER_SIZE / 2;
            HalfReady = 0;
            BSP_LED_Toggle(LED_OK);
        }

        if (FullReady)
        {
            /* Write second half of buffer */
            fres = f_write(&AudioFile, &RecordBuffer[BUFFER_SIZE / 2],
                          (BUFFER_SIZE / 2) * sizeof(int16_t), &bytesWritten);
            if (fres != FR_OK)
            {
                sprintf(msg, "Write error: %d\r\n", fres);
                UART_Print(msg);
                break;
            }
            totalSamplesWritten += BUFFER_SIZE / 2;
            FullReady = 0;
        }

        osDelay(1);  /* Yield to other tasks */
    }

    /* Close file */
    f_close(&AudioFile);
    f_mount(NULL, "", 0);

    sprintf(msg, "Recording complete! %lu samples written\r\n", totalSamplesWritten);
    UART_Print(msg);
    UART_Print("File saved as AUDIO.RAW\r\n");
    UART_Print("Import in Audacity: Raw Data, Signed 16-bit PCM, Stereo, 48000Hz\r\n");

    g_RecordingComplete = 1;
    BSP_LED_On(LED_OK);

    /* Task complete - idle forever */
    while(1)
    {
        osDelay(1000);
    }
}

/* USER CODE BEGIN 4 */

/* USER CODE END 4 */

/**
 * @brief  This function is executed in case of error occurrence.
 * @retval None
 */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  BSP_LED_Off(LED_OK);
  BSP_LED_On(LED_ERROR);
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}

/**
 * @brief  Configure the MPU attributes
 * @param  None
 * @retval None
 */
static void MPU_Config(void)
{
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

  /* Enable the MPU */
  HAL_MPU_Enable(MPU_PRIVILEGED_DEFAULT);
}

static void MX_USART3_UART_Init(void)
{

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
  if (HAL_UART_Init(&huart3) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetTxFifoThreshold(&huart3, UART_TXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetRxFifoThreshold(&huart3, UART_RXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_DisableFifoMode(&huart3) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART3_Init 2 */

  /* USER CODE END USART3_Init 2 */
}

void HAL_UART_MspInit(UART_HandleTypeDef *huart)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  RCC_PeriphCLKInitTypeDef PeriphClkInitStruct = {0};

  if (huart->Instance == USART3)
  {
    /* Enable HSI oscillator for USART3 clock */
    __HAL_RCC_HSI_ENABLE();
    while (__HAL_RCC_GET_FLAG(RCC_FLAG_HSIRDY) == 0)
    {
    }

    /* Configure USART3 clock source as HSI (64 MHz) */
    PeriphClkInitStruct.PeriphClockSelection = RCC_PERIPHCLK_USART3;
    PeriphClkInitStruct.Usart234578ClockSelection = RCC_USART234578CLKSOURCE_HSI;
    if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInitStruct) != HAL_OK)
    {
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
PUTCHAR_PROTOTYPE
{
  /* Place your implementation of fputc here */
  /* e.g. write a character to the USART1 and Loop until the end of transmission */
  HAL_UART_Transmit(&huart3, (uint8_t *)&ch, 1, 0xFFFF);

  return ch;
}

static void CPU_CACHE_Enable(void)
{
  /* Enable I-Cache */
  SCB_EnableICache();

  /* Enable D-Cache */
  SCB_EnableDCache();
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
