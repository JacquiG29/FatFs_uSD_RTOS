/*
 * lcd_function.h
 *
 *  Created on: Mar 11, 2026
 *      Author: Lenovo
 */

#ifndef APPLICATION_USER_CORE_LCD_FUNCTION_H_
#define APPLICATION_USER_CORE_LCD_FUNCTION_H_

#include "main.h"
#include "stm32h735g_discovery_ts.h"
#include "ft5336.h"
#include "gt911.h"

typedef struct {
	uint16_t x;
	uint16_t y;
	uint16_t w;
	uint16_t h;
} TouchZone_t;

void StartMenu_LCD(char version[10]);
void Print_DateTime_LCD(void);
uint8_t Set_DateTime_LCD(void);
void Standalone_Menu(char version[10]);
void RF_Menu(char version[10]);
uint8_t Set_Mode_LCD(void);

uint8_t Set_Day_Alarm_LCD(void);
uint8_t Set_Weekday_Alarm_LCD(void);
uint8_t Set_Time_Alarm_LCD(void);
uint8_t Alarm_Type_LCD(void);
void Set_Alarm_button_LCD(void);

/* New alarm-workflow screens */
uint8_t Pick_Time_LCD(uint8_t *hours, uint8_t *minutes, uint8_t *seconds);
uint8_t Pick_Weekdays_LCD(uint8_t *mask);
uint8_t Pick_Repeat_LCD(uint8_t *times, uint8_t *iHours, uint8_t *iMinutes);
uint8_t Alarm_Workflow_LCD(void);

/* Globals populated by the alarm workflow */
extern uint8_t  g_AlarmWeekdayMask;   /* bit0=Mon .. bit6=Sun, 0x7F = everyday */
extern uint8_t  g_AlarmXTimes;        /* number of repetitions */
extern uint8_t  g_AlarmIntervalHours;
extern uint8_t  g_AlarmIntervalMinutes;

extern volatile uint8_t g_Mode;
#endif /* APPLICATION_USER_CORE_LCD_FUNCTION_H_ */
