// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

// Sensors are not available in HIL_MODE_ATTITUDE
#if HIL_MODE != HIL_MODE_ATTITUDE

void ReadSCP1000(void) {}

void init_barometer(void)
{
	int flashcount;

	#if HIL_MODE == HIL_MODE_SENSORS
		hil.update();					// look for inbound hil packets for initialization
	#endif

	ground_pressure = 0;

	while(ground_pressure == 0){
		barometer.Read(); 					// Get initial data from absolute pressure sensor
		ground_pressure 	= barometer.Press;
		ground_temperature 	= barometer.Temp;
		delay(20);
		//Serial.printf("barometer.Press %ld\n", barometer.Press);
	}

	for(int i = 0; i < 30; i++){		// We take some readings...

		#if HIL_MODE == HIL_MODE_SENSORS
			hil.update(); 				// look for inbound hil packets
		#endif

		barometer.Read(); 				// Get initial data from absolute pressure sensor
		ground_pressure	= (ground_pressure * 9l   + barometer.Press) / 10l;
		ground_temperature	= (ground_temperature * 9 + barometer.Temp) / 10;

		delay(20);
		if(flashcount == 5) {
			digitalWrite(C_LED_PIN, LOW);
			digitalWrite(A_LED_PIN, HIGH);
			digitalWrite(B_LED_PIN, LOW);
		}

		if(flashcount >= 10) {
			flashcount = 0;
			digitalWrite(C_LED_PIN, HIGH);
			digitalWrite(A_LED_PIN, LOW);
			digitalWrite(B_LED_PIN, HIGH);
		}
		flashcount++;
	}

	// makes the filtering work later
	abs_pressure  = barometer.Press;

	// save home pressure - will be overwritten by init_home, no big deal
	ground_pressure = abs_pressure;

	//Serial.printf("abs_pressure %ld\n", abs_pressure);
	SendDebugln("barometer calibration complete.");
}

long read_barometer(void)
{
 	float x, scaling, temp;

	barometer.Read();		// Get new data from absolute pressure sensor

	//abs_pressure 			= (abs_pressure + barometer.Press) >> 1;		// Small filtering
	abs_pressure 			= ((float)abs_pressure * .7) + ((float)barometer.Press * .3);		// large filtering
	scaling 				= (float)ground_pressure / (float)abs_pressure;
	temp 					= ((float)ground_temperature / 10.0f) + 273.15f;
	x 						= log(scaling) * temp * 29271.267f;
	return 	(x / 10);
}

// in M/S * 100
void read_airspeed(void)
{

}

void zero_airspeed(void)
{

}

#endif // HIL_MODE != HIL_MODE_ATTITUDE

void read_battery(void)
{
	battery_voltage1 = BATTERY_VOLTAGE(analogRead(BATTERY_PIN1)) * .1 + battery_voltage1 * .9;
	battery_voltage2 = BATTERY_VOLTAGE(analogRead(BATTERY_PIN2)) * .1 + battery_voltage2 * .9;
	battery_voltage3 = BATTERY_VOLTAGE(analogRead(BATTERY_PIN3)) * .1 + battery_voltage3 * .9;
	battery_voltage4 = BATTERY_VOLTAGE(analogRead(BATTERY_PIN4)) * .1 + battery_voltage4 * .9;

	if(g.battery_monitoring == 1)
		battery_voltage = battery_voltage3; // set total battery voltage, for telemetry stream
	if(g.battery_monitoring == 2)
		battery_voltage = battery_voltage4;
	if(g.battery_monitoring == 3 || g.battery_monitoring == 4)
		battery_voltage = battery_voltage1;
	if(g.battery_monitoring == 4) {
		current_amps	 = CURRENT_AMPS(analogRead(CURRENT_PIN_1)) * .1 + current_amps * .9; //reads power sensor current pin
		current_total	 += current_amps * (float)delta_ms_medium_loop * 0.000278;
	}

	#if BATTERY_EVENT == 1
		if(battery_voltage < LOW_VOLTAGE)	low_battery_event();
		if(g.battery_monitoring == 4 && current_total > g.pack_capacity)	low_battery_event();
	#endif
}

//v: 10.9453, a: 17.4023, mah: 8.2
