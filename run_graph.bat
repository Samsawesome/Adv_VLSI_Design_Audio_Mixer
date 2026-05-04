@echo off
echo Running graph.py with all analysis options enabled...
py graph.py --full --full-wave --spectrum --metrics --no-show
echo.
echo All graphs saved in Data\ folder (zoom, RMS envelope, full waveform, spectrum).
echo Metrics saved to Data\metrics.txt
