#!/usr/bin/env bash
#
# copy executables from ompp/bin and ompp/models/bin into bundle directory
# codesign executables, make zip archive and submit for Apple notarization
# wait for Apple response, on success do:
# copy certified executables from bundle directory into deploy directory
# create .tar.gz archive from existing deploy directory: openmpp_mac_ARCH_YYYYMMDD
#
# export BUNDLE_VERSION=0.0.1
# export DEPLOY_DIR=openmpp_mac_x86_64_20210629
# export DEV_APP_USER_ID=ABCDEFGHIJ
# export MODEL_COPY_NAMES=modelOne,NewCaseBased,NewTimeBased,NewCaseBased_bilingual,IDMM,RiskPaths
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

[ -n "$MODEL_COPY_NAMES" ] && \
  OM_COPY_MDLS=${MODEL_COPY_NAMES//,/ } || \
  OM_COPY_MDLS="modelOne NewCaseBased NewTimeBased NewCaseBased_bilingual IDMM RiskPaths"

BUNDLE_DIR=bundle-$BUNDLE_VERSION

echo " DEPLOY_DIR       = $DEPLOY_DIR"
echo " BUNDLE_DIR       = $BUNDLE_DIR"
echo " BUNDLE_VERSION   = $BUNDLE_VERSION"
echo " DEV_APP_USER_ID  = $DEV_APP_USER_ID"
echo " MODEL_COPY_NAMES = $OM_COPY_MDLS"

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
do_cmd cp -pv ompp/bin/dbget  $BUNDLE_DIR/

do_cmd find ompp/models/bin -type f -perm +u+x -exec cp -pv {} $BUNDLE_DIR/ \;

# sign executables and create zip archive

pushd $BUNDLE_DIR

do_cmd codesign --options runtime -s ${DEV_APP_USER_ID} *

do_cmd zip img.zip *

popd

# submit to Apple

echo xcrun notarytool submit ${BUNDLE_DIR}/img.zip --keychain-profile "notary-tool" --wait

if ! xcrun notarytool submit ${BUNDLE_DIR}/img.zip --keychain-profile "notary-tool" --wait > notarytool.submit.txt 2>&1;
then
  echo FAILED.
  cat notarytool.submit.txt
  exit 1
fi

# analyze response:
#
# Processing complete
#   id: 5940c789-fa3b-45e7-8527-f1fc0119c390
#   status: Accepted

echo "sed -n '/Processing complete/{n;p;n;p;}' notarytool.submit.txt | grep 'status: Accepted'"

if ! sed -n '/Processing complete/{n;p;n;p;}' notarytool.submit.txt | grep 'status: Accepted' 2>&1 ;
then
  echo FAILED.
  cat notarytool.submit.txt
  exit 1
fi

# copy certified executables into deploy directory

do_cmd cp -pv $BUNDLE_DIR/omc    $DEPLOY_DIR/bin/
do_cmd cp -pv $BUNDLE_DIR/oms    $DEPLOY_DIR/bin/
do_cmd cp -pv $BUNDLE_DIR/dbcopy $DEPLOY_DIR/bin/
do_cmd cp -pv $BUNDLE_DIR/dbget  $DEPLOY_DIR/bin/

for M in $OM_COPY_MDLS; do

  do_cmd cp -pv $BUNDLE_DIR/$M $DEPLOY_DIR/models/bin/

done

# copy OzProjX models

do_cmd cp -pv $BUNDLE_DIR/OzProjX    $DEPLOY_DIR/models/bin/OzProjX/ompp/bin/
do_cmd cp -pv $BUNDLE_DIR/OzProjGenX $DEPLOY_DIR/models/bin/OzProjGenX/ompp/bin/

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
