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

// Device Main Application File

// Libraries 
#require "UBloxM8N.device.lib.nut:1.0.1"
#require "UbxMsgParser.lib.nut:2.0.0"
#require "LIS3DH.device.lib.nut:2.0.2"
#require "HTS221.device.lib.nut:2.0.1"
#require "SPIFlashFileSystem.device.lib.nut:2.0.0"
#require "ConnectionManager.lib.nut:3.1.1"
#require "MessageManager.lib.nut:2.4.0"
#require "UBloxAssistNow.device.lib.nut:0.1.0"
// Battery Charger/Fuel Gauge Libraries
#require "MAX17055.device.lib.nut:1.0.1"
#require "BQ25895M.device.lib.nut:1.0.0"

// Beta Libraries (unpublished versions)
@include "github:electricimp/LPDeviceManager/LPDeviceManager.device.lib.nut@develop"

// Supporting files
// NOTE: Order of files matters do NOT change unless you know how it will effect 
// the application

// Manually select the hardware file that matches the device you are deploying to.
// @include __PATH__ + "/HardwareCustomIBC.device.nut"
@include __PATH__ + "/HardwareBreakOut.device.nut"

@include __PATH__ + "/../shared/Logger.shared.nut"
@include __PATH__ + "/../shared/Constants.shared.nut"
@include __PATH__ + "/Persist.device.nut"
@include __PATH__ + "/Location.device.nut"
@include __PATH__ + "/Motion.device.nut"
@include __PATH__ + "/Battery.device.nut"
@include __PATH__ + "/Env.device.nut"


// Main Application
// -----------------------------------------------------------------------

// NOTE: If changing CHECK_IN_TIME_SEC uncomment code in the constructor that 
// overwrites the currently stored checking timestamp, so changes take will take 
// effect immediately.
// Wake every x seconds to check if report should be sent 
const CHECK_IN_TIME_SEC  = 900; // (for production update to 86400) 60s * 60m * 24h 
// Wake every x seconds to send a report, regaurdless of check results
const REPORT_TIME_SEC    = 3600; // (for production update to 604800) 60s * 60m * 24h * 7d 

// Force in Gs that will trigger movement interrupt
const MOVEMENT_THRESHOLD = 0.05;
// Accuracy of GPS fix in meters, cut power to GPS & report immediately 
const LOCATION_TARGET_ACCURACY  = 5;
// Accuracy of GPS fix in meters, add to report if fix is btwn this and ideal accuracy
const LOCATION_REPORT_ACCURACY  = 10;
// Constant used to validate imp's timestamp 
const VALID_TS_YEAR      = 2019;
// Maximum time to stay awake
const MAX_WAKE_TIME      = 60;
// Maximum time to wait for GPS to get a fix, before trying to send report
// NOTE: This should be less than the MAX_WAKE_TIME
const GPS_TIMEOUT        = 55; 

class MainController {

    cm          = null;
    mm          = null;
    lpm         = null;
    move        = null;
    loc         = null;
    persist     = null;

    bootTime    = null;
    fix         = null;
    battStatus  = null;
    thReading   = null;
    isUpright   = null;
    readyToSend = null;
    sleep       = null;
    reportTimer = null;

    constructor() {
        // Get boot timestamp
        bootTime = hardware.millis();

        // Initialize ConnectionManager Library - this sets the connection policy, so divice can 
        // run offline code. The connection policy should be one of the first things set when the 
        // code starts running.
        // TODO: In production update CM_BLINK to NEVER to conserve battery power
        // TODO: Look into setting connection timeout (currently using default of 60s)
        cm = ConnectionManager({ 
	        "blinkupBehavior": CM_BLINK_ALWAYS,
	        "retryOnTimeout" : false
	    });
        imp.setsendbuffersize(8096);

        // Initialize Logger 
        Logger.init(LOG_LEVEL.DEBUG, cm);

        ::debug("--------------------------------------------------------------------------");
        ::debug("Device started...");
        ::debug(imp.getsoftwareversion());
        ::debug("--------------------------------------------------------------------------");
        PWR_GATE_EN.configure(DIGITAL_OUT, 0);

        // Initialize movement tracker, boolean to configure i2c in Motion constructor
        // NOTE: This does NOT configure/enable/disable movement tracker
        move = Motion(true);

        // Initialize SPI storage class
        persist = Persist();

        // Initialize Low Power Manager Library - this registers callbacks for each of the
        // different wake reasons (ie, onTimer, onInterrupt, defaultOnWake, etc);
        local handlers = {
            "onTimer"       : onScheduledWake.bindenv(this),
            "onInterrupt"   : onMovementWake.bindenv(this),
            "defaultOnWake" : onBoot.bindenv(this)
        }
        lpm = LPDeviceManager(cm, handlers);

        // Set connection callbacks
        lpm.onConnect(onConnect.bindenv(this));
        cm.onTimeout(onConnTimeout.bindenv(this));

        // Initialize Message Manager for agent/device communication
        mm = MessageManager({"connectionManager" : cm});
        mm.onTimeout(mmOnTimeout.bindenv(this));

        // Flag for sending GPS fix data only when connected
        readyToSend = false;
    }

    // MM handlers 
    // -------------------------------------------------------------

    // Global MM Timeout handler
    function mmOnTimeout(msg, wait, fail) {
        ::debug("MM message timed out");
        fail();
    }

    // MM onFail handler for report
    function mmOnReportFail(msg, err, retry) {
        ::error("Report send failed");
        powerDown();
    }

    // MM onFail handler for assist messages
    function mmOnAssistFail(msg, err, retry) {
        ::error("Request for assist messages failed, retrying");
        retry();
    }

    // MM onAck handler for report
    function mmOnReportAck(msg) {
        // Report successfully sent
        ::debug("Report ACK received from agent");

        // Clear & reset movement detection
        if (persist.getMoveDetected()) {
            // Re-enable movement detection
            move.enable(MOVEMENT_THRESHOLD, onMovement.bindenv(this));
            // Toggle stored movement flag
            persist.setMoveDetected(false);
        }
        updateReportingTime();
        powerDown();
    }

    // MM onReply handler for assist messages
    function mmOnAssist(msg, response) {
        ::debug("Assist messages received from agent. Writing to u-blox");
        // Response contains assist messages from cloud.
        loc.writeAssistMsgs(response, onAssistMsgDone.bindenv(this));
    }

    // Connection & Connection Flow Handlers 
    // -------------------------------------------------------------

    // Connection Flow
    function onConnect() {
        ::debug("Device connected...");
        // Note: We are only checking for GPS fix, not battery status completion 
        // before sending report. The assumption is that an accurate GPS fix will 
        // take longer than getting battery status.
        if (fix == null) {
            // Flag used to trigger report send from inside location callback
            readyToSend = true;
            // We don't have a fix, request assist online data
            ::debug("Requesting assist messages from agnet/cloud.");
            local mmHandlers = {
                "onReply" : mmOnAssist.bindenv(this),
                "onFail"  : mmOnAssistFail.bindenv(this)
            };
            mm.send(MM_ASSIST, null, mmHandlers);
        } else {
            sendReport();
        }
    }

    // Connection time-out flow
    function onConnTimeout() {
        ::debug("Connection try timed out.");
        powerDown();
    }

    // Wake up on timer flow
    function onScheduledWake() {
        ::debug("Wake reason: " + lpm.wakeReasonDesc());

        // Configure Interrupt Wake Pin
        // No need to (re)enable movement detection, these settings
        // are stored in the accelerometer registers. Just need  
        // to configure the wake pin. 
        move.configIntWake(onMovement.bindenv(this));

        // Set a limit on how long we are connected
        // Note: Setting a fixed duration to sleep here means next connection
        // will happen in calculated time + the time it takes to complete all
        // tasks. 
        lpm.doAsyncAndSleep(function(done) {
            // Set sleep function
            sleep = done;
            // Check if we need to connect and report
            checkAndSleep();
        }.bindenv(this), getSleepTimer(), MAX_WAKE_TIME);
    }

    // Wake up on interrupt flow
    function onMovementWake() {
        ::debug("Wake reason: " + lpm.wakeReasonDesc());

        // If event valid, disables movement interrupt and store movement flag
        onMovement();

        // Sleep til next check-in time
        // Note: To conserve battery power, after movement interrupt 
        // we are not connecting right away, we will report movement
        // on the next scheduled check-in time
        powerDown();
    }

    // Wake up (not on interrupt or timer) flow
    function onBoot(wakereson) {
        ::debug("Wake reason: " + lpm.wakeReasonDesc());

        // Enable movement monitor
        move.enable(MOVEMENT_THRESHOLD, onMovement.bindenv(this));

        // NOTE: overwriteStoredConnectSettings method only needed if CHECK_IN_TIME_SEC 
        // and/or REPORT_TIME_SEC have been changed
        overwriteStoredConnectSettings();

        // Send report if connected or alert condition noted, then sleep 
        // Set a limit on how long we are connected
        // Note: Setting a fixed duration to sleep here means next connection
        // will happen in calculated time + the time it takes to complete all
        // tasks. 
        lpm.doAsyncAndSleep(function(done) {
            // Set sleep function
            sleep = done;
            // Check if we need to connect and report
            checkAndSleep();
        }.bindenv(this), getSleepTimer(), MAX_WAKE_TIME);
    }

    // Actions
    // -------------------------------------------------------------

    // Create and send device status report to agent
    function sendReport() {
        local report = {
            "secSinceBoot" : (hardware.millis() - bootTime) / 1000.0,
            "ts"           : time(), 
            "movement"     : persist.getMoveDetected()
        }

        if (battStatus != null) report.battStatus <- battStatus;
        if (thReading != null) {
            report.temperature <- thReading.temperature;
            report.humidity <- thReading.humidity;
        }
        if (isUpright != null) report.containerUpright <- isUpright;
        if (fix != null) {
            report.fix <- fix;
        } else {
            local mostAccFix = loc.gpsFix;
            // If GPS got a fix of any sort
            if (mostAccFix != null) {
                // Log the fix summery
                ::debug(format("fixType: %s, numSats: %s, accuracy: %s", mostAccFix.fixType.tostring(), mostAccFix.numSats.tostring(), mostAccFix.accuracy.tostring()));
                // Add to report if fix was within the reporting accuracy
                if (mostAccFix.accuracy <= LOCATION_REPORT_ACCURACY) report.fix <- mostAccFix;
            } 
        }

        // Toggle send flag
        readyToSend = false;

        // DEBUGGING MOVEMENT ISSUE
        ::debug("Accel is enabled: " + move._isAccelEnabled() + ", accel int enabled: " + move._isAccelIntEnabled() + ", movement flag: " + persist.getMoveDetected());

        // Send to agent
        ::debug("Sending device status report to agent");
        local mmHandlers = {
            "onAck" : mmOnReportAck.bindenv(this),
            "onFail" : mmOnReportFail.bindenv(this)
        };
        mm.send(MM_REPORT, report, mmHandlers);
    }

    // Powers up GPS and starts location message filtering for accurate fix
    function getLocation() {
        PWR_GATE_EN.write(1);
        if (loc == null) loc = Location(bootTime);
        loc.getLocation(LOCATION_TARGET_ACCURACY, onAccFix.bindenv(this));
    }

    // Initializes Battery monitor and gets battery status
    function getBattStatus() {
        // NOTE: I2C is configured when Motion class is initailized in the 
        // constructor of this class, so we don't need to configure it here.
        // Initialize Battery Monitor without configuring i2c
        local battery = Battery(false);
        battery.getStatus(onBatteryStatus.bindenv(this));
    }

    // Initializes Env Monitor and gets temperature and humidity
    function getSensorReadings() {
        // Get temperature and humidity reading
        // NOTE: I2C is configured when Motion class is initailized in the 
        // constructor of this class, so we don't need to configure it here.
        // Initialize Environmental Monitor without configuring i2c
        local env = Env();
        env.getTempHumid(onTempHumid.bindenv(this));
    }

    // Checks container position using Accelerometer
    function getContainerPosition() {
        // Movement monitor is already initialized in constructor,
        // just check position 
        move.isUpright(onPositionIsUpright.bindenv(this));
    }

    // Updates report time, after having just sent a report
    function updateReportingTime() {
        // We just sent a report, calculate next report time based on the time we booted
        local now = time();

        // If report timer expired set based off of stored report ts, otherwise 
        // set based on current time offset with by the boot ts
        local reportTime = now + REPORT_TIME_SEC - (bootTime / 1000);

        // Update report time if it has changed
        persist.setReportTime(reportTime);
        ::debug("Next report time " + reportTime + ", in " + (reportTime - now) + "s");
    }

    function setReportTimer() {
        // Ensure only one timer is set
        cancelReportTimer();
        // Start a timer to send report if accurate GPS fix is not found
        reportTimer = imp.wakeup(GPS_TIMEOUT, onReportTimerExpired.bindenv(this)) 
    }

    function cancelReportTimer() {
        if (reportTimer != null) {
            imp.cancelwakeup(reportTimer);
            reportTimer = null;
        }
    }

    // Async Action Handlers 
    // -------------------------------------------------------------

    // Pin state change callback & on wake pin action
    // If event valid, disables movement interrupt and store movement flag
    function onMovement() { 
        // Check if movement occurred
        // Note: Motion detected method will clear interrupt when called
        if (move.detected()) {
            ::debug("Movement event detected");
            // Store movement flag
            persist.setMoveDetected(true);

            // If movement occurred then disable interrupt, so we will not 
            // wake again until scheduled check-in time
            move.disable();
        }
    }

    // Assist messages written to u-blox completed
    // Logs write errors if any
    function onAssistMsgDone(errs) {
        ::debug("Assist messages written to u-blox");
        if (errs != null) {
            foreach(err in errs) {
                // Log errors encountered
                ::error(err.error);
            }
        }
    }

    // If report timer expires before accurate GPS fix is not found, 
    // disable GPS power and send report if connected
    function onReportTimerExpired() {
        ::debug("GPS failed to get an accurate fix. Disabling GPS power."); 
        PWR_GATE_EN.write(0);    

        // Send report if connection handler has already run
        // and report has not been sent
        if (readyToSend) sendReport();   
    }

    // Stores fix data, and powers down the GPS
    function onAccFix(gpxFix) {
        // We got a fix, cancel timer to send report automatically
        cancelReportTimer();

        ::debug("Got fix");
        fix = gpxFix;

        ::debug("Disabling GPS power");
        PWR_GATE_EN.write(0);
        
        // Send report if connection handler has already run
        // and report has not been sent
        if (readyToSend) sendReport();
    }

    // Stores battery status for use in report
    function onBatteryStatus(status) {
        ::debug("Get battery status complete:")
        ::debug("Remaining cell capacity: " + status.capacity + "mAh");
        ::debug("Percent of battery remaining: " + status.percent + "%");
        battStatus = status;
    }

    // Stores temperature and humidity reading for use in report
    function onTempHumid(reading) {
        ::debug("Get temperature and humidity complete:")
        ::debug(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", reading.humidity, "%", reading.temperature));
        thReading = reading;
    }

    // Stores container position for use in report
    function onPositionIsUpright(isUp) {
        ::debug("Container is upright: " + isUp);
        isUpright = isUp;
    }

    // Sleep Management
    // -------------------------------------------------------------

    // Updates check-in time if needed, and returns time in sec to sleep for
    function getSleepTimer() {
        local now = time();
        // Get stored wake time
        local wakeTime = persist.getWakeTime();
        
        // Our timer has expired, update it to next interval
        if (wakeTime == null || now >= wakeTime) {
            wakeTime = now + CHECK_IN_TIME_SEC - (bootTime / 1000);
            persist.setWakeTime(wakeTime);
        }

        local sleepTime = (wakeTime - now);
        ::debug("Setting sleep timer: " + sleepTime + "s");
        return sleepTime;
    }

    // Runs a check and triggers sleep flow 
    function checkAndSleep() {
        if (shouldConnect() || lpm.isConnected()) {
            // We are connected or if report should be filed
            if (!lpm.isConnected()) ::debug("Connecting...");
            // Set timer to send report if GPS doesn't get a fix, and we are connected
            setReportTimer();
            // Connect if needed and run connection flow 
            lpm.connect();
            // Power up GPS and try to get a location fix
            getLocation();
            // Get sensor readings for report
            getSensorReadings();
            // Check if container is upright
            getContainerPosition();
            // Get battery status
            // NOTE: Until Hardware determination and Fuel Gauge Library 
            // implemented. Don't include battery status in report.
            // getBattStatus();
        } else {
            // Go to sleep
            powerDown();
        }
    }

    // Debug logs about how long divice was awake, and puts device to sleep
    function powerDown() {
        // Log how long we have been awake
        local now = hardware.millis();
        ::debug("Time since code started: " + (now - bootTime) + "ms");
        ::debug("Going to sleep...");

        // DEBUGGING MOVEMENT ISSUE
        ::debug("Accel is enabled: " + move._isAccelEnabled() + ", accel int enabled: " + move._isAccelIntEnabled() + ", movement flag: " + persist.getMoveDetected());

        local sleepTime;
        if (sleep == null) {
            sleepTime = getSleepTimer();
            ::debug("Setting sleep timer: " + sleepTime + "s");
        }

        // Put device to sleep 
        (sleep != null) ? sleep() : lpm.sleepFor(sleepTime);
    }

    // Helpers
    // -------------------------------------------------------------

    // Overwrites currently stored wake and report times
    function overwriteStoredConnectSettings() {
        local now = time();
        persist.setWakeTime(now);
        persist.setReportTime(now);
    }

    // Returns boolean, checks for event(s) or if report time has passed
    function shouldConnect() {
        // Check for events 
        // Note: We are not currently storing position changes. The assumption
        // is that if we change position then movement will be detected and trigger
        // a report to be generated.
        local haveMoved = persist.getMoveDetected();
        ::debug("Movement detected: " + haveMoved);
        if (haveMoved) return true;

        // NOTE: We need a valid timestamp to determine sleep times.
        // If the imp looses all power, a connection to the server is 
        // needed to get a valid timestamp.
        local validTS = validTimestamp();
        ::debug("Valid timestamp: " + validTS);
        if (!validTS) return true;

        // Check if report time has passed
        local now = time(); 
        local shouldReport = (now >= persist.getReportTime());
        ::debug("Time to send report: " + shouldReport);
        return shouldReport;
    }

    // Returns boolean, if the imp module currently has a valid timestamp
    function validTimestamp() {
        local d = date();
        // If imp doesn't have a valid timestamp the date method returns
        // a year of 2000. Check that the year returned by the date method
        // is greater or equal to VALID_TS_YEAR constant.
        return (d.year >= VALID_TS_YEAR);
    }

}

// Runtime
// -----------------------------------------------------------------------

// Start controller
MainController();
