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

// Motion Monitoring File

// Number of readings per sec
const ACCEL_DATA_RATE     = 100;
// Number of readings condition must be true before int triggered 
const ACCEL_INT_DURATION  = 50;  
// Constants used to determine if container is upright
const ACCEL_UPRIGHT_X     = 1;
const ACCEL_UPRIGHT_Y     = 0;
const ACCEL_UPRIGHT_Z     = 0;
const ACCEL_UPRIGHT_RANGE = 0.5;

// Manages Motion Sensing  
// Dependencies: LIS3DH (may configure sensor i2c)
// Initializes: LIS3DH
class Motion {

    accel = null;

    constructor(configureI2C) {
        if (configureI2C) SENSOR_I2C.configure(CLOCK_SPEED_400_KHZ);
        accel = LIS3DH(SENSOR_I2C, ACCEL_ADDR);
    }

    function enable(threshold, onInterrupt = null) {
        ::debug("Enabling motion detection");

        configIntWake(onInterrupt);
        
        // Configures and enables motion interrupt
        accel.reset();
        accel.setDataRate(ACCEL_DATA_RATE);
        accel.setMode(LIS3DH_MODE_LOW_POWER);
        accel.enable(true);
        accel.configureHighPassFilter(LIS3DH_HPF_AOI_INT1, LIS3DH_HPF_CUTOFF1, LIS3DH_HPF_NORMAL_MODE);
        accel.getInterruptTable();
        accel.configureInertialInterrupt(true, threshold, ACCEL_INT_DURATION);
        accel.configureInterruptLatching(true);
    }

    function configIntWake(onInterrupt = null) {
        // Configure interrupt pin 
            // Wake when interrupt occurs 
            // (optional) With state change callback to catch interrupts when awake
        if (onInterrupt != null) {
            ACCEL_INT.configure(DIGITAL_IN_WAKEUP, onInterrupt);
        } else {
            ACCEL_INT.configure(DIGITAL_IN_WAKEUP);
        }
    }

    // This method does NOT clear the latched interrupt pin. It disables the accelerometer and reconfigures wake pin.  
    function disable() {
        ::debug("Disabling motion detection");

        // Disables accelerometer 
        accel.setDataRate(0);
        accel.enable(false);

        // Disable accel interrupt and high pass filter
        accel.configureHighPassFilter(LIS3DH_HPF_DISABLED);
        accel.configureInertialInterrupt(false);

        // Note: Configuring pin doesn't chage pin's current state
        // Reconfiguring int pin 
            // Disables wake on pin high
            // Clear state change callback
        ACCEL_INT.configure(DIGITAL_IN_PULLDOWN); 
    }

    // Returns boolean if interrupt was detected. 
    // Note: Calling this method clears the interrupt.
    function detected() {
        ::debug("Checking and clearing interrupt");
        // Get interrupt table. Note this clears the interrupt data 
        local res = accel.getInterruptTable();
        // Return boolean - if motion event has occurred
        return res.int1;
    }

    // Returns boolean if container is upright
    function isUpright() {
        // Enable accel if needed (check register and enable if needed)
        // Get accel reading
        // Disable accel if needed (if we just enabled, then disable)
        // Check reading against expected to determine if container is upright 
    }

    // Helper that returns boolean if accel reading is within the expected range
    function _inRange(actual, expected) {
        local min = expected + ACCEL_UPRIGHT_RANGE;
        local max = expected - ACCEL_UPRIGHT_RANGE;
        return (actual <= max && actual >= min);
    }

}
