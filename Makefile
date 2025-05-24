.PHONY: install deps compile test livebook

# Default target
all: deps compile

# Compile the project
compile:
	mix compile

# Run tests
test:
	mix test

# Format code
format:
	@echo "Formatting code..."
	@mix format

# Check if code is properly formatted
check.format:
	@echo "Checking code format..."
	@mix format --check-formatted

# Run linting
lint: deps
	@echo "Running linter..."
	@mix credo --strict

# Run all checks
check: check.format
	@echo "Running compilation check..."
	@mix compile --warnings-as-errors

# Generate documentation
docs:
	@echo "Generating documentation..."
	@mix docs

# Install dependencies
deps:
	@echo "Installing dependencies..."
	@mix deps.get

# Update dependencies
deps.update:
	@echo "Updating dependencies..."
	@mix deps.update --all 

# Ensure notebooks directory exists
ensure-notebooks-dir:
	@mkdir -p notebooks

# Install Livebook if not already installed
install-livebook:
	@if ! ls ~/.mix/escripts/livebook >/dev/null 2>&1; then \
		echo "Installing Livebook..."; \
		mix escript.install hex livebook --force; \
	else \
		echo "Livebook is already installed."; \
	fi

# Start Livebook with the engine examples notebook
livebook: install-livebook ensure-notebooks-dir
	@echo "Starting Livebook..."
	@~/.mix/escripts/livebook server

# Start Livebook in detached mode (background)
livebook-detached: install-livebook ensure-notebooks-dir
	@echo "Starting Livebook in the background..."
	@~/.mix/escripts/livebook server --no-auto-shutdown &

# Start Livebook with notebooks directory as home
livebook-home: install-livebook ensure-notebooks-dir
	@echo "Starting Livebook with notebooks directory as home..."
	@~/.mix/escripts/livebook server --home notebooks

# Help target
help:
	@echo "Available targets:"
	@echo "  deps              - Install dependencies"
	@echo "  compile           - Compile the project"
	@echo "  test              - Run tests"
	@echo "  install-livebook  - Install Livebook if not already installed"
	@echo "  livebook          - Start Livebook"
	@echo "  livebook-detached - Start Livebook in detached mode"
	@echo "  livebook-home     - Start Livebook with notebooks directory as home"
	@echo "  help              - Show this help" 