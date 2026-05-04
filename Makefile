SHELL := /bin/bash

SERVICE := app
COMPOSE := docker compose

.PHONY: up down logs shell test format credo check

up:
	$(COMPOSE) up $(SERVICE)

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f $(SERVICE)

shell:
	$(COMPOSE) run --rm $(SERVICE) bash

test:
	$(COMPOSE) run --rm $(SERVICE) mix test

format:
	$(COMPOSE) run --rm $(SERVICE) mix format --check-formatted

credo:
	$(COMPOSE) run --rm $(SERVICE) mix credo --strict

check: format credo test
