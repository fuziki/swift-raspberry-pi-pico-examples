#!/bin/bash

# Get the list of /dev/tty.usb* devices
devices=$(ls /dev/tty.usb*)

# Check if any devices were found
if [ -z "$devices" ]; then
    echo "No USB devices found."
    exit 1
fi

# Display the found devices
echo "Found USB devices:"
echo "$devices"
echo "Do you want to connect to one of these devices? (y/n)"
read -r response

# If the user responds with 'y', connect to the first device
if [ "$response" = "y" ]; then
    device=$(echo "$devices" | head -n 1)
    echo "Connecting to $device..."
    screen "$device"
else
    echo "No connection made."
fi
