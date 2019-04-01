// MIT License

// Copyright 2019 Electric Imp

// SPDX-License-Identifier: MIT

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// Hardware Abstraction Layer
// NOTE: All hardware objects are mapped to GLOBAL 
// variables. These variables are used throughout 
// the code, so vairable names should NOT be changed.

// NOTE: The hardware for this tracker is NOT compatible with the impC001 ibc-tracker board. 

// impC001-breakout-tracker-with-GPS rev5    
LED_SPI         <- hardware.spiYJTHU;

GPS_UART        <- hardware.uartNU;
PWR_GATE_EN     <- hardware.pinYG;

BATT_CHGR_OTG   <- hardware.pinYU;
BATT_CHGR_INT   <- hardware.pinV;

// Sensor i2c AKA i2c0 in schematics
SENSOR_I2C      <- hardware.i2cKL;     
ACCEL_INT       <- hardware.pinW;      
TEMP_HUMID_ADDR <- 0xBE;
ACCEL_ADDR      <- 0x32;
BATT_CHGR_ADDR  <- 0xD4;
FUEL_GAUGE_ADDR <- 0x6C;   

// Recommended for offline logging, remove when in production    
LOGGING_UART    <- hardware.uartDCAB;
