#!/usr/bin/make -f
.DEFAULT_GOAL := help
.PHONY: help

COMMAND_COLOR  := \033[0;1;32m
TITLE_COLOR := \033[0;1;33m
NO_COLOR := \033[0m

# Docker compose files
COMPOSE_FILES     := -f docker-compose.yml -f docker-compose.override.yml
# Production build + ECR push (overrides image → ECR URI, platform → linux/amd64)
COMPOSE_PROD      := -f docker-compose.yml -f docker-compose.prod.yml
# Compose files for production image test (no override/xdebug)
COMPOSE_PROD_TEST := -f docker-compose.yml -f docker-compose.prod-test.yml
# Shared network used by web, data_sync, data_calc (external in all compose files)
NETWORK_NAME := realit-network

# ============================================================
# ECR / AWS Configuration
# Override via env or make args:
#   make ecr-push AWS_PROFILE=my-profile
#   make ecr-push TAG=v1.2.3
# ============================================================
AWS_PROFILE   ?= paint-energymonitor
AWS_REGION    ?= ap-northeast-1
PROJECT_NAME  ?= paint-energymonitor
TAG           ?= latest

# Resolve AWS Account ID dynamically (requires valid credentials)
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text --profile $(AWS_PROFILE) 2>/dev/null)
ECR_BASE       := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
ECR_APP_URI    := $(ECR_BASE)/$(PROJECT_NAME)-app
ECR_PUBLIC_URI := $(ECR_BASE)/$(PROJECT_NAME)-public

help: ## List all command name
	@printf "${TITLE_COLOR}Usage:${NO_COLOR}\n";\
	printf "  ${COMMAND_COLOR}make command${NO_COLOR}\n\n";\
	printf "${TITLE_COLOR}Example:${NO_COLOR}\n";\
	printf "  ${COMMAND_COLOR}make help${NO_COLOR}\n\n";\
	printf "${TITLE_COLOR}Available commands:${NO_COLOR}\n";\
	grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' ${MAKEFILE_LIST} \
	| sed -n "s/^\(.*\): \(.*\)##\(.*\)/  $(shell printf "${COMMAND_COLOR}") \1$(shell printf "${NO_COLOR}")@\3/p" \
	| column -t -s'@';

ensure-network: ## Create shared network if not exists (used by web, data_sync, data_calc)
	@docker network inspect $(NETWORK_NAME) >/dev/null 2>&1 || docker network create $(NETWORK_NAME)

on-app-latest: ensure-network ## Start app with latest build (rebuild images)
	uid=`id -u` gid=`id -g` docker-compose $(COMPOSE_FILES) up --build --detach --remove-orphans
	@echo "✅ Containers started with latest build"

on-app: ensure-network ## Start app containers (builds images if they don't exist)
	uid=`id -u` gid=`id -g` docker compose $(COMPOSE_FILES) up --build --detach --remove-orphans
	@branch_or_tag=$$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match 2>/dev/null || echo "unknown");\
	sha_id=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown");\
	echo "$$branch_or_tag - $$sha_id" > VERSION 2>/dev/null || true
	@echo "✅ Containers started"
	@echo "📝 VERSION file updated"

off-app: ## Stop app containers
	uid=`id -u` gid=`id -g` docker-compose $(COMPOSE_FILES) down
	@echo "✅ Containers stopped"

restart-app: ## Restart app containers
	@$(MAKE) off-app
	@$(MAKE) on-app

destroy-app: clean ## Stop containers and remove volumes (⚠️ removes all data)
	uid=`id -u` gid=`id -g` docker-compose $(COMPOSE_FILES) down -v
	@echo "⚠️  All containers and volumes removed"

status: ## Show status of all containers
	@docker-compose $(COMPOSE_FILES) ps

health: ## Check health status of all services
	@echo "🏥 Checking service health..."
	@docker ps --format "table {{.Names}}\t{{.Status}}" --filter "name=realit"

composer-install-test-libraries: ## Composer install on tests directory
	cd tests && composer install

test: on-app ## Run phpunit test app integration with database
	docker exec -t realit_app tests/phpunit --no-coverage --testdox -c tests/phpunit.xml

test-library: on-app ## Run phpunit test library only - testdox
	docker exec -t realit_app tests/phpunit --no-coverage --testdox -c tests/phpunit.lib.xml

test-coverage: on-app ## Measure test coverage
	docker exec -t -e XDEBUG_MODE=coverage realit_app tests/phpunit -d memory_limit=-1 -c tests/phpunit.xml

clean-test-realit: ## Clean test coverage results
	rm -rf tests/coverage

ssh-app: ## SSH into app container
	docker exec -it realit_app sh

ssh-app-as-root: ## SSH into app container as root user
	docker exec -it --user 0 realit_app sh

ssh-db: ## SSH into database container
	docker exec -it realit_db sh

show-log-app: ## Show log app container
	docker logs -f realit_app

show-log-app-nginx: ## Show log nginx container
	docker logs -f realit_public

show-log-db: ## Show log PostgreSQL database container
	docker logs -f realit_db


show-logs: ## Show logs from all containers
	docker-compose $(COMPOSE_FILES) logs -f
npm-run: ## Run NPM watch in app container
	docker exec -t --user 0 realit_app npm run watch

npm-dev: ## Run NPM dev server (Vite HMR)
	docker exec -t --user 0 realit_app npm run dev

npm-build: ## Build frontend assets for production
	docker exec -t --user 0 realit_app npm run build

check-eslint: ## Run ESLint check in source
	docker exec -t --user 0 realit_app npm run eslint

composer-install: ## Run Composer install in app container
	docker exec -t realit_app composer install

composer-update: ## Run Composer update in app container
	docker exec -t realit_app composer update

composer-dump: ## Run Composer dump-autoload
	docker exec -t realit_app composer dump-autoload

npm-install: ## Run NPM install in app container
	rm -rf node_modules && docker exec -t --user 0 realit_app npm install

# Laravel Artisan Commands
up-db: ## Run database migrations
	docker exec -it --user 0 realit_app php artisan migrate

migrate-fresh: ## Run fresh migrations (⚠️ drops all tables)
	docker exec -it --user 0 realit_app php artisan migrate:fresh

migrate-seed: ## Run migrations with seeders
	docker exec -it --user 0 realit_app php artisan migrate --seed

artisan-key: ## Generate application key
	docker exec -it realit_app php artisan key:generate

artisan-cache-clear: ## Clear application cache
	docker exec -t realit_app php artisan cache:clear
	docker exec -t realit_app php artisan config:clear
	docker exec -t realit_app php artisan route:clear
	docker exec -t realit_app php artisan view:clear
	@echo "✅ All caches cleared"

artisan-optimize: ## Optimize application for production
	docker exec -t realit_app php artisan config:cache
	docker exec -t realit_app php artisan route:cache
	docker exec -t realit_app php artisan view:cache
	@echo "✅ Application optimized"

artisan: ## Run any artisan command (usage: make artisan CMD="command")
	@if [ -z "$(CMD)" ]; then \
		echo "❌ Usage: make artisan CMD=\"your:command\""; \
		exit 1; \
	fi
	docker exec -it realit_app php artisan $(CMD)

# Docker Management
build: ## Build Docker images
	uid=`id -u` gid=`id -g` docker-compose $(COMPOSE_FILES) build
	@echo "✅ Images built"

build-prod: ## Build production Docker images
	docker-compose -f docker-compose.yml build
	@echo "✅ Production images built"

config: ## Show merged docker-compose configuration
	docker-compose $(COMPOSE_FILES) config

clean: ## Clean temporary files and caches
	@echo "🧹 Cleaning temporary files..."
	rm -rf node_modules/.vite
	rm -rf storage/framework/cache/*
	rm -rf storage/framework/sessions/*
	rm -rf storage/framework/views/*
	@echo "✅ Clean completed"

# ============================================================
# Production Build & ECR Deploy
# ============================================================

npm-build-prod: ## Build Vite frontend assets inside a temporary container (no Node.js needed on host)
	@echo "📦 Building frontend assets inside container..."
	docker run --rm \
		-v $(shell pwd):/var/www/html/realit_product \
		--workdir /var/www/html/realit_product \
		node:20-alpine \
		sh -c "npm ci --silent && npm run build"
	@echo "✅ Frontend assets built → public/build/"

build-prod-image: ## Build production Docker images tagged with ECR URI (uses docker-compose.prod.yml)
	@echo "🐳 Building production images..."
	@echo "   Tag       : $(TAG)"
	@echo "   ECR App   : $(ECR_APP_URI):$(TAG)"
	@echo "   ECR Public: $(ECR_PUBLIC_URI):$(TAG)"
	AWS_ACCOUNT_ID=$(AWS_ACCOUNT_ID) \
	AWS_REGION=$(AWS_REGION) \
	TAG=$(TAG) \
	GIT_COMMIT_HASH=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
	GIT_BRANCH_NAME=$(shell git symbolic-ref -q --short HEAD 2>/dev/null || echo "unknown") \
	docker compose $(COMPOSE_PROD) build --no-cache
	@echo "✅ Production images built"
	@echo "   $(ECR_APP_URI):$(TAG)"
	@echo "   $(ECR_PUBLIC_URI):$(TAG)"

ecr-check-account: ## Verify AWS credentials and show account info
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "❌ Cannot resolve AWS Account ID. Check credentials:"; \
		echo "   aws sts get-caller-identity --profile $(AWS_PROFILE)"; \
		exit 1; \
	fi
	@echo "✅ AWS Account: $(AWS_ACCOUNT_ID)"
	@echo "   Region:  $(AWS_REGION)"
	@echo "   Profile: $(AWS_PROFILE)"
	@echo "   ECR App: $(ECR_APP_URI)"
	@echo "   ECR Pub: $(ECR_PUBLIC_URI)"

ecr-login: ecr-check-account ## Login to AWS ECR
	@echo "🔐 Logging in to ECR $(ECR_BASE)..."
	aws ecr get-login-password --region $(AWS_REGION) --profile paint-energymonitor-temp | \
		docker login --username AWS --password-stdin $(ECR_BASE)
	@echo "✅ ECR login successful"

ecr-push: ecr-login ## Push production images to ECR via docker-compose.prod.yml (TAG=latest)
	@echo "📤 Pushing images with tag: $(TAG)"
	AWS_ACCOUNT_ID=$(AWS_ACCOUNT_ID) \
	AWS_REGION=$(AWS_REGION) \
	TAG=$(TAG) \
	GIT_COMMIT_HASH=unknown GIT_BRANCH_NAME=unknown \
	docker compose $(COMPOSE_PROD) push
	@echo "🏷️  Tagging and pushing :latest..."
	docker tag $(ECR_APP_URI):$(TAG)    $(ECR_APP_URI):latest
	docker tag $(ECR_PUBLIC_URI):$(TAG) $(ECR_PUBLIC_URI):latest
	docker push $(ECR_APP_URI):latest
	docker push $(ECR_PUBLIC_URI):latest
	@echo "✅ Images pushed:"
	@echo "   $(ECR_APP_URI):$(TAG)"
	@echo "   $(ECR_APP_URI):latest"
	@echo "   $(ECR_PUBLIC_URI):$(TAG)"
	@echo "   $(ECR_PUBLIC_URI):latest"

ecs-deploy: ecr-check-account ## Force ECS service to redeploy with latest images
	@echo "🚀 Forcing ECS redeployment..."
	aws ecs update-service \
		--cluster $(PROJECT_NAME)-cluster \
		--service $(PROJECT_NAME)-realit_product-service \
		--force-new-deployment \
		--region $(AWS_REGION) \
		--profile $(AWS_PROFILE) \
		--output text --query 'service.serviceName'
	@echo "✅ ECS redeployment triggered"
	@echo "   Monitor: https://$(AWS_REGION).console.aws.amazon.com/ecs/v2/clusters/$(PROJECT_NAME)-cluster/services"

ecs-status: ecr-check-account ## Show ECS service running/desired task count
	@echo "📊 ECS Service status:"
	@aws ecs describe-services \
		--cluster $(PROJECT_NAME)-cluster \
		--services $(PROJECT_NAME)-realit_product-service \
		--region $(AWS_REGION) \
		--profile $(AWS_PROFILE) \
		--query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}' \
		--output table

deploy: ## Full deploy pipeline: docker build (incl. Vite) → ECR push → ECS redeploy
	@echo "🚀 Starting full deployment pipeline..."
	@echo "   Profile: $(AWS_PROFILE) | Region: $(AWS_REGION) | Tag: $(TAG)"
	@echo "   ℹ️  Vite assets are built inside Docker (node-builder stage) — no npm needed on host"
	@$(MAKE) build-prod-image
	@$(MAKE) ecr-push
	@$(MAKE) ecs-deploy
	@echo ""
	@echo "✅ Deploy complete! Monitor ECS:"
	@echo "   https://$(AWS_REGION).console.aws.amazon.com/ecs/v2/clusters/$(PROJECT_NAME)-cluster/services"

deploy-no-ecs: ## Build + push to ECR only, skip ECS redeploy
	@echo "   ℹ️  Vite assets built inside Docker — no npm needed on host"
	@$(MAKE) build-prod-image
	@$(MAKE) ecr-push
	@echo "✅ Images pushed to ECR. Run 'make ecs-deploy' when ready."

prod-test-up: ensure-network ## Build production images & start locally (http://localhost:8080)
	@echo "🐳 Building production images (target: realit-app / realit-public)..."
	GIT_COMMIT_HASH=$(shell git rev-parse --short HEAD 2>/dev/null || echo "local") \
	GIT_BRANCH_NAME=$(shell git symbolic-ref -q --short HEAD 2>/dev/null || echo "local") \
	docker compose $(COMPOSE_PROD_TEST) up --build --detach --remove-orphans
	@echo ""
	@echo "✅ Production test environment running!"
	@echo "   Direct Nginx : http://localhost:8080  (no ALB headers)"
	@echo "   Via Fake ALB : http://localhost:8081  (ALB headers injected ← debug 419 here)"
	@echo "   DB port      : 5435 (prod-test DB, isolated from dev)"
	@echo ""
	@echo "📌 Next steps:"
	@echo "   make prod-test-migrate       # run migrations"
	@echo "   make fake-alb-csrf-test      # tái hiện và test lỗi 419"
	@echo "   make fake-alb-debug-env      # kiểm tra env CSRF/Sanctum"
	@echo "   make prod-test-logs          # follow all logs"

prod-test-down: ## Stop production test containers
	docker compose $(COMPOSE_PROD_TEST) down
	@echo "✅ Production test environment stopped"

prod-test-destroy: ## Stop prod-test containers AND remove volumes (⚠️ deletes prod-test DB data)
	docker compose $(COMPOSE_PROD_TEST) down -v
	@echo "⚠️  Prod-test containers and volumes removed"

prod-test-migrate: ## Run database migrations in prod-test app container
	docker exec realit_app php artisan migrate --force
	@echo "✅ Migrations done"

prod-test-seed: ## Seed database in prod-test app container
	docker exec realit_app php artisan db:seed --force
	@echo "✅ Database seeded"

prod-test-logs: ## Follow logs from prod-test containers
	docker compose $(COMPOSE_PROD_TEST) logs -f

prod-test-status: ## Show prod-test container health & status
	@echo "🩺 Prod-test container status:"
	@docker compose $(COMPOSE_PROD_TEST) ps

prod-test-ssh: ## Exec shell into prod-test app container
	docker exec -it realit_app sh

prod-test-artisan: ## Run artisan command in prod-test (usage: make prod-test-artisan CMD="migrate:status")
	@if [ -z "$(CMD)" ]; then echo "❌ Usage: make prod-test-artisan CMD=\"your:command\""; exit 1; fi
	docker exec -it realit_app php artisan $(CMD)

# ============================================================
# Fake ALB Debug — giả lập AWS ALB headers trên local
# Fake ALB listen: http://localhost:8081
# ============================================================

fake-alb-headers: ## Kiểm tra X-Forwarded headers nhận được qua fake-ALB (dùng /api/health hoặc endpoint bất kỳ)
	@echo "🔍 Checking headers received through fake-ALB (port 8081)..."
	@echo ""
	@echo "--- Request qua FAKE-ALB (localhost:8081) ---"
	@curl -si http://localhost:8081/api/health | head -20 || true
	@echo ""
	@echo "--- Request trực tiếp tới Nginx (localhost:8080) ---"
	@curl -si http://localhost:8080/api/health | head -20 || true

fake-alb-logs: ## Follow logs của fake-ALB container
	docker logs -f realit_fake_alb

fake-alb-csrf-test: ## Test lấy CSRF cookie qua fake-ALB rồi gửi POST (tái hiện lỗi 419)
	@echo "🧪 CSRF Token test qua fake-ALB (localhost:8081)"
	@echo ""
	@echo "Step 1: Lấy CSRF cookie từ /sanctum/csrf-cookie..."
	@curl -si -c /tmp/csrf_cookies_alb.txt http://localhost:8081/sanctum/csrf-cookie \
		-H "Origin: http://localhost:8081" \
		-H "Referer: http://localhost:8081/" | grep -E "HTTP|Set-Cookie|X-XSRF" || true
	@echo ""
	@echo "Step 2: Đọc XSRF-TOKEN từ cookie jar..."
	@XSRF_TOKEN=$$(cat /tmp/csrf_cookies_alb.txt 2>/dev/null | grep XSRF-TOKEN | awk '{print $$7}' | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))"); \
	echo "XSRF-TOKEN: $$XSRF_TOKEN"; \
	echo ""; \
	echo "Step 3: Gửi POST /api/login với CSRF token..."; \
	curl -si -b /tmp/csrf_cookies_alb.txt http://localhost:8081/api/login \
		-X POST \
		-H "Content-Type: application/json" \
		-H "Accept: application/json" \
		-H "Origin: http://localhost:8081" \
		-H "Referer: http://localhost:8081/" \
		-H "X-XSRF-TOKEN: $$XSRF_TOKEN" \
		-d '{"user_id":"admin","password":"123456"}' | grep -E "HTTP|419|422|200|token_mismatch|message" || true
	@echo ""
	@echo "✅ 200/422 = CSRF OK | ❌ 419 = vẫn còn lỗi CSRF"

fake-alb-debug-env: ## In các biến môi trường CSRF/Session/Sanctum trong app container
	@echo "🔍 Environment variables liên quan đến CSRF/Session/Sanctum:"
	@docker exec realit_app php artisan tinker --execute="\
		echo 'APP_URL           = ' . env('APP_URL') . PHP_EOL; \
		echo 'APP_ENV           = ' . env('APP_ENV') . PHP_EOL; \
		echo 'SANCTUM_STATEFUL  = ' . env('SANCTUM_STATEFUL_DOMAINS') . PHP_EOL; \
		echo 'SESSION_DRIVER    = ' . env('SESSION_DRIVER') . PHP_EOL; \
		echo 'SESSION_SECURE    = ' . env('SESSION_SECURE_COOKIE') . PHP_EOL; \
		echo 'SESSION_SAME_SITE = ' . env('SESSION_SAME_SITE') . PHP_EOL; \
		echo 'SESSION_DOMAIN    = ' . env('SESSION_DOMAIN') . PHP_EOL; \
		echo 'Sanctum stateful  = ' . implode(', ', config('sanctum.stateful')) . PHP_EOL; \
	" 2>/dev/null || docker exec realit_app php -r "\
		require 'vendor/autoload.php'; \
		\$$app = require 'bootstrap/app.php'; \
		\$$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap(); \
		echo 'APP_URL          = ' . env('APP_URL') . PHP_EOL; \
		echo 'SANCTUM_STATEFUL = ' . env('SANCTUM_STATEFUL_DOMAINS') . PHP_EOL; \
		echo 'SESSION_SECURE   = ' . env('SESSION_SECURE_COOKIE') . PHP_EOL; \
	"

fake-alb-setup-hosts: ## Thêm 'alb.paint-energymonitor.local' vào /etc/hosts (cần sudo)
	@echo "📝 Thêm fake ALB hostname vào /etc/hosts..."
	@grep -q "alb.paint-energymonitor.local" /etc/hosts && \
		echo "⏭️  Đã tồn tại trong /etc/hosts, bỏ qua." || \
		(echo "127.0.0.1  alb.paint-energymonitor.local" | sudo tee -a /etc/hosts && \
		echo "✅ Đã thêm: 127.0.0.1  alb.paint-energymonitor.local")
	@echo ""
	@echo "   Sau khi thêm, truy cập qua: http://alb.paint-energymonitor.local:8081"
