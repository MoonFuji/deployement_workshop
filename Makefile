.PHONY: help build up down logs restart health test deploy clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the application Docker image
	cd app && docker build -t deploy-demo-app:local .

up: ## Start all services
	docker compose up -d

down: ## Stop all services
	docker compose down

logs: ## View logs for all services
	docker compose logs -f

logs-web: ## View logs for web service only
	docker compose logs -f web

logs-traefik: ## View logs for Traefik only
	docker compose logs -f traefik

restart: ## Restart all services
	docker compose restart

restart-web: ## Restart web service only
	docker compose restart web

health: ## Check application health
	@curl -fsS http://localhost:3000/healthz || echo "Health check failed"

test: ## Run health check
	@echo "Testing health endpoint..."
	@curl -fsS http://localhost:3000/healthz && echo "✓ Health check passed" || echo "✗ Health check failed"

deploy: ## Deploy using deploy.sh (requires IMAGE env var)
	@if [ -z "$(IMAGE)" ]; then \
		echo "Error: IMAGE variable required. Usage: make deploy IMAGE=your-dockerhub-username/deploy-demo-app:tag"; \
		exit 1; \
	fi
	./deploy.sh $(IMAGE)

clean: ## Remove unused Docker resources
	docker system prune -f

clean-all: ## Remove all containers, networks, and images
	docker compose down -v
	docker system prune -af

status: ## Show status of all services
	docker compose ps

