#!/bin/bash

set -euo pipefail

cd "$HOME/Library/Application Support/Sid Meier's Civilization VI/Firaxis Games/Sid Meier's Civilization VI"

# replace the line that begins with PerformanceImpact
sed -i '' 's/^PerformanceImpact.*/PerformanceImpact 1/' GraphicsOptions.txt

# replace RenderWidth with RenderWidth 3456
sed -i '' 's/RenderWidth .*/RenderWidth 3456/' AppOptions.txt

# replace RenderHeight with RenderHeight 2000
sed -i '' 's/RenderHeight .*/RenderHeight 2000/' AppOptions.txt

# replace UIUpscale with UIUpscale 1.25
sed -i '' 's/UIUpscale .*/UIUpscale 1.25/' AppOptions.txt