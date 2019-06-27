/**
 * \file
 *
 * \brief FreeRTOS demo application main function.
 *
 * Copyright (C) 2014-2015 Atmel Corporation. All rights reserved.
 *
 * \asf_license_start
 *
 * \page License
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. The name of Atmel may not be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * 4. This software may only be redistributed and used in connection with an
 *    Atmel microcontroller product.
 *
 * THIS SOFTWARE IS PROVIDED BY ATMEL "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT ARE
 * EXPRESSLY AND SPECIFICALLY DISCLAIMED. IN NO EVENT SHALL ATMEL BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * \asf_license_stop
 *
 */

/**
 * \file
 *
 * \brief SAM
 *
 * Copyright (C) 2013-2015 Atmel Corporation. All rights reserved.
 *
 * \asf_license_start
 *
 * \page License
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. The name of Atmel may not be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * 4. This software may only be redistributed and used in connection with an
 *    Atmel microcontroller product.
 *
 * THIS SOFTWARE IS PROVIDED BY ATMEL "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT ARE
 * EXPRESSLY AND SPECIFICALLY DISCLAIMED. IN NO EVENT SHALL ATMEL BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * \asf_license_stop
 *
 */
/*
 * Support and FAQ: visit <a href="http://www.atmel.com/design-support/">Atmel Support</a>
 */

#include <asf.h>
#include <stdio.h>
#include <conf_demo.h>
#include <stdarg.h>
#include "oled1.h"
#include <math.h>


//! Delcaração das constantes e defines do programa	
#define NUMERO_ESTADOS 6
#define NUMERO_EVENTOS 4

#define INICIO 0
#define SENSOR 1
#define CALCULA_MEDIA 2
#define MOSTRA_DISPLAY 3
#define ESPERA_TAXA 4
#define RESET_APPICATION 5

#define MANTEM_ESTADO 0 
#define PROXIMO_ESTADO 1
#define ESTADO_ANTERIOR 2
#define HARD_RESET 3

#define ABOUT_TASK_PRIORITY     (tskIDLE_PRIORITY + 1)
#define ABOUT_TASK_DELAY        (33 / portTICK_RATE_MS)

#define TERMINAL_TASK_PRIORITY  (tskIDLE_PRIORITY + 1)
#define TERMINAL_TASK_DELAY     (1000 / portTICK_RATE_MS)

//! Estrutura das Protothreads 
typedef struct
{
	void (*ptrFunc) (void);
	uint8_t NextState;
	
} FSM_STATE_TABLE;

//! prototipos dos estados 
void init(void);
void le_sensor(void);
void calcula_media(void);
void mostra_display(void);
void ocioso(void);
void hard_reset(void);
void debounce(void);
int converte_celcius_task (int);
void mostra_console_task(void);

//! Tabela de estados 
const FSM_STATE_TABLE StateTable [NUMERO_ESTADOS][NUMERO_EVENTOS] =
{
      init,           INICIO,              init,           SENSOR,               init,           SENSOR,               init,           RESET_APPICATION, 
      le_sensor,      SENSOR,              le_sensor,      CALCULA_MEDIA, 	     le_sensor,      CALCULA_MEDIA, 	   le_sensor,      RESET_APPICATION, 
      calcula_media,  CALCULA_MEDIA,       calcula_media,  MOSTRA_DISPLAY,       calcula_media,  MOSTRA_DISPLAY,	   calcula_media,  RESET_APPICATION,
      mostra_display, MOSTRA_DISPLAY,      mostra_display, ESPERA_TAXA,	         mostra_display, ESPERA_TAXA,	       mostra_display, RESET_APPICATION,
      ocioso,         ESPERA_TAXA,         ocioso,         SENSOR,			     ocioso,         MOSTRA_DISPLAY,       ocioso,         RESET_APPICATION,   
	  hard_reset,     INICIO,              hard_reset,     INICIO,               hard_reset,     INICIO,               hard_reset,     RESET_APPICATION,             
};

int evento = 0;

//! Modulo de comunicação serial 
struct usart_module usart_instance;
struct usart_config usart_conf;

//! Oled 
static OLED1_CREATE_INSTANCE(oled1, OLED1_EXT_HEADER);

//! Protótipos de funções 
void configure_rtc_count(void);
void configure_eeprom(void);
void configure_adc(void);



/// Variáveis Real Time Counter
struct rtc_module rtc_instance;
struct adc_module adc_instance;

/// Conversao de Temperatura
uint16_t conversao_temperatura;

/// Variaveis de Buffer
int x, y;
char c[50];
char mensagem [20];


uint8_t temperatura_atual = 0;
uint8_t temp_min   = 255 ;
uint8_t temp_media = 0 ;
uint8_t temp_max   = 0 ;


uint8_t page_data[EEPROM_PAGE_SIZE];

enum state 
{
	TEMP_ATUAL = 0, 
	MEIO, 
	TEMP_MAX, 
	TEMP_MIN
}estado; //estados para o mostrador do display
	

//! Configuração da memoria
void configure_eeprom(void)
{	
	enum status_code error_code = eeprom_emulator_init();

	if (error_code == STATUS_ERR_NO_MEMORY) 
	{
		while (true) 
		{
			/* No EEPROM section has been set in the device's fuses */
			printf("No EEPROM section has been set in the device's fuses!!\n\r");
			delay_s(1);
		}
	}

	else if (error_code != STATUS_OK) 
	{
		/* Erase the emulated EEPROM memory (assume it is unformatted or
		 * irrecoverably corrupt) */
		printf("Memory error!!! \r\n");
		eeprom_emulator_erase_memory();
		eeprom_emulator_init();
	}
}

//! Estava no exemplo
#if (SAMD || SAMR21)
void SYSCTRL_Handler(void)
{
	if (SYSCTRL->INTFLAG.reg & SYSCTRL_INTFLAG_BOD33DET) {
		SYSCTRL->INTFLAG.reg |= SYSCTRL_INTFLAG_BOD33DET;
		eeprom_emulator_commit_page_buffer();
	}
}
#endif

/// Converte a temperatura para celcius
//@param temperatura
int converte_celcius_task (int __temperatura)
{
	//printf("CONVERTE CELCIUS  %d -> %d \r\n", __temperatura, ((__temperatura - 32) * 5 )/9  );
	return ( ( ( (int)__temperatura - 32) * 5)/9);
	
}
//! Estava no exemplo
static void configure_bod(void)
{
	#if (SAMD || SAMR21)
		struct bod_config config_bod33;
		bod_get_config_defaults(&config_bod33);
		config_bod33.action = BOD_ACTION_INTERRUPT;
		/* BOD33 threshold level is about 3.2V */
		config_bod33.level = 48;
		bod_set_config(BOD_BOD33, &config_bod33);
		bod_enable(BOD_BOD33);

		SYSCTRL->INTENSET.reg |= SYSCTRL_INTENCLR_BOD33DET;
		system_interrupt_enable(SYSTEM_INTERRUPT_MODULE_SYSCTRL);
	#endif

}
//! [setup]

//! Configuração do Real time Counter
void configure_rtc_count(void)
{
	struct rtc_count_config config_rtc_count;

	rtc_count_get_config_defaults(&config_rtc_count);

	config_rtc_count.prescaler           = RTC_COUNT_PRESCALER_DIV_32;
	config_rtc_count.mode                = RTC_COUNT_MODE_16BIT;
	#ifdef FEATURE_RTC_CONTINUOUSLY_UPDATED
	config_rtc_count.continuously_update = true;
	#endif
	config_rtc_count.compare_values[0]   = 1000;
	rtc_count_init(&rtc_instance, RTC, &config_rtc_count);
	rtc_count_enable(&rtc_instance);
}

//! Configuração do Analog to digital Converter ( Conversor Analógico para Digital)
void configure_adc(void)
{
	struct adc_config config_adc;
	adc_get_config_defaults(&config_adc);
	config_adc.resolution = ADC_RESOLUTION_12BIT; 
	config_adc.positive_input = ADC_POSITIVE_INPUT_TEMP;
	adc_init(&adc_instance, ADC, &config_adc);
	adc_enable(&adc_instance);
}

//! Debouncer para garantir que o botao é pressionado somente uma vez
void debounce()
{
	volatile uint16_t i;
	for(i = 0; i < 40000; i++);
}

//! Inicialização do programa
void init()
{
	configure_rtc_count();
	rtc_count_set_period(&rtc_instance, 2000);
	configure_adc();
	oled1_init(&oled1);
	gfx_mono_init();
	estado  = TEMP_ATUAL;

	configure_eeprom();
	configure_bod();	
	
	eeprom_emulator_read_page(0, page_data);
	temperatura_atual = page_data[0]; 
	temp_media = page_data[1];
	temp_max = page_data[2];
	temp_min = page_data[3];
	
	
	/// task 1 Conversao de Farenheit pra celcius
	///  (funcao, paramentros, size, NULL, prioridade, NULL
	xTaskCreate( converte_celcius_task, "Converte", 100, NULL, ABOUT_TASK_PRIORITY, NULL);
	
	xTaskCreate( mostra_console_task, NULL, 50, NULL, TERMINAL_TASK_PRIORITY, NULL);
	
	//! PRINT DE DEBUG
	printf("Inicializando\r\n"); 
	
	evento = PROXIMO_ESTADO;
}


//! Leitura de Sensor
void le_sensor()
{
	//! Acende o Led para debug
	port_pin_toggle_output_level(LED_0_PIN); 
	adc_start_conversion(&adc_instance);
	
	do {
		/// Aguarda a conversao e guarda o resultado em temperatura_atual 
	} while (adc_read(&adc_instance, &conversao_temperatura) == STATUS_BUSY); 
	printf("CONVERSAO = %d \r\n", conversao_temperatura);
	
	temperatura_atual =  ((float)conversao_temperatura*3.3/(4096))/0.01;
	temperatura_atual = converte_celcius_task(temperatura_atual);
		
	vTaskDelay(ABOUT_TASK_DELAY);
	
	//printf("Lendo do sensor !!\r\n");
	
	evento = PROXIMO_ESTADO;
}

/// Calcula a media das temperaturas e salva na memoria
void calcula_media(){
	
	if (temperatura_atual > temp_max){
		temp_max = temperatura_atual;
	}else if (temperatura_atual < temp_min){
		temp_min = temperatura_atual;
	}
	
	temp_media = (temp_media + temperatura_atual) / 2;
	
	printf("Calculando media e gravando na memoria !!\r\n");	

	/// Grava nas respectivas páginas de memoria
	page_data[0] = temperatura_atual;
	page_data[1] = temp_media;
	page_data[2] = temp_max;
	page_data[3] = temp_min;
	eeprom_emulator_write_page(0, page_data);
	eeprom_emulator_commit_page_buffer();
	
	evento = PROXIMO_ESTADO;
}

void mostra_console_task(void)
{
	/// Debug, Mostrando no console
	printf ( "\nTemperatura Atual  %d \r\n", temperatura_atual);
	printf ( "Temperatura Minima %d \r\n",   temp_min);
	printf ( "Temperatura Media  %d \r\n",   temp_media);
	printf ( "Temperatura Maxima %d \r\n",   temp_max);
}

/// Switch que mostra o display
void mostra_display()
{
	/// Debug
	printf ( "Mostrando display\r\n");
	
	//temperatura_atual = converte_celcius(temperatura_atual);
	
	mostra_console_task();
	switch (estado)
	{
		case TEMP_ATUAL:
		strcpy(mensagem, "Temperatura  Atual:");
		itoa ((int)temperatura_atual , c, 10);
		//printf ("temp atual %d\n", (int)temperatura_atual);
		break;
		
		case MEIO:
		strcpy(mensagem, "Temperatura  Media:");
		itoa ((int)temp_media, c, 10);
		//printf ("temp media %d\n", (int)temp_media);
		break;
		
		case TEMP_MAX:
		strcpy(mensagem, "Temperatura Maxima:");
		itoa ((int)temp_max, c, 10);
		//printf ("temp max %d\n", (int)temp_max);
		break;
		
		case TEMP_MIN:
		strcpy(mensagem, "Temperatura Minima:");
		itoa ((int)temp_min, c, 10);
		//printf ("temp min %d\n", (int)temp_min);
		break;
	}
	
	/// Escrita
	x = 0;
	y = 0;
	gfx_mono_draw_string(mensagem, x, y, &sysfont);
	
	x = 54;
	y = 10;
	strcat(c, "  ");
	gfx_mono_draw_string(c, x, y, &sysfont);
	evento = PROXIMO_ESTADO;
}

/// Tempo ocioso da aplicação, utiliza para verificar o estado dos botoes
void ocioso()
{
	if (rtc_count_is_compare_match( &rtc_instance, RTC_COUNT_COMPARE_0)) 
	{
		rtc_count_clear_compare_match( &rtc_instance, RTC_COUNT_COMPARE_0);
		evento = PROXIMO_ESTADO;
	}
	else if(oled1_get_button_state( &oled1, OLED1_BUTTON1_ID))
	{
		estado = (estado - 1) % 4;
		evento = ESTADO_ANTERIOR;
		debounce();
	}
	//else if (oled1_get_button_state( &oled1, OLED1_BUTTON2_ID))
	//{
	//	evento = HARD_RESET;
	//	debounce();
	//}
	else if (oled1_get_button_state( &oled1, OLED1_BUTTON2_ID))
	{
		estado = (estado + 1) % 4;
		evento = ESTADO_ANTERIOR;
		debounce();
	}
	else
	{
		evento = MANTEM_ESTADO;
	}
}

/// Reset na Placa e na memoria
void hard_reset()
{
	printf("Reset Pressionado \n");
	
	temperatura_atual = 0;
	temp_max = 0;
	temp_min = 255;
	temp_media = 0;
	
	// zera a memoria fisica utilizada
	page_data[0] = 0; // temperatura atual
	page_data[1] = 0; // temperatura media
	page_data[2] = 0; //temperatura maxima
	page_data[3] = 255; // temperatura minima
	eeprom_emulator_write_page( 0, page_data);
	eeprom_emulator_commit_page_buffer();
	evento = PROXIMO_ESTADO;
}


int main (void)
{
	//int i = 0;
	system_init();
	usart_get_config_defaults(&usart_conf);
	usart_conf.baudrate    = 9600;
	usart_conf.mux_setting = EDBG_CDC_SERCOM_MUX_SETTING;
	usart_conf.pinmux_pad0 = EDBG_CDC_SERCOM_PINMUX_PAD0;
	usart_conf.pinmux_pad1 = EDBG_CDC_SERCOM_PINMUX_PAD1;
	usart_conf.pinmux_pad2 = EDBG_CDC_SERCOM_PINMUX_PAD2;
	usart_conf.pinmux_pad3 = EDBG_CDC_SERCOM_PINMUX_PAD3;
	stdio_serial_init( &usart_instance, EDBG_CDC_MODULE, &usart_conf);
	
	usart_enable( &usart_instance);
	
	uint8_t currentState = INICIO;
	
	while (1) 
	{	
		if (StateTable[currentState][evento].ptrFunc != NULL)
			{
				StateTable[currentState][evento].ptrFunc();					
			}
			
		currentState = StateTable[currentState][evento].NextState;	
	}
}

