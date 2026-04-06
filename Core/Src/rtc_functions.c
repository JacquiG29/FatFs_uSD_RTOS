#include "rtc_functions.h"
extern volatile uint8_t g_AlarmFlag;
extern osSemaphoreId_t ExtiSemaphoreHandle;

void SystemClock_ConfigRTC(void) {
}

void MX_RTC_Init(void) {

	/* USER CODE BEGIN RTC_Init 0 */

	/* USER CODE END RTC_Init 0 */

	RTC_TimeTypeDef sTime = { 0 };
	RTC_DateTypeDef sDate = { 0 };
	RTC_AlarmTypeDef sAlarm = { 0 };

	/* USER CODE BEGIN RTC_Init 1 */

	/* USER CODE END RTC_Init 1 */

	/** Initialize RTC Only
	 */
	hrtc.Instance = RTC;
	hrtc.Init.HourFormat = RTC_HOURFORMAT_24;
	hrtc.Init.AsynchPrediv = 127;
	hrtc.Init.SynchPrediv = 255;
	hrtc.Init.OutPut = RTC_OUTPUT_DISABLE;
	hrtc.Init.OutPutPolarity = RTC_OUTPUT_POLARITY_HIGH;
	hrtc.Init.OutPutType = RTC_OUTPUT_TYPE_OPENDRAIN;
	hrtc.Init.OutPutRemap = RTC_OUTPUT_REMAP_NONE;
	if (HAL_RTC_Init(&hrtc) != HAL_OK) {
		Error_Handler();
	}

	/* USER CODE BEGIN Check_RTC_BKUP */
	//Check if RTC is in the backup register
	if (HAL_RTCEx_BKUPRead(&hrtc, RTC_BKP_DR1) == 0xBEBE) {
		// The RTC is already running perfectly.
		// We "return" right now to exit the function BEFORE it resets the time below.
		flag_set_time = 0;
		return;
	}
	/* USER CODE END Check_RTC_BKUP */

	/** Initialize RTC and set the Time and Date
	 */
	sTime.Hours = 0x0;
	sTime.Minutes = 0x0;
	sTime.Seconds = 0x0;
	sTime.DayLightSaving = RTC_DAYLIGHTSAVING_SUB1H;
	sTime.StoreOperation = RTC_STOREOPERATION_SET;
	if (HAL_RTC_SetTime(&hrtc, &sTime, RTC_FORMAT_BCD) != HAL_OK) {
		Error_Handler();
	}
	sDate.WeekDay = RTC_WEEKDAY_MONDAY;
	sDate.Month = RTC_MONTH_JANUARY;
	sDate.Date = 0x01;
	sDate.Year = 0x00;
	if (HAL_RTC_SetDate(&hrtc, &sDate, RTC_FORMAT_BCD) != HAL_OK) {
		Error_Handler();
	}

	/** Enable the Alarm A
	 */
	sAlarm.AlarmTime.Hours = 0x0;
	sAlarm.AlarmTime.Minutes = 0x0;
	sAlarm.AlarmTime.Seconds = 0x0;
	sAlarm.AlarmTime.SubSeconds = 0x0;
	sAlarm.AlarmTime.DayLightSaving = RTC_DAYLIGHTSAVING_SUB1H;
	sAlarm.AlarmTime.StoreOperation = RTC_STOREOPERATION_SET;
	sAlarm.AlarmMask = RTC_ALARMMASK_NONE;
	sAlarm.AlarmSubSecondMask = RTC_ALARMSUBSECONDMASK_ALL;
	sAlarm.AlarmDateWeekDaySel = RTC_ALARMDATEWEEKDAYSEL_DATE;
	sAlarm.AlarmDateWeekDay = 0x1;
	sAlarm.Alarm = RTC_ALARM_A;
	if (HAL_RTC_SetAlarm_IT(&hrtc, &sAlarm, RTC_FORMAT_BCD) != HAL_OK) {
		Error_Handler();
	}
	/* USER CODE BEGIN RTC_Init 2 */
	// We only reach this point if the RTC WASN'T configured in the register (first boot).
	// The time was just set above. Now, save current value so we don't reset next boot.
	HAL_PWR_EnableBkUpAccess();
	HAL_RTCEx_BKUPWrite(&hrtc, RTC_BKP_DR1, 0xBEBE);
	HAL_PWR_DisableBkUpAccess();

	HAL_NVIC_SetPriority(RTC_Alarm_IRQn, 6, 0); /* Must be >= configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY (5) for FreeRTOS API calls */
	HAL_NVIC_EnableIRQ(RTC_Alarm_IRQn);
	/* USER CODE END RTC_Init 2 */

}

/**
 * @brief RTC MSP Initialization
 * This function configures the hardware resources used in this example
 * @param hrtc: RTC handle pointer
 * @retval None
 */
void HAL_RTC_MspInit(RTC_HandleTypeDef *hrtc) {
	RCC_PeriphCLKInitTypeDef PeriphClkInitStruct = { 0 };
	if (hrtc->Instance == RTC) {
		/* USER CODE BEGIN RTC_MspInit 0 */

		/* USER CODE END RTC_MspInit 0 */

		/** Initializes the peripherals clock
		 */
		PeriphClkInitStruct.PeriphClockSelection = RCC_PERIPHCLK_RTC;
		PeriphClkInitStruct.RTCClockSelection = RCC_RTCCLKSOURCE_LSE;
		if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInitStruct) != HAL_OK) {
			Error_Handler();
		}

		/* Peripheral clock enable */
		__HAL_RCC_RTC_ENABLE();
		/* RTC interrupt Init */
		HAL_NVIC_SetPriority(RTC_Alarm_IRQn, 6, 0); /* Must be >= configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY (5) for FreeRTOS API calls */
		HAL_NVIC_EnableIRQ(RTC_Alarm_IRQn);
		/* USER CODE BEGIN RTC_MspInit 1 */

		/* USER CODE END RTC_MspInit 1 */

	}

}

/**
 * @brief RTC MSP De-Initialization
 * This function freeze the hardware resources used in this example
 * @param hrtc: RTC handle pointer
 * @retval None
 */
void HAL_RTC_MspDeInit(RTC_HandleTypeDef *hrtc) {
	if (hrtc->Instance == RTC) {
		/* USER CODE BEGIN RTC_MspDeInit 0 */

		/* USER CODE END RTC_MspDeInit 0 */
		/* Peripheral clock disable */
		__HAL_RCC_RTC_DISABLE();

		/* RTC interrupt DeInit */
		HAL_NVIC_DisableIRQ(RTC_Alarm_IRQn);
		/* USER CODE BEGIN RTC_MspDeInit 1 */

		/* USER CODE END RTC_MspDeInit 1 */
	}

}

void UART_Receive(uint8_t *buffer, uint16_t size) {
	// Ensure the buffer is null-terminated
	HAL_UART_Receive(&huart3, buffer, size, HAL_MAX_DELAY);
	buffer[size] = '\0';
}

uint8_t Set_RTC_Time(void) {
	RTC_TimeTypeDef sTime = { 0 };
	uint8_t buffer[3];

	HAL_UART_Transmit(&huart3, (uint8_t*) "Enter Hours (00-23): ", 21,
	HAL_MAX_DELAY);
	UART_Receive(buffer, 2);
	sTime.Hours = (buffer[0] - '0') * 10 + (buffer[1] - '0');

	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rEnter Minutes (00-59): ", 24,
	HAL_MAX_DELAY);
	UART_Receive(buffer, 2);
	sTime.Minutes = (buffer[0] - '0') * 10 + (buffer[1] - '0');

	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rEnter Seconds (00-59): \n\r", 24,
	HAL_MAX_DELAY);
	UART_Receive(buffer, 2);
	sTime.Seconds = (buffer[0] - '0') * 10 + (buffer[1] - '0');

	sTime.DayLightSaving = RTC_DAYLIGHTSAVING_NONE;
	sTime.StoreOperation = RTC_STOREOPERATION_RESET;

	if (HAL_RTC_SetTime(&hrtc, &sTime, RTC_FORMAT_BIN) != HAL_OK) {
		Error_Handler();
	}
	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rTime is set!\n\r ", 16,
	HAL_MAX_DELAY);
	return 1;
}

uint8_t Set_RTC_Date(void) {
	RTC_DateTypeDef sDate = { 0 };
	uint8_t buffer[3];

	HAL_UART_Transmit(&huart3, (uint8_t*) "Enter Year (00-99): ", 20,
	HAL_MAX_DELAY);
	UART_Receive(buffer, 2);
	sDate.Year = (buffer[0] - '0') * 10 + (buffer[1] - '0');

	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rEnter Month (01-12): ", 22,
	HAL_MAX_DELAY);
	UART_Receive(buffer, 2);
	sDate.Month = (buffer[0] - '0') * 10 + (buffer[1] - '0');

	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rEnter Date (01-31): ", 21,
	HAL_MAX_DELAY);
	UART_Receive(buffer, 2);
	sDate.Date = (buffer[0] - '0') * 10 + (buffer[1] - '0');

	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rEnter Weekday (1=Mon, 7=Sun): ",
			33, HAL_MAX_DELAY);
	UART_Receive(buffer, 1);
	sDate.WeekDay = buffer[0] - '0';

	if (HAL_RTC_SetDate(&hrtc, &sDate, RTC_FORMAT_BIN) != HAL_OK) {
		Error_Handler();
	}
	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rDate is set!\n\r ", 16,
	HAL_MAX_DELAY);
	return 1;
}

uint8_t Set_RTC_Alarm(void) {
	RTC_AlarmTypeDef sAlarm = { 0 };
	uint8_t buffer[3];

	// --- Time ---
	HAL_UART_Transmit(&huart3, (uint8_t*) "Enter Alarm Hours (00-23): ", 27,
	HAL_MAX_DELAY);
	UART_Receive(buffer, 2);
	sAlarm.AlarmTime.Hours = (buffer[0] - '0') * 10 + (buffer[1] - '0');

	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rEnter Alarm Minutes (00-59): ",
			30, HAL_MAX_DELAY);
	UART_Receive(buffer, 2);
	sAlarm.AlarmTime.Minutes = (buffer[0] - '0') * 10 + (buffer[1] - '0');

	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rEnter Alarm Seconds (00-59): ",
			30, HAL_MAX_DELAY);
	UART_Receive(buffer, 2);
	sAlarm.AlarmTime.Seconds = (buffer[0] - '0') * 10 + (buffer[1] - '0');

	// --- Date mode ---
	HAL_UART_Transmit(&huart3,
			(uint8_t*) "\n\rMatch by: (1) Date  (2) Weekday  (3) Time only: ",
			50, HAL_MAX_DELAY);
	UART_Receive(buffer, 1);

	switch (buffer[0]) {

	case '1':  // match by day of month
		HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rEnter Date (01-31): ", 21,
		HAL_MAX_DELAY);
		UART_Receive(buffer, 2);
		sAlarm.AlarmDateWeekDay = (buffer[0] - '0') * 10 + (buffer[1] - '0');
		sAlarm.AlarmDateWeekDaySel = RTC_ALARMDATEWEEKDAYSEL_DATE;
		sAlarm.AlarmMask = RTC_ALARMMASK_NONE;
		break;

	case '2':  // match by weekday
		HAL_UART_Transmit(&huart3,
				(uint8_t*) "\n\rEnter Weekday (1=Mon, 7=Sun): ", 32,
				HAL_MAX_DELAY);
		UART_Receive(buffer, 1);
		sAlarm.AlarmDateWeekDay = buffer[0] - '0';
		sAlarm.AlarmDateWeekDaySel = RTC_ALARMDATEWEEKDAYSEL_WEEKDAY;
		sAlarm.AlarmMask = RTC_ALARMMASK_NONE;
		break;

	case '3':  // match time only, ignore date
	default:
		sAlarm.AlarmDateWeekDay = 0x01;  // ignored
		sAlarm.AlarmDateWeekDaySel = RTC_ALARMDATEWEEKDAYSEL_DATE;
		sAlarm.AlarmMask = RTC_ALARMMASK_DATEWEEKDAY;
		break;
	}

	sAlarm.AlarmTime.SubSeconds = 0;
	sAlarm.AlarmTime.DayLightSaving = RTC_DAYLIGHTSAVING_NONE;
	sAlarm.AlarmTime.StoreOperation = RTC_STOREOPERATION_RESET;
	sAlarm.AlarmSubSecondMask = RTC_ALARMSUBSECONDMASK_ALL;
	sAlarm.Alarm = RTC_ALARM_A;

	if (HAL_RTC_SetAlarm_IT(&hrtc, &sAlarm, RTC_FORMAT_BIN) != HAL_OK) {
		Error_Handler();
	}
	HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rAlarm is set!\n\r", 17,
	HAL_MAX_DELAY);
}

void Print_Time(void) {
	RTC_TimeTypeDef sTime;
	RTC_DateTypeDef sDate;
	char buffer[50];

	HAL_RTC_GetTime(&hrtc, &sTime, RTC_FORMAT_BIN);
	HAL_RTC_GetDate(&hrtc, &sDate, RTC_FORMAT_BIN); // <-- unlock shadow registers
	sprintf(buffer, "Current Time: %02d:%02d:%02d\n\r", sTime.Hours,
			sTime.Minutes, sTime.Seconds);
	HAL_UART_Transmit(&huart3, (uint8_t*) buffer, strlen(buffer),
	HAL_MAX_DELAY);
}

void Print_Date(void) {
	RTC_DateTypeDef sDate;
	char buffer[50];

	HAL_RTC_GetDate(&hrtc, &sDate, RTC_FORMAT_BIN);
	sprintf(buffer, "Current Date: %02d-%02d-20%02d\n\r", sDate.Date,
			sDate.Month, sDate.Year);
	HAL_UART_Transmit(&huart3, (uint8_t*) buffer, strlen(buffer),
	HAL_MAX_DELAY);
}

void Print_Alarm(void) {
	RTC_AlarmTypeDef sAlarm;
	char buffer[50];

	HAL_RTC_GetAlarm(&hrtc, &sAlarm, RTC_ALARM_A, RTC_FORMAT_BIN);

	// Print time
	sprintf(buffer, "Alarm Time: %02d:%02d:%02d\n\r", sAlarm.AlarmTime.Hours,
			sAlarm.AlarmTime.Minutes, sAlarm.AlarmTime.Seconds);
	HAL_UART_Transmit(&huart3, (uint8_t*) buffer, strlen(buffer),
	HAL_MAX_DELAY);

	// Print date mode
	if (sAlarm.AlarmMask & RTC_ALARMMASK_DATEWEEKDAY) {
		// Bit is set -> date/weekday is masked out -> time-only mode
		HAL_UART_Transmit(&huart3, (uint8_t*) "Match: Time only\n\r", 18,
		HAL_MAX_DELAY);

	} else if (sAlarm.AlarmDateWeekDaySel == RTC_ALARMDATEWEEKDAYSEL_WEEKDAY) {
		sprintf(buffer, "Match: Weekday %d\n\r", sAlarm.AlarmDateWeekDay);
		HAL_UART_Transmit(&huart3, (uint8_t*) buffer, strlen(buffer),
		HAL_MAX_DELAY);

	} else {
		sprintf(buffer, "Match: Date %02d\n\r", sAlarm.AlarmDateWeekDay);
		HAL_UART_Transmit(&huart3, (uint8_t*) buffer, strlen(buffer),
		HAL_MAX_DELAY);
	}
}

void Show_Menu(void) {
	const char *menu = "\r\nMenu:\r\n"
			"0. Show Menu\r\n"
			"1. Show Time\r\n"
			"2. Show Date\r\n"
			"3. Show Alarm\r\n"
			"4. Set Time\r\n"
			"5. Set Date\r\n"
			"6. Set Alarm\r\n"
			"7. Reset Alarm Led\r\n\n";

	HAL_UART_Transmit(&huart3, (uint8_t*) menu, strlen(menu), HAL_MAX_DELAY);
}

void HAL_RTC_AlarmAEventCallback(RTC_HandleTypeDef *hrtc) {
	BSP_LED_On(LED_ERROR);
	HAL_GPIO_WritePin(ARD_D6_PORT, ARD_D6_PIN, GPIO_PIN_SET);
    g_AlarmFlag = 1;
    osSemaphoreRelease(ExtiSemaphoreHandle);
}

static int32_t FS_WriteAlarm(void) {
	FRESULT res;
	uint32_t byteswritten;
	char wtext[50];
	RTC_AlarmTypeDef sAlarm;

	// Get the current Alarm A configuration
	HAL_RTC_GetAlarm(&hrtc, &sAlarm, RTC_ALARM_A, RTC_FORMAT_BIN);

	//Format it into a string with a newline character at the end
	sprintf(wtext, "%02d %02d:%02d:%02d\n", sAlarm.AlarmDateWeekDay,
			sAlarm.AlarmTime.Hours, sAlarm.AlarmTime.Minutes,
			sAlarm.AlarmTime.Seconds);

	// Mount the SD Card and open the file
	if (f_mount(&SDFatFS, (TCHAR const*) SDPath, 0) == FR_OK) {

		// Use FA_OPEN_APPEND to add to the list instead of overwriting it
		if (f_open(&SDFile, "ALARMS.TXT", FA_OPEN_APPEND | FA_WRITE) == FR_OK) {

			// Write the string
			res = f_write(&SDFile, wtext, strlen(wtext), (void*) &byteswritten);
			f_close(&SDFile);

			if ((res == FR_OK) && (byteswritten > 0)) {
				HAL_UART_Transmit(&huart3,
						(uint8_t*) "\r\nAlarm saved to ALARMS.TXT\r\n", 30,
						HAL_MAX_DELAY);
				return 0; // Success
			}
		}
	}

	HAL_UART_Transmit(&huart3, (uint8_t*) "\r\nFailed to write to SD Card.\r\n",
			31, HAL_MAX_DELAY);
	return -1; // Error
}

static int32_t FS_ReadAlarmList(void) {
	char line[50];
	char uart_buf[100];
	int day, hour, min, sec;

	if (f_mount(&SDFatFS, (TCHAR const*) SDPath, 0) == FR_OK) {

		// Open the file with Read access
		if (f_open(&SDFile, "ALARMS.TXT", FA_READ) == FR_OK) {

			HAL_UART_Transmit(&huart3,
					(uint8_t*) "\r\n--- SD Card Alarm List ---\r\n", 30,
					HAL_MAX_DELAY);

			// Read the file line by line until we hit the end
			while (f_gets(line, sizeof(line), &SDFile) != NULL) {

				// Extract the integers from our "DD HH:MM:SS" format
				if (sscanf(line, "%d %d:%d:%d", &day, &hour, &min, &sec) == 4) {

					// --- NEXT-IN-LINE LOGIC GOES HERE ---
					// Right now, it just prints the alarm to UART.
					// Later, you can load these into a struct array, sort them,
					// and push the earliest one to Alarm A.

					sprintf(uart_buf,
							"Parsed Alarm -> Day: %02d, Time: %02d:%02d:%02d\r\n",
							day, hour, min, sec);
					HAL_UART_Transmit(&huart3, (uint8_t*) uart_buf,
							strlen(uart_buf), HAL_MAX_DELAY);
				}
			}

			f_close(&SDFile); // Always close the file
			return 0; // Success
		}
	}

	HAL_UART_Transmit(&huart3, (uint8_t*) "\r\nCannot read ALARMS.TXT\r\n", 26,
			HAL_MAX_DELAY);
	return -1; // Error
}
