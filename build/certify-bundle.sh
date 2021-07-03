#!/usr/bin/env bash
#
# copy executables from ompp/bin and ompp/models/bin into bundle directory
# codesign executables, make zip archive and submit for Apple notarization
# wait for Apple response, on success do:
# copy certified executables from bundle directory into deploy directory
# create .tar.gz archive from existing deploy directory: openmpp_mac_ARCH_YYYYMMDD
#
# export DEPLOY_DIR=openmpp_mac_x86_64_20210629
# export BUNDLE_VERSION=0.0.1
# export DEV_APP_USER_ID=ABCDEFGHIJ
# export DEV_APP_EMAIL=my-email@some-where.mail
# export DEV_APP_KEYCHAIN=altool-app-pwd-key
#

if [ -z "$DEPLOY_DIR" ]; then
  echo ERROR: undefined DEPLOY_DIR: $DEPLOY_DIR
  exit 1
fi
if [ ! -d $DEPLOY_DIR ]; then
  echo ERROR: missing deploy directory: $DEPLOY_DIR
  exit 1
fi
if [ -z "$BUNDLE_VERSION" ]; then
  echo ERROR: undefined BUNDLE_VERSION
  exit 1
fi
if [ -z "$DEV_APP_USER_ID" ]; then
  echo ERROR: undefined DEV_APP_USER_ID
  exit 1
fi
if [ -z "$DEV_APP_EMAIL" ]; then
  echo ERROR: undefined DEV_APP_EMAIL
  exit 1
fi
if [ -z "$DEV_APP_KEYCHAIN" ]; then
  echo ERROR: undefined DEV_APP_KEYCHAIN
  exit 1
fi

BUNDLE_DIR=bundle-$BUNDLE_VERSION

echo " DEPLOY_DIR       = $DEPLOY_DIR"
echo " BUNDLE_DIR       = $BUNDLE_DIR"
echo " BUNDLE_VERSION   = $BUNDLE_VERSION"
echo " DEV_APP_USER_ID  = $DEV_APP_USER_ID"
echo " DEV_APP_EMAIL    = $DEV_APP_EMAIL"
echo " DEV_APP_KEYCHAIN = $DEV_APP_KEYCHAIN"

# execute command and exit on errors
#
do_cmd()
{
  echo $@
  
  if ! $@ ;
  then
    echo FAILED.
    exit 1
  fi
}

# copy into bundle directory

do_cmd rm -rf $BUNDLE_DIR
do_cmd mkdir  $BUNDLE_DIR

do_cmd cp -pv ompp/bin/omc    $BUNDLE_DIR/
do_cmd cp -pv ompp/bin/oms    $BUNDLE_DIR/
do_cmd cp -pv ompp/bin/dbcopy $BUNDLE_DIR/

do_cmd find ompp/models/bin -type f -perm +u+x -exec cp -pv {} $BUNDLE_DIR/ \;

# sign executables and create zip archive

pushd $BUNDLE_DIR

do_cmd codesign --options runtime -s ${DEV_APP_USER_ID} *

do_cmd zip img.zip *

popd

# submit to Apple

echo xcrun altool \
  --notarize-app \
  --primary-bundle-id "org.openmpp.img-${BUNDLE_VERSION}" \
  -u "${DEV_APP_EMAIL}" \
  -p "@keychain:${DEV_APP_KEYCHAIN}" \
  -f ${BUNDLE_DIR}/img.zip

if ! xcrun altool \
  --notarize-app \
  --primary-bundle-id "org.openmpp.img-${BUNDLE_VERSION}" \
  -u "${DEV_APP_EMAIL}" \
  -p "@keychain:${DEV_APP_KEYCHAIN}" \
  -f ${BUNDLE_DIR}/img.zip > altool.submit.txt 2>&1;
then
  echo FAILED.
  cat altool.submit.txt
  exit 1
fi

# wait for Apple response

rq_uuid=`cat altool.submit.txt | grep -Eo '\w{8}-(\w{4}-){3}\w{12}$'`

echo request UIUID: $rq_uuid
if [ -z "$rq_uuid" ]; then
  echo " FAILED."
  exit 1
fi

while true; do
  echo -n "."
  sleep 20
 
  if ! xcrun altool --notarization-info "$rq_uuid" -u "${DEV_APP_EMAIL}" -p "@keychain:${DEV_APP_KEYCHAIN}" > altool.wait.txt 2>&1;
  then
    echo FAILED xcrun altool --notarization-info "$rq_uuid" -u "${DEV_APP_EMAIL}" -p "@keychain:${DEV_APP_KEYCHAIN}"
    echo "$w_txt"
    exit 1
  fi

  w_txt=`cat altool.wait.txt`
  ok_rsp=`echo "$w_txt" | grep "success"`
  not_rsp=`echo "$w_txt" | grep "invalid"`
  if [ -n "$ok_rsp" ]; then
    echo " OK."
    echo "$w_txt"
    echo " OK."
    break
  fi
  if [ -n "$not_rsp" ]; then
    echo " FAILED."
    echo "$w_txt"
    exit 1
  fi

done

# copy certified executables into deploy directory

do_cmd cp -pv $BUNDLE_DIR/omc    $DEPLOY_DIR/bin/
do_cmd cp -pv $BUNDLE_DIR/oms    $DEPLOY_DIR/bin/
do_cmd cp -pv $BUNDLE_DIR/dbcopy $DEPLOY_DIR/bin/

do_cmd cp -pv $BUNDLE_DIR/* $DEPLOY_DIR/models/bin/

do_cmd rm -v $DEPLOY_DIR/models/bin/omc
do_cmd rm -v $DEPLOY_DIR/models/bin/oms
do_cmd rm -v $DEPLOY_DIR/models/bin/dbcopy
do_cmd rm -v $DEPLOY_DIR/models/bin/img.zip

# MacOS: cleanup

do_cmd xattr -rc "$DEPLOY_DIR"

do_cmd find $DEPLOY_DIR -name ".DS_Store" -delete
do_cmd find $DEPLOY_DIR -name "*.ipa" -delete
do_cmd find $DEPLOY_DIR -name ".dSYM.zip" -delete
do_cmd find $DEPLOY_DIR -name ".dSYM" -delete
do_cmd find $DEPLOY_DIR -name ".AppleDouble" -delete
do_cmd find $DEPLOY_DIR -name ".LSOverride" -delete
do_cmd find $DEPLOY_DIR -name "._*" -delete

# re-create tar.gz archive from deployment directory

do_cmd rm -v   ${DEPLOY_DIR}.tar.gz
do_cmd tar czf ${DEPLOY_DIR}.tar.gz ${DEPLOY_DIR}

echo `date` Done.
