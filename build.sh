#!/bin/bash

set_plist_string() {
  local plist_path="$1"
  local key="$2"
  local value="$3"

  /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_path" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist_path"
}

add_bhtwitter_url_scheme() {
  local plist_path="$1"

  python3 - "$plist_path" <<'PY'
import plistlib
import sys

plist_path = sys.argv[1]

with open(plist_path, "rb") as plist_file:
    raw_plist = plist_file.read()

plist_format = plistlib.FMT_BINARY if raw_plist.startswith(b"bplist") else plistlib.FMT_XML
plist = plistlib.loads(raw_plist)
url_types = plist.setdefault("CFBundleURLTypes", [])

scheme_exists = any(
    "bhtwitter" in url_type.get("CFBundleURLSchemes", [])
    for url_type in url_types
)

if not scheme_exists:
    url_types.append({
        "CFBundleURLName": "com.bhtwitter.open-in-x",
        "CFBundleURLSchemes": ["bhtwitter"],
    })

with open(plist_path, "wb") as plist_file:
    plistlib.dump(plist, plist_file, fmt=plist_format, sort_keys=False)
PY
}

patch_ipa_privacy_strings() {
  local input_ipa="$1"
  local output_ipa="$2"

  if [ ! -f "$input_ipa" ]; then
    echo -e "\033[1m\033[31mInput IPA not found: $input_ipa\033[0m"
    return 1
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  local output_dir
  output_dir="$(cd "$(dirname "$output_ipa")" && pwd)"

  local output_name
  output_name="$(basename "$output_ipa")"

  local output_abs="$output_dir/$output_name"

  rm -f "$output_abs"

  unzip -q "$input_ipa" -d "$tmp_dir"

  local app_dir
  app_dir="$(find "$tmp_dir/Payload" -maxdepth 1 -type d -name "*.app" | head -n 1)"

  if [ -z "$app_dir" ]; then
    echo -e '\033[1m\033[31mCould not find Payload/*.app inside IPA.\033[0m'
    rm -rf "$tmp_dir"
    return 1
  fi

  local info_plist="$app_dir/Info.plist"

  if [ ! -f "$info_plist" ]; then
    echo -e "\033[1m\033[31mInfo.plist not found at: $info_plist\033[0m"
    rm -rf "$tmp_dir"
    return 1
  fi

  echo -e '\033[1m\033[32mPatching Info.plist privacy usage descriptions.\033[0m'

  set_plist_string "$info_plist" "NSCameraUsageDescription" "Twitter needs camera access to take photos and videos."
  set_plist_string "$info_plist" "NSMicrophoneUsageDescription" "Twitter needs microphone access to record videos."
  set_plist_string "$info_plist" "NSPhotoLibraryUsageDescription" "Twitter needs photo library access to select media."
  set_plist_string "$info_plist" "NSPhotoLibraryAddUsageDescription" "Twitter needs photo library access to save media."

  add_bhtwitter_url_scheme "$info_plist"

  if [ $? -ne 0 ]; then
    echo -e '\033[1m\033[31mFailed to add the bhtwitter URL scheme.\033[0m'
    rm -rf "$tmp_dir"
    return 1
  fi

  (
    cd "$tmp_dir" || exit 1
    zip -qry "$output_abs" Payload
  )

  local zip_status=$?
  rm -rf "$tmp_dir"

  if [ $zip_status -ne 0 ]; then
    echo -e '\033[1m\033[31mFailed to rebuild patched IPA.\033[0m'
    return 1
  fi

  echo -e "\033[1m\033[32mPatched IPA created: $output_abs\033[0m"
  return 0
}

BUILD_MODE="${1:-rootfull}"

case "$BUILD_MODE" in
  --sideloaded|sideloaded)
    echo -e '\033[1m\033[32mBuilding BHTwitter project for sideloaded.\033[0m'

    make clean
    rm -rf .theos
    make SIDELOADED=1 OPEN_IN_X=1

    if [ $? -eq 0 ]; then
      echo -e '\033[1m\033[32mMake command succeeded.\033[0m'
    else
      echo -e '\033[1m\033[31mMake command failed.\033[0m'
      exit 1
    fi

    if [ -e ./packages/com.atebits.Tweetie2.ipa ]; then
      echo -e '\033[1m\033[32mPatching source IPA before injection.\033[0m'

      patch_ipa_privacy_strings \
        "packages/com.atebits.Tweetie2.ipa" \
        "packages/com.atebits.Tweetie2.privacy.ipa"

      if [ $? -ne 0 ]; then
        exit 1
      fi

      echo -e '\033[1m\033[32mBuilding the IPA.\033[0m'

      cyan \
        -i packages/com.atebits.Tweetie2.privacy.ipa \
        -o packages/BHTwitter-sideloaded \
        --ignore-encrypted \
        --remove-extensions \
        -u \
        -w \
        -f \
        .theos/obj/debug/keychainfix.dylib \
        .theos/obj/debug/BHTwitter.dylib \
        layout/Library/Application\ Support/BHT/BHTwitter.bundle \
        .theos/obj/debug/OpenInX.appex

      if [ $? -ne 0 ]; then
        echo -e '\033[1m\033[31mFailed to build the sideloaded IPA.\033[0m'
        exit 1
      fi

      echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
    else
      echo -e '\033[1m\033[0;31mpackages/com.atebits.Tweetie2.ipa not found.\033[0m'
      exit 1
    fi
    ;;

  --rootless|rootless)
    echo -e '\033[1m\033[32mBuilding BHTwitter project for Rootless.\033[0m'

    make clean
    rm -rf .theos
    export THEOS_PACKAGE_SCHEME=rootless
    make package

    if [ $? -eq 0 ]; then
      echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
    else
      echo -e '\033[1m\033[31mMake command failed.\033[0m'
      exit 1
    fi
    ;;

  --trollstore|trollstore)
    echo -e '\033[1m\033[32mBuilding BHTwitter project for TrollStore.\033[0m'

    make clean
    rm -rf .theos
    make OPEN_IN_X=1

    if [ $? -eq 0 ]; then
      echo -e '\033[1m\033[32mMake command succeeded.\033[0m'
    else
      echo -e '\033[1m\033[31mMake command failed.\033[0m'
      exit 1
    fi

    if [ -e ./packages/com.atebits.Tweetie2.ipa ]; then
      echo -e '\033[1m\033[32mPatching source IPA before injection.\033[0m'

      patch_ipa_privacy_strings \
        "packages/com.atebits.Tweetie2.ipa" \
        "packages/com.atebits.Tweetie2.privacy.ipa"

      if [ $? -ne 0 ]; then
        exit 1
      fi

      echo -e '\033[1m\033[32mBuilding the IPA.\033[0m'

      cyan \
        -i packages/com.atebits.Tweetie2.privacy.ipa \
        -o packages/BHTwitter-trollstore.tipa \
        --ignore-encrypted \
        --remove-extensions \
        -u \
        -w \
        -f \
        .theos/obj/debug/BHTwitter.dylib \
        layout/Library/Application\ Support/BHT/BHTwitter.bundle \
        .theos/obj/debug/OpenInX.appex

      if [ $? -ne 0 ]; then
        echo -e '\033[1m\033[31mFailed to build the TrollStore IPA.\033[0m'
        exit 1
      fi

      echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
    else
      echo -e '\033[1m\033[0;31mpackages/com.atebits.Tweetie2.ipa not found.\033[0m'
      exit 1
    fi
    ;;

  --rootfull|rootfull|"")
    echo -e '\033[1m\033[32mBuilding BHTwitter project for Rootfull.\033[0m'

    make clean
    rm -rf .theos
    unset THEOS_PACKAGE_SCHEME
    make package

    if [ $? -eq 0 ]; then
      echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
    else
      echo -e '\033[1m\033[31mMake command failed.\033[0m'
      exit 1
    fi
    ;;

  *)
    echo -e "\033[1m\033[31mUnknown build option: $BUILD_MODE\033[0m"
    echo "Usage: ./build.sh [--rootfull|--rootless|--sideloaded|--trollstore]"
    exit 1
    ;;
esac
