#!/bin/bash

LONG=sideloaded,rootless,trollstore
OPTS=$(getopt -a --longoptions "$LONG" -- "$@")

if [ $? -ne 0 ]; then
  echo -e '\033[1m\033[31mInvalid build option.\033[0m'
  exit 1
fi

eval set -- "$OPTS"

set_plist_string() {
  local plist_path="$1"
  local key="$2"
  local value="$3"

  /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_path" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist_path"
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

while :; do
  case "$1" in
    --sideloaded)
      echo -e '\033[1m\033[32mBuilding BHTwitter project for sideloaded.\033[0m'

      make clean
      rm -rf .theos
      make SIDELOADED=1

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

        cyan -i packages/com.atebits.Tweetie2.privacy.ipa -o packages/BHTwitter-sideloaded --ignore-encrypted \
          -uwf .theos/obj/debug/keychainfix.dylib .theos/obj/debug/BHTwitter.dylib layout/Library/Application\ Support/BHT/BHTwitter.bundle

        echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
      else
        echo -e '\033[1m\033[0;31mpackages/com.atebits.Tweetie2.ipa not found.\033[0m'
      fi

      break
      ;;

    --rootless)
      echo -e '\033[1m\033[32mBuilding BHTwitter project for Rootless.\033[0m'

      make clean
      rm -rf .theos
      export THEOS_PACKAGE_SCHEME=rootless
      make package

      echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
      break
      ;;

    --trollstore)
      echo -e '\033[1m\033[32mBuilding BHTwitter project for TrollStore.\033[0m'

      make clean
      rm -rf .theos
      make

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

        cyan -i packages/com.atebits.Tweetie2.privacy.ipa -o packages/BHTwitter-trollstore.tipa --ignore-encrypted \
          -uwf .theos/obj/debug/BHTwitter.dylib layout/Library/Application\ Support/BHT/BHTwitter.bundle

        echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
      else
        echo -e '\033[1m\033[0;31mpackages/com.atebits.Tweetie2.ipa not found.\033[0m'
      fi

      break
      ;;

    --)
      shift

      echo -e '\033[1m\033[32mBuilding BHTwitter project for Rootfull.\033[0m'

      make clean
      rm -rf .theos
      unset THEOS_PACKAGE_SCHEME
      make package

      echo -e '\033[1m\033[32mDone, thanks for using BHTwitter.\033[0m'
      break
      ;;

    *)
      echo -e '\033[1m\033[31mUnknown option.\033[0m'
      exit 1
      ;;
  esac
done
