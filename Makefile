# Makefile for Scryer Prolog with WASI Component Model support

# Default target
.DEFAULT_GOAL := help

# Variables
CARGO := cargo
WASM_TOOLS := wasm-tools
TARGET_DIR := target/wasm32-wasi
SCRIPTS_DIR := scripts

# Colors for output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Help target
.PHONY: help
help:
	@echo "$(CYAN)Scryer Prolog Build Targets$(NC)"
	@echo ""
	@echo "$(GREEN)Regular builds:$(NC)"
	@echo "  make build          - Build in debug mode"
	@echo "  make release        - Build in release mode"
	@echo "  make test           - Run tests"
	@echo ""
	@echo "$(GREEN)WASI Component builds:$(NC)"
	@echo "  make wasi-component-dev     - Build WASI component (dev profile)"
	@echo "  make wasi-component-release - Build WASI component (release profile)"
	@echo "  make wasi-component-debug   - Build WASI component (debug profile)"
	@echo ""
	@echo "$(GREEN)Utilities:$(NC)"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make check-deps     - Check if required dependencies are installed"
	@echo "  make install-deps   - Install required dependencies"
	@echo ""

# Regular build targets
.PHONY: build
build:
	$(CARGO) build

.PHONY: release
release:
	$(CARGO) build --release

.PHONY: test
test:
	$(CARGO) test

# WASI Component targets
.PHONY: wasi-component-dev
wasi-component-dev: check-wasi-deps
	@echo "$(YELLOW)Building WASI component with dev profile...$(NC)"
	$(CARGO) build --profile=wasi-dev --target wasm32-wasi --no-default-features --features wasi-component
	$(WASM_TOOLS) component new $(TARGET_DIR)/wasi-dev/scryer_prolog.wasm \
		-o $(TARGET_DIR)/wasi-dev/scryer_prolog_component.wasm
	@echo "$(GREEN)✓ WASI component built: $(TARGET_DIR)/wasi-dev/scryer_prolog_component.wasm$(NC)"

.PHONY: wasi-component-release
wasi-component-release: check-wasi-deps
	@echo "$(YELLOW)Building WASI component with release profile...$(NC)"
	$(CARGO) build --profile=wasi-release --target wasm32-wasi --no-default-features --features wasi-component
	$(WASM_TOOLS) component new $(TARGET_DIR)/wasi-release/scryer_prolog.wasm \
		-o $(TARGET_DIR)/wasi-release/scryer_prolog_component.wasm
	@echo "$(GREEN)✓ WASI component built: $(TARGET_DIR)/wasi-release/scryer_prolog_component.wasm$(NC)"

.PHONY: wasi-component-debug
wasi-component-debug: check-wasi-deps
	@echo "$(YELLOW)Building WASI component with debug profile...$(NC)"
	$(CARGO) build --target wasm32-wasi --no-default-features --features wasi-component
	$(WASM_TOOLS) component new $(TARGET_DIR)/debug/scryer_prolog.wasm \
		-o $(TARGET_DIR)/debug/scryer_prolog_component.wasm
	@echo "$(GREEN)✓ WASI component built: $(TARGET_DIR)/debug/scryer_prolog_component.wasm$(NC)"

# Alternative target using the shell script
.PHONY: wasi-component-script-dev
wasi-component-script-dev:
	$(SCRIPTS_DIR)/build-wasi-component.sh --dev

.PHONY: wasi-component-script-release
wasi-component-script-release:
	$(SCRIPTS_DIR)/build-wasi-component.sh --release

# Check dependencies
.PHONY: check-deps
check-deps: check-rust check-wasi-deps

.PHONY: check-rust
check-rust:
	@command -v $(CARGO) >/dev/null 2>&1 || { \
		echo "$(RED)Error: cargo not found. Please install Rust.$(NC)"; \
		echo "Visit: https://www.rust-lang.org/tools/install"; \
		exit 1; \
	}
	@echo "$(GREEN)✓ Rust/Cargo found$(NC)"

.PHONY: check-wasi-deps
check-wasi-deps: check-rust
	@command -v $(WASM_TOOLS) >/dev/null 2>&1 || { \
		echo "$(RED)Error: wasm-tools not found.$(NC)"; \
		echo "Install with: cargo install wasm-tools"; \
		echo "Or download from: https://github.com/bytecodealliance/wasm-tools/releases"; \
		exit 1; \
	}
	@rustup target list --installed | grep -q "wasm32-wasi" || { \
		echo "$(RED)Error: wasm32-wasi target not installed.$(NC)"; \
		echo "Install with: rustup target add wasm32-wasi"; \
		exit 1; \
	}
	@echo "$(GREEN)✓ WASI dependencies found$(NC)"

# Install dependencies
.PHONY: install-deps
install-deps:
	@echo "$(YELLOW)Installing dependencies...$(NC)"
	@command -v $(CARGO) >/dev/null 2>&1 || { \
		echo "$(RED)Please install Rust first: https://www.rust-lang.org/tools/install$(NC)"; \
		exit 1; \
	}
	@echo "$(CYAN)Installing wasm-tools...$(NC)"
	$(CARGO) install wasm-tools
	@echo "$(CYAN)Installing wasm32-wasi target...$(NC)"
	rustup target add wasm32-wasi
	@echo "$(GREEN)✓ All dependencies installed$(NC)"

# Clean build artifacts
.PHONY: clean
clean:
	$(CARGO) clean
	@echo "$(GREEN)✓ Build artifacts cleaned$(NC)"

.PHONY: clean-wasi
clean-wasi:
	rm -rf $(TARGET_DIR)
	@echo "$(GREEN)✓ WASI build artifacts cleaned$(NC)"

# Test WASI component
.PHONY: test-wasi-component
test-wasi-component: wasi-component-debug
	@echo "$(YELLOW)Running WASI component tests...$(NC)"
	@echo "$(RED)TODO: Implement WASI component tests$(NC)"

# Show component information
.PHONY: wasi-component-info
wasi-component-info:
	@if [ -f "$(TARGET_DIR)/debug/scryer_prolog_component.wasm" ]; then \
		echo "$(CYAN)Debug component info:$(NC)"; \
		$(WASM_TOOLS) component wit $(TARGET_DIR)/debug/scryer_prolog_component.wasm || true; \
	fi
	@if [ -f "$(TARGET_DIR)/wasi-dev/scryer_prolog_component.wasm" ]; then \
		echo "$(CYAN)Dev component info:$(NC)"; \
		$(WASM_TOOLS) component wit $(TARGET_DIR)/wasi-dev/scryer_prolog_component.wasm || true; \
	fi
	@if [ -f "$(TARGET_DIR)/wasi-release/scryer_prolog_component.wasm" ]; then \
		echo "$(CYAN)Release component info:$(NC)"; \
		$(WASM_TOOLS) component wit $(TARGET_DIR)/wasi-release/scryer_prolog_component.wasm || true; \
	fi
