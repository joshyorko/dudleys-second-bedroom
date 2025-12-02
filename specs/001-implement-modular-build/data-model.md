# Data Model: Modular Build System

**Feature**: Modular Build Architecture
**Date**: 2025-10-05

## Core Entities

### 1. Build Module

**Description**: A self-contained unit of build functionality with clear inputs, outputs, and dependencies.

**Attributes**:
- `name` (string): Unique identifier (e.g., "shared/package-install")
- `path` (string): Absolute path to script file
- `category` (enum): Category type - shared | desktop | developer | user-hooks
- `dependencies` (array[string]): List of module names this depends on
- `parallel_safe` (boolean): Can run in parallel with other modules
- `execution_order` (integer): Relative execution priority (lower = earlier)
- `description` (string): Human-readable purpose
- `author` (string): Maintainer contact
- `last_updated` (date): Last modification date

**Validation Rules**:
- Name MUST match file path pattern
- Dependencies MUST reference existing modules
- Circular dependencies MUST be detected and rejected
- Category MUST match directory structure

**State Transitions**:
```
pending → running → [completed | failed | skipped]
```

**Relationships**:
- Has many: Dependencies (other Build Modules)
- Produces: Build Artifacts
- Consumes: Configuration Files

---

### 2. Package Configuration

**Description**: JSON-based definition of all packages to install or remove.

**Attributes**:
- `category` (string): Scope - "all" | Fedora version number
- `install` (array[string]): Package names to install
- `remove` (array[string]): Package names to remove/exclude
- `install_overrides` (object): Version-specific package substitutions
- `copr_repos` (array[string]): COPR repositories to enable

**Validation Rules**:
- JSON syntax MUST be valid
- Package names MUST NOT be empty strings
- No duplicate packages across install/remove lists
- COPR repos MUST be in format "owner/repo"

**Schema**:
```json
{
  "type": "object",
  "properties": {
    "all": {
      "type": "object",
      "properties": {
        "install": {"type": "array", "items": {"type": "string", "minLength": 1}},
        "remove": {"type": "array", "items": {"type": "string", "minLength": 1}}
      }
    },
    "41": {"$ref": "#/properties/all"}
  }
}
```

**Relationships**:
- Used by: package-install.sh module
- Validated by: validation.sh utility

---

### 3. Build Stage

**Description**: A phase in the multi-stage Containerfile with specific caching behavior.

**Attributes**:
- `name` (string): Stage identifier (context, base, cleanup)
- `from_image` (string): Base image or previous stage
- `cache_strategy` (enum): none | bind | cache | both
- `modules` (array[Build Module]): Modules executed in this stage
- `layer_count` (integer): Number of RUN commands (impacts cache)
- `estimated_duration` (duration): Expected build time

**Validation Rules**:
- Stage names MUST be unique within Containerfile
- from_image MUST reference existing stage or valid image
- Cache strategy MUST be appropriate for stage purpose

**State Transitions**:
```
queued → building → [cached | built | failed]
```

**Relationships**:
- Contains: Build Modules
- Depends on: Previous Build Stage (if not FROM scratch)
- Produces: Container Layer

---

### 4. System File Deployment

**Description**: Static configuration files copied to specific system locations.

**Attributes**:
- `source_path` (string): Path in repository
- `target_path` (string): Destination in container image
- `permissions` (octal): File permissions (e.g., 0644)
- `owner` (string): File owner (typically root)
- `category` (enum): etc | usr | opt
- `backup_required` (boolean): Whether to backup existing file

**Validation Rules**:
- Source path MUST exist in repository
- Target path MUST be absolute
- Permissions MUST be valid octal (000-777)
- Target path MUST NOT conflict with package-managed files

**Relationships**:
- Managed by: branding.sh or gnome-customizations.sh
- Organized by: system_files/ directory structure

---

### 5. Build Validation

**Description**: Automated checks verifying build configuration correctness.

**Attributes**:
- `type` (enum): syntax | configuration | integration
- `target` (string): What's being validated (file path, module, entire build)
- `severity` (enum): error | warning
- `validator` (string): Tool or script performing validation
- `error_message` (string): Human-readable failure description
- `remediation` (string): How to fix the issue

**Validation Rules**:
- Errors MUST block build execution
- Warnings MAY allow override with explicit flag
- Each validator MUST have clear pass/fail criteria

**State Transitions**:
```
queued → running → [passed | failed]
```

**Relationships**:
- Validates: Build Modules, Configuration Files, Build Stages
- Executed by: validation.sh utility, pre-commit hooks, CI/CD

---

### 6. Build Cache

**Description**: Reusable artifacts from previous builds.

**Attributes**:
- `cache_key` (string): Hash of dependencies (files, vars, base image)
- `cache_type` (enum): layer | mount | artifact
- `size_bytes` (integer): Cache storage size
- `created_at` (timestamp): When cached
- `last_used` (timestamp): Most recent cache hit
- `hit_rate` (float): Percentage of builds using this cache

**Validation Rules**:
- Cache key MUST change when dependencies change
- Stale caches (> 30 days unused) MAY be purged
- Cache size MUST NOT exceed configured limits

**State Transitions**:
```
valid → [hit | miss | invalidated | purged]
```

**Relationships**:
- Associated with: Build Stage, Build Module
- Managed by: Container runtime (podman/docker)

---

### 7. Cleanup Specification

**Description**: Rules defining what to remove for image size optimization.

**Attributes**:
- `target_pattern` (string): File glob pattern to match
- `category` (enum): cache | temp | log | repo | artifact
- `required_recreate` (boolean): Whether to recreate directory after deletion
- `recreate_permissions` (octal): Permissions for recreated directory
- `size_impact` (string): Estimated size savings

**Validation Rules**:
- Target patterns MUST NOT match critical system files
- Recreate permissions MUST be correct for directory purpose (e.g., 1777 for /tmp)

**Examples**:
```
/var/cache/dnf*         → category: cache, recreate: false
/tmp/*                  → category: temp, recreate: true (1777)
/var/log/*              → category: log, recreate: true (0755)
/etc/yum.repos.d/*.repo → category: repo, recreate: false (set enabled=0)
```

**Relationships**:
- Executed by: cleanup.sh module
- Applied in: Final build stage

---

## Entity Relationships Diagram

```
┌─────────────────┐
│  Build Module   │
└────────┬────────┘
         │ contains
         ▼
┌─────────────────┐      validates      ┌──────────────────┐
│  Build Stage    │◄─────────────────────│Build Validation │
└────────┬────────┘                      └──────────────────┘
         │ produces                                │
         ▼                                         │ validates
┌─────────────────┐                                │
│  Build Cache    │                                ▼
└─────────────────┘                      ┌──────────────────┐
                                         │Package Config    │
                                         └──────────────────┘
┌─────────────────┐
│System File      │      deployed by     ┌──────────────────┐
│Deployment       │◄─────────────────────│  Build Module    │
└─────────────────┘                      └──────────────────┘

┌─────────────────┐
│Cleanup Spec     │      executed by     ┌──────────────────┐
└─────────────────┘◄─────────────────────│  Build Module    │
                                         └──────────────────┘
```

---

## Data Flows

### 1. Build Execution Flow
```
1. Load Package Configuration (JSON)
   → Validate schema
   → Parse install/remove lists

2. Discover Build Modules
   → Scan directories
   → Parse dependencies
   → Build execution DAG

3. Execute Build Stages
   → Check cache validity
   → Run modules (parallel where safe)
   → Log progress

4. Apply System File Deployments
   → Copy to target locations
   → Set permissions

5. Run Cleanup Specification
   → Remove artifacts
   → Recreate required directories

6. Generate Build Cache
   → Commit container layers
   → Store metadata
```

### 2. Validation Flow
```
1. Pre-build Validation
   → Syntax check (shellcheck, jq)
   → Configuration validation (JSON schema)
   → Dependency verification

2. Build-time Validation
   → Module execution monitoring
   → Error detection and reporting
   → Artifact presence checks

3. Post-build Validation
   → Image size verification
   → Functional smoke tests
   → OSTree commit integrity
```

### 3. Cache Invalidation Flow
```
1. Calculate cache keys
   → Hash file contents
   → Include environment variables
   → Include base image digest

2. Compare with stored caches
   → Exact match → CACHE HIT
   → Partial match → PARTIAL REBUILD
   → No match → FULL REBUILD

3. Update cache on build completion
   → Store new layers
   → Update metadata
   → Purge stale caches
```

---

## Data Constraints

### Global Constraints
- All file paths MUST be absolute (no relative paths)
- All shell scripts MUST use `set -eoux pipefail`
- All timestamps MUST be ISO 8601 format
- All sizes MUST be in bytes (convert to human-readable for display)

### Performance Constraints
- Build module execution timeout: 30 minutes
- Cache lookup timeout: 5 seconds
- Validation timeout per file: 10 seconds
- Total build timeout (CI/CD): 2 hours

### Size Constraints
- Individual script file: ≤ 200 lines
- packages.json: ≤ 1000 entries
- Final image size: ≤ 8 GB
- Cleanup must achieve: ≥ 10% reduction

---

## Metadata Schema

### Build Module Header Format
```bash
#!/usr/bin/bash
# Script: module-name.sh
# Purpose: [One-line description]
# Category: [shared|desktop|developer|user-hooks]
# Dependencies: [comma-separated module names, or "none"]
# Parallel-Safe: [yes|no]
# Usage: Called by build-base.sh during [stage name]
# Author: [Name/Handle]
# Last Updated: YYYY-MM-DD
```

### Package Configuration JSON
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Dudley's Second Bedroom Package Configuration",
  "type": "object",
  "properties": {
    "all": {
      "type": "object",
      "properties": {
        "install": {"type": "array", "items": {"type": "string"}},
        "remove": {"type": "array", "items": {"type": "string"}},
        "copr_repos": {"type": "array", "items": {"type": "string"}}
      }
    }
  },
  "additionalProperties": {
    "type": "object",
    "properties": {
      "install": {"type": "array", "items": {"type": "string"}},
      "remove": {"type": "array", "items": {"type": "string"}},
      "install_overrides": {"type": "object"}
    }
  }
}
```

---

**Status**: ✅ Data model complete, entities and relationships defined
