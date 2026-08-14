
--  This is the ESP-IDF/ESP32 version of this file.

package Ada.Interrupts.Names is

   --  All identifiers in this unit are implementation defined

   pragma Implementation_Defined;

   WIFI_MAC_Interrupt       : constant Interrupt_ID := 0;
   WIFI_NMI_Interrupt       : constant Interrupt_ID := 1;
   WIFI_BB_Interrupt        : constant Interrupt_ID := 2;
   BT_MAC_Interrupt         : constant Interrupt_ID := 3;
   BT_BB_Interrupt          : constant Interrupt_ID := 4;
   BT_BB_NMI_Interrupt      : constant Interrupt_ID := 5;
   RWBT_Interrupt           : constant Interrupt_ID := 6;
   RWBLE_Interrupt          : constant Interrupt_ID := 7;
   RWBT_NMI_Interrupt       : constant Interrupt_ID := 8;
   RWBLE_NMI_Interrupt      : constant Interrupt_ID := 9;
   UHCI0_Interrupt          : constant Interrupt_ID := 12;
   UHCI1_Interrupt          : constant Interrupt_ID := 13;
   TG0_T0_LEVEL_Interrupt   : constant Interrupt_ID := 14;
   TG0_T1_LEVEL_Interrupt   : constant Interrupt_ID := 15;
   TG0_WDT_LEVEL_Interrupt  : constant Interrupt_ID := 16;
   TG0_LACT_LEVEL_Interrupt : constant Interrupt_ID := 17;
   TG1_T0_LEVEL_Interrupt   : constant Interrupt_ID := 18;
   TG1_T1_LEVEL_Interrupt   : constant Interrupt_ID := 19;
   TG1_WDT_LEVEL_Interrupt  : constant Interrupt_ID := 20;
   TG1_LACT_LEVEL_Interrupt : constant Interrupt_ID := 21;
   GPIO_Interrupt           : constant Interrupt_ID := 22;
   GPIO_NMI_Interrupt       : constant Interrupt_ID := 23;
   FROM_CPU_INTR0_Interrupt : constant Interrupt_ID := 24;
   FROM_CPU_INTR1_Interrupt : constant Interrupt_ID := 25;
   FROM_CPU_INTR2_Interrupt : constant Interrupt_ID := 26;
   FROM_CPU_INTR3_Interrupt : constant Interrupt_ID := 27;
   SPI0_Interrupt           : constant Interrupt_ID := 28;
   SPI1_Interrupt           : constant Interrupt_ID := 29;
   SPI2_Interrupt           : constant Interrupt_ID := 30;
   SPI3_Interrupt           : constant Interrupt_ID := 31;
   I2S0_Interrupt           : constant Interrupt_ID := 32;
   I2S1_Interrupt           : constant Interrupt_ID := 33;
   UART0_Interrupt          : constant Interrupt_ID := 34;
   UART1_Interrupt          : constant Interrupt_ID := 35;
   UART2_Interrupt          : constant Interrupt_ID := 36;
   SDIO_HOST_Interrupt      : constant Interrupt_ID := 37;
   ETH_MAC_Interrupt        : constant Interrupt_ID := 38;
   MCPWM0_Interrupt         : constant Interrupt_ID := 39;
   MCPWM1_Interrupt         : constant Interrupt_ID := 40;
   MCPWM2_Interrupt         : constant Interrupt_ID := 41;
   MCPWM3_Interrupt         : constant Interrupt_ID := 42;
   LEDC_Interrupt           : constant Interrupt_ID := 43;
   EFUSE_Interrupt          : constant Interrupt_ID := 44;
   TWAI0_Interrupt          : constant Interrupt_ID := 45;
   RTC_CORE_Interrupt       : constant Interrupt_ID := 46;
   RMT_Interrupt            : constant Interrupt_ID := 47;
   PCNT_Interrupt           : constant Interrupt_ID := 48;
   I2C_EXT0_Interrupt       : constant Interrupt_ID := 49;
   I2C_EXT1_Interrupt       : constant Interrupt_ID := 50;
   RSA_Interrupt            : constant Interrupt_ID := 51;
   SPI1_DMA_Interrupt       : constant Interrupt_ID := 52;
   SPI2_DMA_Interrupt       : constant Interrupt_ID := 53;
   SPI3_DMA_Interrupt       : constant Interrupt_ID := 54;
   WDT_Interrupt            : constant Interrupt_ID := 55;
   TIMER1_Interrupt         : constant Interrupt_ID := 56;
   TIMER2_Interrupt         : constant Interrupt_ID := 57;
   TG0_T0_EDGE_Interrupt    : constant Interrupt_ID := 58;
   TG0_T1_EDGE_Interrupt    : constant Interrupt_ID := 59;
   TG0_WDT_EDGE_Interrupt   : constant Interrupt_ID := 60;
   TG0_LACT_EDGE_Interrupt  : constant Interrupt_ID := 61;
   TG1_T0_EDGE_Interrupt    : constant Interrupt_ID := 62;
   TG1_T1_EDGE_Interrupt    : constant Interrupt_ID := 63;
   TG1_WDT_EDGE_Interrupt   : constant Interrupt_ID := 64;
   TG1_LACT_EDGE_Interrupt  : constant Interrupt_ID := 65;
   MMU_IA_Interrupt         : constant Interrupt_ID := 66;
   MPU_IA_Interrupt         : constant Interrupt_ID := 67;
   CACHE_IA_Interrupt       : constant Interrupt_ID := 68;

end Ada.Interrupts.Names;
