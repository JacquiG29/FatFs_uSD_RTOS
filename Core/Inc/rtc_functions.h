/*
 * rtc_functions.h
 *
 *  Created on: Mar 11, 2026
 *      Author: Lenovo
 */

#ifndef APPLICATION_USER_CORE_RTC_FUNCTIONS_H_
#define APPLICATION_USER_CORE_RTC_FUNCTIONS_H_


#include "main.h"
#include "stm32h7xx_hal.h"
#include <stdio.h>
#include <string.h>
#include "ff.h"      // FatFs header
#include <stdlib.h>  // For string manipulation if needed

extern RTC_HandleTypeDef hrtc;
extern UART_HandleTypeDef huart3;
extern volatile uint8_t g_AlarmFlag;
extern osSemaphoreId_t ExtiSemaphoreHandle;


// Pull in the global FatFs variables defined in app_fatfs.c
extern FATFS SDFatFS;
extern FIL SDFile;
extern char SDPath[4];
extern uint8_t flag_set_time;
void MX_RTC_Init(void);
uint8_t Set_RTC_Time(void);
uint8_t Set_RTC_Date(void);
uint8_t Set_RTC_Alarm(void);
void Show_Menu(void);
void Print_Time(void);
void Print_Date(void);
void Print_Alarm(void);
void HAL_RTC_AlarmAEventCallback(RTC_HandleTypeDef *hrtc);
void UART_Receive(uint8_t *data, uint16_t size);
int32_t FS_WriteAlarm(uint8_t xtimes, uint8_t intervalMinutes, uint8_t intervalHours);
//static int32_t FS_WriteAlarm(void);
int32_t FS_ReadAlarmList(void);
int32_t FS_MarkAlarmExecuted(void);
#endif /* APPLICATION_USER_CORE_RTC_FUNCTIONS_H_ */
