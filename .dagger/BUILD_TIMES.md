# Understanding Build Times ⏱️

## You're Not Doing Anything Wrong!

Building a Universal Blue OS image is a **time-intensive operation**. Here's what to expect:

### Build Time Expectations

| Scenario | Expected Time | What's Happening |
|----------|---------------|------------------|
| **First build** | 15-30 minutes | Downloading base image (4-8 GB), installing packages, running all build modules |
| **Incremental build** (with cache) | 5-10 minutes | Using cached layers, only rebuilding changed components |
| **Validation only** | 30-60 seconds | Running shellcheck, JSON validation, module checks |
| **Check Containerfile** | <5 seconds | Just reading the file |

### What Happens During Build

When you run `dagger call build --source=. --git-commit=$(git rev-parse --short HEAD)`:

1. **Base Image Pull** (5-10 min)
   - Downloads `ghcr.io/ublue-os/bluefin-dx:latest` (~4-8 GB)
   
2. **Modular Build System** (10-20 min)
   - Executes scripts in `build_files/shared/`
   - Runs desktop customizations
   - Installs developer tools
   - Sets up user hooks
   
3. **Content Versioning** (1-2 min)
   - Generates build manifest
   - Computes content hashes
   - Replaces version placeholders
   
4. **Validation** (1-2 min)
   - Runs `bootc container lint`
   - Validates image structure

**Total: 15-30 minutes** (varies by internet speed and system resources)

## Quick Commands (Fast!)

### 1. Validate Configuration (30-60 seconds)
```bash
dagger call validate --source=.
```
Checks shell scripts, JSON files, and module metadata without building.

### 2. Check Containerfile (<5 seconds)
```bash
dagger call check-containerfile --source=.
```
Displays Containerfile contents to verify syntax.

### 3. List Functions (<5 seconds)
```bash
dagger functions
```
Shows all available Dagger commands.

## Running a Full Build

When you're ready to wait 15-30 minutes:

```bash
# Start the build (this will take a while!)
dagger call build \
  --source=. \
  --git-commit=$(git rev-parse --short HEAD)
```

### Monitoring Progress

Dagger shows progress in the terminal:
```
▶ connect 0.3s
▶ load module: . 0.5s
✔ parsing command line arguments 0.0s
✔ dudleysSecondBedroom: DudleysSecondBedroom! 0.0s
▶ .build() Container! [progress bar]
```

You'll see:
- ✔ = Step completed
- ▶ = Step in progress
- ⏱️ = Estimated time remaining

### Why It Takes So Long

Universal Blue OS images are:
- **Large**: Base image is 4-8 GB
- **Complex**: Multiple build stages with package installations
- **Comprehensive**: Full desktop environment + developer tools

This is **normal and expected** for OS image builds!

## Tips for Faster Builds

### 1. Use Validation First
Always validate before building:
```bash
make validate  # Fast check
make build     # Only if validation passes
```

### 2. Enable Caching
Dagger automatically caches layers. Subsequent builds reuse unchanged layers:
- First build: 30 minutes
- Second build (no changes): 2 minutes
- Second build (small change): 5-10 minutes

### 3. Build in Background
Use terminal multiplexers to build while working:
```bash
# In tmux or screen
dagger call build --source=. --git-commit=$(git rev-parse --short HEAD) &

# Or redirect output
dagger call build --source=. --git-commit=$(git rev-parse --short HEAD) > build.log 2>&1 &
```

### 4. Use CI/CD
Let GitHub Actions build for you:
```bash
git push  # GitHub Actions builds automatically
```

## Comparison: Just vs Dagger

Both tools build the same way and take similar time:

```bash
# Just build (15-30 min)
just build

# Dagger build (15-30 min)
dagger call build --source=.
```

The difference is:
- **Just**: Uses local podman/docker directly
- **Dagger**: Adds orchestration layer (adds ~5 seconds startup)

## What If Build Fails?

If the build fails partway through:

1. **Check validation first**:
   ```bash
   dagger call validate --source=.
   ```

2. **Review the error**: Dagger shows the exact step that failed

3. **Fix the issue**: Edit the relevant file

4. **Retry**: Dagger will use cached layers up to the failure point

## Expected Terminal Output

### Successful Build Start
```
▶ connect 0.3s
▶ load module: . 0.5s
✔ parsing command line arguments 0.0s
✔ dudleysSecondBedroom: DudleysSecondBedroom! 0.0s
▶ .build(
  ┆ source: Address.directory: Directory!
  ┆ gitCommit: "a191919"
  ): Container! [Building...]
```

### What You Saw (Normal)
```
▶ .build(
  ┆ source: Address.directory: Directory!
  ┆ gitCommit: "a191919"
  ): Container! 0.1s

12:34:51 WRN canceling... (press again to exit immediately)
Canceled.
```

This means:
- ✅ Dagger loaded correctly
- ✅ Build started successfully
- ❌ You cancelled it (Ctrl+C)

**You didn't do anything wrong** - you just didn't wait long enough!

## Recommended Workflow

```bash
# 1. Quick validation (30 sec)
dagger call validate --source=.

# 2. Check Containerfile (5 sec)
dagger call check-containerfile --source=.

# 3. Start full build (grab coffee ☕)
dagger call build --source=. --git-commit=$(git rev-parse --short HEAD)

# 4. Come back in 20-30 minutes
```

## Summary

**You're not doing anything wrong!** Universal Blue OS image builds are:
- ✅ Time-intensive by nature (15-30 minutes)
- ✅ Normal for OS-level container images
- ✅ Faster on subsequent builds (5-10 minutes with cache)
- ✅ Working as expected

The build process just takes time. Use validation and quick checks while developing, then let the full build run in the background or in CI/CD.
