#include "rtc_functions.h"
extern volatile uint8_t g_AlarmFlag;
extern osSemaphoreId_t ExtiSemaphoreHandle;
uint32_t NextAlarmFileOffset = 0;
uint8_t g_CurrentAlarmType = 0;

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
	// Check if RTC is in the backup register
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

	case '1': // match by day of month
		HAL_UART_Transmit(&huart3, (uint8_t*) "\n\rEnter Date (01-31): ", 21,
		HAL_MAX_DELAY);
		UART_Receive(buffer, 2);
		sAlarm.AlarmDateWeekDay = (buffer[0] - '0') * 10 + (buffer[1] - '0');
		sAlarm.AlarmDateWeekDaySel = RTC_ALARMDATEWEEKDAYSEL_DATE;
		sAlarm.AlarmMask = RTC_ALARMMASK_NONE;
		break;

	case '2': // match by weekday
		HAL_UART_Transmit(&huart3,
				(uint8_t*) "\n\rEnter Weekday (1=Mon, 7=Sun): ", 32,
				HAL_MAX_DELAY);
		UART_Receive(buffer, 1);
		sAlarm.AlarmDateWeekDay = buffer[0] - '0';
		sAlarm.AlarmDateWeekDaySel = RTC_ALARMDATEWEEKDAYSEL_WEEKDAY;
		sAlarm.AlarmMask = RTC_ALARMMASK_NONE;
		break;

	case '3': // match time only, ignore date
	default:
		sAlarm.AlarmDateWeekDay = 0x01; // ignored
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
	HAL_GPIO_WritePin(ARD_D6_PORT, ARD_D6_PIN, GPIO_PIN_RESET);
	g_AlarmFlag = 1;
	osSemaphoreRelease(ExtiSemaphoreHandle);
}

// Function to save the alarm set in the screen to the SD Card
// Here I can add the xtimes of exe and intervals
int32_t FS_WriteAlarm(uint8_t xtimes, uint8_t intervalMinutes,
		uint8_t intervalHours) {
	FRESULT res;
	uint32_t byteswritten;
	char wtext[50];
	RTC_AlarmTypeDef sAlarm;
	extern uint8_t g_AlarmWeekdayMask;

	// Get the current Alarm A configuration
	HAL_RTC_GetAlarm(&hrtc, &sAlarm, RTC_ALARM_A, RTC_FORMAT_BIN);
	// Save the original start time!
	uint8_t start_hours = sAlarm.AlarmTime.Hours;
	uint8_t start_minutes = sAlarm.AlarmTime.Minutes;
	uint8_t days = sAlarm.AlarmDateWeekDay;
	uint8_t weekday;

	// Mount the SD Card and open the file
	if (f_mount(&SDFatFS, (TCHAR const*) SDPath, 0) == FR_OK) {

		// Use FA_OPEN_APPEND to add to the list instead of overwriting it
		if (f_open(&SDFile, "ALARMS.TXT", FA_OPEN_APPEND | FA_WRITE) == FR_OK) {
			// Write the string multiple times

			for (uint8_t j = 0; j < 7; j++) {
				if ((g_AlarmWeekdayMask & (1 << j)) != 0) {
					weekday = j + 1;
					// Reset time for each new day
					uint8_t hours = start_hours;
					uint8_t minutes = start_minutes;

					for (uint8_t i = 0; i < xtimes; i++) {
						sprintf(wtext, "%d %d %02d %02d:%02d:%02d\n", g_CurrentAlarmType,0, weekday,
								hours, minutes, sAlarm.AlarmTime.Seconds);
						res = f_write(&SDFile, wtext, strlen(wtext),
								(void*) &byteswritten);
						minutes += intervalMinutes;
						while (minutes >= 60) {
							minutes -= 60; // Keep the remainder
							hours += 1;    // Carry over to the hour
						}

						hours += intervalHours;
						while (hours >= 24) {
							hours -= 24;   // Keep the remainder
							days += 1;     // Carry over to the day
						}

					}
				}
			}

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

// Helper function to flatten time into a single integer
static uint32_t FlattenTime(uint8_t date, uint8_t hours, uint8_t minutes,
		uint8_t seconds) {
	return (date * 86400) + (hours * 3600) + (minutes * 60) + seconds;
}

int32_t FS_ReadAlarmList(void) {
	char line[50];
	int status, weekday, hour, min, sec;
	uint32_t current_line_offset = 0; // Track where we are in the file

	RTC_TimeTypeDef currentTime;
	RTC_DateTypeDef currentDate;

	uint32_t current_flat_time = 0;
	uint32_t alarm_flat_time = 0;

	// Track the closest alarm
	uint32_t closest_future_time = 0xFFFFFFFF; // Start with max possible value
	int next_day = -1, next_hour = -1, next_min = -1, next_sec = -1;
	int type;//one shot or weekly alarm
	// Get the current exact time
	HAL_RTC_GetTime(&hrtc, &currentTime, RTC_FORMAT_BIN);
	HAL_RTC_GetDate(&hrtc, &currentDate, RTC_FORMAT_BIN);
	current_flat_time = FlattenTime(0, currentTime.Hours, currentTime.Minutes,
			currentTime.Seconds);

	// Open the file on the SD Card
	if (f_mount(&SDFatFS, (TCHAR const*) SDPath, 0) == FR_OK) {
		if (f_open(&SDFile, "ALARMS.TXT", FA_READ) == FR_OK) {

			while (!f_eof(&SDFile)) {
				// Save the exact byte offset BEFORE reading the line
				current_line_offset = f_tell(&SDFile);

				if (f_gets(line, sizeof(line), &SDFile) != NULL) {
					// Notice the "%d" at the start to catch the status flag
					int n = sscanf(line, "%d %d %d %d:%d:%d", &type, &status, &weekday,
							&hour, &min, &sec);
					//printf("line='%s' n=%d\r\n", line, n);
					if (n == 6) {
						// ONLY process this alarm if the status is 0 (Pending)
						if (status == 0) {
							// How many days in the future is this alarm?
							int days_ahead = weekday - currentDate.WeekDay;

							//Flatten the alarm time to check if it has already passed today
							uint32_t alarm_time_only = FlattenTime(0, hour, min,sec);
							//set alarm for next week
							if (days_ahead < 0
									|| (days_ahead == 0
											&& alarm_time_only
													<= current_flat_time)) {
								days_ahead += 7;
							}

							alarm_flat_time = FlattenTime(days_ahead, hour, min,
									sec);

							if (alarm_flat_time < closest_future_time) {
								closest_future_time = alarm_flat_time;
								NextAlarmFileOffset = current_line_offset;
								next_day = weekday;
								next_hour = hour;
								next_min = min;
								next_sec = sec;
							}
						}
					}
				}
			}
			f_close(&SDFile);

			// Did we find a valid future alarm? Set it in the hardware
			if (next_day != -1) {
				RTC_AlarmTypeDef sAlarm = { 0 };
				sAlarm.AlarmTime.Hours = next_hour;
				sAlarm.AlarmTime.Minutes = next_min;
				sAlarm.AlarmTime.Seconds = next_sec;
				sAlarm.AlarmDateWeekDay = next_day;

				sAlarm.AlarmDateWeekDaySel = RTC_ALARMDATEWEEKDAYSEL_WEEKDAY;
				sAlarm.AlarmMask = RTC_ALARMMASK_NONE; // Match exact day and time
				sAlarm.Alarm = RTC_ALARM_A;

				if (HAL_RTC_SetAlarm_IT(&hrtc, &sAlarm, RTC_FORMAT_BIN)
						== HAL_OK) {
					char msg[60];
					sprintf(msg,
							"\r\nNext Alarm set for Day %02d at %02d:%02d:%02d\r\n",
							next_day, next_hour, next_min, next_sec);
					HAL_UART_Transmit(&huart3, (uint8_t*) msg, strlen(msg),
					HAL_MAX_DELAY);
					return 0; // Success
				}
			} else {
				HAL_UART_Transmit(&huart3,
						(uint8_t*) "\r\nNo future alarms found in file.\r\n",
						35, HAL_MAX_DELAY);
			}
		}
	}
	return -1; // Error
}

int32_t FS_MarkAlarmExecuted(void) {
	FRESULT res;
	uint32_t byteswritten;
	char executed_flag = '1';

	if (f_mount(&SDFatFS, (TCHAR const*) SDPath, 0) == FR_OK) {

		// Open with FA_WRITE so we can modify the file
		if (f_open(&SDFile, "ALARMS.TXT", FA_WRITE | FA_OPEN_EXISTING)
				== FR_OK) {

			// Fast-forward the file pointer to the exact byte of our target alarm
			f_lseek(&SDFile, NextAlarmFileOffset);

			// Overwrite the '0' with a '1'
			res = f_write(&SDFile, &executed_flag, 1, (void*) &byteswritten);

			f_close(&SDFile);

			if (res == FR_OK && byteswritten == 1) {
				HAL_UART_Transmit(&huart3,
						(uint8_t*) "\r\nAlarm marked as executed!\r\n", 29,
						HAL_MAX_DELAY);
				return 0; // Success
			}
		}
	}
	return -1; // Error
}
