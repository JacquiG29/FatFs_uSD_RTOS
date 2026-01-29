################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2/cmsis_os2.c 

OBJS += \
./Middlewares/FreeRTOS/CMSIS_RTOS/cmsis_os2.o 

C_DEPS += \
./Middlewares/FreeRTOS/CMSIS_RTOS/cmsis_os2.d 


# Each subdirectory must supply rules for building sources it contributes
Middlewares/FreeRTOS/CMSIS_RTOS/cmsis_os2.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2/cmsis_os2.c Middlewares/FreeRTOS/CMSIS_RTOS/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Middlewares-2f-FreeRTOS-2f-CMSIS_RTOS

clean-Middlewares-2f-FreeRTOS-2f-CMSIS_RTOS:
	-$(RM) ./Middlewares/FreeRTOS/CMSIS_RTOS/cmsis_os2.cyclo ./Middlewares/FreeRTOS/CMSIS_RTOS/cmsis_os2.d ./Middlewares/FreeRTOS/CMSIS_RTOS/cmsis_os2.o ./Middlewares/FreeRTOS/CMSIS_RTOS/cmsis_os2.su

.PHONY: clean-Middlewares-2f-FreeRTOS-2f-CMSIS_RTOS

