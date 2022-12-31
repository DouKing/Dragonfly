#!/bin/sh
swift package clean
swift build -c release
cp .build/release/Dragonfly /usr/local/bin/Dragonfly
