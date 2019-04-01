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

// Location/GPS File

const DEFAULT_GPS_ACCURACY = 9999;
const GPS_UART_BAUDRATE    = 115200;
const LOCATION_CHECK_SEC   = 1;

enum FIX_TYPE {
    NO_FIX,
    DEAD_REC_ONLY,
    FIX_2D,
    FIX_3D,
    GNSS_DEAD_REC,
    TIME_ONLY
}

// Manages Location Application Logic
// Dependencies: UBloxM8N, UBloxAssistNow(device), UbxMsgParser
// Initializes: UBloxM8N, UBloxAssistNow(device)
class Location {
    
    ubx        = null;
    assist     = null;

    gpsFix     = null;
    accTarget  = null;
    onAccFix   = null;

    bootTime   = null;

    constructor(_bootTime) {
        bootTime = _bootTime;

        ::debug("Configuring u-blox...");
        ubx = UBloxM8N(GPS_UART);
        local ubxSettings = {
            "baudRate"     : GPS_UART_BAUDRATE,
            "outputMode"   : UBLOX_M8N_MSG_MODE.UBX_ONLY,
            "inputMode"    : UBLOX_M8N_MSG_MODE.BOTH
        }
        
        // Register handlers with debug logging only if needed
        if (Logger.level <= LOG_LEVEL.DEBUG) {
            // Register command ACK and NAK callbacks
            ubx.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_ACK, _onACK.bindenv(this));
            ubx.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_NAK, _onNAK.bindenv(this));
            // Register general handler
            ubxSettings.defaultOnMsg <- _onMessage.bindenv(this);
        }

        ubx.configure(ubxSettings);
        assist = UBloxAssistNow(ubx);
        
        ::debug("Enable navigation messages...");
        // Enable Position Velocity Time Solution messages
        ubx.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT, LOCATION_CHECK_SEC, _onNavMsg.bindenv(this));
    }

    function getLocation(target, onAccurateFix) {
        accTarget = target;
        onAccFix = onAccurateFix;
        
        if (gpsFix != null) {
            _checkAccuracy();
        } else {
            // Write a time assist packet to help get fix
            assist.writeUtcTimeAssist();
        }
    }

    function writeAssistMsgs(msgs, onDone = null) {
        assist.writeAssistNow(msgs, onDone);
    }

    function _onNavMsg(payload) {
        // This will trigger on every msg, so don't log message unless you need to debug something
        // ::debug("In NAV_PVT msg handler...");
        // ::debug("-----------------------------------------");
        // ::debug("Msg len: " + payload.len());

        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT](payload);
        if (parsed.error == null) {
            _checkFix(parsed);
        } else {
            ::error(parsed.error);
            ::debug(paylaod);
        }

        // ::debug("-----------------------------------------");
    }

    function _onMessage(msg, classId = null) {
        if (classId != null) {
            // Received UBX message
            _onUbxMsg(msg, classId);
         } else {
             // Received NMEA sentence
             _onNmeaMsg(msg);
         }
    }

    function _onUbxMsg(payload, classId) {
        ::debug("In Location ubx msg handler...");
        ::debug("-----------------------------------------");

        // Log message info
        ::debug(format("Msg Class ID: 0x%04X", classId));
        ::debug("Msg len: " + payload.len());

        ::debug("-----------------------------------------");
    }

    function _onNmeaMsg(sentence) {
        ::debug("In Location NMEA msg handler...");
        // Log NMEA message
        ::debug(sentence);
    }

    function _onACK(payload) {
        ::debug("In Location ACK_ACK msg handler...");
        ::debug("-----------------------------------------");

        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.ACK_ACK](payload);
        if (parsed.error != null) {
            ::error(parsed.error);
        } else {
            ::debug(format("ACK-ed msgId: 0x%04X", parsed.ackMsgClassId));
        }

        ::debug("-----------------------------------------");
    }

    function _onNAK(payload) {
        ::debug("In Location ACK_NAK msg handler...");
        ::debug("-----------------------------------------");

        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.ACK_NAK](payload);
        if (parsed.error != null) {
            ::error(parsed.error);
        } else {
            ::error(format("NAK-ed msgId: 0x%04X", parsed.nakMsgClassId));
        }

        ::debug("-----------------------------------------");
    }

    function _checkFix(payload) {
        // Check fixtype
        local fixType = payload.fixType;
        local timeStr = format("%04d-%02d-%02dT%02d:%02d:%02dZ", payload.year, payload.month, payload.day, payload.hour, payload.min, payload.sec);

        if (fixType >= FIX_TYPE.FIX_3D) {
            // Get timestamp for this fix
            local fixTime = (hardware.millis() - bootTime) / 1000.0;
            local accuracy = _getAccuracy(payload.hAcc);

            // If this is the first fix, create fix report table
            if (gpsFix == null) {
                // And record time to first fix
                gpsFix = {
                    "secTo1stFix" : fixTime
                };
                ::debug(format("first fix time %s, satellites %d, fix type %d, accuracy %s", timeStr, payload.numSV, fixType, accuracy.tostring()));
            }

            // Update GPS fix info if we have better accuracy than the last reported value
            if (!("accuracy" in gpsFix) || accuracy < gpsFix.accuracy) {
                // Add/Update fix report values
                gpsFix.secToFix <- fixTime;
                gpsFix.fixType <- fixType;
                gpsFix.numSats <- payload.numSV;
                gpsFix.lon <- UbxMsgParser.toDecimalDegreeString(payload.lon);
                gpsFix.lat <- UbxMsgParser.toDecimalDegreeString(payload.lat);
                gpsFix.time <- timeStr;
                gpsFix.accuracy <- accuracy;
            }

            // Check if we have reached our target accuracy
            if (onAccFix != null) _checkAccuracy();
        } else {
            // This will trigger on every message, so don't log message unless you are debugging
            ::debug(format("no fix %d, satellites %d, date %s", fixType, payload.numSV, timeStr));
        }
    }

    function _checkAccuracy() {
        // Check if GPS has good accuracy
        if (gpsFix.accuracy <= accTarget) {
            onAccFix(gpsFix);
        }
    }

    function _getAccuracy(hacc) {
        // Squirrel only handles 32 bit signed integers
        // hacc is an unsigned 32 bit integer
        // Read as signed integer and if value is negative set to
        // highly inaccurate default
        hacc.seek(0, 'b');
        local gpsAccuracy = hacc.readn('i');
        return (gpsAccuracy < 0) ? DEFAULT_GPS_ACCURACY : gpsAccuracy / 1000.0;
    }

}
