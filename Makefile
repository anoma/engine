# EngineSystem Makefile

.PHONY: help docs livebook test compile clean deps check

# Default target
help:
	@echo "EngineSystem Development Commands:"
	@echo ""
	@echo "  📚 Documentation & Tutorials:"
	@echo "    docs        - Generate ExDoc documentation"
	@echo "    livebook    - Start Livebook with the interactive tutorial"
	@echo ""
	@echo "  🔧 Development:"
	@echo "    compile     - Compile the project"
	@echo "    test        - Run tests"
	@echo "    check       - Run quality checks (credo, dialyzer)"
	@echo "    deps        - Get dependencies"
	@echo "    clean       - Clean build artifacts"
	@echo ""
	@echo "  🚀 Quick Start:"
	@echo "    make livebook   # Start the interactive tutorial"
	@echo "    make docs       # Generate documentation"

# Documentation generation
docs:
	@echo "📚 Generating ExDoc documentation..."
	mix docs
	@echo "✅ Documentation generated at doc/index.html"
	@echo "   You can also view it online after publishing to hex.pm"

# Start Livebook with the tutorial
livebook:
	@echo "🚀 Starting Livebook with EngineSystem tutorial..."
	@echo "   The tutorial will open at: http://localhost:8080"
	@echo "   📓 Interactive examples and guided learning ahead!"
	@echo ""
	livebook server README.livemd --open

# Alternative livebook command for systems without livebook installed
livebook-docker:
	@echo "🐳 Starting Livebook via Docker..."
	docker run -p 8080:8080 -v $(PWD):/data livebook/livebook

# Development tasks
compile:
	@echo "🔨 Compiling EngineSystem..."
	mix compile

test:
	@echo "🧪 Running tests..."
	mix test

deps:
	@echo "📦 Getting dependencies..."
	mix deps.get

clean:
	@echo "🧹 Cleaning build artifacts..."
	mix clean
	rm -rf doc/
	rm -rf _build/

# Quality checks
check: credo dialyzer
	@echo "✅ All quality checks completed"

credo:
	@echo "🔍 Running Credo..."
	mix credo

dialyzer:
	@echo "🔬 Running Dialyzer..."
	mix dialyzer

# Setup for new developers
setup: deps compile test docs
	@echo ""
	@echo "🎉 EngineSystem development environment setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  📓 Start learning: make livebook"
	@echo "  📚 View docs: open doc/index.html"
	@echo "  🧪 Run tests: make test"

# Publishing (for maintainers)
publish-docs: docs
	@echo "📤 Publishing documentation to hex.pm..."
	@echo "   Note: This happens automatically when publishing the package"

# Development server (if you want to serve docs locally)
serve-docs: docs
	@echo "🌐 Serving documentation locally..."
	@echo "   Available at: http://localhost:8000"
	cd doc && python -m http.server 8000

# Install development dependencies
dev-deps:
	@echo "🛠️  Installing development dependencies..."
	mix deps.get
	@echo "   Consider installing:"
	@echo "   - Livebook: https://livebook.dev/"
	@echo "   - ExDoc: included in deps"

# Format code
format:
	@echo "💅 Formatting code..."
	mix format

# Run all checks before committing
pre-commit: format compile test credo
	@echo "✅ Pre-commit checks completed successfully!"
	@echo "   Ready to commit! 🚀"