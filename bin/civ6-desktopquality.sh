#!/bin/bash

set -euo pipefail

cd "$HOME/Library/Application Support/Sid Meier's Civilization VI/Firaxis Games/Sid Meier's Civilization VI"

# replace the line that begins with PerformanceImpact
sed -i '' 's/^PerformanceImpact.*/PerformanceImpact 4/' GraphicsOptions.txt

# replace RenderWidth 
sed -i '' 's/RenderWidth .*/RenderWidth 3072/' AppOptions.txt

# replace RenderHeight
sed -i '' 's/RenderHeight .*/RenderHeight 1390/' AppOptions.txt

# replace UIUpscale
sed -i '' 's/UIUpscale .*/UIUpscale 0.25/' AppOptions.txt