#!/bin/bash

# Move applications back to /Applications
sudo mv /Applications/Development/Sublime\ Text.app /Applications/
sudo mv /Applications/Development/Visual\ Studio\ Code.app /Applications/
sudo mv /Applications/Development/VSCodium.app /Applications/
sudo mv /Applications/Development/CLion.app /Applications/
sudo mv /Applications/Development/Arduino\ IDE.app /Applications/
sudo mv /Applications/Development/MarkText.app /Applications/
sudo mv /Applications/Development/GitKraken.app /Applications/
sudo mv /Applications/Development/Upscayl.app /Applications/

sudo mv /Applications/Productivity/Microsoft\ Word.app /Applications/
sudo mv /Applications/Productivity/Microsoft\ PowerPoint.app /Applications/
sudo mv /Applications/Productivity/Microsoft\ Outlook.app /Applications/
sudo mv /Applications/Productivity/Microsoft\ Excel.app /Applications/
sudo mv /Applications/Productivity/Pages.app /Applications/
sudo mv /Applications/Productivity/Numbers.app /Applications/
sudo mv /Applications/Productivity/Keynote.app /Applications/
sudo mv /Applications/Productivity/Goodnotes.app /Applications/
sudo mv /Applications/Productivity/OneDrive.app /Applications/
sudo mv /Applications/Productivity/Microsoft\ Teams\ \(work\ or\ school\).app /Applications/
sudo mv /Applications/Productivity/Spark.app /Applications/
sudo mv /Applications/Productivity/Rectangle.app /Applications/

sudo mv /Applications/Utilities/AppCleaner.app /Applications/
sudo mv /Applications/Utilities/The\ Unarchiver.app /Applications/
sudo mv /Applications/Utilities/Image2Icon.app /Applications/
sudo mv /Applications/Utilities/LocalSend.app /Applications/
sudo mv /Applications/Utilities/Karabiner-EventViewer.app /Applications/
sudo mv /Applications/Utilities/Karabiner-Elements.app /Applications/
sudo mv /Applications/Utilities/logioptionsplus.app /Applications/
sudo mv /Applications/Utilities/Speedtest.app /Applications/
sudo mv /Applications/Utilities/Hot.app /Applications/

sudo mv /Applications/Media/VLC.app /Applications/
sudo mv /Applications/Media/uTorrent\ Web.app /Applications/
sudo mv /Applications/Media/balenaEtcher.app /Applications/
sudo mv /Applications/Media/Stellarium.app /Applications/
sudo mv /Applications/Media/Obsidian.app /Applications/

sudo mv /Applications/Science_Math/Mathematica.app /Applications/
sudo mv /Applications/Science_Math/GeoGebra\ Calculator\ Suite.app /Applications/
sudo mv /Applications/Science_Math/LTspice.app /Applications/
sudo mv /Applications/Science_Math/TeX /Applications/
sudo mv /Applications/Science_Math/National\ Instruments /Applications/

sudo mv /Applications/Networking/Speedtest.app /Applications/

sudo mv /Applications/Communication/Telegram.app /Applications/
sudo mv /Applications/Communication/WhatsApp.app /Applications/
sudo mv /Applications/Communication/zoom.us.app /Applications/

sudo mv /Applications/Web_Browsers/Google\ Chrome.app /Applications/
sudo mv /Applications/Web_Browsers/Safari.app /Applications/

sudo mv /Applications/Unsorted/qtiplot.app /Applications/

# Remove empty directories
sudo rmdir /Applications/Development
sudo rmdir /Applications/Productivity
sudo rmdir /Applications/Utilities
sudo rmdir /Applications/Media
sudo rmdir /Applications/Science_Math
sudo rmdir /Applications/Networking
sudo rmdir /Applications/Communication
sudo rmdir /Applications/Web_Browsers
sudo rmdir /Applications/Unsorted
