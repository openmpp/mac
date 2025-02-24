## Build of openM++ release for MacOS 

Requirements:
  Xcode command line tools: c++, make, git
  Bison version 2.7, for example from Homebrew: brew install bison@2.7
  Go fresh version, for example: https://dl.google.com/go/go1.14.3.darwin-amd64.pkg
  Node.js fresh version, for example: https://nodejs.org/dist/v12.17.0/node-v12.17.0.pkg
  R fresh 3+ version (v4+ not tested yet), for example: https://cran.r-project.org/bin/macosx/R-3.6.3.nn.pkg

To build openM++ release for MacOS:

  git clone https://github.com/openmpp/mac ompp-mac
  mkdir my-build
  cd my-build
  ../ompp-mac/build/build-mac

Environment variables:
  OMPP_BUILD_TAG=v1.2.3          # default: build from latest git
  OM_BUILD_CONFIGS=RELEASE,DEBUG # default: RELEASE,DEBUG for libraries and RELEASE for models
  OM_DATE_STAMP=20220817         # default: current date as YYYYMMDD
  MODEL_DIRS=modelOne,NewCaseBased,NewTimeBased,NewCaseBased_bilingual,IDMM,RiskPaths,OzProjGenX,OzProjX,SM1

Additional environment variable for build-open and build-model:
  OMPP_CPP_BUILD_TAG=test_branch # default: build from latest git

If both OMPP_BUILD_TAG and OMPP_CPP_BUILD_TAG specified then OMPP_CPP_BUILD_TAG take precedence

Examples:
  MODEL_DIRS=RiskPaths,IDMM ./build-mac  # include only RiskPaths,IDMM models
  OM_DATE_STAMP=20220817    ./build-mac  # archive name openmpp_mac_x86_64_20220817.tar.gz
  OM_BUILD_CONFIGS=RELEASE  ./build-mac  # include only RELEASE executables and libs

To build openM++ libraries and omc compiler do:

  ./build-openm
  
  Environment variables to control "build-openm": OM_BUILD_CONFIGS

To build models do:

  ./build-models
  
  Environment variables to control "build-models": OM_BUILD_CONFIGS, MODEL_DIRS

To build openM++ tools do any of:

  GOPATH=$PWD/ompp/ompp-go ./build-go # Go oms web-service and dbcopy utility
  ./build-r  # openMpp R package
  ./build-ui # openM++ UI
  
To create openmpp_mac_YYYYMMDD.tar.gz archive:

  ./build-mac-tar-gz
  
  Environment variables to control "build-mac-tar-gz": MODEL_DIRS, OM_DATE_STAMP

To sign executables and notarize archive:

  export DEV_APP_USER_ID=ABCDEFGHIJ
  export DEV_APP_EMAIL=my-email@some-where.mail
  export DEV_APP_KEYCHAIN=altool-app-pwd-key

  export BUNDLE_VERSION=0.0.1
  export DEPLOY_DIR=openmpp_mac_x86_64_20210629
  export MODEL_COPY_NAMES=modelOne,NewCaseBased,NewTimeBased,NewCaseBased_bilingual,IDMM,RiskPaths

  ./certify-bundle.sh
