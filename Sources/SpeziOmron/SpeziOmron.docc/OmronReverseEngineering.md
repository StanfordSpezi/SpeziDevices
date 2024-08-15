# Reverse Engineering Omron Devices

Collects knowledge acquired when reverse engineering Omron Health devices.

<!--
#
# This source file is part of the Stanford SpeziDevices open source project
#
# SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
#
# SPDX-License-Identifier: MIT
#
-->

## Overview

// TODO: what happens with unhandeled responses in Omron state machine while subscribing to characteristics?
// TODO: omron has a connection timeout of 60s and any disonnect before that is considered a successful pairing! (do they?)

- Discovery
- Peripheral Name is the model (use that to display images)
- 

- Setting Time on first notification

- When is a device considered paried

Omron application considers an application paired when it disconnects and any success-indicating condition is fulfilled.
Such conditions are:
* A CurrentTime notification was received after sending the initial update time command.
* Battery Level notification was received.
* Any measurement was received (only applies to transfer mode!).

// TODO: should we mention timeout of 60 seconds?

- Tip: SpeziDevices improves pairing speed by not waiting for a disconnect to check these conditions, but notifying the `PairedDevices`
    module as soon as these conditions are fulfilled, leading to a better user experience.

// TODO: link paired devices module!


// TODO: failure if wanted to read measurement and didn't
// TODO: Failre if wanted to register new user but didn't
// TODO: failure if registered new user but didn't recieved an updated database change increment
