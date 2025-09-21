#!/bin/bash

set -e

VMID=8000 ./debian-13-cloudinit.sh
VIMD=8100 ./ubuntu-noble-cloudinit.sh
