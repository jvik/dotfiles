#!/bin/bash

# Sets intended default-app MIME associations declaratively via xdg-mime, instead
# of tracking mimeapps.list directly — apps like Okular and imv silently rewrite
# that file whenever they're opened, so chezmoi could never keep it in sync.
if ! command -v xdg-mime &> /dev/null; then
    echo "xdg-mime not found. Skipping default application associations."
    exit 0
fi

xdg-mime default wine.desktop application/x-ms-dos-executable
xdg-mime default firefox.desktop x-scheme-handler/https
xdg-mime default firefox.desktop x-scheme-handler/http
xdg-mime default firefox.desktop application/xhtml+xml
xdg-mime default firefox.desktop text/html
xdg-mime default okularApplication_pdf.desktop application/pdf
xdg-mime default imv.desktop image/jpeg
