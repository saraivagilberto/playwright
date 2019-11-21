#!/bin/bash
set -e
set +x

if [[ ("$1" == "-h") || ("$1" == "--help") ]]; then
  echo "usage: $(basename $0) [output-absolute-path]"
  echo
  echo "Generate distributable .zip archive from ./checkout folder that was previously built."
  echo
  exit 0
fi

if [[ $# != 1 ]]; then
  echo "error: missing zip output path"
  echo "try '$(basename $0) --help' for details"
  exit 1
fi

ZIP_PATH=$1
if [[ $ZIP_PATH != /* ]]; then
  echo "ERROR: path $ZIP_PATH is not absolute"
  exit 1
fi
if [[ $ZIP_PATH != *.zip ]]; then
  echo "ERROR: path $ZIP_PATH must have .zip extension"
  exit 1
fi
if [[ -f $ZIP_PATH ]]; then
  echo "ERROR: path $ZIP_PATH exists; can't do anything."
  exit 1
fi
if ! [[ -d $(dirname $ZIP_PATH) ]]; then
  echo "ERROR: folder for path $($ZIP_PATH) does not exist."
  exit 1
fi

main() {
  cd checkout

  set -x
  if [[ "$(uname)" == "Darwin" ]]; then
    createZipForMac
  elif [[ "$(uname)" == "Linux" ]]; then
    createZipForLinux
  else
    echo "ERROR: cannot upload on this platform!" 1>&2
    exit 1;
  fi
}

createZipForLinux() {
  # create a TMP directory to copy all necessary files
  local tmpdir=$(mktemp -d -t webkit-deploy-XXXXXXXXXX)
  mkdir -p $tmpdir

  # copy all relevant binaries
  cp -t $tmpdir ./WebKitBuild/Release/bin/MiniBrowser ./WebKitBuild/Release/bin/WebKit*Process
  # copy runner
  cp -t $tmpdir ../pw_run.sh
  # copy protocol
  node ../concat_protocol.js > $tmpdir/protocol.json
  # copy all relevant shared objects
  LD_LIBRARY_PATH="$PWD/WebKitBuild/DependenciesGTK/Root/lib" ldd WebKitBuild/Release/bin/MiniBrowser | grep -o '[^ ]*WebKitBuild/[^ ]*' | xargs cp -t $tmpdir

  # we failed to nicely build libgdk_pixbuf - expect it in the env
  rm $tmpdir/libgdk_pixbuf*

  # tar resulting directory and cleanup TMP.
  zip -jr $ZIP_PATH $tmpdir
  rm -rf $tmpdir
}

createZipForMac() {
  # create a TMP directory to copy all necessary files
  local tmpdir=$(mktemp -d)

  # copy all relevant files
  ditto {./WebKitBuild/Release,$tmpdir}/com.apple.WebKit.Networking.xpc
  ditto {./WebKitBuild/Release,$tmpdir}/com.apple.WebKit.Plugin.64.xpc
  ditto {./WebKitBuild/Release,$tmpdir}/com.apple.WebKit.WebContent.xpc
  ditto {./WebKitBuild/Release,$tmpdir}/JavaScriptCore.framework
  ditto {./WebKitBuild/Release,$tmpdir}/libwebrtc.dylib
  ditto {./WebKitBuild/Release,$tmpdir}/MiniBrowser.app
  ditto {./WebKitBuild/Release,$tmpdir}/PluginProcessShim.dylib
  ditto {./WebKitBuild/Release,$tmpdir}/SecItemShim.dylib
  ditto {./WebKitBuild/Release,$tmpdir}/WebCore.framework
  ditto {./WebKitBuild/Release,$tmpdir}/WebInspectorUI.framework
  ditto {./WebKitBuild/Release,$tmpdir}/WebKit.framework
  ditto {./WebKitBuild/Release,$tmpdir}/WebKitLegacy.framework
  ditto {..,$tmpdir}/pw_run.sh
  # copy protocol
  node ../concat_protocol.js > $tmpdir/protocol.json

  # zip resulting directory and cleanup TMP.
  ditto -c -k $tmpdir $ZIP_PATH
  rm -rf $tmpdir
}

trap "cd $(pwd -P)" EXIT
cd "$(dirname "$0")"

main "$@"
