

# sdk
NUM=21
if [ "$API" -lt $NUM ]; then
  ui_print "! Unsupported SDK $API."
  ui_print "  You have to upgrade your Android version"
  ui_print "  at least SDK API $NUM to use this module."
  abort
else
  ui_print "- SDK $API"
fi

# sepolicy.rule
if [ "$BOOTMODE" != true ]; then
  mount -o rw -t auto /dev/block/bootdevice/by-name/persist /persist
  mount -o rw -t auto /dev/block/bootdevice/by-name/metadata /metadata
fi

# magisk
MAGISKTMP="$(magisk --path)"
[ -z "$MAGISKTMP" ] && MAGISKTMP=/sbin
# function
NAME=_ZN7android23sp_report_stack_pointerEv
FILE=/system/lib*/libandroid_runtime.so
ui_print "- Checking $NAME function..."
if ! grep -Eq $NAME $FILE; then
  ui_print "  Using legacy libraries"
  cp -rf $MODPATH/system_10/* $MODPATH/system
fi
rm -rf $MODPATH/system_10

# extract
APP=miuisystem
ui_print "- Extracting $APP.apk folder..."
FILE=`find $MODPATH/system -type f -name $APP.apk`
DIR=$MODPATH/system/etc
DES=assets/*
unzip -d $TMPDIR -o $FILE $DES
cp -rf $TMPDIR/$DES $DIR

# cleaning
ui_print "- Cleaning..."
APP="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app` framework-ext-res"
PKG="com.miui.rom
     com.miui.core
     com.miui.system
     com.xiaomi.micloud.sdk"
if [ "$BOOTMODE" == true ]; then
  for PKGS in $PKG; do
    RES=`pm uninstall $PKGS`
  done
fi
for APPS in $APP; do
  rm -f `find /data/dalvik-cache /data/resource-cache -type f -name *$APPS*.apk`
done
rm -f $MODPATH/LICENSE
rm -rf /metadata/magisk/$MODID
rm -rf /mnt/vendor/persist/magisk/$MODID
rm -rf /persist/magisk/$MODID
rm -rf /data/unencrypted/magisk/$MODID
rm -rf /cache/magisk/$MODID
ui_print " "

# power save
PROP=`getprop power.save`
FILE=$MODPATH/system/etc/sysconfig/*
if [ "$PROP" == 1 ]; then
  ui_print "- $MODNAME will not be allowed in power save."
  ui_print "  It may save your battery but decreasing $MODNAME performance."
  for PKGS in $PKG; do
    sed -i "s/<allow-in-power-save package=\"$PKGS\"\/>//g" $FILE
    sed -i "s/<allow-in-power-save package=\"$PKGS\" \/>//g" $FILE
  done
fi

# function
conflict() {
for NAMES in $NAME; do
  DIR=/data/adb/modules_update/$NAMES
  if [ -f $DIR/uninstall.sh ]; then
    sh $DIR/uninstall.sh
  fi
  rm -rf $DIR
  DIR=/data/adb/modules/$NAMES
  rm -f $DIR/update
  touch $DIR/remove
  FILE=/data/adb/modules/$NAMES/uninstall.sh
  if [ -f $FILE ]; then
    sh $FILE
    rm -f $FILE
  fi
done
}

# conflict
NAME=MIUICore
conflict

# function
hide_oat() {
for APPS in $APP; do
  mkdir -p `find $MODPATH/system -type d -name $APPS`/oat
  touch `find $MODPATH/system -type d -name $APPS`/oat/.replace
done
}

# hide
hide_oat

# function
file_check_bin() {
  for NAMES in $NAME; do
    if [ "$BOOTMODE" == true ]; then
      FILE=`find $MAGISKTMP/mirror/*/*bin -mindepth 1 -maxdepth 1 -type f -name $NAMES`
    else
      FILE=`find /*/*bin -mindepth 1 -maxdepth 1 -type f -name $NAMES`
    fi
    if [ "$FILE" ]; then
      rm -f `find $MODPATH/system -type f -name $NAMES`
    fi
  done
}
file_check_system() {
  for NAMES in $NAME; do
    if [ "$BOOTMODE" == true ]; then
      if [ "$IS64BIT" == true ]; then
        FILE=$MAGISKTMP/mirror/system/lib64/$NAMES
      else
        FILE=$MAGISKTMP/mirror/system/lib/$NAMES
      fi
    else
      if [ "$IS64BIT" == true ]; then
        FILE=/system/lib64/$NAMES
      else
        FILE=/system/lib/$NAMES
      fi
    fi
    if [ -f $FILE ]; then
      rm -f `find $MODPATH/system -type f -name $NAMES`
    fi
  done
}
file_check_vendor() {
  for NAMES in $NAME; do
    if [ "$BOOTMODE" == true ]; then
      if [ "$IS64BIT" == true ]; then
        FILE=$MAGISKTMP/mirror/vendor/lib64/$NAMES
      else
        FILE=$MAGISKTMP/mirror/vendor/lib/$NAMES
      fi
    else
      if [ "$IS64BIT" == true ]; then
        FILE=/vendor/lib64/$NAMES
      else
        FILE=/vendor/lib/$NAMES
      fi
    fi
    if [ -f $FILE ]; then
      rm -f `find $MODPATH/system -type f -name $NAMES`
    fi
  done
}
file_check_vendor_grep() {
  for NAMES in $NAME; do
    if [ "$BOOTMODE" == true ]; then
      if [ "$IS64BIT" == true ]; then
        FILE=$MAGISKTMP/mirror/vendor/lib64/$NAMES
      else
        FILE=$MAGISKTMP/mirror/vendor/lib/$NAMES
      fi
    else
      if [ "$IS64BIT" == true ]; then
        FILE=/vendor/lib64/$NAMES
      else
        FILE=/vendor/lib/$NAMES
      fi
    fi
    if [ -f $FILE ]; then
      rm -f `find $MODPATH/system -type f -name $NAMES`
    else
      if ! grep -Eq $NAMES $DES; then
        rm -f `find $MODPATH/system -type f -name $NAMES`
      fi
    fi
  done
}

# check
NAME=`ls $MODPATH/system/bin`
file_check_bin
NAME=`ls $MODPATH/system/lib`
file_check_system
NAME="libarcsoft_beautyshot.so libmpbase.so libc++_shared.so"
if getprop | grep -Eq "miui.camlib\]: \[1"; then
  ui_print "- Using camera libs"
  file_check_vendor
else
  for NAMES in $NAME; do
    rm -f `find $MODPATH/system -type f -name $NAMES`
  done
fi
NAME="librs_adreno_sha1.so libbccQTI.so"
if [ "$BOOTMODE" == true ]; then
  DES=$MAGISKTMP/mirror/vendor/lib*/lib*_adreno.so
else
  DES=/vendor/lib*/lib*_adreno.so
fi
file_check_vendor_grep

# public
if getprop | grep -Eq "miui.public\]: \[1"; then
  ui_print "- Using public.libraries.txt patch"
  sed -i 's/#p//g' $MODPATH/post-fs-data.sh
fi

# permission
ui_print "- Setting permission..."
DIR=$MODPATH/system/*bin
chmod 0751 $DIR
chmod 0755 $DIR/*
chown -R 0.2000 $DIR
DIR=`find $MODPATH/system/vendor -type d`
for DIRS in $DIR; do
  chown 0.2000 $DIRS
done
if [ "$API" -ge 26 ]; then
  chcon -R u:object_r:system_lib_file:s0 $MODPATH/system/lib*
  chcon -R u:object_r:vendor_file:s0 $MODPATH/system/vendor
  chcon -R u:object_r:vendor_configs_file:s0 $MODPATH/system/vendor/etc
fi





