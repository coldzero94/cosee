.PHONY: build run test package release format lint

build:
	./scripts/build.sh Debug

run: build
	bash scripts/sign-debug.sh
	open DerivedData/Build/Products/Debug/Cosee.app

test:
	swift test --package-path LocalPackage

package:
	./scripts/package.sh development

release:
	./scripts/package.sh release

format:
	xcrun swift-format format --in-place --recursive Cosee LocalPackage/Sources LocalPackage/Tests

lint:
	xcrun swift-format lint --strict --recursive Cosee LocalPackage/Sources LocalPackage/Tests

.PHONY: audit-runner
audit-runner: build
	mkdir -p artifacts
	bash scripts/sign-debug.sh
	DerivedData/Build/Products/Debug/Cosee.app/Contents/MacOS/Cosee --audit-runner artifacts/runner-audit.json --audit-runner-kind orbit
