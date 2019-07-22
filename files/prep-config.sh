#!/bin/sh

sed -i \
	-e "s#@POD_SUBNET@#$3#" \
	-e "s/@CLUSTER_NAME@/$4/" \
	-e "s#@SERVICE_SUBNET@#$2#" \
	-e "s/@EXTERNAL_DNS@/$5/" \
	-e "s/@ROUTE53_ID@/$6/" \
	$1/*
