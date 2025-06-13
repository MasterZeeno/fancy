#!/bin/bash

function gradient() {
    local color_from="$1"
    local color_to="$2"
    local text="$3"
    local length=${#text}

    local colors
    colors=$(fancy gradient -n "$length" "$color_from" "$color_to" -sLCh)

    local i=0
    for color in $colors; do
        fancy paint -n "$color" "${text:$i:1}"
        i=$((i+1))
    done
    printf "\n"
}


gradient yellow crimson 'look at these colors!'
gradient lightseagreen lightgreen 'look at these colors!'
