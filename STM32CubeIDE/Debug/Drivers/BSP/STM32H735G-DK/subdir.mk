################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/STM32H735G-DK/stm32h735g_discovery.c \
../Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_audio.c \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_bus.c \
D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_sd.c 

OBJS += \
./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery.o \
./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_audio.o \
./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_bus.o \
./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_sd.o 

C_DEPS += \
./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery.d \
./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_audio.d \
./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_bus.d \
./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_sd.d 


# Each subdirectory must supply rules for building sources it contributes
Drivers/BSP/STM32H735G-DK/stm32h735g_discovery.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/STM32H735G-DK/stm32h735g_discovery.c Drivers/BSP/STM32H735G-DK/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"
Drivers/BSP/STM32H735G-DK/%.o Drivers/BSP/STM32H735G-DK/%.su Drivers/BSP/STM32H735G-DK/%.cyclo: ../Drivers/BSP/STM32H735G-DK/%.c Drivers/BSP/STM32H735G-DK/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"
Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_bus.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_bus.c Drivers/BSP/STM32H735G-DK/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"
Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_sd.o: D:/EMECS/stm32cubeh7-v1-12-0/STM32Cube_FW_H7_V1.12.0/Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_sd.c Drivers/BSP/STM32H735G-DK/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m7 -std=gnu11 -g3 -DUSE_HAL_DRIVER -DARM_MATH_CM7 -DUSE_PWR_DIRECT_SMPS_SUPPLY -DDEBUG -DSTM32H735xx -c -I../../Core/Inc -I../../../../../../../Drivers/CMSIS/DSP/Include -I../../../../../../../Middlewares/ST/STM32_Audio/Addons/PDM/Inc -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../../../../../../../Drivers/CMSIS/Device/ST/STM32H7xx/Include -I../../../../../../../Middlewares/Third_Party/FatFs/src -I../../../../../../../Utilities/Fonts -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/include -I../../../../../../../Middlewares/Third_Party/FatFs/src/drivers -I../../../../../../../Utilities/CPU -I../../../../../../../Drivers/BSP/STM32H735G-DK -I../../FatFs/App -I../../Core/Src -I../../FatFs/Target -I../../../../../../../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -I../../../../../../../Drivers/STM32H7xx_HAL_Driver/Inc -I../../../../../../../Drivers/BSP/Components/Common -I../../../../../../../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Drivers-2f-BSP-2f-STM32H735G-2d-DK

clean-Drivers-2f-BSP-2f-STM32H735G-2d-DK:
	-$(RM) ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery.cyclo ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery.d ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery.o ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery.su ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_audio.cyclo ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_audio.d ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_audio.o ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_audio.su ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_bus.cyclo ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_bus.d ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_bus.o ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_bus.su ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_sd.cyclo ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_sd.d ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_sd.o ./Drivers/BSP/STM32H735G-DK/stm32h735g_discovery_sd.su

.PHONY: clean-Drivers-2f-BSP-2f-STM32H735G-2d-DK

