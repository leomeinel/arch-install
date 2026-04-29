#!/usr/bin/env bash

# Set TMOUT of 1d
export TMOUT=86400

# Set umask
umask 027

# Disable coredumps
ulimit -c 0
