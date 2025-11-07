# Quick Reference Card 🚀

## You're Not Doing Anything Wrong!

**The build takes 15-30 minutes.** This is normal for Universal Blue OS images.

## Fast Commands (Use These First!)

```bash
# ✅ Validate configuration (30-60 seconds)
dagger call validate --source=.

# ✅ Check Containerfile syntax (<5 seconds)  
dagger call check-containerfile --source=.

# ✅ List all functions (<5 seconds)
dagger functions
```

## Full Build (15-30 Minutes ⏱️)

```bash
# Start the build (grab coffee ☕)
dagger call build --source=. --git-commit=$(git rev-parse --short HEAD)

# Or use the convenience Makefile
make build
```

### What You'll See

```
▶ connect 0.3s
▶ load module: . 0.5s
✔ parsing command line arguments 0.0s
✔ dudleysSecondBedroom: DudleysSecondBedroom! 0.0s
▶ .build() Container! [Building... this takes 15-30 min]
```

**Don't cancel it!** The build is working, it just takes time.

## Why So Slow?

- Base image download: 4-8 GB
- Package installation: 100+ packages
- Multiple build stages
- Desktop environment setup
- Developer tools installation

**This is normal for OS image builds!**

## Faster Workflow

### Option 1: Validate, Then Build
```bash
# Fast check (30 sec)
dagger call validate --source=.

# If validation passes, then build (30 min)
dagger call build --source=. --git-commit=$(git rev-parse --short HEAD)
```

### Option 2: Use Make
```bash
# Copy the example Makefile
cp .dagger/examples/Makefile ./Makefile

# Quick commands
make validate    # 30 sec
make build       # 30 min (builds in background)
make test        # Build + test
```

### Option 3: Let CI/CD Build
```bash
# Set up GitHub Actions
cp .dagger/examples/github-actions.yml .github/workflows/dagger-ci.yml

# Push to trigger build
git add .
git commit -m "Add Dagger CI"
git push

# GitHub builds for you (while you work on other things)
```

## Build Time Comparison

| Command | Time | What It Does |
|---------|------|--------------|
| `dagger call validate --source=.` | 30-60 sec | Check syntax, no build |
| `dagger call check-containerfile --source=.` | <5 sec | View Containerfile |
| `dagger call build --source=.` | **15-30 min** | Full image build |
| `dagger call build --source=.` (cached) | 5-10 min | Rebuild with cache |

## Troubleshooting

### "It's stuck!"
- It's not stuck, it's building (takes 15-30 minutes)
- Look for progress: `▶` means running, `✔` means done
- Be patient or run in background

### "It failed!"
- Check validation first: `dagger call validate --source=.`
- Read the error message (Dagger shows exact failure point)
- Fix the issue and retry (uses cache up to failure)

### "Can I speed it up?"
- First build: No, it downloads and builds everything
- Subsequent builds: Yes, Dagger caches layers (5-10 min)
- Use validation during development (30 sec)

## Recommended Workflow

**During Development:**
```bash
# Edit files
vim build_files/developer/my-tool.sh

# Quick validation
dagger call validate --source=.

# Repeat until validation passes
```

**Ready to Test:**
```bash
# Start full build
dagger call build --source=. --git-commit=$(git rev-parse --short HEAD)

# Go get coffee ☕ (15-30 minutes)

# Come back to test
dagger call test --image=$IMAGE
```

**For Production:**
```bash
# Push to GitHub
git push

# Let GitHub Actions build and publish
# (Check Actions tab for progress)
```

## Summary

✅ Your command is correct  
✅ Dagger is working properly  
✅ The build just takes 15-30 minutes  
✅ This is normal for Universal Blue OS images  
✅ Use validation during development  
✅ Let the full build run in background or CI/CD  

**You're not doing anything wrong - building OS images just takes time!**

---

For detailed explanations, see:
- `.dagger/BUILD_TIMES.md` - Complete build time guide
- `.dagger/QUICKSTART.md` - Full quick start tutorial
- `.dagger/README.md` - Function reference
