# ===== Config =====
PLUGIN_NAME        ?= helloworld

# Entry main
MAIN_SERVER_FILE   ?= ./server/hello.go

# Nombre del binario dentro del paquete
OUT_SERVER_BIN     ?= server/bin/helloworld

# Solo linux/arm64
TARGETS            ?= linux/arm64

# Dónde se instalará en el sistema
PLUGIN_ROOT        ?= /var/lib/echopbx/plugins

# ===== Derived =====
VERSION            ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo 0.1.0)
COMMIT             := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
DATE               := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

BUILD_DIR          := build
PKG_STAGING        := $(BUILD_DIR)/package/$(PLUGIN_NAME)/$(VERSION)
SERVER_OUT_DIR     := $(PKG_STAGING)/server/bin
MANIFEST_SRC       := ./echo.plugin.json
MANIFEST_OUT       := $(PKG_STAGING)/echo.plugin.json
TARBALL            := $(BUILD_DIR)/$(PLUGIN_NAME)-$(VERSION).tgz

LD_FLAGS           := -s -w -X 'main.version=$(VERSION)' -X 'main.commit=$(COMMIT)' -X 'main.buildDate=$(DATE)'

# ===== Default =====
.PHONY: all
all: package

# ===== Build server (linux/arm64) =====
.PHONY: build-server
build-server:
	@mkdir -p $(SERVER_OUT_DIR)
	@for tgt in $(TARGETS); do \
	  GOOS=$${tgt%/*}; GOARCH=$${tgt#*/}; \
	  OUT="$(SERVER_OUT_DIR)/$(notdir $(OUT_SERVER_BIN))-$${GOOS}-$${GOARCH}"; \
	  echo "-> Building $$OUT"; \
	  CGO_ENABLED=0 GOOS=$$GOOS GOARCH=$$GOARCH go build -trimpath -ldflags "$(LD_FLAGS)" -o $$OUT $(MAIN_SERVER_FILE); \
	done
	# Enlace canónico sin sufijo apuntando al binario linux/arm64
ifneq (,$(findstring linux/arm64,$(TARGETS)))
	@ln -sf $(notdir $(OUT_SERVER_BIN))-linux-arm64 $(SERVER_OUT_DIR)/$(notdir $(OUT_SERVER_BIN))
else
	@tgt=$(firstword $(TARGETS)); \
	 ln -sf $(notdir $(OUT_SERVER_BIN))-$$tgt $(SERVER_OUT_DIR)/$(notdir $(OUT_SERVER_BIN))
endif

# ===== Manifest (inyecta VERSION sin tocar el original) =====
.PHONY: manifest
manifest:
	@mkdir -p $(PKG_STAGING)
	@cp $(MANIFEST_SRC) $(MANIFEST_OUT)
	@# Sustituye ${VERSION} -> $(VERSION)
	@perl -0777 -pe "s/\\$\\{VERSION\\}/$(VERSION)/g" -i $(MANIFEST_OUT)
	@echo "Manifest -> $(MANIFEST_OUT)"

# ===== Package =====
.PHONY: package
package: clean build-server manifest
	@mkdir -p $(BUILD_DIR)
	@tar -C $(BUILD_DIR)/package -czf $(TARBALL) $(PLUGIN_NAME)
	@echo "Paquete -> $(TARBALL)"

# ===== Install =====
.PHONY: install
install: package
	install -d $(DESTDIR)$(PLUGIN_ROOT)
	tar -C $(DESTDIR)$(PLUGIN_ROOT) -xzf $(TARBALL)
	@echo "Instalado en: $(DESTDIR)$(PLUGIN_ROOT)/$(PLUGIN_NAME)/$(VERSION)"
	@echo "Activa con:   echopbxctl plugins enable $(PLUGIN_NAME) --version $(VERSION)"

# ===== Test =====
.PHONY: test
test:
	@go test ./... || true

# ===== Clean =====
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
