# VS Code Agent Architecture Analysis

**Date**: 2025-11-12
**Source**: [microsoft/vscode](https://github.com/microsoft/vscode)
**Purpose**: Extract best-in-class agent context engineering patterns for integration into Dudley's Second Bedroom

---

## Executive Summary

Microsoft's VS Code repository demonstrates a sophisticated, production-grade approach to GitHub Copilot agent configuration. Their architecture separates concerns across multiple file types, leverages MCP servers strategically, and provides comprehensive context through structured instructions and prompts.

### Key Findings

1. **Multi-layered Configuration System**: Separates global instructions, domain-specific instructions, role-based prompts, and specialized agent definitions
2. **Strategic MCP Server Usage**: Integrates GitHub, Azure DevOps, and custom Playwright MCP servers for domain-specific capabilities
3. **Modular Instruction Pattern**: Domain expertise encoded in reusable `.instructions.md` files that can be applied conditionally
4. **Meta-Learning System**: Self-improving instructions that track usefulness and adapt over time
5. **GitHub Actions Integration**: Dedicated `copilot-setup-steps.yml` workflow for Copilot agent environment preparation

---

## Architecture Overview

### File Structure

```
.github/
├── copilot-instructions.md          # Global repository context
├── agents/                           # Specialized agent definitions
│   └── demonstrate.md               # QA testing agent with MCP integration
├── instructions/                     # Domain-specific patterns & APIs
│   ├── disposable.instructions.md   # IDisposable pattern guidance
│   ├── observables.instructions.md  # Observable pattern guidance
│   ├── telemetry.instructions.md    # Telemetry implementation patterns
│   ├── tree-widgets.instructions.md # Tree widget development guide
│   └── learnings.instructions.md    # Meta-instruction for self-improvement
├── prompts/                          # Task-specific prompt templates
│   ├── build-champ.prompt.md       # Build failure investigation
│   ├── find-issue.prompt.md        # Issue search and discovery
│   ├── setup-environment.prompt.md  # Development environment setup
│   ├── component.prompt.md         # Component documentation generation
│   ├── data.prompt.md              # Telemetry data analysis with Kusto
│   ├── codenotify.prompt.md        # CODENOTIFY file maintenance
│   └── [13 other specialized prompts]
└── workflows/
    └── copilot-setup-steps.yml      # Agent environment preparation
```

---

## Best Practices Identified

### 1. Global Context (`copilot-instructions.md`)

**Pattern**: Single source of truth for repository-wide context

**Key Elements**:
- **Project Overview**: Layered architecture explanation (base → platform → editor → workbench)
- **Root Folder Map**: Clear directory structure with purpose statements
- **Core Architecture**: Dependency injection, contribution model, cross-platform abstractions
- **Validation Requirements**: MANDATORY TypeScript compilation checks before declaring work complete
- **Coding Guidelines**: Comprehensive style guide (tabs vs spaces, naming, comments, UI labels)
- **Finding Related Code**: Strategic guidance (semantic search first, grep for exact strings, follow imports, check tests)
- **Code Quality Rules**: Copyright headers, async/await patterns, localization, test suite organization

**VS Code-Specific Patterns**:
```markdown
## Validating TypeScript changes

MANDATORY: Always check the `VS Code - Build` watch task output via #runTasks/getTaskOutput
for compilation errors before running ANY script or declaring work complete

- NEVER run tests if there are compilation errors
- NEVER use `npm run compile` but call #runTasks/getTaskOutput instead
```

**Adoption for Dudley's Second Bedroom**:
- Document modular build system architecture
- Explain content versioning system
- Define module contract requirements
- Specify validation workflow (just check, tests, build)

---

### 2. Domain-Specific Instructions (`.instructions.md`)

**Pattern**: Reusable knowledge modules that apply to specific code patterns

**Structure** (consistent YAML frontmatter):
```markdown
---
description: Brief description of when to use this instruction
applyTo: ** | path/to/files/**
---

# [Pattern Name]

[Detailed guidance on the pattern]

## Core Symbols
- API reference with brief descriptions

## Usage Patterns
- Code examples and best practices

## Learnings
- Self-improving section (see meta-learning pattern)
```

**Example: `observables.instructions.md`**
- Provides observable pattern API reference
- Code examples with proper usage
- Common pitfalls and solutions
- Important learnings section

**Example: `telemetry.instructions.md`**
- GDPR-compliant telemetry patterns
- Type definitions with classifications
- Required properties and naming conventions
- Critical Don'ts section

**Adoption for Dudley's Second Bedroom**:
Create domain-specific instructions for:
- `module-contract.instructions.md`: Build module pattern guidance
- `content-versioning.instructions.md`: Hook versioning and manifest patterns
- `containerfile.instructions.md`: Multi-stage build patterns
- `shell-scripting.instructions.md`: Bash best practices and conventions

---

### 3. Task-Specific Prompts (`.prompt.md`)

**Pattern**: Executable agent workflows for common developer tasks

**Structure**:
```markdown
---
agent: agent                          # Declares this as an agent prompt
description: 'Task description'       # Shown in UI
tools: ['tool1', 'tool2', 'mcp/*']   # Required tools and MCP servers
model: Claude Sonnet 4.5 (optional)  # Model specification
---

# Role
[Define the agent's role and responsibilities]

# Instructions
[Step-by-step workflow]

# Variables
[Dynamic placeholders]

# Guidelines
[Best practices and constraints]

# Output Format
[Expected deliverable structure]
```

**Standout Examples**:

#### `find-issue.prompt.md` - Intelligent Issue Discovery
- **Multi-strategy search**: Parallel searches with keyword variations
- **Transparent process**: Shows all search queries attempted
- **Context-aware matching**: Verifies component/context alignment, not just keywords
- **Structured output**: Markdown tables with relevance indicators
- **Fallback suggestions**: Provides new issue template if nothing matches

```markdown
## Workflow
1. Interpret Input - Identify specific context (UI component, feature area)
2. Search - Run parallel searches with variations
3. Read & Analyze - Only read full content for top 1-2 matches
4. Display Results - Transparent search log + relevance table
5. Conclude - Context-based recommendations
```

#### `setup-environment.prompt.md` - Automated Dev Setup
- **Documentation aggregation**: Fetches README, CONTRIBUTING, and linked docs
- **Tool verification**: Version checks for all dependencies
- **OS-specific installation**: Uses appropriate package manager (winget, brew, apt, etc.)
- **PATH management**: Handles session and permanent PATH updates
- **Build and run**: Automates first build and launch
- **Documentation updates**: Updates docs with discovered information

#### `data.prompt.md` - Telemetry Data Analysis
- **MCP server installation detection**: Checks for Azure MCP extension
- **Kusto query execution**: Actually runs queries, doesn't just suggest them
- **Time window best practices**: Defaults to 28-day rolling windows
- **Query parallelization**: Runs independent queries concurrently
- **Data exploration patterns**: Uses 1-day samples for quick data shape understanding

**Adoption for Dudley's Second Bedroom**:
Create task prompts for:
- `build-module.prompt.md`: Scaffold new build modules
- `add-wallpaper.prompt.md`: Add and configure custom wallpapers with version bump
- `validate-all.prompt.md`: Run comprehensive validation suite
- `debug-build.prompt.md`: Investigate container build failures
- `update-packages.prompt.md`: Modify packages.json with validation

---

### 4. Specialized Agents (`agents/`)

**Pattern**: Full agent definitions with MCP server integration

**Example: `demonstrate.md` - QA Testing Agent**

**YAML Frontmatter**:
```markdown
---
name: Demonstrate
description: Agent for demonstrating VS Code features
target: github-copilot
tools: ['edit', 'search', 'vscode-playwright-mcp/*', 'github/github-mcp-server/*', 'usages', 'fetch', 'githubRepo', 'todos']
---
```

**Key Patterns**:
- **MCP Server Integration**: Uses `vscode-playwright-mcp` for UI automation, `github-mcp-server` for PR context
- **Structured Workflow**: Setup → Testing → Demonstration → Cleanup phases
- **Tool Preference Guidance**: "Prefer `vscode_automation_*` tools over `browser_*` tools"
- **Monaco Editor Workarounds**: Detailed instructions for VS Code's custom editor interactions
- **Context Gathering**: Retrieves PR details, searches docs, examines commits
- **Mandatory Cleanup**: Always calls `vscode_automation_stop` regardless of outcome

**MCP Server Usage Pattern**:
```markdown
## GitHub MCP Tools

**Prefer using GitHub MCP tools over `gh` CLI commands**

### Pull Request Tools
- `pull_request_read` - Get PR details, diff, status, files, reviews
  - Use `method="get"` for PR metadata
  - Use `method="get_diff"` for full diff
  - Use `method="get_files"` for changed files list
```

**Adoption for Dudley's Second Bedroom**:
Consider creating specialized agents for:
- `build-verification.agent.md`: Container build testing and validation
- `package-management.agent.md`: Intelligent package.json modification
- `documentation.agent.md`: Auto-generate docs from code and modules

---

### 5. Meta-Learning System (`learnings.instructions.md`)

**Pattern**: Self-improving instructions that track usefulness

**Structure**:
```markdown
---
applyTo: **
description: Meta instruction for managing learnings
---

## Learnings
* Prefer `const` over `let` whenever possible (1)
* Avoid `any` type (3)
* [Each learning has a counter indicating usefulness]
```

**Workflow**:
1. User says "learn!"
2. Agent identifies the problem created
3. Agent determines why it was a problem
4. Agent creates a 1-4 sentence learning
5. Learning added to appropriate instruction file
6. Counter increased when learning proves useful
7. Counter decreased if learning causes problems

**Value**: Creates a feedback loop for continuous improvement of agent behavior

**Adoption for Dudley's Second Bedroom**:
- Add learnings section to all instruction files
- Track common mistakes in module development
- Document shell scripting pitfalls
- Record successful validation patterns

---

### 6. MCP Server Integration Patterns

**Discovery**: VS Code uses MCP servers sparingly but strategically

**MCP Servers Identified**:
1. **`github/github-mcp-server/*`**: GitHub API operations (PRs, issues, commits, searches)
2. **`microsoft/azure-devops-mcp/*`**: Azure DevOps integration (pipelines, work items)
3. **`vscode-playwright-mcp/*`**: VS Code UI automation for testing
4. **`Azure MCP/kusto_query`**: Telemetry data analysis

**Integration Pattern in Agent Definitions**:
```markdown
---
tools: ['edit', 'search', 'github/github-mcp-server/*', 'todos']
---

## GitHub MCP Tools

**Prefer using GitHub MCP tools over `gh` CLI commands** - these provide
structured data and better integration

### Tool Selection Guidance
1. Use 'list_*' tools for broad retrieval and pagination
2. Use 'search_*' tools for targeted queries with specific criteria

### Best Practices
- Use pagination with batches of 5-10 items
- Use minimal_output parameter when full info not needed
- Always call 'get_me' first to understand context
```

**Anti-Pattern Noted**: No evidence of MCP server usage in GitHub Actions workflows - these remain pure bash/YAML

**Adoption for Dudley's Second Bedroom**:
- **Keep existing GitHub MCP integration** in agents and prompts
- **Add MCP servers for**:
  - Container registry inspection
  - OSTree repository queries
  - Flatpak repository management
- **Document MCP tool preferences** in agent definitions
- **Avoid MCP in GitHub Actions** - stick with shell scripts

---

### 7. GitHub Actions Setup (`copilot-setup-steps.yml`)

**Pattern**: Dedicated workflow for preparing Copilot agent environment

**Key Characteristics**:
- **Special job name**: MUST be called `copilot-setup-steps` for discovery
- **Minimal permissions**: `contents: read` only (Copilot gets separate token)
- **Automatic checkout**: If you don't clone, Copilot does it after steps
- **Full environment setup**: Dependencies, caching, build tools, test infrastructure
- **System services**: X server, display setup, service initialization

**Structure**:
```yaml
name: "Copilot Setup Steps"

on:
  workflow_dispatch:
  push:
    paths:
      - .github/workflows/copilot-setup-steps.yml
  pull_request:
    paths:
      - .github/workflows/copilot-setup-steps.yml

jobs:
  copilot-setup-steps:  # MUST use this exact name
    runs-on: vscode-large-runners
    permissions:
      contents: read  # Minimal permissions
    steps:
      - name: Checkout
        uses: actions/checkout@v5
      - name: Setup Node.js
        uses: actions/setup-node@v6
      # ... full dependency installation
      # ... caching strategies
      # ... build artifacts preparation
```

**Adoption for Dudley's Second Bedroom**:
Create `.github/workflows/copilot-setup-steps.yml` with:
- Containerfile validation
- Module validation
- Package.json validation
- Test suite setup
- Build tools preparation (podman/docker, just, shellcheck, shfmt)

---

### 8. Frontmatter Metadata Standards

**Pattern**: Consistent YAML frontmatter for agent discovery and configuration

**Instruction Files**:
```yaml
---
description: Brief description of when to use
applyTo: path/pattern/**
---
```

**Prompt Files**:
```yaml
---
agent: agent
description: 'User-facing description'
tools: ['tool1', 'mcp/server/*']
model: Claude Sonnet 4.5 (optional)
---
```

**Agent Files**:
```yaml
---
name: Agent Name
description: Purpose and role
target: github-copilot
tools: ['edit', 'search', 'mcp/*', 'todos']
---
```

**Benefits**:
- Machine-readable configuration
- Consistent discovery mechanism
- Clear tool dependencies
- Explicit target platform

**Adoption for Dudley's Second Bedroom**:
- Standardize frontmatter across all agent config files
- Add `applyTo` patterns for module-specific instructions
- Document tool dependencies explicitly
- Enable conditional instruction loading

---

## Detailed File Analysis

### Global Instructions: `copilot-instructions.md`

**Length**: 7,080 bytes
**Structure**: 9 major sections

**Section Breakdown**:

1. **Project Overview** (Architecture context)
   - Root folder explanation
   - Core architecture layers (base → platform → editor → workbench)
   - Principles: DI, contribution model, cross-platform

2. **Validating TypeScript Changes** (Critical workflow)
   - Mandatory compilation check before declaring work complete
   - Never run tests with compilation errors
   - Use task output monitoring, not direct `npm run compile`

3. **Coding Guidelines** (Style and conventions)
   - Indentation: Tabs, not spaces
   - Naming: PascalCase types, camelCase functions/properties
   - Types: Don't export unnecessarily, avoid global namespace pollution
   - Comments: JSDoc for public APIs
   - Strings: Double quotes for localized, single quotes otherwise
   - UI Labels: Title-case capitalization rules

4. **Style** (Code patterns)
   - Arrow functions over anonymous functions
   - Minimal arrow function parentheses
   - Curly braces for conditionals/loops
   - Whitespace rules
   - Prefer top-level `export function` over `export const` for stack traces

5. **Code Quality** (Requirements)
   - Microsoft copyright header
   - Async/await over Promise chains
   - Localization for user-facing messages
   - Proper test suite organization
   - Clean up temporary files
   - Avoid `any`/`unknown`
   - No duplicate imports
   - Named regex capture groups

**Adoption Recommendations**:
- Create similar comprehensive guide for Dudley's Second Bedroom
- Include module contract requirements
- Document shell scripting standards
- Explain content versioning system

---

### Instruction Files Analysis

#### `disposable.instructions.md` (890 bytes)
**Purpose**: IDisposable pattern guidance
**Core Symbols**: `IDisposable`, `Disposable`, `DisposableStore`, `MutableDisposable`, `toDisposable`
**Pattern**: Short, reference-style with core APIs and usage notes

#### `observables.instructions.md` (3,177 bytes)
**Purpose**: Observable and derived pattern guidance
**Structure**:
- Complete example class showing all patterns
- Core symbols with usage
- Important learnings section (glitches, observable types, event patterns)
**Pattern**: Code-heavy with annotated examples

#### `telemetry.instructions.md` (4,326 bytes)
**Purpose**: GDPR-compliant telemetry implementation
**Structure**:
- Implementation pattern (define types → send event → service injection)
- Classification & purposes (SystemMetaData, CallstackOrException, FeatureInsight, PerformanceAndHealth)
- Naming & privacy rules
- Critical Don'ts section
**Pattern**: Compliance-focused with code templates

#### `tree-widgets.instructions.md` (6,940 bytes)
**Purpose**: Comprehensive guide to VS Code tree widget development
**Structure**:
- Location and architecture overview
- Scope (included/excluded/integration points)
- Key classes and files
- Development guidelines with choosing the right widget
- Construction patterns
- Lifecycle management
- Performance considerations
**Pattern**: Full architectural document with decision frameworks

#### `learnings.instructions.md` (1,171 bytes)
**Purpose**: Meta-instruction for managing learnings
**Structure**:
- Learning structure definition
- Example format
- Workflow when user says "learn!"
- Counter increment/decrement rules
**Pattern**: Meta-level instruction for instruction evolution

**Key Insight**: Instructions range from brief API references (disposables) to comprehensive architectural guides (tree-widgets). All share:
- Clear frontmatter with `description`
- Code examples or symbol references
- Optional learnings section
- Conditional application via `applyTo`

---

### Prompt Files Analysis

#### `build-champ.prompt.md` (2,827 bytes)
**Role**: Build champion for VS Code team
**Tools**: `github/github-mcp-server/*`, `microsoft/azure-devops-mcp/*`, `todos`
**Workflow**:
1. Display warning about known issues
2. Investigate failing jobs (prioritize unit tests)
3. Find successful build before failure
4. Identify merged PRs in range
5. Analyze PR changes
6. Draft message with URLs and possible root causes
7. Suggest rerun if no obvious cause

**Notable**: Includes warning message about agent limitations - transparent about known issues

#### `find-issue.prompt.md` (4,503 bytes)
**Role**: GitHub issue investigator
**Tools**: `github/github-mcp-server/issue_read`, `list_issues`, `search_issues`, `runSubagent`
**Model**: Claude Sonnet 4.5
**Workflow**:
1. Interpret input - identify context and component
2. Search - parallel searches with keyword variations
3. Read & Analyze - only read top 1-2 matches
4. Display results - transparent search log + table
5. Conclude - recommend or suggest new issue

**Notable**: Emphasizes context matching ("UI component", "file type", "workflow step") over keyword matching

#### `setup-environment.prompt.md` (4,547 bytes)
**Role**: Setup automation assistant
**Tools**: `runCommands`, `runTasks/runTask`, `search`, `todos`, `fetch`
**Workflow**: 10-step comprehensive setup
1. Find setup instructions
2. Show required tools list
3. Verify installed tools
4. Display summary (installed/missing/unable to verify)
5. Install missing tools (OS-specific package managers)
6. Show installation summary
7. Build repository
8. Run application
9. Show recap
10. Update documentation

**Notable**: Heavy emphasis on automation - "execute them directly" not "display commands"

#### `component.prompt.md` (2,535 bytes)
**Role**: Component documentation generator
**Tools**: `edit`, `search`, `usages`, `vscodeAPI`, `fetch`, `extensions`, `todos`
**Output Format**: Structured markdown with Purpose, Scope, Architecture, Key Classes, Key Files, Development Guidelines
**Pattern**: Creates `.components/[name].md` files for agent context

#### `data.prompt.md` (2,759 bytes)
**Role**: Azure Data Explorer analyst
**Tools**: `search`, `runCommands/runInTerminal`, `Azure MCP/kusto_query`, `githubRepo`, `extensions`, `todos`
**Workflow**:
1. Read telemetry documentation
2. Execute Kusto queries (not just describe)
3. Format and present results

**Notable**: Strong emphasis on actually running queries with best practices (time windows, aggregation, parallel execution)

#### `codenotify.prompt.md` (3,510 bytes)
**Role**: CODENOTIFY file maintenance
**Tools**: `edit`, `search`, `runCommands`, `fetch`, `todos`
**Workflow**:
1. User provides GitHub handle and aliases
2. Search git blame history
3. Analyze contributions
4. Follow existing structure in CODENOTIFY
5. Add entries to appropriate sections
6. Maintain alphabetical order

**Notable**: Detailed path-to-section mapping examples for proper categorization

**Common Patterns Across Prompts**:
- Todo list integration for progress tracking
- Structured output formats with examples
- Transparent process logging
- OS/context awareness
- Tool preference guidance (MCP over CLI)
- Failure handling and fallback strategies

---

## Integration Recommendations for Dudley's Second Bedroom

### Priority 1: Foundation

#### 1.1 Create Global Instructions
**File**: `.github/copilot-instructions.md`

**Content**:
```markdown
# Dudley's Second Bedroom Copilot Instructions

## Project Overview

Dudley's Second Bedroom is a custom Fedora Atomic (OSTree) image built on Universal Blue's
base image. The project uses a modular build system with content versioning for intelligent
updates and a user hook system for first-boot customization.

### Root Folders
- `build_files/`: Build-time module system
  - `shared/`: Core build utilities and services
  - `desktop/`: Desktop environment customization
  - `developer/`: Developer tools and CLI setup
  - `user-hooks/`: First-boot user setup hooks
- `system_files/`: Runtime configuration files deployed to image
- `custom_wallpapers/`: Wallpaper assets with content-based versioning
- `tests/`: Validation suite for modules, packages, and content versioning
- `specs/`: Architecture specifications and implementation plans

### Core Architecture

- **Modular Build System**: Auto-discovered modules with standard headers
- **Content Versioning**: Hash-based detection of changes requiring hook re-runs
- **Manifest Generation**: Build-time manifest with metadata for runtime inspection
- **Package Management**: Declarative packages.json with conflict detection
- **Testing Framework**: Module validation, package validation, build verification

## Validating Changes

MANDATORY: Always run validation before declaring work complete:

```bash
just check  # Runs all validation (syntax, lint, package and module checks)
```

- NEVER modify modules without running `tests/validate-modules.sh`
- NEVER modify packages.json without running `just validate-packages`
- ALWAYS run `just lint` after shell script changes
- ALWAYS run `just format` to apply consistent formatting

## Module Development Guidelines

[Include module contract requirements]
[Document standard headers]
[Explain execution order]
[Shell scripting best practices]

## Content Versioning System

[Explain hash computation]
[Document placeholder replacement]
[Hook gating mechanism]
[Manifest structure]

## Coding Guidelines

[Shell script style]
[JSON formatting]
[Markdown conventions]
[Commit message format]
```

#### 1.2 Create Domain Instructions

**Files to Create**:

**`.github/instructions/module-contract.instructions.md`**:
```markdown
---
description: Guidelines for creating build modules
applyTo: build_files/**/*.sh
---

# Build Module Contract

## Required Header
Every module must include:
```bash
#!/usr/bin/env bash
# Purpose: [Brief description]
# Category: [shared|desktop|developer|user-hooks]
# Dependencies: [comma-separated list or 'none']
# Parallel-Safe: [yes|no]
# Cache-Friendly: [yes|no]
set -euo pipefail  # Required for error handling

[MODULE:category/filename]  # Standard log prefix
```

## Core Patterns
- Use standard error exit code: `exit 2` for intentional skips
- Log with `[MODULE:category/name]` prefix
- Source utilities from `build_files/shared/utils/`, don't execute
- Alphabetical execution within category
- Test with `tests/validate-modules.sh`

## Learnings
[To be populated as learnings are captured]
```

**`.github/instructions/content-versioning.instructions.md`**:
```markdown
---
description: Hook versioning and content hash system
applyTo: build_files/user-hooks/**
---

# Content Versioning System

## Hook Version Placeholders
[Explain __CONTENT_VERSION__ pattern]

## Adding New Dependency to Hook
[Show `generate-manifest.sh` modification pattern]

## Computing Content Hash
[Document `compute_content_hash` function usage]

## Learnings
[To be populated]
```

**`.github/instructions/shell-scripting.instructions.md`**:
```markdown
---
description: Shell scripting standards and best practices
applyTo: **/*.sh
---

# Shell Scripting Standards

## Required Headers
- Shebang: `#!/usr/bin/env bash`
- Error handling: `set -euo pipefail`
- Optional debug: `set -x`

## Logging Standards
- Module logs: `[MODULE:category/name]`
- Utility logs: `[UTIL:utility-name]`
- Error logs: `[ERROR]` prefix

## Common Pitfalls
[Document shell-specific learnings]

## Validation
- Run `just lint` (shellcheck)
- Run `just format` (shfmt)
- Test with `bash -n script.sh` (syntax check)

## Learnings
[To be populated]
```

### Priority 2: Task Automation

#### 2.1 Create Task Prompts

**`.github/prompts/build-module.prompt.md`**:
```markdown
---
agent: agent
description: 'Scaffold a new build module'
tools: ['edit', 'search', 'runCommands', 'todos']
---

# Role
You are a build module scaffolding assistant for Dudley's Second Bedroom.

# Instructions
1. Ask user for module details (purpose, category, dependencies, parallel-safe)
2. Validate category (shared/desktop/developer/user-hooks)
3. Generate module file with standard header
4. Create module in appropriate directory
5. Run `tests/validate-modules.sh` to verify
6. Add any necessary utilities to `build_files/shared/utils/`
7. Update documentation if needed

# Module Template
[Include standard module template]

# Guidelines
- Alphabetical ordering determines execution within category
- Use descriptive names: `10-install-packages.sh` not `packages.sh`
- Always include comprehensive header
- Test before declaring complete
```

**`.github/prompts/add-wallpaper.prompt.md`**:
```markdown
---
agent: agent
description: 'Add custom wallpaper with version bump'
tools: ['edit', 'search', 'runCommands', 'todos']
---

# Role
You are a wallpaper management assistant that handles adding wallpapers with
proper content versioning.

# Instructions
1. Accept wallpaper file from user
2. Validate image format (jpg, png, etc.)
3. Copy to `custom_wallpapers/` directory
4. Trigger content hash recomputation (build will handle)
5. Explain that new hash will trigger wallpaper hook on next boot
6. Optionally update wallpaper list in wallpaper enforcement hook

# Guidelines
- Content hash includes all image bytes
- Hook version will auto-increment on build
- No manual version updates needed
```

**`.github/prompts/validate-all.prompt.md`**:
```markdown
---
agent: agent
description: 'Run comprehensive validation suite'
tools: ['runCommands', 'todos', 'search']
---

# Role
You are a comprehensive validation orchestrator for Dudley's Second Bedroom.

# Instructions
1. Run `just check` to execute all validations
2. If failures occur:
   a. Parse output to identify specific issues
   b. Run targeted validation for failed component
   c. Provide actionable remediation steps
3. Display summary of all checks:
   - Syntax validation (Containerfile, JSON, shell scripts)
   - Lint checks (shellcheck)
   - Module validation
   - Package validation
4. Only declare success when all checks pass

# Validation Components
- `just lint`: shellcheck for all shell scripts
- `just validate-packages`: packages.json integrity
- `tests/validate-modules.sh`: module contract compliance
- `tests/validate-containerfile.sh`: Containerfile syntax
```

**`.github/prompts/debug-build.prompt.md`**:
```markdown
---
agent: agent
description: 'Investigate container build failures'
tools: ['search', 'runCommands', 'fetch', 'todos']
---

# Role
You are a container build debugging specialist for Dudley's Second Bedroom.

# Instructions
1. Ask user for build log or error message
2. Identify failing stage (ctx, base) and module
3. Search for similar issues in recent commits
4. Check common failure points:
   - Module dependency order
   - Missing utilities
   - Package conflicts in packages.json
   - Content versioning placeholders
5. Provide remediation steps with explanation
6. Suggest validation to run before retry

# Common Failure Patterns
- Module exits with non-2 code: Check error handling
- Package conflicts: Run `just validate-packages`
- Utility not found: Check sourcing vs execution
- Content hash issues: Verify placeholder format
```

#### 2.2 Create GitHub Actions Setup

**`.github/workflows/copilot-setup-steps.yml`**:
```yaml
name: "Copilot Setup Steps"

on:
  workflow_dispatch:
  push:
    paths:
      - .github/workflows/copilot-setup-steps.yml
  pull_request:
    paths:
      - .github/workflows/copilot-setup-steps.yml

jobs:
  copilot-setup-steps:
    runs-on: ubuntu-latest

    permissions:
      contents: read

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install build tools
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            podman \
            shellcheck \
            jq

      - name: Install Just command runner
        uses: extractions/setup-just@v2

      - name: Install shfmt
        run: |
          go install mvdan.cc/sh/v3/cmd/shfmt@latest

      - name: Validate modules
        run: tests/validate-modules.sh

      - name: Validate packages
        run: just validate-packages

      - name: Run linting
        run: just lint

      - name: Run all validations
        run: just check
```

### Priority 3: Advanced Features

#### 3.1 Self-Improving Instructions

Add learnings sections to all instruction files:

**Example for `module-contract.instructions.md`**:
```markdown
## Learnings
* Always use `exit 2` for intentional skips, not `exit 0` (3)
  - exit 0 indicates success, might mask issues
  - exit 2 is recognized by orchestrator as intentional skip
* Source utilities don't need execute permission (2)
  - Utilities under `utils/` are sourced, not executed
  - Only module scripts need +x permission
* Parallel-safe requires no shared state (1)
  - No writing to same files
  - No modifying global system state
  - Independent operations only
```

#### 3.2 Specialized Agent (Optional)

If UI testing becomes relevant:

**`.github/agents/test-build.md`**:
```markdown
---
name: Build Verification
description: Agent for testing container builds end-to-end
target: github-copilot
tools: ['edit', 'search', 'runCommands', 'github/github-mcp-server/*', 'todos']
---

# Role and Objective
You are a container build verification agent. Your task is to build the image,
verify its contents, and report any issues.

# Core Requirements
## Build Phase
1. Run `just build` to build container
2. Monitor build logs for warnings/errors
3. Verify all modules executed successfully

## Verification Phase
1. Run `tests/verify-build.sh <image:tag>`
2. Check manifest presence at `/etc/dudley/build-manifest.json`
3. Verify content hashes match expectations
4. Run `dudley-build-info` CLI to inspect build

## Reporting Phase
1. Summarize build success/failure
2. List any warnings or issues
3. Provide remediation steps if needed
```

### Priority 4: MCP Server Strategy

**Recommended Approach**: Conservative adoption

**Current MCP Servers to Keep**:
- GitHub MCP Server (already configured in prompts)

**Potential Future MCP Servers** (only if needed):
- **Container Registry MCP**: Inspect published images, tags, metadata
- **OSTree MCP**: Query OSTree repository, inspect commits
- **Flatpak MCP**: Manage flatpak refs, inspect manifests

**Anti-Pattern to Avoid**:
- Don't use MCP in GitHub Actions workflows
- Keep build process pure shell/containerfile
- MCP is for interactive agent workflows only

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Create `.github/copilot-instructions.md` with comprehensive context
- [ ] Create 3 core instruction files:
  - [ ] `module-contract.instructions.md`
  - [ ] `content-versioning.instructions.md`
  - [ ] `shell-scripting.instructions.md`
- [ ] Add learnings sections (empty initially)

### Phase 2: Automation (Week 2)
- [ ] Create 4 task prompts:
  - [ ] `build-module.prompt.md`
  - [ ] `add-wallpaper.prompt.md`
  - [ ] `validate-all.prompt.md`
  - [ ] `debug-build.prompt.md`
- [ ] Test each prompt with real scenarios
- [ ] Refine based on feedback

### Phase 3: CI Integration (Week 3)
- [ ] Create `.github/workflows/copilot-setup-steps.yml`
- [ ] Test workflow execution
- [ ] Document workflow purpose in README

### Phase 4: Iteration (Ongoing)
- [ ] Use prompts regularly and capture learnings
- [ ] Update instructions with learned patterns
- [ ] Increment usefulness counters
- [ ] Add new prompts as patterns emerge

---

## Metrics for Success

### Quantitative
- **Reduction in validation errors**: Track before/after validation failure rate
- **Time to create new module**: Measure with build-module prompt
- **Build failure diagnosis time**: Track debug-build prompt effectiveness

### Qualitative
- **Agent accuracy**: Does agent follow module contract correctly?
- **Learning retention**: Are learnings actually preventing repeat mistakes?
- **Prompt clarity**: Do agents execute prompts without confusion?

---

## Key Takeaways

### What VS Code Does Exceptionally Well

1. **Layered Context System**: Global → Domain → Task provides right level of detail at right time
2. **MCP Server Integration**: Strategic, not gratuitous - used where truly valuable
3. **Self-Improvement**: Meta-learning system creates feedback loop
4. **Transparency**: Agents show their work (search logs, validation steps)
5. **Comprehensive Coverage**: Instructions for patterns, prompts for tasks, agents for workflows
6. **Frontmatter Standards**: Machine-readable metadata enables sophisticated tooling

### What to Adopt Immediately

1. **Global copilot-instructions.md**: Single source of truth
2. **Modular instruction files**: Reusable domain expertise
3. **Task-specific prompts**: Executable workflows for common tasks
4. **Validation requirements**: Mandatory checks before work complete
5. **Learnings sections**: Capture and codify experience

### What to Defer or Skip

1. **Specialized agents**: Create only if complex workflows emerge
2. **Additional MCP servers**: Current GitHub MCP sufficient for now
3. **GitHub Actions MCP integration**: Keep workflows pure shell/YAML
4. **Over-engineering**: Start simple, add complexity as needed

---

## Appendix: Full File List from VS Code

### Agents (1 file)
- `demonstrate.md` - QA testing agent with Playwright + GitHub MCP

### Instructions (5 files)
- `disposable.instructions.md` - IDisposable pattern
- `learnings.instructions.md` - Meta-instruction for learning capture
- `observables.instructions.md` - Observable pattern
- `telemetry.instructions.md` - GDPR-compliant telemetry
- `tree-widgets.instructions.md` - Tree widget development

### Prompts (14 files)
- `build-champ.prompt.md` - Build failure investigation
- `codenotify.prompt.md` - CODENOTIFY maintenance
- `component.prompt.md` - Component documentation
- `data.prompt.md` - Telemetry data analysis
- `doc-comments.prompt.md` - Documentation comment generation
- `find-issue.prompt.md` - Issue search and discovery
- `fixIssueNo.prompt.md` - Fix issue number references
- `implement.prompt.md` - Feature implementation
- `no-any.prompt.md` - Remove TypeScript `any` types
- `plan-deep.prompt.md` - Deep planning for complex features
- `plan-fast.prompt.md` - Quick planning for simple tasks
- `plan.prompt.md` - General planning
- `setup-environment.prompt.md` - Development environment setup
- `update-instructions.prompt.md` - Update instruction files

### Other Configuration
- `copilot-instructions.md` - Global repository context
- `workflows/copilot-setup-steps.yml` - Agent environment preparation

---

## References

- [VS Code Repository](https://github.com/microsoft/vscode)
- [Universal Blue Documentation](https://universal-blue.org/)
- [GitHub Copilot Workspace Documentation](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-workspace)
- [Model Context Protocol](https://modelcontextprotocol.io/)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-12
**Author**: AI Analysis of microsoft/vscode repository
