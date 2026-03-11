################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (14.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Projects/STM32H735G-DK/Applications/FatFs/FatFs_uSD_RTOS/FatFs/Target/sd_diskio.c 

OBJS += \
./Application/User/FatFs/Target/sd_diskio.o 

C_DEPS += \
./Application/User/FatFs/Target/sd_diskio.d 


# Each subdirectory must supply rules for building sources it contributes
Application/User/FatFs/Target/sd_diskio.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Projects/STM32H735G-DK/Applications/FatFs/FatFs_uSD_RTOS/FatFs/Target/sd_diskio.c Application/User/FatFs/Target/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Utilities/lcd -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Application-2f-User-2f-FatFs-2f-Target

clean-Application-2f-User-2f-FatFs-2f-Target:
	-$(RM) ./Application/User/FatFs/Target/sd_diskio.cyclo ./Application/User/FatFs/Target/sd_diskio.d ./Application/User/FatFs/Target/sd_diskio.o ./Application/User/FatFs/Target/sd_diskio.su

.PHONY: clean-Application-2f-User-2f-FatFs-2f-Target

