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

// Basic Logging Class

// Confiure Logging UART on device
const LOGGING_UART_BAUD_RATE = 115200;
if ("LOGGING_UART" in getroottable()) {
    // Configure logging UART
    LOGGING_UART.configure(LOGGING_UART_BAUD_RATE, 8, PARITY_NONE, 1, NO_CTSRTS);
    // Flag used to determine if UART logging is configured
    uartLoggingConfigured <- true;
}

enum LOG_LEVEL {
    DEBUG,
    INFO,
    ERROR
}

// Logging Singleton 
// NOTE: Logger can be used without initializing, log level will default to the initial 
// value "level"
Logger <- {

    "level"       : LOG_LEVEL.DEBUG,
    "isAgent"     : null, 
    "offlineLogs" : [],

    "init" : function(_level, _cm = null) {
        // Set log level
        level = _level;
        // Store environment lookup 
        if (isAgent == null) isAgent = _isAgent();
        // Update isConnected to use connection manager
        if (_cm != null) {
            _isConnected = function() {
                return _cm.isConnected();
            }
        }
    },

    "debug" : function(msg) {
        if (level <= LOG_LEVEL.DEBUG) {
            _log("[DEBUG]: " + msg.tostring());
        }
    },

    "info" : function(msg) {
        if (level <= LOG_LEVEL.INFO) {
            _log("[INFO]: " + msg.tostring());
        }
    },

    "error" : function(msg) {
        if (level <= LOG_LEVEL.ERROR) {
            _log("[ERROR]: " + msg.tostring());
        }
    },

    "storeOfflineLog" : function(cnow, d, reason, cfunction, text, t) {
        local msg = {
            "cnow"      : cnow,
            "date"      : d,
            "reason"    : reason,
            "cfunction" : cfunction,
            "text"      : text,
            "time"      : t
        }
        offlineLogs.push(msg);
    },

    "dumpOfflineLogs" : function() {
        foreach (log in offlineLogs) {
            _log("logdatetime: " + log.cnow);
            _log("formatted date: " + log.date);
            _log("reason: " + log.reason);
            _log("function: " + log.cfunction)
            _log("text: " + log.text);
            _log("which time: " + log.time);
        }
    },

    "_isConnected" : function() {
        return server.isconnected();
    },

    "_isAgent" : function() {
        return (imp.environment() == ENVIRONMENT_AGENT);
    },

    "_log" : function(msg, err = false) {
        // Configure isAgent if needed 
        if (isAgent == null) isAgent = _isAgent();

        // Log message
        if (isAgent) {
            (err) ? server.error(msg) : server.log(msg);
        } else {
            if (_isConnected()) {
                (err) ? server.error(msg) : server.log(msg);
            }
            if (uartLoggingConfigured) {
                local d = date();
                local ts = format("%04d-%02d-%02d %02d:%02d:%02d", d.year, d.month+1, d.day, d.hour, d.min, d.sec);
                LOGGING_UART.write(ts + " " + msg + "\n\r");
            }
        }
    },
}

// Global logging functions
// NOTE: "error", "debug" and "log" are now all
// global variables and should not be used as 
// local variable names in other places in the code
debug <- Logger.debug.bindenv(Logger);
log <- Logger.info.bindenv(Logger);
error <- Logger.error.bindenv(Logger);
