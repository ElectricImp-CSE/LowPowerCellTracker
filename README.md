# Low Power Cellular IBC Asset Tracker

## Overview

This is software for a low power cellular asset tracker. The tracker monitors for movement, and if movement has been detected it will report daily, otherwise the device will report once a week sending GPS location, temperature, accelerometer readings, and movement status. 

## Hardware

impC001 cellular module
impC-ibc-tracker with GNSS

**NOTE:** Hardware differences make this code incompatible with the impC001 breakout board tracker. Do not use this code unless your hardware is compatible.

Differences from the breakout board include: RGB LED control (pins vs SPI), power routing (GPS is the only component that requires power gate to be enabled), battery charger and fuel gauge changes TBD, may be different components.  

## Setup

This project uses u-blox AssistNow services, and requires and account and authorization token from u-blox. To apply for an account register [here](http://www.u-blox.com/services-form.html). 
<br>
<br>
This project has been written using [VS code plug-in](https://github.com/electricimp/vscode). All configuration settings and pre-processed files have been excluded. Follow the instructions [here](https://github.com/electricimp/vscode#installation) to install the plug-in and create a project. 
<br>
<br>
Replace the **src** folder in your newly created project with the **src** folder found in this repository
<br>
<br>
Update settings/imp.config "device_code", "agent_code", and "builderSettings" to the following (updating the UBLOX_ASSISTNOW_TOKEN with your u-blox Assist Now authorization token):

```
    "device_code": "src/device/Main.device.nut"
    "agent_code": "src/agent/Main.agent.nut"
    "builderSettings": {
        "variable_definitions": {
            "UBLOX_ASSISTNOW_TOKEN" : "<YOUR-UBLOX-ASSIST-NOW-TOKEN-HERE>"
        }
    }
```
<br>
For development purposes uart logging is recommended to see offline device logs. Current code uses hardware.uartDCAB (A: RTS, B: CTS, C: RX, D: TX) for logging. 

## Customization

Settings are all stored as constants. Modify to customize the application.

## Measurements

No hardware is available to test on, so no measurements have been taken for impC-ibc-tracker. 

Rough wake timings for impC001 breakout board with GPS base on code committed on 3/1/18 under good cellular conditions and in a location that can get a GPS fix .

- Wake with no connections ~650-655 ms
- Wake and connection ~40s
- Cold boot (connection established before code starts) ~20-30s

# License

Code licensed under the [MIT License](./LICENSE).