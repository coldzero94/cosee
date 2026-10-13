# Repository Guidelines

## Project Structure & Module Organization

This directory currently contains no application code, tests, or assets. As the project takes shape, place implementation files in `src/`, automated tests in `tests/`, and static assets in `assets/`. Keep related code together by feature and document any different layout in the root `README.md`.

## Build, Test, and Development Commands

No build system or package manager is configured yet. When adding one, document the exact setup, local run, build, and test commands in `README.md`. Prefer commands that work from the repository root, and commit the lockfile or equivalent dependency manifest so others can reproduce the environment. Do not assume `npm test`, `make build`, or another command exists until it has been added.

## Coding Style & Naming Conventions

Follow the conventions of the language and framework chosen for each new module. Use consistent indentation within a file, descriptive names, and one naming pattern for similar files (for example, `user_service.ts` and `order_service.ts`). Add a formatter and linter with the first substantial code change, commit their configuration, and run them before opening a pull request.

## Testing Guidelines

There is no test framework or coverage target yet. Add tests alongside the first behavior they verify, using names that describe the expected outcome. Keep unit tests deterministic and isolate external services. Once a test runner is configured, record its command in `README.md` and ensure it passes before submitting changes.

## Commit & Pull Request Guidelines

This directory has no Git history from which to infer a commit convention. Use short, imperative subjects such as `Add project setup` or `Fix login validation`. Keep commits focused. Pull requests should explain the change, how it was checked, and any setup or migration steps; link relevant issues and include screenshots for visible interface changes.
