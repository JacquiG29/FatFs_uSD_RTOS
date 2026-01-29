################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/Components/mfxstm32l152/mfxstm32l152.c \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/Components/mfxstm32l152/mfxstm32l152_reg.c \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/Components/wm8994/wm8994.c \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/Components/wm8994/wm8994_reg.c 

OBJS += \
./Drivers/BSP/Components/mfxstm32l152.o \
./Drivers/BSP/Components/mfxstm32l152_reg.o \
./Drivers/BSP/Components/wm8994.o \
./Drivers/BSP/Components/wm8994_reg.o 

C_DEPS += \
./Drivers/BSP/Components/mfxstm32l152.d \
./Drivers/BSP/Components/mfxstm32l152_reg.d \
./Drivers/BSP/Components/wm8994.d \
./Drivers/BSP/Components/wm8994_reg.d 


# Each subdirectory must supply rules for building sources it contributes
Drivers/BSP/Components/mfxstm32l152.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/Components/mfxstm32l152/mfxstm32l152.c Drivers/BSP/Components/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"
Drivers/BSP/Components/mfxstm32l152_reg.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/Components/mfxstm32l152/mfxstm32l152_reg.c Drivers/BSP/Components/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"
Drivers/BSP/Components/wm8994.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/Components/wm8994/wm8994.c Drivers/BSP/Components/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"
Drivers/BSP/Components/wm8994_reg.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/Components/wm8994/wm8994_reg.c Drivers/BSP/Components/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Drivers-2f-BSP-2f-Components

clean-Drivers-2f-BSP-2f-Components:
	-$(RM) ./Drivers/BSP/Components/mfxstm32l152.cyclo ./Drivers/BSP/Components/mfxstm32l152.d ./Drivers/BSP/Components/mfxstm32l152.o ./Drivers/BSP/Components/mfxstm32l152.su ./Drivers/BSP/Components/mfxstm32l152_reg.cyclo ./Drivers/BSP/Components/mfxstm32l152_reg.d ./Drivers/BSP/Components/mfxstm32l152_reg.o ./Drivers/BSP/Components/mfxstm32l152_reg.su ./Drivers/BSP/Components/wm8994.cyclo ./Drivers/BSP/Components/wm8994.d ./Drivers/BSP/Components/wm8994.o ./Drivers/BSP/Components/wm8994.su ./Drivers/BSP/Components/wm8994_reg.cyclo ./Drivers/BSP/Components/wm8994_reg.d ./Drivers/BSP/Components/wm8994_reg.o ./Drivers/BSP/Components/wm8994_reg.su

.PHONY: clean-Drivers-2f-BSP-2f-Components

