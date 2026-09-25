#!/usr/bin/env sh
set -eu
gleam format --check src test
gleam build --warnings-as-errors
gleam build --target javascript --warnings-as-errors
