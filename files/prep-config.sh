#!/bin/sh

sed -i \
	-e "s#@POD_SUBNET@#$3#" \
	-e "s#@SERVICE_SUBNET@#$2#" \
	$1/*
