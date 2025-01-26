RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#!/bin/bash
if ! [[ -x "$(command -v jq)" ]]; then
  echo 'Error: jq is not available. Please install it.' >&2
  exit 1
fi

if ! [[ -x "$(command -v curl)" ]]; then
  echo 'Error: curl is not available. Please install it.' >&2
  exit 1
fi

cleanup() {
  unset RED
  unset GREEN
  unset YELLOW
  unset NC
  unset RELEASE
  unset RELEASE_DATE
  unset RELEASE_ZIP
  unset STEAM_LIB_FOLDERS
  unset STEAM_MEDIA_FOLDERS
  unset GRIM_DAWN_INSTALLATION_FOLDER
  unset GRIM_DAWN_LANGAGE_FOLDER

  rm -Rf /tmp/WanezGD_Tools_release.zip /tmp/WanezGD_Tools_releases.json /tmp/WanezGD_Tools_release
}

trap cleanup EXIT

echo "Searching for Steam installation..."
STEAM_LIB_FOLDERS=$HOME/.steam/debian-installation/config/libraryfolders.vdf
if ! [[ -e "$STEAM_LIB_FOLDERS" ]]; then
    echo "Steam installation folder could not be found..."
    exit 2
fi
echo "Steam installation found."
echo ""

echo "Searching Steam media folders..."
STEAM_MEDIA_FOLDERS=$(cat "$STEAM_LIB_FOLDERS" | grep path | awk -F '\t' '{print $NF}' | tr -d "\"")
echo "Found:"
echo -e "${GREEN}$STEAM_MEDIA_FOLDERS${NC}"
echo ""


echo "Searching Grim Dawn installation folder..."
for STEAM_MEDIA_FOLDER in $STEAM_MEDIA_FOLDERS;
do

if [[ -d "$STEAM_MEDIA_FOLDER/steamapps/common/Grim Dawn" ]]; then
  GRIM_DAWN_INSTALLATION_FOLDER="$STEAM_MEDIA_FOLDER/steamapps/common/Grim Dawn"
  break
fi

done

if [[ -z "$GRIM_DAWN_INSTALLATION_FOLDER" ]]; then
  echo -e "${RED}Grim Dawn installation directory was not found.${NC}" >&2
  exit 3
fi

echo -e "${GREEN}Grim Dawn installation directory is $GRIM_DAWN_INSTALLATION_FOLDER${NC}".
echo ""

echo "Querying the WanezGD_Tools Github latest release..."

curl -L -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/WareBare/WanezGD_Tools/releases?per_page=1 --output /tmp/WanezGD_Tools_releases.json

RELEASE=$(jq '.[].assets[] | select(.name | match("^fullRainbow-[0-9.]*.zip")) |  {"name": .name, "browser_download_url": .browser_download_url, "created_at": .created_at}' < /tmp/WanezGD_Tools_releases.json)

if [[ $? -ne 0 ]]; then
  echo 'No release found.' >&2
  exit 1
fi

RELEASE_DATE=$(echo "$RELEASE" | jq -r '.created_at | strptime("%Y-%m-%dT%H:%M:%S%Z") |  strftime("%Y-%m-%d")')
echo -e "${GREEN}$(echo "$RELEASE" | jq .name)${NC} found (Created on the $RELEASE_DATE)."
read -r -p "Do you want to download it ?" choice
case "$choice" in 
  y|Y ) ;;
  n|N ) echo "Quitting"; exit 0;;
  * ) echo "Invalid choice"; exit 1;;
esac

RELEASE_ZIP=$(echo "$RELEASE" | jq -r .browser_download_url)
echo ""
echo "Downloading $RELEASE_ZIP..."
curl -L "$RELEASE_ZIP" --output /tmp/WanezGD_Tools_release.zip
echo ""

GRIM_DAWN_LANGAGE_FOLDER="$GRIM_DAWN_INSTALLATION_FOLDER/settings/text_en"
if [[ -d "$GRIM_DAWN_LANGAGE_FOLDER" ]]; then
  echo -e "${YELLOW}Warning! The folder /settings/text_en is already existing in the Grim Dawn installation folder!${NC}"
  echo -e "${YELLOW}It is the sign that a mod was already installed. It should be removed for this installer to proceed.${NC}"
  read -r -p "Remove $GRIM_DAWN_LANGAGE_FOLDER?" choice
  case "$choice" in 
  y|Y ) rm -Rf "$GRIM_DAWN_LANGAGE_FOLDER"; echo "";;
  n|N ) echo "Quitting"; exit 0;;
  * ) echo "Invalid choice"; exit 1;;
esac
fi

mkdir -p "$GRIM_DAWN_INSTALLATION_FOLDER/settings"

echo "Decompressing /tmp/WanezGD_Tools_release.zip..."
unzip /tmp/WanezGD_Tools_release.zip -d /tmp/WanezGD_Tools_release
echo "Done."
echo ""

echo "Installing the langage files"
cp -Rv "/tmp/WanezGD_Tools_release/Grim Dawn/settings/text_en/" "$GRIM_DAWN_INSTALLATION_FOLDER/settings"

echo -e "${GREEN}All done.${NC}"
