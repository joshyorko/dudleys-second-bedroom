#!/usr/bin/bash
# Script: build-base.sh
# Purpose: Main build orchestrator - discovers and executes all Build Modules
# Category: shared
# Dependencies: none (this is the entry point)
# Parallel-Safe: no
# Usage: Called from Containerfile RUN directive
# Author: Build System
# Last Updated: 2025-10-05

set -eoux pipefail

# Module metadata
readonly MODULE_NAME="build-base"
readonly CATEGORY="shared"
readonly BUILD_CONTEXT="${BUILD_CONTEXT:-/ctx}"

# Logging helper
log() {
    local level=$1
    shift
    echo "[MODULE:${CATEGORY}/${MODULE_NAME}] ${level}: $*"
}

# Track execution time
track_time() {
    local start_time=$1
    local end_time
    end_time=$(date +%s)
    echo $((end_time - start_time))
}

# Execute a Build Module
# Args: $1 - module script path
# Returns: 0 on success, 1 on error, 2 on skip
execute_module() {
    local module_script=$1
    local module_name
    module_name=$(basename "$module_script" .sh)
    
    log "INFO" "Executing module: $module_name"
    
    local module_start
    module_start=$(date +%s)
    
    # Execute the module
    if bash "$module_script"; then
        local duration
        duration=$(track_time "$module_start")
        log "INFO" "Module $module_name completed successfully (duration: ${duration}s)"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            log "INFO" "Module $module_name skipped"
            return 2
        else
            log "ERROR" "Module $module_name failed with exit code $exit_code"
            return 1
        fi
    fi
}

# Discover all Build Modules in a category
# Args: $1 - category directory
# Returns: List of module scripts
discover_modules() {
    local category_dir=$1
    
    if [[ ! -d "$category_dir" ]]; then
        log "INFO" "Category directory not found: $category_dir"
        return 0
    fi
    
    find "$category_dir" -maxdepth 1 -type f -name "*.sh" | sort
}

# Trigger cleanup on failure
trigger_cleanup() {
    local failed_module=$1
    log "ERROR" "Build failed in module: $(basename "$failed_module")"
    log "INFO" "Triggering cleanup due to failure..."
    if [[ -f "shared/cleanup.sh" ]]; then
        bash shared/cleanup.sh || log "WARNING" "Cleanup failed"
    fi
    exit 1
}

# Main function
main() {
    local build_start
    build_start=$(date +%s)
    
    log "INFO" "START - Build orchestration"
    log "INFO" "Build context: $BUILD_CONTEXT"
    
    # Change to build context
    if [[ -d "$BUILD_CONTEXT/build_files" ]]; then
        cd "$BUILD_CONTEXT/build_files"
    else
        log "ERROR" "Build files directory not found at $BUILD_CONTEXT/build_files"
        exit 1
    fi
    
    local total_modules=0
    local successful_modules=0
    local skipped_modules=0
    local failed_modules=0
    
    # Execute modules by category in order
    # Order: shared utilities -> desktop -> developer -> user-hooks
    
    # Phase 1: Shared utilities (except this orchestrator script itself)
    log "INFO" "Phase 1: Executing shared utilities..."
    if [[ -d "shared" ]]; then
        while IFS= read -r module; do
            # Skip the orchestrator itself
            if [[ $(basename "$module") == "build-base.sh" ]]; then
                continue
            fi
            
            total_modules=$((total_modules + 1))
            
            if execute_module "$module"; then
                successful_modules=$((successful_modules + 1))
            else
                exit_code=$?
                if [[ $exit_code -eq 2 ]]; then
                    skipped_modules=$((skipped_modules + 1))
                else
                    failed_modules=$((failed_modules + 1))
                    trigger_cleanup "$module"
                fi
            fi
        done < <(discover_modules "shared")
    fi
    
    # Execute utils if they exist
    if [[ -d "shared/utils" ]]; then
        log "INFO" "Note: Utility scripts in shared/utils are meant to be sourced, not executed directly"
    fi
    
    # Phase 2: Desktop customizations
    log "INFO" "Phase 2: Executing desktop customizations..."
    if [[ -d "desktop" ]]; then
        while IFS= read -r module; do
            total_modules=$((total_modules + 1))
            
            if execute_module "$module"; then
                successful_modules=$((successful_modules + 1))
            else
                exit_code=$?
                if [[ $exit_code -eq 2 ]]; then
                    skipped_modules=$((skipped_modules + 1))
                else
                    failed_modules=$((failed_modules + 1))
                    trigger_cleanup "$module"
                fi
            fi
        done < <(discover_modules "desktop")
    fi
    
    # Phase 3: Developer tools
    log "INFO" "Phase 3: Executing developer tools..."
    if [[ -d "developer" ]]; then
        while IFS= read -r module; do
            total_modules=$((total_modules + 1))
            
            if execute_module "$module"; then
                successful_modules=$((successful_modules + 1))
            else
                exit_code=$?
                if [[ $exit_code -eq 2 ]]; then
                    skipped_modules=$((skipped_modules + 1))
                else
                    failed_modules=$((failed_modules + 1))
                    trigger_cleanup "$module"
                fi
            fi
        done < <(discover_modules "developer")
    fi
    
    # Phase 4: User hooks (executed during build to install hook scripts)
    log "INFO" "Phase 4: Installing user hooks..."
    if [[ -d "user-hooks" ]]; then
        # User hooks modules install scripts that will run on first user login
        log "INFO" "User hook modules will install scripts for first-boot execution"
        while IFS= read -r module; do
            total_modules=$((total_modules + 1))
            
            if execute_module "$module"; then
                successful_modules=$((successful_modules + 1))
            else
                exit_code=$?
                if [[ $exit_code -eq 2 ]]; then
                    skipped_modules=$((skipped_modules + 1))
                else
                    failed_modules=$((failed_modules + 1))
                    trigger_cleanup "$module"
                fi
            fi
        done < <(discover_modules "user-hooks")
    fi
    
    # Phase 5: Final cleanup
    log "INFO" "Phase 5: Running final cleanup..."
    if [[ -f "shared/cleanup.sh" ]]; then
        if execute_module "shared/cleanup.sh"; then
            successful_modules=$((successful_modules + 1))
        else
            log "WARNING" "Cleanup encountered issues but build continues"
        fi
    fi
    
    # Build summary
    local build_duration
    build_duration=$(track_time "$build_start")
    
    log "INFO" "===================================="
    log "INFO" "Build Summary"
    log "INFO" "===================================="
    log "INFO" "Total modules: $total_modules"
    log "INFO" "Successful: $successful_modules"
    log "INFO" "Skipped: $skipped_modules"
    log "INFO" "Failed: $failed_modules"
    log "INFO" "Total build time: ${build_duration}s"
    log "INFO" "===================================="
    
    if [[ $failed_modules -gt 0 ]]; then
        log "ERROR" "Build completed with failures"
        exit 1
    else
        log "INFO" "DONE - Build completed successfully"
        exit 0
    fi
}

# Execute
main "$@"
