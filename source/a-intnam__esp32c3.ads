
--  This is the ESP-IDF/ESP32C3 version of this file.

package Ada.Interrupts.Names is

   --  All identifiers in this unit are implementation defined

   pragma Implementation_Defined;

   WIFI_MAC_Interrupt              : constant := 0;
   WIFI_MAC_NMI_Interrupt          : constant := 1;
   WIFI_PWR_Interrupt              : constant := 2;
   WIFI_BB_Interrupt               : constant := 3;
   BT_MAC_Interrupt                : constant := 4;
   BT_BB_Interrupt                 : constant := 5;
   BT_BB_NMI_Interrupt             : constant := 6;
   RWBT_Interrupt                  : constant := 7;
   RWBLE_Interrupt                 : constant := 8;
   RWBT_NMI_Interrupt              : constant := 9;
   RWBLE_NMI_Interrupt             : constant := 10;
   I2C_MASTER_Interrupt            : constant := 11;
   SLC0_Interrupt                  : constant := 12;
   SLC1_Interrupt                  : constant := 13;
   APB_CTRL_Interrupt              : constant := 14;
   UHCI0_Interrupt                 : constant := 15;
   GPIO_Interrupt                  : constant := 16;
   GPIO_NMI_Interrupt              : constant := 17;
   SPI1_Interrupt                  : constant := 18;
   SPI2_Interrupt                  : constant := 19;
   I2S0_Interrupt                  : constant := 20;
   UART0_Interrupt                 : constant := 21;
   UART1_Interrupt                 : constant := 22;
   LEDC_Interrupt                  : constant := 23;
   EFUSE_Interrupt                 : constant := 24;
   TWAI0_Interrupt                 : constant := 25;
   USB_DEVICE_Interrupt            : constant := 26;
   RTC_CORE_Interrupt              : constant := 27;
   RMT_Interrupt                   : constant := 28;
   I2C_EXT0_Interrupt              : constant := 29;
   TIMER1_Interrupt                : constant := 30;
   TIMER2_Interrupt                : constant := 31;
   TG0_T0_LEVEL_Interrupt          : constant := 32;
   TG0_WDT_LEVEL_Interrupt         : constant := 33;
   TG1_T0_LEVEL_Interrupt          : constant := 34;
   TG1_WDT_LEVEL_Interrupt         : constant := 35;
   CACHE_IA_Interrupt              : constant := 36;
   SYSTIMER_TARGET0_Interrupt      : constant := 37;
   SYSTIMER_TARGET1_Interrupt      : constant := 38;
   SYSTIMER_TARGET2_Interrupt      : constant := 39;
   SPI_MEM_REJECT_CACHE_Interrupt  : constant := 40;
   ICACHE_PRELOAD0_Interrupt       : constant := 41;
   ICACHE_SYNC0_Interrupt          : constant := 42;
   APB_ADC_Interrupt               : constant := 43;
   DMA_CH0_Interrupt               : constant := 44;
   DMA_CH1_Interrupt               : constant := 45;
   DMA_CH2_Interrupt               : constant := 46;
   RSA_Interrupt                   : constant := 47;
   AES_Interrupt                   : constant := 48;
   SHA_Interrupt                   : constant := 49;
   FROM_CPU_INTR0_Interrupt        : constant := 50;
   FROM_CPU_INTR1_Interrupt        : constant := 51;
   FROM_CPU_INTR2_Interrupt        : constant := 52;
   FROM_CPU_INTR3_Interrupt        : constant := 53;
   ASSIST_DEBUG_Interrupt          : constant := 54;
   DMA_APBPERI_PMS_Interrupt       : constant := 55;
   CORE0_IRAM0_PMS_Interrupt       : constant := 56;
   CORE0_DRAM0_PMS_Interrupt       : constant := 57;
   CORE0_PIF_PMS_Interrupt         : constant := 58;
   CORE0_PIF_PMS_SIZE_Interrupt    : constant := 59;
   BAK_PMS_VIOLATE_Interrupt       : constant := 60;
   CACHE_CORE0_ACS_Interrupt       : constant := 61;

end Ada.Interrupts.Names;
