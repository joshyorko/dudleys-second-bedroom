# Build Caching - Quick Start

## What Changed?

Your GitHub Actions workflow now includes **multi-layer caching** to dramatically speed up builds.

## Expected Speed Improvements

| Build Type | Before | After | Time Saved |
|------------|--------|-------|------------|
| **No changes** (rebuild) | 25-35 min | 8-15 min | ⚡ ~15-20 min |
| **Small script changes** | 25-35 min | 12-20 min | ⚡ ~10-15 min |
| **Package updates** | 25-35 min | 10-18 min | ⚡ ~12-17 min |
| **First build** (cold) | 25-35 min | 25-35 min | No change |

## What's Being Cached?

✅ **Container layers** - Reuses base image and build layers  
✅ **DNF/RPM packages** - Skips re-downloading packages  
✅ **Downloaded binaries** - Caches GitHub release downloads  
✅ **Buildah layer cache** - Native build tool caching  

## How to Verify It's Working

1. **Check the Actions tab** on your next build
2. **Look for these steps** in the workflow log:
   ```
   Cache container layers
     Cache restored successfully from key: Linux-containers-xyz...
     Cache Size: 4.2 GB
   
   Cache DNF packages  
     Cache restored successfully from key: Linux-dnf-abc...
     Cache Size: 856 MB
   ```

3. **Compare build times** - Second builds should be ~60% faster!

## Cache Storage

- **Location:** GitHub Actions cache storage (free for public repos)
- **Size:** ~4-6 GB total (well within 10 GB limit)
- **Retention:** 7 days for unused caches
- **Scope:** Per branch (with fallback to main)

## When Cache is Invalidated

Caches automatically rebuild when you change:

- ❌ `Containerfile` - Container layers cache cleared
- ❌ `packages.json` - DNF packages cache cleared  
- ❌ Files in `build_files/` - Relevant caches cleared
- ✅ Documentation changes - Caches preserved
- ✅ Test files - Caches preserved

## Manual Cache Management

### View caches:
Settings → Actions → Caches

### Clear all caches:
```bash
# Delete specific cache
gh cache delete <cache-key>

# Or just modify a file to invalidate:
touch Containerfile
git add Containerfile
git commit -m "chore: invalidate build cache"
```

## Troubleshooting

**Q: Cache not restoring?**
- Check if it's been >7 days since last build (cache expired)
- Verify you're on the same branch or have merged main recently

**Q: Build still slow?**
- First build after cache invalidation will be slow
- Base image pull still takes time (~2-3 GB download)
- Check logs to see which step is slow

**Q: Want to force a clean build?**
```bash
# Change a file that affects cache keys:
echo "# cache-bust" >> Containerfile
git commit -am "chore: force cache rebuild"
```

## Next Steps

- 🎯 Push a commit and watch the first build (slow)
- 🚀 Push another commit and see the speed improvement!
- 📊 Check cache sizes in Settings → Actions → Caches

## Full Documentation

See [`BUILD-CACHING.md`](./BUILD-CACHING.md) for complete technical details.
