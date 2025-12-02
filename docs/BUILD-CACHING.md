# Build Caching Strategy

This document explains the caching mechanisms used to speed up GitHub Actions builds for dudleys-second-bedroom.

## Overview

Build times can be significantly reduced by caching various artifacts between workflow runs. Our multi-layered caching strategy targets:

1. **Container layers** - Reuse intermediate build layers
2. **Package manager caches** - Skip re-downloading RPM/DNF packages
3. **Downloaded binaries** - Cache GitHub release downloads
4. **Buildah layer cache** - Native build tool caching

## Cache Types

### 1. Container Layer Cache

**Location:** `~/.local/share/containers`, `/var/lib/containers`
**Cache Key:** `${{ runner.os }}-containers-${{ hashFiles('Containerfile', 'packages.json', 'build_files/**') }}`

This caches:
- Base image layers from `ghcr.io/ublue-os/bluefin-dx:stable`
- Intermediate build layers created during the build process
- Previously built images (when available)

**Benefits:**
- Avoids pulling base images repeatedly (multi-GB downloads)
- Reuses unchanged layers between builds
- **Estimated savings:** 2-5 minutes per build

### 2. DNF/RPM Package Cache

**Location:** `~/.cache/dnf`, `/var/cache/dnf5`, `/var/cache/yum`
**Cache Key:** `${{ runner.os }}-dnf-${{ hashFiles('packages.json') }}`

This caches:
- Downloaded RPM packages
- DNF metadata
- Package repository indices

Works in conjunction with Containerfile cache mounts:
```dockerfile
--mount=type=cache,dst=/var/cache/dnf5,sharing=locked
--mount=type=cache,dst=/var/cache/yum,sharing=locked
```

**Benefits:**
- Avoids re-downloading packages when `packages.json` unchanged
- Speeds up `package-install.sh` execution
- **Estimated savings:** 1-3 minutes per build

### 3. Downloaded Binaries Cache

**Location:** `~/.cache/github-releases`, `/tmp/downloads`
**Cache Key:** `${{ runner.os }}-binaries-${{ hashFiles('build_files/developer/*.sh') }}`

This caches:
- GitHub release binaries (VS Code Insiders, RCC CLI, Action Server)
- Other downloaded tools and assets

Relevant to these build modules:
- `build_files/developer/vscode-insiders.sh`
- `build_files/developer/rcc-cli.sh`
- `build_files/developer/action-server.sh`
- Any script using `github-release-install.sh`

**Benefits:**
- Avoids hitting GitHub API rate limits
- Speeds up developer tool installation
- **Estimated savings:** 30-60 seconds per build

### 4. Buildah Native Layer Cache

**Configuration:**
```yaml
layers: true
```

Buildah supports native layer caching with `layers: true`. It does **not** support Docker BuildKit cache arguments like `--cache-from` or `--cache-to`. Layer caching is handled automatically by Buildah and the underlying storage driver.

**Benefits:**
- Efficient reuse of unchanged layers
- No need for extra cache arguments
- **Estimated savings:** 3-7 minutes per build

## Cache Invalidation

Caches are automatically invalidated when their cache key changes:

| Cache | Invalidation Triggers |
|-------|----------------------|
| Container layers | Changes to `Containerfile`, `packages.json`, or any file in `build_files/` |
| DNF packages | Changes to `packages.json` |
| Downloaded binaries | Changes to any script in `build_files/developer/` |

### Restore Keys

Each cache uses "restore-keys" to provide fallback caching:

```yaml
key: ${{ runner.os }}-containers-${{ hashFiles(...) }}
restore-keys: |
  ${{ runner.os }}-containers-
```

This means:
- **Exact match:** Uses cache from identical build configuration
- **Partial match:** Falls back to most recent cache for the OS

## Storage Limits

GitHub Actions cache limits:
- **Total cache size:** 10 GB per repository
- **Cache retention:** 7 days (unused caches are evicted)
- **Cache access:** Scoped to branch (with fallback to default branch)

Our caches typically use:
- Container layers: ~3-5 GB
- DNF packages: ~500 MB - 1 GB
- Downloaded binaries: ~200-500 MB
- **Total:** ~4-6.5 GB

## Monitoring Cache Performance

To see cache effectiveness, check workflow run logs:

```
Cache container layers
  Cache restored from key: Linux-containers-abc123...
  Cache Size: 4.2 GB
```

Look for:
- `Cache restored successfully` - cache hit
- `Cache not found` - cache miss (first build or invalidated)
- Cache restore/save times in the workflow timeline

## Optimization Tips

### 1. Order Matters in Containerfile

Keep volatile operations last:
```dockerfile
# ✅ Good: Static operations first
COPY packages.json /packages.json
RUN install-packages.sh

# ❌ Bad: Frequently changing operations early
ARG GIT_COMMIT
RUN echo $GIT_COMMIT > /version
```

### 2. Minimize Cache Key Scope

Don't include files that change frequently but don't affect cache:
```yaml
# ❌ Too broad
key: ${{ hashFiles('**/*') }}

# ✅ Targeted
key: ${{ hashFiles('packages.json', 'build_files/**') }}
```

### 3. Use Cache Warming

For scheduled builds, the cache is kept warm automatically by the daily cron job:
```yaml
schedule:
  - cron: '05 10 * * *'  # Daily at 10:05am UTC
```

### 4. Manual Cache Clearing

To force a cache rebuild:
- Push a commit that modifies `Containerfile` or `packages.json`
- Or manually delete cache in GitHub Settings → Actions → Caches

## Performance Expectations

| Scenario | Without Cache | With Cache | Savings |
|----------|--------------|------------|---------|
| **Cold build** (first time) | 25-35 min | 25-35 min | 0% |
| **Warm build** (no changes) | 25-35 min | 8-15 min | ~60-70% |
| **Incremental** (small changes) | 25-35 min | 12-20 min | ~40-50% |
| **Package update only** | 25-35 min | 10-18 min | ~50-60% |

> **Note:** Actual times vary based on runner availability, network speed, and GitHub's cache infrastructure.

## Troubleshooting

### Cache Not Restoring

**Symptoms:** Logs show "Cache not found" despite previous builds

**Possible causes:**
1. Cache expired (>7 days old)
2. Cache evicted due to size limits
3. Branch isolation (feature branch can't access main branch cache on first run)
4. Cache key changed due to file modifications

**Solution:**
- Verify cache keys in workflow logs
- Check GitHub Settings → Actions → Caches for available caches
- Merge main branch into feature branch to access caches

### Build Still Slow with Cache

**Check these areas:**
1. **Base image pull:** Still downloads ~2-3 GB base image
2. **Layer cache misses:** Check if Containerfile changes invalidated layers
3. **Network latency:** GitHub Actions network speed varies by region
4. **CPU-bound operations:** Compilation and compression aren't cached

**Optimization:**
- Enable rechunking (commented out in workflow) for better layer reuse
- Consider using self-hosted runners with local cache
- Profile build with `time` commands to identify bottlenecks

## Future Improvements

Potential enhancements to consider:

1. **Registry-based layer cache:** Use dedicated cache registry
2. **Distributed cache:** Use external cache providers (e.g., BuildKit cache)
3. **Parallel builds:** Split build into multiple jobs with shared cache
4. **Smart cache invalidation:** More granular cache keys per build module

## References

- [GitHub Actions Cache Documentation](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [Buildah Caching Strategies](https://buildah.io/blogs/2021/08/16/buildah-cache.html)
- [Container Build Best Practices](https://docs.docker.com/build/cache/)
- [Universal Blue Build Optimization](https://universal-blue.discourse.group/)
