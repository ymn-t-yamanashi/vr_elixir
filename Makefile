SHELL := /bin/bash

.PHONY: test format credo check

test:
	cd resonite_link_ex && mix test

format:
	cd resonite_link_ex && mix format --check-formatted

credo:
	cd resonite_link_ex && mix credo --strict

check: format credo test
