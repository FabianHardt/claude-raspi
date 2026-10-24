.PHONY: deploy build

deploy:
	@test -f deploy/.env.deploy || { echo "deploy/.env.deploy fehlt (siehe deploy/.env.deploy.example)"; exit 1; }
	@scripts/deploy.sh

build:
	docker build --platform linux/arm64 -t claude-raspi:dev .
