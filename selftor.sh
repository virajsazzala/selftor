#!/bin/bash
#
# Script Name : selftor.sh
# Description : A script to torrent anime.
# Author      : Viraj Reddy SNG (exvynai)
# Created On  : 2025-10-13
# Version     : 0.1
# License     : MIT
#

set -euo pipefail

ANIME_NAME=""
SAVE_DIR=""
RESOLUTION="1080p"

BASE_LINK="https://subsplease.org/shows"
ANIME_LINK="${BASE_LINK}/${ANIME_NAME}/"

CUR_DIR=$(pwd)
PAGE_CONTENT=""
EPISODE_LINKS=""

help() {
    echo
    echo "Usage: $0 -a <anime_name> [-d </path/to/save/>]"
    echo "Options:"
    echo "  -a (REQUIRED) : Name of the Anime"
    echo "  -d (OPTIONAL) : path to store files (default: pwd) (DEV)"
    exit 1
}

info() {                                                                                        
    printf "\033[1;35minfo:\033[0m %s\n" "$1"                                                   
}

err () {
    printf "\33[2K\r\033[1;31m%s\033[0m\n" "$@" "exiting..." >&2
    exit 1
}

parse_inputs() {
    while getopts "a:d:" opt
    do
        case "$opt" in
            a ) ANIME_NAME="$OPTARG" ;;
            d ) SAVE_DIR="$OPTARG" ;;
            ? ) help ;;
        esac
    done

    [ -z "$ANIME_NAME" ] && help

    # validate save directory
    [[ "$SAVE_DIR" == ~* ]] && SAVE_DIR="${SAVE_DIR/#\~/$HOME}"

    if [ -n "$SAVE_DIR" ] && [ ! -d "$SAVE_DIR" ] 
    then
        err "cannot find directory '${SAVE_DIR}'"
    fi

    # create default save
    if [ -z "$SAVE_DIR" ]
    then
        SAVE_DIR="$(pwd)/${ANIME_NAME}"
        mkdir -p "$SAVE_DIR";
        info "created directory $SAVE_DIR";
    fi

    SAVE_DIR=$(realpath "$SAVE_DIR")

    export ANIME_NAME SAVE_DIR
}

fetch_page() {
    # 1 - anime link
    PAGE_CONTENT=$(chromium --headless --disable-gpu --virtual-time-budget=5000 --dump-dom "$ANIME_LINK" 2>&1)

}

fetch_links() {
    # 1 - page content, 2 - resolution
    EPISODE_LINKS=$(echo "$1" | pup '.show-release-item' | pup 'a[href^="magnet:"] attr{href}' | grep "$2")
}

add_torrent() {
    # 1 - magnet link, 2 - save dir path
    RES=$(deluge-console add --path "$2" "$1" 2>&1)
    
    if [[ "$RES" == *"Torrent added!"* ]]
    then
        info "a new torrent has been added..."
    fi
}


run() {
    parse_inputs "$@"

    info "Anime: '${ANIME_NAME}'"
    info "Save dir: '${SAVE_DIR}'"

    fetch_page "$ANIME_LINK"
    fetch_links "$PAGE_CONTENT" "$RESOLUTION"

    # in reverse order, due to magnet link order 
    tac <<< "$EPISODE_LINKS" | while IFS= read -r link
    do
        add_torrent "$(echo "$link" | hxunent)" "$SAVE_DIR"
    done

    info "All episodes added."
}

run "$@"
