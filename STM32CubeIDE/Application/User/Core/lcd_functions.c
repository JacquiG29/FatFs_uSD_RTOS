/*
 * lcd_screens.c
 *
 *  Created on: Mar 27, 2026
 *      Author: Lenovo
 */

#include "lcd_function.h"
extern uint8_t system_mode;

/* Globals populated by the alarm workflow (defaults match user request) */
uint8_t g_AlarmWeekdayMask    = 0x7F; /* everyday */
uint8_t g_AlarmXTimes         = 6;
uint8_t g_AlarmIntervalHours  = 0;
uint8_t g_AlarmIntervalMinutes = 10;

void StartMenu_LCD(char version[10]) {
	char message[15] = { 0 };
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_DisplayStringAt(0, 80, (uint8_t*) "Audio Acquisition System",
			CENTER_MODE);
	UTIL_LCD_SetFont(&Font16);
	sprintf(message, "Version: %s", version);
	UTIL_LCD_DisplayStringAt(0, 120, (uint8_t*) message, CENTER_MODE);
}

void Standalone_Menu(char version[10]) {
	char message[15] = { 0 };
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_DisplayStringAt(0, 80, (uint8_t*) "Standalone mode", CENTER_MODE);
	UTIL_LCD_SetFont(&Font16);
	sprintf(message, "Version: %s", version);
	UTIL_LCD_DisplayStringAt(0, 120, (uint8_t*) message, CENTER_MODE);
}
void RF_Menu(char version[10]) {
	char message[15] = { 0 };
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_DisplayStringAt(0, 80, (uint8_t*) "Distributed node", CENTER_MODE);
	UTIL_LCD_SetFont(&Font16);
	sprintf(message, "Version: %s", version);
	UTIL_LCD_DisplayStringAt(0, 120, (uint8_t*) message, CENTER_MODE);
}

/* ---------------------------------------------------------------------------
 * Touchscreen helpers
 * --------------------------------------------------------------------------- */

static uint8_t ts_initialized = 0;

static int32_t TS_InitOnce(void) {
	if (ts_initialized)
		return BSP_ERROR_NONE;

	TS_Init_t hTS;
	hTS.Width = 480;
	hTS.Height = 272;
	hTS.Accuracy = 0;

	if (GT911_Probe(0) == BSP_ERROR_NONE) {
		hTS.Orientation = TS_SWAP_NONE;
	} else if (FT5336_Probe(0) == BSP_ERROR_NONE) {
		hTS.Orientation = TS_SWAP_XY;
	} else {
		return BSP_ERROR_COMPONENT_FAILURE;
	}

	int32_t ret = BSP_TS_Init(0, &hTS);
	if (ret == BSP_ERROR_NONE)
		ts_initialized = 1;
	return ret;
}

static uint8_t IsTouchInZone(uint32_t tx, uint32_t ty, const TouchZone_t *z) {
	return (tx >= z->x && tx < (z->x + z->w) && ty >= z->y && ty < (z->y + z->h));
}

static void DrawButton(const TouchZone_t *z, const char *label,
		uint32_t bgColor, uint32_t textColor) {
	UTIL_LCD_FillRect(z->x, z->y, z->w, z->h, bgColor);
	UTIL_LCD_DrawRect(z->x, z->y, z->w, z->h, textColor);
	UTIL_LCD_SetBackColor(bgColor);
	UTIL_LCD_SetTextColor(textColor);
	UTIL_LCD_SetFont(&Font16);
	uint16_t textX = z->x + (z->w / 2) - (strlen(label) * 8 / 2);
	uint16_t textY = z->y + (z->h / 2) - 8;
	UTIL_LCD_DisplayStringAt(textX, textY, (uint8_t*) label, LEFT_MODE);
}

static void WaitForTouchRelease(void) {
	TS_State_t st;
	do {
		HAL_Delay(20);
		//osDelay(pdMS_TO_TICKS(20));
		BSP_TS_GetState(0, &st);
	} while (st.TouchDetected);
}

/* ---------------------------------------------------------------------------
 * Set Date & Time via LCD touchscreen
 *
 * Page 1: Set Time  (Hours / Minutes / Seconds)  -> [Next] / [Cancel]
 * Page 2: Set Date  (Day / Month / Year)          -> [Set]  / [Back]
 *
 * Returns 1 on success, 0 if cancelled.
 * --------------------------------------------------------------------------- */

/* Layout constants for 480x272 display */
#define COL1_X   60
#define COL2_X  200
#define COL3_X  340
#define BTN_W    80
#define BTN_H    35

#define UP_Y     65
#define VAL_Y   115
#define DOWN_Y  155

#define ACTION_Y  220
#define OK_X      100
#define CANCEL_X  290

static void DrawSetTimeScreen(uint8_t hours, uint8_t minutes, uint8_t seconds) {
	char buf[6];

	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);

	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_DisplayStringAt(0, 10, (uint8_t*) "Set Time", CENTER_MODE);

	/* Column labels */
	UTIL_LCD_SetFont(&Font16);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_LIGHTGRAY);
	UTIL_LCD_DisplayStringAt(COL1_X + 12, 48, (uint8_t*) "Hours", LEFT_MODE);
	UTIL_LCD_DisplayStringAt(COL2_X + 16, 48, (uint8_t*) "Min", LEFT_MODE);
	UTIL_LCD_DisplayStringAt(COL3_X + 16, 48, (uint8_t*) "Sec", LEFT_MODE);

	/* Up buttons */
	TouchZone_t z = { COL1_X, UP_Y, BTN_W, BTN_H };
	DrawButton(&z, "+", UTIL_LCD_COLOR_DARKGREEN, UTIL_LCD_COLOR_WHITE);
	z.x = COL2_X;
	DrawButton(&z, "+", UTIL_LCD_COLOR_DARKGREEN, UTIL_LCD_COLOR_WHITE);
	z.x = COL3_X;
	DrawButton(&z, "+", UTIL_LCD_COLOR_DARKGREEN, UTIL_LCD_COLOR_WHITE);

	/* Values */
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_CYAN);
	sprintf(buf, "%02d", hours);
	UTIL_LCD_DisplayStringAt(COL1_X + 20, VAL_Y, (uint8_t*) buf, LEFT_MODE);
	sprintf(buf, "%02d", minutes);
	UTIL_LCD_DisplayStringAt(COL2_X + 20, VAL_Y, (uint8_t*) buf, LEFT_MODE);
	sprintf(buf, "%02d", seconds);
	UTIL_LCD_DisplayStringAt(COL3_X + 20, VAL_Y, (uint8_t*) buf, LEFT_MODE);

	/* Separators */
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	UTIL_LCD_DisplayStringAt(COL1_X + BTN_W + 10, VAL_Y, (uint8_t*) ":",
			LEFT_MODE);
	UTIL_LCD_DisplayStringAt(COL2_X + BTN_W + 10, VAL_Y, (uint8_t*) ":",
			LEFT_MODE);

	/* Down buttons */
	z.y = DOWN_Y;
	z.x = COL1_X;
	DrawButton(&z, "-", UTIL_LCD_COLOR_DARKRED, UTIL_LCD_COLOR_WHITE);
	z.x = COL2_X;
	DrawButton(&z, "-", UTIL_LCD_COLOR_DARKRED, UTIL_LCD_COLOR_WHITE);
	z.x = COL3_X;
	DrawButton(&z, "-", UTIL_LCD_COLOR_DARKRED, UTIL_LCD_COLOR_WHITE);

	/* Action buttons */
	z = (TouchZone_t ) { OK_X, ACTION_Y, 100, 40 };
	DrawButton(&z, "Next", UTIL_LCD_COLOR_BLUE, UTIL_LCD_COLOR_WHITE);
	z = (TouchZone_t ) { CANCEL_X, ACTION_Y, 100, 40 };
	DrawButton(&z, "Cancel", UTIL_LCD_COLOR_DARKGRAY, UTIL_LCD_COLOR_WHITE);
}

static void DrawSetDateScreen(uint8_t day, uint8_t month, uint8_t year) {
	char buf[6];

	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);

	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_DisplayStringAt(0, 10, (uint8_t*) "Set Date", CENTER_MODE);

	/* Column labels */
	UTIL_LCD_SetFont(&Font16);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_LIGHTGRAY);
	UTIL_LCD_DisplayStringAt(COL1_X + 16, 48, (uint8_t*) "Day", LEFT_MODE);
	UTIL_LCD_DisplayStringAt(COL2_X + 8, 48, (uint8_t*) "Month", LEFT_MODE);
	UTIL_LCD_DisplayStringAt(COL3_X + 12, 48, (uint8_t*) "Year", LEFT_MODE);

	/* Up buttons */
	TouchZone_t z = { COL1_X, UP_Y, BTN_W, BTN_H };
	DrawButton(&z, "+", UTIL_LCD_COLOR_DARKGREEN, UTIL_LCD_COLOR_WHITE);
	z.x = COL2_X;
	DrawButton(&z, "+", UTIL_LCD_COLOR_DARKGREEN, UTIL_LCD_COLOR_WHITE);
	z.x = COL3_X;
	DrawButton(&z, "+", UTIL_LCD_COLOR_DARKGREEN, UTIL_LCD_COLOR_WHITE);

	/* Values */
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_CYAN);
	sprintf(buf, "%02d", day);
	UTIL_LCD_DisplayStringAt(COL1_X + 20, VAL_Y, (uint8_t*) buf, LEFT_MODE);
	sprintf(buf, "%02d", month);
	UTIL_LCD_DisplayStringAt(COL2_X + 20, VAL_Y, (uint8_t*) buf, LEFT_MODE);
	sprintf(buf, "20%02d", year);
	UTIL_LCD_DisplayStringAt(COL3_X + 8, VAL_Y, (uint8_t*) buf, LEFT_MODE);

	/* Separators */
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	UTIL_LCD_DisplayStringAt(COL1_X + BTN_W + 10, VAL_Y, (uint8_t*) "/",
			LEFT_MODE);
	UTIL_LCD_DisplayStringAt(COL2_X + BTN_W + 10, VAL_Y, (uint8_t*) "/",
			LEFT_MODE);

	/* Down buttons */
	z.y = DOWN_Y;
	z.x = COL1_X;
	DrawButton(&z, "-", UTIL_LCD_COLOR_DARKRED, UTIL_LCD_COLOR_WHITE);
	z.x = COL2_X;
	DrawButton(&z, "-", UTIL_LCD_COLOR_DARKRED, UTIL_LCD_COLOR_WHITE);
	z.x = COL3_X;
	DrawButton(&z, "-", UTIL_LCD_COLOR_DARKRED, UTIL_LCD_COLOR_WHITE);

	/* Action buttons */
	z = (TouchZone_t ) { OK_X, ACTION_Y, 100, 40 };
	DrawButton(&z, "Set", UTIL_LCD_COLOR_BLUE, UTIL_LCD_COLOR_WHITE);
	z = (TouchZone_t ) { CANCEL_X, ACTION_Y, 100, 40 };
	DrawButton(&z, "Back", UTIL_LCD_COLOR_DARKGRAY, UTIL_LCD_COLOR_WHITE);
}

/* Redraw only the value area (avoids full screen redraw on each tap) */
static void UpdateValueDisplay(uint16_t colX, uint8_t value, uint8_t show4digit) {
	char buf[6];
	/* Clear value area */
	UTIL_LCD_FillRect(colX, VAL_Y, BTN_W, 24, UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_CYAN);
	if (show4digit) {
		sprintf(buf, "20%02d", value);
		UTIL_LCD_DisplayStringAt(colX + 8, VAL_Y, (uint8_t*) buf, LEFT_MODE);
	} else {
		sprintf(buf, "%02d", value);
		UTIL_LCD_DisplayStringAt(colX + 20, VAL_Y, (uint8_t*) buf, LEFT_MODE);
	}
}

uint8_t Calculate_Weekday(uint8_t year, uint8_t month, uint8_t day) {
	uint8_t fraction = (uint8_t) year / 4;
	uint8_t L = 0;
	if (((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0))
			&& ((month == 1) || (month == 2))) {
		L = 1; //1 when leap year and the month is Jan/Feb
	} else {
		L = 0;
	}
	uint8_t month_code = 0;
	if ((month == 1) || (month == 10)) {
		month_code = 6;
	} else if ((month == 2) || (month == 3) || (month == 11)) {
		month_code = 2;
	} else if ((month == 4) || (month == 7)) {
		month_code = 5;
	} else if (month == 5) {
		month_code = 0;
	} else if (month == 6) {
		month_code = 3;
	} else if (month == 8) {
		month_code = 1;
	} else if ((month == 9) || (month == 12)) {
		month_code = 4;
	}
	uint8_t weekday = (year + fraction + day - L + month_code) % 7;
	if (weekday == 0) {
		weekday = 7;
	}
	return weekday;
}
uint8_t Set_DateTime_LCD(void) {
	if (TS_InitOnce() != BSP_ERROR_NONE)
		return 0;

	TS_State_t tsState;
	RTC_TimeTypeDef sTime;
	RTC_DateTypeDef sDate;

	/* Read current RTC values as starting point */
	HAL_RTC_GetTime(&hrtc, &sTime, RTC_FORMAT_BIN);
	HAL_RTC_GetDate(&hrtc, &sDate, RTC_FORMAT_BIN);

	uint8_t hours = sTime.Hours;
	uint8_t minutes = sTime.Minutes;
	uint8_t seconds = sTime.Seconds;
	uint8_t day = sDate.Date;
	uint8_t month = sDate.Month;
	uint8_t year = sDate.Year;

	/* Touch zones (same layout for both pages) */
	const TouchZone_t upBtn[3] = { { COL1_X, UP_Y, BTN_W, BTN_H }, { COL2_X,
	UP_Y, BTN_W, BTN_H }, { COL3_X, UP_Y, BTN_W, BTN_H } };
	const TouchZone_t downBtn[3] = { { COL1_X, DOWN_Y, BTN_W, BTN_H }, { COL2_X,
	DOWN_Y, BTN_W, BTN_H }, { COL3_X, DOWN_Y, BTN_W, BTN_H } };
	const TouchZone_t okBtn = { OK_X, ACTION_Y, 100, 40 };
	const TouchZone_t cancelBtn = { CANCEL_X, ACTION_Y, 100, 40 };

	/* ---- PAGE 1: SET TIME ---- */
	DrawSetTimeScreen(hours, minutes, seconds);

	uint8_t page = 0; /* 0 = time, 1 = date */

	while (1) {
		HAL_Delay(50);
		BSP_TS_GetState(0, &tsState);

		if (!tsState.TouchDetected)
			continue;

		uint32_t tx = tsState.TouchX;
		uint32_t ty = tsState.TouchY;

		if (page == 0) {
			/* --- Time page --- */
			/* Up buttons */
			if (IsTouchInZone(tx, ty, &upBtn[0])) {
				hours = (hours + 1) % 24;
				UpdateValueDisplay(COL1_X, hours, 0);
			} else if (IsTouchInZone(tx, ty, &upBtn[1])) {
				minutes = (minutes + 1) % 60;
				UpdateValueDisplay(COL2_X, minutes, 0);
			} else if (IsTouchInZone(tx, ty, &upBtn[2])) {
				seconds = (seconds + 1) % 60;
				UpdateValueDisplay(COL3_X, seconds, 0);
			}
			/* Down buttons */
			else if (IsTouchInZone(tx, ty, &downBtn[0])) {
				hours = (hours == 0) ? 23 : hours - 1;
				UpdateValueDisplay(COL1_X, hours, 0);
			} else if (IsTouchInZone(tx, ty, &downBtn[1])) {
				minutes = (minutes == 0) ? 59 : minutes - 1;
				UpdateValueDisplay(COL2_X, minutes, 0);
			} else if (IsTouchInZone(tx, ty, &downBtn[2])) {
				seconds = (seconds == 0) ? 59 : seconds - 1;
				UpdateValueDisplay(COL3_X, seconds, 0);
			}
			/* Next -> go to date page */
			else if (IsTouchInZone(tx, ty, &okBtn)) {
				WaitForTouchRelease();
				page = 1;
				DrawSetDateScreen(day, month, year);
				continue;
			}
			/* Cancel */
			else if (IsTouchInZone(tx, ty, &cancelBtn)) {
				WaitForTouchRelease();
				return 0;
			}
		} else {
			/* --- Date page --- */
			/* Up buttons */
			if (IsTouchInZone(tx, ty, &upBtn[0])) {
				day = (day >= 31) ? 1 : day + 1;
				UpdateValueDisplay(COL1_X, day, 0);
			} else if (IsTouchInZone(tx, ty, &upBtn[1])) {
				month = (month >= 12) ? 1 : month + 1;
				UpdateValueDisplay(COL2_X, month, 0);
			} else if (IsTouchInZone(tx, ty, &upBtn[2])) {
				year = (year + 1) % 100;
				UpdateValueDisplay(COL3_X, year, 1);
			}
			/* Down buttons */
			else if (IsTouchInZone(tx, ty, &downBtn[0])) {
				day = (day <= 1) ? 31 : day - 1;
				UpdateValueDisplay(COL1_X, day, 0);
			} else if (IsTouchInZone(tx, ty, &downBtn[1])) {
				month = (month <= 1) ? 12 : month - 1;
				UpdateValueDisplay(COL2_X, month, 0);
			} else if (IsTouchInZone(tx, ty, &downBtn[2])) {
				year = (year == 0) ? 99 : year - 1;
				UpdateValueDisplay(COL3_X, year, 1);
			}
			/* Set -> apply time & date to RTC */
			else if (IsTouchInZone(tx, ty, &okBtn)) {
				WaitForTouchRelease();

				/* Apply time */
				sTime.Hours = hours;
				sTime.Minutes = minutes;
				sTime.Seconds = seconds;
				sTime.DayLightSaving = RTC_DAYLIGHTSAVING_NONE;
				sTime.StoreOperation = RTC_STOREOPERATION_RESET;
				if (HAL_RTC_SetTime(&hrtc, &sTime, RTC_FORMAT_BIN) != HAL_OK)
					Error_Handler();

				/* Apply date */
				sDate.Date = day;
				sDate.Month = month;
				sDate.Year = year;
				sDate.WeekDay = Calculate_Weekday(year, month, day); /* auto-calc*/
				if (HAL_RTC_SetDate(&hrtc, &sDate, RTC_FORMAT_BIN) != HAL_OK)
					Error_Handler();

				/* Confirmation splash */
				UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
				UTIL_LCD_SetFont(&Font24);
				UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
				UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
				UTIL_LCD_DisplayStringAt(0, 120, (uint8_t*) "Date & Time Set",
						CENTER_MODE);
				HAL_Delay(1500);
				return 1;
			}
			/* Back -> return to time page */
			else if (IsTouchInZone(tx, ty, &cancelBtn)) {
				WaitForTouchRelease();
				page = 0;
				DrawSetTimeScreen(hours, minutes, seconds);
				continue;
			}
		}

		/* Debounce: wait for finger lift before next input */
		WaitForTouchRelease();
	}
}

void Print_DateTime_LCD(void) {
	RTC_TimeTypeDef sTime;
	RTC_DateTypeDef sDate;
	char buffer_date[50] = { 0 };
	char buffer_time[28] = { 0 };

	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_DisplayStringAt(0, 80, (uint8_t*) "Audio Acquisition System",
			CENTER_MODE);
	UTIL_LCD_SetFont(&Font16);
	UTIL_LCD_DisplayStringAt(0, 120, (uint8_t*) "Date & Time", CENTER_MODE);

	HAL_RTC_GetDate(&hrtc, &sDate, RTC_FORMAT_BIN);
	sprintf(buffer_date, "%02d-%02d-20%02d, Weekday:%02d (1=Mon, 7=Sun)",
			sDate.Date, sDate.Month, sDate.Year, sDate.WeekDay);
	UTIL_LCD_DisplayStringAt(0, 140, (uint8_t*) buffer_date, CENTER_MODE);

	HAL_RTC_GetTime(&hrtc, &sTime, RTC_FORMAT_BIN);
	sprintf(buffer_time, "Current Time: %02d:%02d:%02d", sTime.Hours,
			sTime.Minutes, sTime.Seconds);
	UTIL_LCD_DisplayStringAt(0, 160, (uint8_t*) buffer_time, CENTER_MODE);
}

uint8_t Set_Mode_LCD(void) {
	TS_InitOnce();  // make sure touch is ready

	// Define touch zones
	//{left edge,top edge, width,height}
	TouchZone_t btnStandalone = { 50, 100, 380, 50 };   // left button
	TouchZone_t btnRF = { 50, 160, 380, 50 };   // right button

	// 2. DRAW the screen
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	UTIL_LCD_DisplayStringAt(0, 30, (uint8_t*) "Select Mode", CENTER_MODE);
	DrawButton(&btnStandalone, "Standalone", UTIL_LCD_COLOR_DARKBLUE,
			UTIL_LCD_COLOR_WHITE);
	DrawButton(&btnRF, "Distributed node", UTIL_LCD_COLOR_DARKBLUE,
			UTIL_LCD_COLOR_WHITE);

	// 3. EVENT LOOP
	TS_State_t ts;
	while (1) {
		HAL_Delay(50);
		BSP_TS_GetState(0, &ts);
		if (!ts.TouchDetected)
			continue;

		if (IsTouchInZone(ts.TouchX, ts.TouchY, &btnStandalone)) {
			g_Mode = MODE_FULL_DUPLEX;
			system_mode = 0;
			WaitForTouchRelease();
			return system_mode;
		}
		if (IsTouchInZone(ts.TouchX, ts.TouchY, &btnRF)) {
			system_mode = 1;
			WaitForTouchRelease();
			return system_mode;
		}
	}
}

static void DrawAlarmButtonScreen(void) {
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	UTIL_LCD_DisplayStringAt(0, 30, (uint8_t*) "Standalone Mode", CENTER_MODE);
	TouchZone_t z = { 50, 100, 380, 50 };
	//TouchZone_t s  = { 50, 170, 380, 50 };
	DrawButton(&z, "Set alarm", UTIL_LCD_COLOR_DARKBLUE,
			UTIL_LCD_COLOR_WHITE);
	//DrawButton(&s, "Skip",      UTIL_LCD_COLOR_DARKBLUE, UTIL_LCD_COLOR_WHITE);
}

void Set_Alarm_button_LCD(void) {
	TS_InitOnce();

	TouchZone_t btnAlarm = { 50, 100, 380, 50 };
	DrawAlarmButtonScreen();

	TS_State_t ts;
	while (1) {
		if (g_AlarmFlag) return; /* let system task handle it */
		HAL_Delay(50);
		BSP_TS_GetState(0, &ts);
		if (!ts.TouchDetected)
			continue;
        if (IsTouchInZone(ts.TouchX, ts.TouchY, &btnAlarm)) {
            WaitForTouchRelease();
            if (Alarm_Workflow_LCD() == 1) return;
            DrawAlarmButtonScreen();
        }
	}
}

/* ===========================================================================
 * Multi-page Alarm Workflow
 *   Page 1: Pick_Time_LCD     (HH / MM / SS)
 *   Page 2: Pick_Weekdays_LCD (toggle days + Everyday)
 *   Page 3: Pick_Repeat_LCD   (xtimes / intervalH / intervalM)
 *
 * Each picker returns 1 if user pressed Next/Set, 0 if Back/Cancel.
 * Values are passed in/out via pointers so the workflow controller can keep
 * the user's selections when navigating back & forth between pages.
 * ===========================================================================
 */

/* ---- Page 1: Pick time only (no RTC commit) ---- */
uint8_t Pick_Time_LCD(uint8_t *hours, uint8_t *minutes, uint8_t *seconds) {
	if (TS_InitOnce() != BSP_ERROR_NONE)
		return 0;

	TS_State_t tsState;
	uint8_t h = *hours, m = *minutes, s = *seconds;

	const TouchZone_t upBtn[3] = { { COL1_X, UP_Y, BTN_W, BTN_H },
		{ COL2_X, UP_Y, BTN_W, BTN_H }, { COL3_X, UP_Y, BTN_W, BTN_H } };
	const TouchZone_t downBtn[3] = { { COL1_X, DOWN_Y, BTN_W, BTN_H },
		{ COL2_X, DOWN_Y, BTN_W, BTN_H }, { COL3_X, DOWN_Y, BTN_W, BTN_H } };
	const TouchZone_t okBtn = { OK_X, ACTION_Y, 100, 40 };
	const TouchZone_t cancelBtn = { CANCEL_X, ACTION_Y, 100, 40 };

	DrawSetTimeScreen(h, m, s);

	while (1) {
		HAL_Delay(50);
		BSP_TS_GetState(0, &tsState);
		if (!tsState.TouchDetected)
			continue;

		uint32_t tx = tsState.TouchX;
		uint32_t ty = tsState.TouchY;

		if (IsTouchInZone(tx, ty, &upBtn[0])) {
			h = (h + 1) % 24;
			UpdateValueDisplay(COL1_X, h, 0);
		} else if (IsTouchInZone(tx, ty, &upBtn[1])) {
			m = (m + 1) % 60;
			UpdateValueDisplay(COL2_X, m, 0);
		} else if (IsTouchInZone(tx, ty, &upBtn[2])) {
			s = (s + 1) % 60;
			UpdateValueDisplay(COL3_X, s, 0);
		} else if (IsTouchInZone(tx, ty, &downBtn[0])) {
			h = (h == 0) ? 23 : h - 1;
			UpdateValueDisplay(COL1_X, h, 0);
		} else if (IsTouchInZone(tx, ty, &downBtn[1])) {
			m = (m == 0) ? 59 : m - 1;
			UpdateValueDisplay(COL2_X, m, 0);
		} else if (IsTouchInZone(tx, ty, &downBtn[2])) {
			s = (s == 0) ? 59 : s - 1;
			UpdateValueDisplay(COL3_X, s, 0);
		} else if (IsTouchInZone(tx, ty, &okBtn)) {
			WaitForTouchRelease();
			*hours = h;
			*minutes = m;
			*seconds = s;
			return 1;
		} else if (IsTouchInZone(tx, ty, &cancelBtn)) {
			WaitForTouchRelease();
			return 0;
		}
		WaitForTouchRelease();
	}
}

/* ---- Page 2: Pick weekdays ----
 * 7 toggle buttons (Mo Tu We Th Fr Sa Su) + "Everyday" + Next / Back.
 * mask: bit0=Mon .. bit6=Sun.   0x7F means every day.
 */
#define WD_BTN_W   58
#define WD_BTN_H   50
#define WD_GAP      4
#define WD_X0      25
#define WD_Y       55
#define WD_EVERY_X 140
#define WD_EVERY_Y 125

static const char *kDayLabels[7] = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" };

static void DrawDayButton(uint8_t i, uint8_t selected) {
	TouchZone_t z = { (uint16_t)(WD_X0 + i * (WD_BTN_W + WD_GAP)), WD_Y,
			WD_BTN_W, WD_BTN_H };
	uint32_t bg = selected ? UTIL_LCD_COLOR_DARKGREEN : UTIL_LCD_COLOR_DARKBLUE;
	DrawButton(&z, kDayLabels[i], bg, UTIL_LCD_COLOR_WHITE);
}

static void DrawWeekdayScreen(uint8_t mask) {
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	UTIL_LCD_DisplayStringAt(0, 10, (uint8_t*) "Select Days", CENTER_MODE);

	for (uint8_t i = 0; i < 7; i++) {
		DrawDayButton(i, (mask >> i) & 0x01);
	}

	TouchZone_t every = { WD_EVERY_X, WD_EVERY_Y, 200, 40 };
	uint32_t bg = (mask == 0x7F) ? UTIL_LCD_COLOR_DARKGREEN
	                             : UTIL_LCD_COLOR_DARKGRAY;
	DrawButton(&every, "Everyday", bg, UTIL_LCD_COLOR_WHITE);

	TouchZone_t z = { OK_X, ACTION_Y, 100, 40 };
	DrawButton(&z, "Next", UTIL_LCD_COLOR_BLUE, UTIL_LCD_COLOR_WHITE);
	z = (TouchZone_t ) { CANCEL_X, ACTION_Y, 100, 40 };
	DrawButton(&z, "Back", UTIL_LCD_COLOR_DARKGRAY, UTIL_LCD_COLOR_WHITE);
}

uint8_t Pick_Weekdays_LCD(uint8_t *mask) {
	if (TS_InitOnce() != BSP_ERROR_NONE)
		return 0;

	TS_State_t tsState;
	uint8_t m = (*mask) & 0x7F;
	if (m == 0)
		m = 0x7F;

	TouchZone_t dayBtn[7];
	for (uint8_t i = 0; i < 7; i++) {
		dayBtn[i] = (TouchZone_t ) { (uint16_t) (WD_X0 + i * (WD_BTN_W + WD_GAP)),
				WD_Y, WD_BTN_W, WD_BTN_H };
	}
	const TouchZone_t everyBtn = { WD_EVERY_X, WD_EVERY_Y, 200, 40 };
	const TouchZone_t okBtn = { OK_X, ACTION_Y, 100, 40 };
	const TouchZone_t cancelBtn = { CANCEL_X, ACTION_Y, 100, 40 };

	DrawWeekdayScreen(m);

	while (1) {
		HAL_Delay(50);
		BSP_TS_GetState(0, &tsState);
		if (!tsState.TouchDetected)
			continue;

		uint32_t tx = tsState.TouchX;
		uint32_t ty = tsState.TouchY;
		uint8_t handled = 0;

		for (uint8_t i = 0; i < 7; i++) {
			if (IsTouchInZone(tx, ty, &dayBtn[i])) {
				m ^= (uint8_t)(1U << i);
				DrawDayButton(i, (m >> i) & 0x01);
				TouchZone_t every = everyBtn;
				uint32_t bg = (m == 0x7F) ? UTIL_LCD_COLOR_DARKGREEN
				                          : UTIL_LCD_COLOR_DARKGRAY;
				DrawButton(&every, "Everyday", bg, UTIL_LCD_COLOR_WHITE);
				handled = 1;
				break;
			}
		}
		if (!handled) {
			if (IsTouchInZone(tx, ty, &everyBtn)) {
				m = 0x7F;
				DrawWeekdayScreen(m);
			} else if (IsTouchInZone(tx, ty, &okBtn)) {
				WaitForTouchRelease();
				if (m == 0)
					m = 0x7F;
				*mask = m;
				return 1;
			} else if (IsTouchInZone(tx, ty, &cancelBtn)) {
				WaitForTouchRelease();
				return 0;
			}
		}
		WaitForTouchRelease();
	}
}

/* ---- Page 3: Pick repetition (xtimes / interval H / interval M) ---- */
static void DrawRepeatScreen(uint8_t times, uint8_t iH, uint8_t iM) {
	char buf[6];

	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);

	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_DisplayStringAt(0, 10, (uint8_t*) "Repetition", CENTER_MODE);

	UTIL_LCD_SetFont(&Font16);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_LIGHTGRAY);
	UTIL_LCD_DisplayStringAt(COL1_X + 12, 48, (uint8_t*) "Times", LEFT_MODE);
	UTIL_LCD_DisplayStringAt(COL2_X + 8,  48, (uint8_t*) "Hours", LEFT_MODE);
	UTIL_LCD_DisplayStringAt(COL3_X + 16, 48, (uint8_t*) "Min",   LEFT_MODE);

	TouchZone_t z = { COL1_X, UP_Y, BTN_W, BTN_H };
	DrawButton(&z, "+", UTIL_LCD_COLOR_DARKGREEN, UTIL_LCD_COLOR_WHITE);
	z.x = COL2_X;
	DrawButton(&z, "+", UTIL_LCD_COLOR_DARKGREEN, UTIL_LCD_COLOR_WHITE);
	z.x = COL3_X;
	DrawButton(&z, "+", UTIL_LCD_COLOR_DARKGREEN, UTIL_LCD_COLOR_WHITE);

	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_CYAN);
	sprintf(buf, "%02d", times);
	UTIL_LCD_DisplayStringAt(COL1_X + 20, VAL_Y, (uint8_t*) buf, LEFT_MODE);
	sprintf(buf, "%02d", iH);
	UTIL_LCD_DisplayStringAt(COL2_X + 20, VAL_Y, (uint8_t*) buf, LEFT_MODE);
	sprintf(buf, "%02d", iM);
	UTIL_LCD_DisplayStringAt(COL3_X + 20, VAL_Y, (uint8_t*) buf, LEFT_MODE);

	z.y = DOWN_Y;
	z.x = COL1_X;
	DrawButton(&z, "-", UTIL_LCD_COLOR_DARKRED, UTIL_LCD_COLOR_WHITE);
	z.x = COL2_X;
	DrawButton(&z, "-", UTIL_LCD_COLOR_DARKRED, UTIL_LCD_COLOR_WHITE);
	z.x = COL3_X;
	DrawButton(&z, "-", UTIL_LCD_COLOR_DARKRED, UTIL_LCD_COLOR_WHITE);

	z = (TouchZone_t ) { OK_X, ACTION_Y, 100, 40 };
	DrawButton(&z, "Set", UTIL_LCD_COLOR_BLUE, UTIL_LCD_COLOR_WHITE);
	z = (TouchZone_t ) { CANCEL_X, ACTION_Y, 100, 40 };
	DrawButton(&z, "Back", UTIL_LCD_COLOR_DARKGRAY, UTIL_LCD_COLOR_WHITE);
}

uint8_t Pick_Repeat_LCD(uint8_t *times, uint8_t *iHours, uint8_t *iMinutes) {
	if (TS_InitOnce() != BSP_ERROR_NONE)
		return 0;

	TS_State_t tsState;
	uint8_t t = *times, h = *iHours, m = *iMinutes;
	if (t == 0) t = 1;

	const TouchZone_t upBtn[3] = { { COL1_X, UP_Y, BTN_W, BTN_H },
		{ COL2_X, UP_Y, BTN_W, BTN_H }, { COL3_X, UP_Y, BTN_W, BTN_H } };
	const TouchZone_t downBtn[3] = { { COL1_X, DOWN_Y, BTN_W, BTN_H },
		{ COL2_X, DOWN_Y, BTN_W, BTN_H }, { COL3_X, DOWN_Y, BTN_W, BTN_H } };
	const TouchZone_t okBtn = { OK_X, ACTION_Y, 100, 40 };
	const TouchZone_t cancelBtn = { CANCEL_X, ACTION_Y, 100, 40 };

	DrawRepeatScreen(t, h, m);

	while (1) {
		HAL_Delay(50);
		BSP_TS_GetState(0, &tsState);
		if (!tsState.TouchDetected)
			continue;

		uint32_t tx = tsState.TouchX;
		uint32_t ty = tsState.TouchY;

		if (IsTouchInZone(tx, ty, &upBtn[0])) {
			t = (t >= 99) ? 1 : t + 1;
			UpdateValueDisplay(COL1_X, t, 0);
		} else if (IsTouchInZone(tx, ty, &upBtn[1])) {
			h = (h + 1) % 24;
			UpdateValueDisplay(COL2_X, h, 0);
		} else if (IsTouchInZone(tx, ty, &upBtn[2])) {
			m = (m + 1) % 60;
			UpdateValueDisplay(COL3_X, m, 0);
		} else if (IsTouchInZone(tx, ty, &downBtn[0])) {
			t = (t <= 1) ? 99 : t - 1;
			UpdateValueDisplay(COL1_X, t, 0);
		} else if (IsTouchInZone(tx, ty, &downBtn[1])) {
			h = (h == 0) ? 23 : h - 1;
			UpdateValueDisplay(COL2_X, h, 0);
		} else if (IsTouchInZone(tx, ty, &downBtn[2])) {
			m = (m == 0) ? 59 : m - 1;
			UpdateValueDisplay(COL3_X, m, 0);
		} else if (IsTouchInZone(tx, ty, &okBtn)) {
			WaitForTouchRelease();
			*times = t;
			*iHours = h;
			*iMinutes = m;
			return 1;
		} else if (IsTouchInZone(tx, ty, &cancelBtn)) {
			WaitForTouchRelease();
			return 0;
		}
		WaitForTouchRelease();
	}
}

/* ---- Workflow controller ----
 * Time → Weekdays → Repetition.  Each page's Back returns to the previous
 * one; Cancel on the first page aborts the workflow.  On Set (page 3) the
 * RTC alarm is configured (time-only daily fire) and the weekday/repeat
 * choices are stored in g_AlarmWeekdayMask / g_AlarmXTimes /
 * g_AlarmIntervalHours / g_AlarmIntervalMinutes for the System_Controller_Task
 * to consume.
 */
uint8_t Alarm_Workflow_LCD(void) {
	if (TS_InitOnce() != BSP_ERROR_NONE)
		return 0;

	/* Seed time from current RTC */
	RTC_TimeTypeDef sTime;
	RTC_DateTypeDef sDate;
	HAL_RTC_GetTime(&hrtc, &sTime, RTC_FORMAT_BIN);
	HAL_RTC_GetDate(&hrtc, &sDate, RTC_FORMAT_BIN); /* unlock shadow */

	uint8_t hours   = sTime.Hours;
	uint8_t minutes = sTime.Minutes;
	uint8_t seconds = sTime.Seconds;
	uint8_t mask    = g_AlarmWeekdayMask;
	uint8_t xtimes  = g_AlarmXTimes;
	uint8_t iH      = g_AlarmIntervalHours;
	uint8_t iM      = g_AlarmIntervalMinutes;

	uint8_t page = 0;
	while (1) {
		if (page == 0) {
			if (Pick_Time_LCD(&hours, &minutes, &seconds) == 0)
				return 0; /* cancelled the whole workflow */
			page = 1;
		} else if (page == 1) {
			if (Pick_Weekdays_LCD(&mask) == 0) {
				page = 0; /* Back -> time page */
				continue;
			}
			page = 2;
		} else { /* page == 2 */
			if (Pick_Repeat_LCD(&xtimes, &iH, &iM) == 0) {
				page = 1; /* Back -> weekday page */
				continue;
			}
			break; /* Set -> commit below */
		}
	}

	/* Persist user choices */
	g_AlarmWeekdayMask     = mask;
	g_AlarmXTimes          = xtimes;
	g_AlarmIntervalHours   = iH;
	g_AlarmIntervalMinutes = iM;

	/* Program RTC Alarm A: time-only daily fire.
	 * The System_Controller_Task is responsible for filtering by
	 * g_AlarmWeekdayMask and re-arming for the requested repetitions. */
	RTC_AlarmTypeDef sAlarm = { 0 };
	sAlarm.AlarmTime.Hours          = hours;
	sAlarm.AlarmTime.Minutes        = minutes;
	sAlarm.AlarmTime.Seconds        = seconds;
	sAlarm.AlarmTime.SubSeconds     = 0;
	sAlarm.AlarmTime.DayLightSaving = RTC_DAYLIGHTSAVING_NONE;
	sAlarm.AlarmTime.StoreOperation = RTC_STOREOPERATION_RESET;
	sAlarm.AlarmSubSecondMask       = RTC_ALARMSUBSECONDMASK_ALL;
	sAlarm.AlarmMask                = RTC_ALARMMASK_DATEWEEKDAY;
	sAlarm.Alarm                    = RTC_ALARM_A;
	if (HAL_RTC_SetAlarm_IT(&hrtc, &sAlarm, RTC_FORMAT_BIN) != HAL_OK) {
		Error_Handler();
	}

	/* Confirmation splash */
	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	char msg[40];
	sprintf(msg, "Alarm: %02d:%02d:%02d", hours, minutes, seconds);
	UTIL_LCD_DisplayStringAt(0, 90,  (uint8_t*) msg, CENTER_MODE);
	sprintf(msg, "Mask 0x%02X  x%d", mask, xtimes);
	UTIL_LCD_DisplayStringAt(0, 120, (uint8_t*) msg, CENTER_MODE);
	sprintf(msg, "Every %02dh %02dm", iH, iM);
	UTIL_LCD_DisplayStringAt(0, 150, (uint8_t*) msg, CENTER_MODE);
	HAL_Delay(300);

	UTIL_LCD_Clear(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetFont(&Font24);
	UTIL_LCD_SetBackColor(UTIL_LCD_COLOR_BLACK);
	UTIL_LCD_SetTextColor(UTIL_LCD_COLOR_WHITE);
	sprintf(msg, "Saving alarms...");
	UTIL_LCD_DisplayStringAt(0, 90,  (uint8_t*) msg, CENTER_MODE);
	/*Save in SD the alarm specifications*/
	FS_WriteAlarm(g_AlarmXTimes, g_AlarmIntervalMinutes, g_AlarmIntervalHours);
	FS_ReadAlarmList();//Check for the list of alarms to set next one
	return 1;
}

