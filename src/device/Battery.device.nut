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

// Battery Monitoring File 
// NOTE: This class is currently written for a rechargable LiCoO2 battery. 
// Confirm settings before using.

// Settings for a 3.7V 2000mAh battery from Adafruit and impC001 breakout
const BATT_CHARGE_VOLTAGE = 4.2;
const BATT_CURR_LIMIT     = 2000;
const FG_DES_CAP          = 2000;   // mAh
const FG_SENSE_RES        = 0.01;   // ohms
const FG_CHARGE_TERM      = 20;     // mA
const FG_EMPTY_V_TARGET   = 3.3;    // V
const FG_RECOVERY_V       = 3.88;   // V
// NOTE: Fuel gauge setting chrgV, battType are set using library constant, 
// please check these settings if updating these constants.

const BATT_STATUS_CHECK_TIMEOUT = 0.5;

enum TRACKER_BATT_TYPE {
    RECHARGEABLE_2000,
    PRIMARY_CELL
}

// Manages Battery Monitoring  
// Dependencies: MAX17055, BQ25895M (may configure sensor i2c) Libraries
// Initializes: MAX17055, BQ25895M Libraries
class Battery {
    
    charger  = null;
    fg       = null;

    battType = null;
    fgReady  = null;

    constructor(_battType, configureI2C = false) {
        battType = _battType;

        switch(battType) {
            case TRACKER_BATT_TYPE.RECHARGEABLE_2000:
                ::debug("[Battery] Initializing Battery Charger and Fuel Guage");
                _initRechargable(configureI2C);
                break;
            case TRACKER_BATT_TYPE.PRIMARY_CELL: 
                ::debug("[Battery] Primary Cell battery monitoring not available");
                // TODO: Sort out how to measure battery status
                break;
            default: 
                ::error("[Battery] Unknown battery type: " + battType);
        }
    }

    function getStatus(cb) {
        switch(battType) {
            case TRACKER_BATT_TYPE.RECHARGEABLE_2000:
                _rechargableGetStatus(cb);
                break;
            case TRACKER_BATT_TYPE.PRIMARY_CELL:
                ::debug("[Battery] Primary Cell battery status not available");
                cb(null); 
                break;
            default: 
                ::error("[Battery] Unknown battery type: " + battType);
        }
    }

    function _rechargableGetStatus(cb) {
        if (fgReady) {
            cb(fg.getStateOfCharge());
        } else {
            imp.wakeup(BATT_STATUS_CHECK_TIMEOUT, function() {
                getStatus(cb);
            }.bindenv(this))
        }
    }

    function _initRechargable(configureI2C) {
        if (configureI2C) SENSOR_I2C.configure(CLOCK_SPEED_400_KHZ);

        charger = BQ25895(SENSOR_I2C, BATT_CHGR_ADDR);
        fg = MAX17055(SENSOR_I2C, FUEL_GAUGE_ADDR);

        // Charger default to: 4.352V and 2048mA
        charger.enable({"voltage": BATT_CHARGE_VOLTAGE, "current": BATT_CURR_LIMIT});

        local fgSettings = {
            "desCap"       : FG_DES_CAP,
            "senseRes"     : FG_SENSE_RES,
            "chrgTerm"     : FG_CHARGE_TERM,   
            "emptyVTarget" : FG_EMPTY_V_TARGET,
            "recoveryV"    : FG_RECOVERY_V,
            "chrgV"        : MAX17055_V_CHRG_4_2,
            "battType"     : MAX17055_BATT_TYPE.LiCoO2
        }
        // NOTE: Full init will only run when "power on reset alert is detected", 
        // so call this here so ready flag is always set.
        fg.init(fgSettings, function(err) {
            if (err != null) {
                ::error("[Battery] Error initializing fuel gauge: " + err);
            } else {
                fgReady = true;
            }
        }.bindenv(this));
    }
}
