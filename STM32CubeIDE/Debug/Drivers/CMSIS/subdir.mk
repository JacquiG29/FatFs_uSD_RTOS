################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Projects/STM32H735G-DK/Applications/FatFs/FatFs_uSD_RTOS/Core/Src/system_stm32h7xx.c 

OBJS += \
./Drivers/CMSIS/system_stm32h7xx.o 

C_DEPS += \
./Drivers/CMSIS/system_stm32h7xx.d 


# Each subdirectory must supply rules for building sources it contributes
Drivers/CMSIS/system_stm32h7xx.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Projects/STM32H735G-DK/Applications/FatFs/FatFs_uSD_RTOS/Core/Src/system_stm32h7xx.c Drivers/CMSIS/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Drivers-2f-CMSIS

clean-Drivers-2f-CMSIS:
	-$(RM) ./Drivers/CMSIS/system_stm32h7xx.cyclo ./Drivers/CMSIS/system_stm32h7xx.d ./Drivers/CMSIS/system_stm32h7xx.o ./Drivers/CMSIS/system_stm32h7xx.su

.PHONY: clean-Drivers-2f-CMSIS

