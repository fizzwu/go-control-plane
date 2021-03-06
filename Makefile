.DEFAULT_GOAL	:= build

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

SHELL 		:= /bin/bash
BINDIR		:= bin
DOCKERDIR	:= docker
RELEASEDIR  := release
OUTPUT_NAME := go-control-plane
GOHOSTOS 	:= $(shell go env GOHOSTOS)

ifndef GOOS
    GOOS := $(GOHOSTOS)
endif

ifndef GOARCH
	GOARCH := $(shell go env GOHOSTARCH)
endif

GOFILES		= $(shell find . -type f -name '*.go' -not -path "./vendor/*" -not -path "./api/*")
GODIRS		= $(shell go list -f '{{.Dir}}' ./... \
            | grep -vFf <(go list -f '{{.Dir}}' ./vendor/...) \
            | grep -vFf <(go list -f '{{.Dir}}' ./api/...))
GOPKGS		= $(shell go list ./... \
            | grep -vFf <(go list ./vendor/...) \
            | grep -vFf <(go list ./api/...))

APP_VER		:= $(shell git describe --always 2> /dev/null || echo "unknown")

.PHONY: build
build:
	@go build ./...

clean:
	@echo "--> cleaning compiled objects and binaries"
	@go clean -tags netgo -i $(GOPKGS)
	@rm -rf $(BINDIR)/*
	@rm -rf $(RELEASEDIR)/*

.PHONY: test
test:
	@echo "--> running unit tests"
	@go test -v $(GOPKGS)

.PHONY: cover
cover:
	@echo "--> running coverage tests"
	@go test -race -cover $(GOPKGS)

.PHONY: check
check: format.check vet lint

format: tools.goimports
	@echo "--> formatting code with 'goimports' tool"
	@goimports -w -l $(GOFILES)

format.check: tools.goimports
	@echo "--> checking code formatting with 'goimports' tool"
	@goimports -l $(GOFILES) | sed -e "s/^/\?\t/" | tee >(test -z)

vet: tools.govet
	@echo "--> checking code correctness with 'go vet' tool"
	@go vet $(GOPKGS)

lint: tools.golint
	@echo "--> checking code style with 'golint' tool"
	@echo $(GODIRS) | xargs -n 1 golint

#------------------
#-- dependencies
#------------------
.PHONY: depend.update depend.install

depend.update: tools.glide
	@echo "--> updating dependencies from glide.yaml"
	@glide update --strip-vendor

depend.install: tools.glide
	@echo "--> installing dependencies from glide.lock "
	@glide install --strip-vendor

#---------------
#-- tools
#---------------
.PHONY: tools tools.glide tools.goimports tools.golint tools.govet

tools: tools.glide tools.goimports tools.golint tools.govet

tools.goimports:
	@command -v goimports >/dev/null ; if [ $$? -ne 0 ]; then \
		echo "--> installing goimports"; \
		go get golang.org/x/tools/cmd/goimports; \
	fi

tools.govet:
	@go tool vet 2>/dev/null ; if [ $$? -eq 3 ]; then \
		echo "--> installing govet"; \
		go get golang.org/x/tools/cmd/vet; \
	fi

tools.golint:
	@command -v golint >/dev/null ; if [ $$? -ne 0 ]; then \
		echo "--> installing golint"; \
		go get github.com/golang/lint/golint; \
	fi

tools.glide:
	@command -v glide >/dev/null ; if [ $$? -ne 0 ]; then \
		echo "--> installing glide"; \
		curl https://glide.sh/get | sh; \
	fi
