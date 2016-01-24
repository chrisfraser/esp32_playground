/*
 * Created by: Chris Fraser (@thegwa)
 * Email: hello<at>chrisfraser<dot>co<dot>za
 * License: MIT
 *
 * Blink
 * Step 1: Flash an LED
 * Step 2: ...
 * Step 3: Profit
 */
#include <espressif/esp_common.h>
#include <espressif/esp_sensor.h>
#include <freertos/task.h>
#include <freertos/FreeRTOS.h>

// Config
#include "user_config.h"

// Drivers
#include <gpio.h>

static int statusLedInterval = 5000;

// Wifi Callback handler
void wifi_event_handler_cb(System_Event_t *event);

/* wifiConfigTask to setup wifi config */
void wifiConfigTask(void *p) {

    if (wifi_get_opmode() != STATION_MODE)
    {
    	os_printf("Wifi not in Station Mode... Resetting.");
        wifi_set_opmode(STATION_MODE);
		wifi_station_set_auto_connect(false);
        vTaskDelay(1000 / portTICK_RATE_MS);
        system_restart();
    }

    if (wifi_station_get_auto_connect())
	{
		os_printf("Wifi set to auto connect... Resetting.");
		wifi_station_set_auto_connect(false);
		system_restart();
	}

	os_printf("Wifi correctly configured.");

    vTaskDelete(NULL);
}

/* wifiConfigTask to setup wifi config */
void wifiConnectTask(void *p) {

    wifi_set_event_handler_cb(wifi_event_handler_cb);
    int count = 0;
    while(!wifi_station_connect()){
    	if( count++ > 10){
    		os_printf("Setting wifi credentials");
    	    // set AP parameter
    	    struct station_config config;

    	    bzero(&config, sizeof(struct station_config));
    	    sprintf(config.ssid, SSID);
    	    sprintf(config.password, PASSWORD);
    	    wifi_station_set_config(&config);

    	    wifi_station_connect();

    	    break;
    	}

    	vTaskDelay(250 / portTICK_RATE_MS);
    }

    vTaskDelete(NULL);
}

void wifi_event_handler_cb(System_Event_t *event)
{
    if (event == NULL) {
    	os_printf("No event\n");
        return;
    }

	Event_Info_u event_info = event->event_info;
    switch (event->event_id) {
		case EVENT_STAMODE_SCAN_DONE:
			os_printf("ESP32 station finish scanning AP\n");
			break;
		case EVENT_STAMODE_CONNECTED:
			os_printf("ESP32 station connected to AP\n");

			Event_StaMode_Connected_t c = event_info.connected;
			os_printf("SSID: %s\n",c.ssid);

			statusLedInterval = 100;
			break;
		case EVENT_STAMODE_DISCONNECTED:
			os_printf("ESP32 station disconnected to AP\n");
			break;
		case EVENT_STAMODE_AUTHMODE_CHANGE:
			os_printf("The auth mode of AP connected by ESP32 station changed\n");
			break;
		case EVENT_STAMODE_GOT_IP:
			os_printf("ESP32 station got IP from connected AP\n");
			statusLedInterval = 1000;
			break;
		case EVENT_STAMODE_DHCP_TIMEOUT:
			os_printf("ESP32 station dhcp client got IP timeout\n");
			break;
		case EVENT_SOFTAPMODE_STACONNECTED:
			os_printf("A station connected to ESP32 soft-AP\n");
			break;
		case EVENT_SOFTAPMODE_STADISCONNECTED:
			os_printf("A station disconnected to ESP32 soft-AP\n");
			break;
		case EVENT_SOFTAPMODE_PROBEREQRECVED:
			os_printf("Receive probe request packet in soft-AP interface\n");
			break;
		case EVENT_MAX:
			os_printf("EVENT_MAX\n");
			break;
        default:
            break;
    }
}

// blinkTask for LED
void blinkTask(void *p) {
	while (1) {
		//printf("PIN:%i ON\n", LEDPIN);
		// Set the pin to high
		GPIO_OUTPUT_SET(LEDPIN, 1);

		// For some reason FreeRTOS has a tick rate of 100Hz
		// Dividing by portTICK_RATE_MS fixes ms values
		vTaskDelay(statusLedInterval / portTICK_RATE_MS);

		//printf("PIN:%i OFF\n", LEDPIN);
		// Set the pin to low
		GPIO_OUTPUT_SET(LEDPIN, 0);
		vTaskDelay(statusLedInterval / portTICK_RATE_MS);
	}
}

// tempReadTask for internal sensor
void tempReadTask(void *p) {

	int* delay = (int*)p;

	while (1) {
		printf("Temp: %d\n", temperature_sensor_read() );

		vTaskDelay(*delay / portTICK_RATE_MS);
	}
}

// "main" method
void user_init(void) {
	// Print out some interesting things
	printf("SDK version:%s\n", system_get_sdk_version());
	printf("CPU running at %dMHz\n", system_get_cpu_freq());
	printf("Free Heap size: %d\n", system_get_free_heap_size());
	system_print_meminfo();

	printf("Starting wifiConfigTask");
	printf("==================================================================\n");
	// Create the wifiConfig Task
	xTaskCreate(wifiConfigTask, (signed char * )"wifiConfigTask", configMINIMAL_STACK_SIZE, NULL, 1, NULL);

	printf("Starting wifiConnectTask");
	printf("==================================================================\n");
	// Create the wifiConmect Task
	xTaskCreate(wifiConnectTask, (signed char * )"wifiConnectTask", configMINIMAL_STACK_SIZE, NULL, 1, NULL);

	printf("Starting blinkTask");
	printf("==================================================================\n");

	// Create the blink task
	xTaskCreate(blinkTask, (signed char * )"blinkTask", configMINIMAL_STACK_SIZE, NULL, 1, NULL);

	printf("Starting tempReadTask");
	printf("==================================================================\n");
	static int tempInterval = 5000; // interval to pass to the tempReadTask via *pvParameters

	// Create the tempRead Task
	xTaskCreate(tempReadTask, (signed char * )"tempReadTask", configMINIMAL_STACK_SIZE, &tempInterval, 1, NULL);
}
