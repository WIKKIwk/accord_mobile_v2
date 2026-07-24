HOST_OS := $(shell uname -s)
API_URL ?= https://mini-rs-erp-test.wspace.sbs
LOCAL_API_URL ?= http://127.0.0.1:18081
WORKSPACE_ROOT := $(abspath ..)
LOCAL_TOOLS_ROOT ?= $(WORKSPACE_ROOT)/.tools
LOCAL_FLUTTER_HOME ?= $(LOCAL_TOOLS_ROOT)/flutter-sdk/flutter
FLUTTER_BIN ?= $(shell if command -v flutter >/dev/null 2>&1; then command -v flutter; elif [ -x "$(LOCAL_FLUTTER_HOME)/bin/flutter" ]; then printf '%s\n' "$(LOCAL_FLUTTER_HOME)/bin/flutter"; elif [ -x "$$HOME/.local/flutter/bin/flutter" ]; then printf '%s\n' "$$HOME/.local/flutter/bin/flutter"; fi)
DART_BIN ?= $(shell if command -v dart >/dev/null 2>&1; then command -v dart; elif [ -x "$(LOCAL_FLUTTER_HOME)/bin/dart" ]; then printf '%s\n' "$(LOCAL_FLUTTER_HOME)/bin/dart"; fi)
export PUB_CACHE ?= $(LOCAL_TOOLS_ROOT)/pub-cache
CHROME_EXECUTABLE ?= $(shell if command -v chromium-browser >/dev/null 2>&1; then command -v chromium-browser; elif command -v chromium >/dev/null 2>&1; then command -v chromium; elif command -v google-chrome >/dev/null 2>&1; then command -v google-chrome; fi)
ifeq ($(HOST_OS),Darwin)
JDK_HOME ?= $(LOCAL_TOOLS_ROOT)/jdk-17/Contents/Home
else
JDK_HOME ?= $(LOCAL_TOOLS_ROOT)/jdk-17
endif
ANDROID_SDK_ROOT ?= $(LOCAL_TOOLS_ROOT)/android-sdk
APK_NAME ?= accord.apk
MINI_ERP_ROOT ?= ../mini_rs_erp
MOBILE_RELEASE_DIR ?= $(MINI_ERP_ROOT)/data/mobile_releases
APP_VERSION := $(shell awk '/^version:/ { print $$2; exit }' pubspec.yaml)
APP_VERSION_NAME := $(word 1,$(subst +, ,$(APP_VERSION)))
APP_VERSION_CODE := $(word 2,$(subst +, ,$(APP_VERSION)))
MINIMUM_VERSION_CODE ?=
MANDATORY_UPDATE ?=
RELEASE_NOTES ?=
RELEASE_NOTES_FILE ?=
ERP_ROOT ?= ../../erpnext_n1/erp
MOCK_DIR ?= /tmp/accord_mobile_mock
RUST_BACKEND_ROOT ?= ../accord_mobile_server_rs
PRINT_BRIDGE_HOST ?= 127.0.0.1
PRINT_BRIDGE_PORT ?= 39118
PRINT_BRIDGE_URL ?= http://$(PRINT_BRIDGE_HOST):$(PRINT_BRIDGE_PORT)
PRINT_BRIDGE_HELPER ?= $(CURDIR)/garbage/accord_mac_usb_raw_write
PRINT_BRIDGE_PID ?= garbage/.accord_print_bridge.pid
PRINT_BRIDGE_LOG ?= garbage/accord_print_bridge.log

ifeq ($(HOST_OS),Darwin)
RUN_DEVICE ?= web-server
RUN_DART_DEFINES ?= --dart-define=APP_FORCE_DEVICE_PREVIEW=true
RUN_WEB_HOST ?= 127.0.0.1
RUN_WEB_PORT ?= auto
RUN_BROWSER_APP ?= Chromium
else
RUN_DEVICE ?= chrome
RUN_DART_DEFINES ?= --dart-define=APP_FORCE_DEVICE_PREVIEW=true
endif

CHROME_PROFILE_DIR := $(shell mktemp -d /tmp/accord-mobile-chrome.XXXXXX)
CHROME_WEB_BROWSER_FLAGS := --web-browser-flag=--disable-web-security --web-browser-flag=--disable-site-isolation-trials --web-browser-flag=--user-data-dir=$(CHROME_PROFILE_DIR)
ifeq ($(RUN_DEVICE),chrome)
RUN_BROWSER_FLAGS := $(CHROME_WEB_BROWSER_FLAGS)
else ifeq ($(RUN_DEVICE),web-server)
RUN_BROWSER_FLAGS := --web-hostname=$(RUN_WEB_HOST)
ifneq ($(strip $(RUN_WEB_PORT)),auto)
ifneq ($(strip $(RUN_WEB_PORT)),)
RUN_BROWSER_FLAGS += --web-port=$(RUN_WEB_PORT)
endif
endif
else
RUN_BROWSER_FLAGS :=
endif

ifneq ($(filter oneni ami,$(MAKECMDGOALS)),)
API_URL := $(LOCAL_API_URL)
RUN_PREREQ := mock-backend
else
RUN_PREREQ := prepare-run
endif

# Release APKs: arm64-v8a only (typical phones); no universal/fat APK.
FLUTTER_APK_RELEASE_FLAGS := --release --target-platform android-arm64

.PHONY: run oneni ami web analyze test deps backend-up backend-stop mock-backend mock-stop core-up core-stop remote-up remote-stop remote-url apk publish-apk-local apk-remote run-remote android-sdk-setup domain-up domain-up-fast domain-url apk-domain run-domain bench-start bench-restart bench-stop bench-limit-start bench-limit-stop prepare-run run-local web-local ios-release-install print-bridge-build print-bridge-up print-bridge-stop

deps:
	@$(FLUTTER_BIN) pub get

android-sdk-setup:
	@LOCAL_TOOLS_ROOT="$(LOCAL_TOOLS_ROOT)" \
		ANDROID_HOME="$(ANDROID_SDK_ROOT)" \
		JDK_HOME="$(JDK_HOME)" \
		FLUTTER_BIN="$(FLUTTER_BIN)" \
		./tools/bootstrap/setup_android_sdk.sh

backend-up:
	@API_URL=$(API_URL) BACKEND_ROOT="$$(cd .. && pwd)" ./tools/bootstrap/ensure_mobileapi.sh

prepare-run:
	@case "$(API_URL)" in \
		http://127.0.0.1:*|http://localhost:*|https://127.0.0.1:*|https://localhost:*) \
			echo "Using local API: $(API_URL)"; \
			API_URL=$(API_URL) BACKEND_ROOT="$$(cd .. && pwd)" ./tools/bootstrap/ensure_mobileapi.sh ;; \
		*) \
			echo "Using external API: $(API_URL)" ;; \
	esac

print-bridge-build:
ifeq ($(HOST_OS),Darwin)
	@mkdir -p garbage
	@clang -Wall -Wextra -O2 -framework IOKit -framework CoreFoundation tools/printer/mac_usb_raw_write.c -o "$(PRINT_BRIDGE_HELPER)"
	@echo "Mac USB print helper: $(PRINT_BRIDGE_HELPER)"
else
	@echo "Mac USB print bridge is only available on Darwin"
endif

print-bridge-up: print-bridge-build
ifeq ($(HOST_OS),Darwin)
	@if curl -fsS "$(PRINT_BRIDGE_URL)/healthz" 2>/dev/null | grep -q '"version":2'; then \
		echo "Mac print bridge already running: $(PRINT_BRIDGE_URL)"; \
	else \
		if curl -fsS "$(PRINT_BRIDGE_URL)/healthz" >/dev/null 2>&1; then \
			if [ ! -f "$(PRINT_BRIDGE_PID)" ]; then \
				echo "Mac print bridge is outdated and its PID file is missing"; exit 1; \
			fi; \
			kill "$$(cat "$(PRINT_BRIDGE_PID)")" 2>/dev/null || true; \
			rm -f "$(PRINT_BRIDGE_PID)"; \
			sleep 1; \
		fi; \
		mkdir -p garbage; \
		ACCORD_PRINT_BRIDGE_HOST="$(PRINT_BRIDGE_HOST)" \
		ACCORD_PRINT_BRIDGE_PORT="$(PRINT_BRIDGE_PORT)" \
		ACCORD_MAC_USB_HELPER="$(PRINT_BRIDGE_HELPER)" \
		nohup "$(DART_BIN)" run tools/printer/mac_print_bridge.dart >"$(PRINT_BRIDGE_LOG)" 2>&1 & \
		echo $$! >"$(PRINT_BRIDGE_PID)"; \
		for i in $$(seq 1 30); do \
			if curl -fsS "$(PRINT_BRIDGE_URL)/healthz" 2>/dev/null | grep -q '"version":2'; then \
				echo "Mac print bridge ready: $(PRINT_BRIDGE_URL)"; exit 0; \
			fi; \
			sleep 1; \
		done; \
		echo "Mac print bridge start failed"; tail -80 "$(PRINT_BRIDGE_LOG)" 2>/dev/null || true; exit 1; \
	fi
endif

print-bridge-stop:
	@if [ -f "$(PRINT_BRIDGE_PID)" ]; then \
		kill "$$(cat "$(PRINT_BRIDGE_PID)")" 2>/dev/null || true; \
		rm -f "$(PRINT_BRIDGE_PID)"; \
		echo "Mac print bridge stopped"; \
	else \
		echo "Mac print bridge pid file not found"; \
	fi

core-up:
	@API_URL=$(API_URL) BACKEND_ROOT="$$(cd .. && pwd)" ./tools/bootstrap/ensure_core.sh

bench-start:
	@$(ERP_ROOT)/restart_bench.sh

bench-restart: bench-start

bench-stop:
	@$(ERP_ROOT)/stop_bench.sh

bench-limit-start:
	@$(ERP_ROOT)/start_limited_bench.sh

bench-limit-stop:
	@$(ERP_ROOT)/stop_limited_bench.sh

backend-stop:
	@if [ -f garbage/.mobileapi.pid ]; then \
		kill "$$(cat garbage/.mobileapi.pid)" 2>/dev/null || true; \
		rm -f garbage/.mobileapi.pid; \
		echo "mobileapi stopped"; \
	else \
		echo "mobileapi pid file not found"; \
	fi

mock-backend:
	@mkdir -p "$(MOCK_DIR)"
	@if curl -fsS "$(LOCAL_API_URL)/healthz" >/dev/null 2>&1; then \
		echo "mock backend already running: $(LOCAL_API_URL)"; \
	else \
		screen -S accord_mock_backend -X quit >/dev/null 2>&1 || true; \
		screen -dmS accord_mock_backend bash -lc '\
			cd "$(RUST_BACKEND_ROOT)" && \
			env \
			MOBILE_API_ADDR=127.0.0.1:8081 \
			MOBILE_API_LOCAL_STORE_ALLOW_JSON_FALLBACK=1 \
			MOBILE_API_SESSION_STORE_BACKEND=json \
			MOBILE_API_SESSION_STORE_PATH="$(MOCK_DIR)/mobile_sessions.json" \
			MOBILE_API_PROFILE_STORE_BACKEND=json \
			MOBILE_API_PROFILE_STORE_PATH="$(MOCK_DIR)/mobile_profile_prefs.json" \
			MOBILE_API_PUSH_TOKEN_STORE_BACKEND=json \
			MOBILE_API_PUSH_TOKEN_STORE_PATH="$(MOCK_DIR)/mobile_push_tokens.json" \
			MOBILE_API_ADMIN_SUPPLIER_STORE_BACKEND=json \
			MOBILE_API_ADMIN_SUPPLIER_STORE_PATH="$(MOCK_DIR)/mobile_admin_suppliers.json" \
			MOBILE_API_PRODUCTION_MAP_STORE_PATH="$(MOCK_DIR)/production_maps.json" \
			MOBILE_API_ROLE_STORE_PATH="$(MOCK_DIR)/mobile_roles.json" \
			RUST_LOG=info \
			cargo run --bin accord_mobile_server_rs \
			> "$(MOCK_DIR)/backend.log" 2>&1'; \
		for i in $$(seq 1 60); do \
			if curl -fsS "$(LOCAL_API_URL)/healthz" >/dev/null 2>&1; then \
				echo "mock backend ready: $(LOCAL_API_URL)"; \
				exit 0; \
			fi; \
			sleep 1; \
		done; \
		echo "mock backend start failed"; \
		tail -120 "$(MOCK_DIR)/backend.log" 2>/dev/null || true; \
		exit 1; \
	fi

mock-stop:
	@screen -S accord_mock_backend -X quit >/dev/null 2>&1 || true
	@lsof -tiTCP:8081 -sTCP:LISTEN | xargs -r kill >/dev/null 2>&1 || true
	@echo "mock backend stopped"

core-stop:
	@./tools/runtime/stop_remote_core.sh

remote-up:
	@BACKEND_ROOT="$$(cd .. && pwd)" ./tools/runtime/start_remote_core.sh

domain-up:
	@BACKEND_ROOT="$$(cd .. && pwd)" ./tools/runtime/start_domain_core.sh

domain-up-fast:
	@SKIP_PUBLIC_HEALTHCHECK=1 BACKEND_ROOT="$$(cd .. && pwd)" ./tools/runtime/start_domain_core.sh

remote-url:
	@if [ -f garbage/.core_tunnel_url ]; then \
		cat garbage/.core_tunnel_url; \
	else \
		echo "remote URL topilmadi. Avval make remote-up ishlating."; \
		exit 1; \
	fi

domain-url:
	@if [ -f garbage/.core_domain_url ]; then \
		cat garbage/.core_domain_url; \
	else \
		echo "domain URL topilmadi. Avval make domain-up ishlating."; \
		exit 1; \
	fi

remote-stop:
	@./tools/runtime/stop_remote_core.sh

run: $(RUN_PREREQ) deps
ifeq ($(HOST_OS),Darwin)
run: print-bridge-up
endif
ifeq ($(RUN_DEVICE),web-server)
ifeq ($(HOST_OS),Darwin)
ifneq ($(strip $(RUN_WEB_PORT)),auto)
ifneq ($(strip $(RUN_WEB_PORT)),)
	@(for i in $$(seq 1 120); do \
		if curl -fsS "http://$(RUN_WEB_HOST):$(RUN_WEB_PORT)/main.dart.js" >/dev/null 2>&1; then \
			open -a "$(RUN_BROWSER_APP)" "http://$(RUN_WEB_HOST):$(RUN_WEB_PORT)"; \
			exit 0; \
		fi; \
		sleep 1; \
	done) >/dev/null 2>&1 &
endif
endif
endif
endif
	@CHROME_EXECUTABLE="$(CHROME_EXECUTABLE)" $(FLUTTER_BIN) run -d $(RUN_DEVICE) $(RUN_BROWSER_FLAGS) --dart-define=MOBILE_API_BASE_URL=$(API_URL) --dart-define=ACCORD_PRINT_BRIDGE_URL=$(PRINT_BRIDGE_URL) $(RUN_DART_DEFINES)

oneni:
	@:

ami:
	@:

web: prepare-run deps
ifeq ($(HOST_OS),Darwin)
web: print-bridge-up
endif
	@CHROME_EXECUTABLE="$(CHROME_EXECUTABLE)" $(FLUTTER_BIN) run -d chrome $(CHROME_WEB_BROWSER_FLAGS) --dart-define=MOBILE_API_BASE_URL=$(API_URL) --dart-define=ACCORD_PRINT_BRIDGE_URL=$(PRINT_BRIDGE_URL)

run-local: API_URL=$(LOCAL_API_URL)
run-local: run

web-local: API_URL=$(LOCAL_API_URL)
web-local: web

run-remote: deps remote-up
	@REMOTE_URL="$$(cat garbage/.core_tunnel_url)" && \
		$(FLUTTER_BIN) run -d linux --dart-define=MOBILE_API_BASE_URL="$$REMOTE_URL"

run-domain: deps domain-up
	@DOMAIN_URL="$$(cat garbage/.core_domain_url)" && \
		$(FLUTTER_BIN) run -d linux --dart-define=MOBILE_API_BASE_URL="$$DOMAIN_URL"

apk: deps android-sdk-setup
	@JAVA_HOME="$(JDK_HOME)" ANDROID_HOME="$(ANDROID_SDK_ROOT)" ANDROID_SDK_ROOT="$(ANDROID_SDK_ROOT)" PATH="$(JDK_HOME)/bin:$(ANDROID_SDK_ROOT)/platform-tools:$$PATH" $(FLUTTER_BIN) build apk $(FLUTTER_APK_RELEASE_FLAGS) --dart-define=MOBILE_API_BASE_URL=$(API_URL) && \
	cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/$(APK_NAME) && \
	echo "APK (arm64-v8a): build/app/outputs/flutter-apk/$(APK_NAME)" && \
	echo "API: $(API_URL)"

publish-apk-local: apk
	@$(MAKE) -C "$(MINI_ERP_ROOT)" publish-mobile-apk \
		APK="$(abspath build/app/outputs/flutter-apk/$(APK_NAME))" \
		VERSION_CODE="$(APP_VERSION_CODE)" \
		VERSION_NAME="$(APP_VERSION_NAME)" \
		MOBILE_RELEASE_DIR="$(abspath $(MOBILE_RELEASE_DIR))" \
		MINIMUM_VERSION_CODE="$(MINIMUM_VERSION_CODE)" \
		MANDATORY_UPDATE="$(MANDATORY_UPDATE)" \
		RELEASE_NOTES="$(RELEASE_NOTES)" \
		RELEASE_NOTES_FILE="$(RELEASE_NOTES_FILE)"

apk-remote: deps remote-up android-sdk-setup
	@REMOTE_URL="$$(cat garbage/.core_tunnel_url)" && \
	JAVA_HOME="$(JDK_HOME)" ANDROID_HOME="$(ANDROID_SDK_ROOT)" ANDROID_SDK_ROOT="$(ANDROID_SDK_ROOT)" PATH="$(JDK_HOME)/bin:$(ANDROID_SDK_ROOT)/platform-tools:$$PATH" $(FLUTTER_BIN) build apk $(FLUTTER_APK_RELEASE_FLAGS) --dart-define=MOBILE_API_BASE_URL="$$REMOTE_URL" && \
	cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/$(APK_NAME) && \
	echo "APK (arm64-v8a) tayyor: build/app/outputs/flutter-apk/$(APK_NAME)" && \
	echo "Core URL: $$REMOTE_URL"

apk-domain: deps domain-up android-sdk-setup
	@DOMAIN_URL="$$(cat garbage/.core_domain_url)" && \
	JAVA_HOME="$(JDK_HOME)" ANDROID_HOME="$(ANDROID_SDK_ROOT)" ANDROID_SDK_ROOT="$(ANDROID_SDK_ROOT)" PATH="$(JDK_HOME)/bin:$(ANDROID_SDK_ROOT)/platform-tools:$$PATH" $(FLUTTER_BIN) build apk $(FLUTTER_APK_RELEASE_FLAGS) --dart-define=MOBILE_API_BASE_URL="$$DOMAIN_URL" && \
	cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/$(APK_NAME) && \
	echo "APK (arm64-v8a) tayyor: build/app/outputs/flutter-apk/$(APK_NAME)" && \
	echo "Core URL: $$DOMAIN_URL"

ios-release-install:
	@./tools/runtime/install_ios_release.sh

analyze:
	@$(FLUTTER_BIN) analyze

test:
	@$(FLUTTER_BIN) test
