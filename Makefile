include .env
-include .local.env

TAG ?= latest

VERSION ?=

# Mega-Linter Version
_ML_VERSION = v6

# get all files that are currently changed, but not committed
_FILES = $$(git diff --name-only HEAD | tr '\n' ',')

# get the current working dir
_CWD = $$(pwd)

CI_COMMIT_REF_SLUG ?=
CI_COMMIT_SHORT_SHA ?=
CI_COMMIT_TAG ?=

REGISTRY_NAME ?=
REPO ?=

DOCKER_CACHE_FROM_IMAGES = $(REPO):$(TAG),$(REPO):$(CI_COMMIT_REF_SLUG),$(REPO):$(CI_COMMIT_SHORT_SHA),$(REPO):$(CI_COMMIT_TAG)
DOCKER_PORTS ?=

# WARNING: need to export the env var, otherwise docker build will fail
export DOCKER_BUILDKIT ?= 1
export COMPOSE_DOCKER_CLI_BUILD ?= 1

.DEFAULT_GOAL = help	# if you type 'make' without arguments, this is the default: show the help
.PHONY        : # Not needed here, but you can put your all your targets to be sure
				# there is no name conflict between your files and your targets.

## pull, build and tag
.PHONY: default
default: pull build tag

## login to the docker registry
.PHONY: login
login:
	echo "$(CUSTOM_REGISTRY_PASSWORD)" | docker login $(REGISTRY_NAME) --username $(CUSTOM_REGISTRY_USERNAME) --password-stdin

## pull the latest images from the registry
.PHONY: pull
pull:
	if [ -n "$(TAG)" ];  then docker pull $(REPO):$(TAG) || true; fi
	if [ -n "$(CI_COMMIT_REF_SLUG)" ] && [ -n "$(CI_COMMIT_SHORT_SHA)" ]; then docker pull $(REPO):$(CI_COMMIT_REF_SLUG)-$(CI_COMMIT_SHORT_SHA) || true; fi
	if [ -n "$(CI_COMMIT_REF_SLUG)" ];  then docker pull $(REPO):$(CI_COMMIT_REF_SLUG) || true; fi
	if [ -n "$(CI_COMMIT_SHORT_SHA)" ];  then docker pull $(REPO):$(CI_COMMIT_SHORT_SHA) || true; fi
	if [ -n "$(CI_COMMIT_TAG)" ];  then docker pull $(REPO):$(CI_COMMIT_TAG) || true; fi

## build docker image
.PHONY: build
build:
	docker buildx build --push \
		--tag $(REPO):latest \
		--platform=linux/arm64/v8,linux/amd64 \
		--cache-from $(DOCKER_CACHE_FROM_IMAGES) \
		--build-arg VERSION=$(VERSION) \
		-f $(PWD)/Dockerfile \
		.

## tag the latest build
.PHONY: tag
tag:
	if [ -n "$(TAG)" ];       then docker tag $(REPO):latest $(REPO):$(TAG); fi
	if [ -n "$(CI_COMMIT_SHORT_SHA)" ]; then docker tag $(REPO):latest $(REPO):$(CI_COMMIT_SHORT_SHA); fi
	if [ -n "$(CI_COMMIT_TAG)" ];       then docker tag $(REPO):latest $(REPO):$(CI_COMMIT_TAG); fi
	if [ -n "$(CI_COMMIT_REF_SLUG)" ];  then docker tag $(REPO):latest $(REPO):$(CI_COMMIT_REF_SLUG); fi
	if [ -n "$(CI_COMMIT_REF_SLUG)" ] && [ -n "$(CI_COMMIT_SHORT_SHA)" ]; then docker tag $(REPO):latest $(REPO):$(CI_COMMIT_REF_SLUG)-$(CI_COMMIT_SHORT_SHA); fi

## push the latest build to the registry
.PHONY: push
push:
	if [ -n "$(TAG)" ];       then docker push $(REPO):$(TAG); fi
	if [ -n "$(CI_COMMIT_SHORT_SHA)" ]; then docker push $(REPO):$(CI_COMMIT_SHORT_SHA); fi
	if [ -n "$(CI_COMMIT_TAG)" ];       then docker push $(REPO):$(CI_COMMIT_TAG); fi
	if [ -n "$(CI_COMMIT_REF_SLUG)" ];  then docker push $(REPO):$(CI_COMMIT_REF_SLUG); fi
	if [ -n "$(CI_COMMIT_REF_SLUG)" ] && [ -n "$(CI_COMMIT_SHORT_SHA)" ]; then docker push $(REPO):$(CI_COMMIT_REF_SLUG)-$(CI_COMMIT_SHORT_SHA); fi

## open a shell to the latest build
.PHONY: shell
shell:
	docker run --rm --name $(NAME) -i -t $(DOCKER_PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) sh -c "clear && (bash || sh)"

## run the latest build as it was built to do
.PHONY: run
run:
	docker run --rm --name $(NAME) $(DOCKER_PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

## run the latest build in daemon mode
.PHONY: start
start:
	docker run -d --name $(NAME) $(DOCKER_PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG)

## stop the running container
.PHONY: stop
stop:
	docker stop --time 1 $(NAME)

## get the latest logs
.PHONY: logs
logs:
	docker logs $(NAME)

## remove the latest builds from the local machine
.PHONY: clean
clean:
	-docker rm -f $(NAME)

## pull, build, tag and push
.PHONY: release
release: pull build tag push

_check-for-all:
	@echo "================================== Warning! ==================================" && \
	echo "== Linting the whole codebase can take" && \
	echo "== a very long time" && \
	echo "==============================================================================="
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]

_check-for-changed-files:
	@if [ -z $(_FILES) ]; then \
		echo "No files to lint";\
		exit 1;\
	fi

# this is the actual command that will be called with arguments
define mega-linter-runner
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock:rw \
		-v $(_CWD):/tmp/lint:rw \
		-e MEGALINTER_CONFIG=.mega-linter.yml \
		$(strip $(2)) \
		oxsecurity/$(strip $(1)):$(_ML_VERSION)
endef

## Lint only changed and uncommitted files with all available file linters
.PHONY: lint
.ONESHELL:
lint: _check-for-changed-files
	$(call mega-linter-runner, megalinter, -e SKIP_CLI_LINT_MODES=project -e MEGALINTER_FILES_TO_LINT=$(_FILES))

## Same as `lint`, but with automatic fixes where possible
.PHONY: lint-fix
.ONESHELL:
lint-fix: _check-for-changed-files
	$(call mega-linter-runner, megalinter, -e SKIP_CLI_LINT_MODES=project -e MEGALINTER_FILES_TO_LINT=$(_FILES) -e APPLY_FIXES=all)

## Lint only changed and uncommitted files with the lighter `ci_light` flavor.
## Optimized for CI items (Dockerfile, Jenkinsfile, JSON/YAML schemas, XML)
.PHONY: lint-ci
.ONESHELL:
lint-ci: _check-for-changed-files
	$(call mega-linter-runner, megalinter-ci_light, -e SKIP_CLI_LINT_MODES=project -e MEGALINTER_FILES_TO_LINT=$(_FILES))

## Same as `lint-ci`, but with automatic fixes where possible
.PHONY: lint-ci-fix
.ONESHELL:
lint-ci-fix: _check-for-changed-files
	$(call mega-linter-runner, megalinter-ci_light, -e SKIP_CLI_LINT_MODES=project -e MEGALINTER_FILES_TO_LINT=$(_FILES) -e APPLY_FIXES=all)

## Lint all files with all available file linters
.PHONY: lint-all-files
.ONESHELL:
lint-all-files: _check-for-all
	$(call mega-linter-runner, megalinter, -e SKIP_CLI_LINT_MODES=project)

## Same as `lint-all-files`, but with automatic fixes where possible
.PHONY: lint-all-files-fix
.ONESHELL:
lint-all-files-fix: _check-for-all
	$(call mega-linter-runner, megalinter, -e SKIP_CLI_LINT_MODES=project -e APPLY_FIXES=all)

## Lint the whole repository with all available linters, file and project
.PHONY: lint-all
.ONESHELL:
lint-all: _check-for-all
	$(call mega-linter-runner, megalinter)
	# docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:rw -v /Users/vitaliquiering/Klick-Tipp/git/k8stipp:/tmp/lint:rw -e MEGALINTER_CONFIG=.mega-linter.yml oxsecurity/megalinter:v6

## Same as `lint-all`, but with automatic fixes where possible
.PHONY: lint-all-fix
.ONESHELL:
lint-all-fix: _check-for-all
	$(call mega-linter-runner, megalinter, -e APPLY_FIXES=all)

## get this help page
.PHONY: help
help:
	@awk '{ \
			if ($$0 ~ /^.PHONY: [a-zA-Z\-\_\.0-9]+$$/) { \
				helpCommand = substr($$0, index($$0, ":") + 2); \
				if (helpMessage) { \
					printf "\033[36m%-40s\033[0m \t%s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^[a-zA-Z\-\_0-9.]+:/) { \
				helpCommand = substr($$0, 0, index($$0, ":")); \
				if (helpMessage) { \
					printf "\033[36m%-40s\033[0m %s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^##/) { \
				if (helpMessage) { \
					helpMessage = helpMessage"\n                                                  "substr($$0, 3); \
				} else { \
					helpMessage = substr($$0, 3); \
				} \
			} else { \
				if (helpMessage) { \
					printf "\n\033[33m%-80s\033[0m\n", \
			helpMessage; \
				} \
				helpMessage = ""; \
			} \
		}' \
		$(MAKEFILE_LIST)
