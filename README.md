# Low Power Cellular IBC Asset Tracker

## Overview

This is software for a low power cellular asset tracker. The tracker monitors for movement, and if movement has been detected it will report daily, otherwise the device will report once a week sending GPS location, temperature, accelerometer readings, and movement status. 

## Hardware

Hardware differences between the Custom IBC tracker and the Breakout board require some code customization. 
<br>
Differences from the breakout board include: Different pin mapping (different Hardware files to be included), RGB LED control (pins vs SPI, should not effect the current code since no LED control has been programmed), power routing (GPS is the only component that requires power gate to be enabled), battery charger and fuel gauge changes TBD, may be different components (Battery Charger and Fuel Gauge code are included but the main file doesn't instantiate or use.).
<br>
See below for setup instructions.

### Setup Custom IBC Tracker Board

impC001 cellular module
<br>
impC-ibc-tracker with GNSS

<br>
In the src/device/Main.device.nut file make sure `@include __PATH__ + "/HardwareBreakOut.device.nut"` is commented out and `@include __PATH__ + "/HardwareCustomIBC.device.nut"` is uncommented

```
@include __PATH__ + "/HardwareCustomIBC.device.nut"
// @include __PATH__ + "/HardwareBreakOut.device.nut"
```

### Setup ImpC001 Breakout Board

impC001 cellular module
<br>
impC001 breakout board
<br>
u-blox M8N GPS module
<br>
[3.7V 2000mAh battery from Adafruit](https://www.adafruit.com/product/2011?gclid=EAIaIQobChMIh7uL6pP83AIVS0sNCh1NNQUsEAQYAiABEgKFA_D_BwE)
<br>
In the src/device/Main.device.nut file make sure `@include __PATH__ + "/HardwareCustomIBC.device.nut"` is commented out and `@include __PATH__ + "/HardwareBreakOut.device.nut"` is uncommented

```
// @include __PATH__ + "/HardwareCustomIBC.device.nut"
@include __PATH__ + "/HardwareBreakOut.device.nut"
```

## Software Setup

This project uses u-blox AssistNow services, and requires and account and authorization token from u-blox. To apply for an account register [here](http://www.u-blox.com/services-form.html). 
<br>
<br>
This project has been written using [VS code plug-in](https://github.com/electricimp/vscode). All configuration settings and pre-processed files have been excluded. Follow the instructions [here](https://github.com/electricimp/vscode#installation) to install the plug-in and create a project. 
<br>
<br>
Add github credentials to `auth.info` file "builderSettings" (only needed if pulling code directly from GitHub repositories).
```
  "builderSettings": {
    "github_user": "<YOUR-GITHUB-USERNAME>",
    "github_token": "<YOUR-GITHUB-TOKEN>"
  }
```
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