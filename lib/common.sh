#!/bin/bash

# -----------------------------------------
# load environment variables

if [ -z "${buildpack}" ]; then
    buildpack=$(cd "$(dirname $0)/.." && pwd)
fi

steptxt="----->"
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color
CURL="curl -s -L --retry 15 --retry-delay 2" # retry for up to 30 seconds

TOOL=""
# Default to $SOURCE_VERSION environment variable: https://devcenter.heroku.com/articles/buildpack-api#bin-compile
GO_LINKER_VALUE=${SOURCE_VERSION}


warn() {
    echo -e "${YELLOW} !!    $@${NC}"
}

err() {
    echo -e >&2 "${RED} !!    $@${NC}"
}

step() {
    echo "$steptxt $@"
}

start() {
    echo -n "$steptxt $@... "
}

finished() {
    echo "done"
}

# TODO: SHA CHECK
SHAValid() {
    # local fileName="${1}"
    # local targetFile="${2}"
    # local sh=""
    # local sw="$(<"${FilesJSON}" jq -r '."'${fileName}'".SHA')"
    # if [ ${#sw} -eq 40 ]; then
    #     sh="$(shasum "${targetFile}" | cut -d \  -f 1)"
    # else
    #     sh="$(shasum -a256 "${targetFile}" | cut -d \  -f 1)"
    # fi
    # [ "${sh}" = "${sw}" ]
    return 1
}

addToPATH() {
    local targetDir="${1}"
    if echo "${PATH}" | grep -v "${targetDir}" &> /dev/null; then
        PATH="${targetDir}:${PATH}"
    fi
}

ensureInPath() {
    local fileName="${1}"
    local targetDir="${2}"
    local xCmd="${3:-chmod a+x}"
    local targetFile="${targetDir}/${fileName}"
    addToPATH "${targetDir}"
    ensureFile "${fileName}" "${targetDir}" "${xCmd}"
}

loadEnvDir() {
    local envFlags=()
    envFlags+=("CGO_CFLAGS")
    envFlags+=("CGO_CPPFLAGS")
    envFlags+=("CGO_CXXFLAGS")
    envFlags+=("CGO_LDFLAGS")
    envFlags+=("GO_LINKER_SYMBOL")
    envFlags+=("GO_LINKER_VALUE")
    envFlags+=("GO15VENDOREXPERIMENT")
    envFlags+=("GOVERSION")
    envFlags+=("GO_INSTALL_PACKAGE_SPEC")
    envFlags+=("GO_INSTALL_PACKAGE_SPEC_CMD_FLAGS")
    envFlags+=("GO_INSTALL_PACKAGE_MAIN")
    envFlags+=("GO_INSTALL_TOOLS_IN_IMAGE")
    envFlags+=("GO_SETUP_GOPATH_IN_IMAGE")
    envFlags+=("GO_TEST_SKIP_BENCHMARK")
    local env_dir="${1}"
    if [ ! -z "${env_dir}" ]; then
        mkdir -p "${env_dir}"
        env_dir=$(cd "${env_dir}/" && pwd)
        for key in ${envFlags[@]}; do
            if [ -f "${env_dir}/${key}" ]; then
                export "${key}=$(cat "${env_dir}/${key}" | sed -e "s:\${build_dir}:${build}:")"
            fi
        done
    fi
}

setGoVersionFromEnvironment() {
    if [ -z "${GOVERSION}" ]; then
        warn ""
        warn "'GOVERSION' isn't set, defaulting to '${DefaultGoVersion}'"
        warn ""
        warn "Run 'heroku config:set GOVERSION=goX.Y' to set the Go version to use"
        warn "for future builds"
        warn ""
    fi
    ver=${GOVERSION:-$DefaultGoVersion}
}
