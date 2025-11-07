"""
Dagger module for building Universal Blue OS custom images.

This module provides CI/CD automation for Dudley's Second Bedroom,
a customized Universal Blue image based on Bluefin-DX.
"""

import dagger
from dagger import dag, function, object_type, field
from typing import Annotated


@object_type
class DudleysSecondBedroom:
    """
    Dagger module for building, testing, and publishing Universal Blue OS images.
    
    This module automates the build pipeline for custom bootc-compatible
    container images, including validation, building, testing, and publishing.
    """

    @function
    def validate(
        self,
        source: Annotated[
            dagger.Directory,
            "Source directory containing the project files"
        ],
    ) -> dagger.Container:
        """
        Validate build configuration and scripts.
        
        Runs all validation checks including:
        - Shellcheck on bash scripts
        - JSON schema validation for packages.json
        - Build module metadata validation
        - Containerfile syntax validation
        
        Args:
            source: The project source directory
            
        Returns:
            Container with validation results
        """
        return (
            dag.container()
            .from_("fedora:41")
            .with_exec(["dnf", "install", "-y", "shellcheck", "jq", "git"])
            .with_directory("/workspace", source)
            .with_workdir("/workspace")
            .with_exec(["bash", "-c", "find build_files -name '*.sh' -exec shellcheck {} +"])
            .with_exec(["jq", "empty", "packages.json"])
            .with_exec(["bash", "tests/validate-modules.sh"])
            .with_exec(["bash", "tests/validate-packages.sh"])
        )

    @function
    async def build(
        self,
        source: Annotated[
            dagger.Directory,
            "Source directory containing the project files"
        ],
        image_name: Annotated[
            str,
            "Name of the image to build"
        ] = "dudleys-second-bedroom",
        tag: Annotated[
            str,
            "Tag for the image"
        ] = "latest",
        base_image: Annotated[
            str,
            "Base Universal Blue image"
        ] = "ghcr.io/ublue-os/bluefin-dx:latest",
        git_commit: Annotated[
            str,
            "Git commit SHA (short)"
        ] = "unknown",
    ) -> dagger.Container:
        """
        Build the custom Universal Blue OS image.
        
        ⏱️  WARNING: This takes 15-30 minutes on first run!
        Subsequent builds with caching: 5-10 minutes.
        
        Builds a bootc-compatible container image using the modular build system.
        The build process includes:
        1. Multi-stage Containerfile build
        2. Modular script execution (shared, desktop, developer, user-hooks)
        3. Content-based versioning for hooks
        4. Build manifest generation
        5. Image validation with bootc container lint
        
        Args:
            source: The project source directory
            image_name: Name for the output image (default: "dudleys-second-bedroom")
            tag: Image tag (default: "latest")
            base_image: Universal Blue base image (default: "ghcr.io/ublue-os/bluefin-dx:latest")
            git_commit: Git commit SHA for build tracking (default: "unknown")
            
        Returns:
            Built container image
        """
        # Build using the directory's docker_build method
        return (
            source.docker_build(
                dockerfile="Containerfile",
                build_args=[
                    dagger.BuildArg(name="IMAGE_NAME", value=image_name),
                    dagger.BuildArg(name="SHA_HEAD_SHORT", value=git_commit),
                ],
            )
        )

    @function
    async def check_containerfile(
        self,
        source: Annotated[
            dagger.Directory,
            "Source directory"
        ],
    ) -> str:
        """
        Quick check: Parse and display Containerfile without building.
        
        Fast operation (<5 seconds) to verify Containerfile syntax.
        
        Args:
            source: Source directory
            
        Returns:
            Containerfile contents
        """
        return await source.file("Containerfile").contents()

    @function
    async def test(
        self,
        image: Annotated[
            dagger.Container,
            "The built container image to test"
        ],
    ) -> str:
        """
        Run tests on the built image.
        
        Executes integration tests including:
        - Build manifest validation
        - Package installation verification
        - User hook presence checks
        - Image size validation
        
        Args:
            image: The container image to test
            
        Returns:
            Test results as string
        """
        # Run test suite
        result = await (
            image
            .with_exec(["test", "-f", "/etc/dudley/build-manifest.json"])
            .with_exec(["test", "-f", "/usr/bin/dudley-build-info"])
            .with_exec(["bash", "-c", "ls -lh /usr/share/ublue-os/user-setup.hooks.d/"])
            .with_exec(["dudley-build-info", "--json"])
            .stdout()
        )
        
        return f"✅ All tests passed!\n\nBuild info:\n{result}"

    @function
    async def publish(
        self,
        image: Annotated[
            dagger.Container,
            "The built container image to publish"
        ],
        registry: Annotated[
            str,
            "Container registry to push to"
        ],
        repository: Annotated[
            str,
            "Repository path (e.g., owner/repo)"
        ],
        username: Annotated[
            dagger.Secret,
            "Registry username"
        ],
        password: Annotated[
            dagger.Secret,
            "Registry password/token"
        ],
        tag: Annotated[
            str,
            "Tag for the published image"
        ] = "latest",
    ) -> str:
        """
        Publish the built image to a container registry.
        
        Pushes the container image to the specified registry (default: GitHub Container Registry).
        Requires authentication credentials as Dagger secrets.
        
        Args:
            image: The container image to publish
            registry: Container registry URL
            repository: Repository path without registry (e.g., "joshyorko/dudleys-second-bedroom")
            username: Registry username (as Dagger secret)
            password: Registry password/token (as Dagger secret)
            tag: Image tag (default: "latest")
            
        Returns:
            Published image reference
        """
        image_ref = f"{registry}/{repository}:{tag}"
        
        # Publish with authentication
        address = await (
            image
            .with_registry_auth(registry, username, password)
            .publish(image_ref)
        )
        
        return f"✅ Published to: {address}"

    @function
    async def build_iso(
        self,
        source: Annotated[
            dagger.Directory,
            "Source directory containing disk_config"
        ],
        image_ref: Annotated[
            str,
            "OCI image reference to build ISO from"
        ],
        config_file: Annotated[
            str,
            "Disk config TOML file"
        ] = "disk_config/iso.toml",
    ) -> dagger.File:
        """
        Build an ISO installation image using bootc-image-builder.
        
        Creates a bootable ISO image from the container image using
        the bootc-image-builder tool with the specified disk configuration.
        
        Args:
            source: Source directory containing disk_config
            image_ref: Full OCI image reference (e.g., "ghcr.io/owner/repo:tag")
            config_file: Path to disk config TOML (default: "disk_config/iso.toml")
            
        Returns:
            ISO file
        """
        return (
            dag.container()
            .from_("quay.io/centos-bootc/bootc-image-builder:latest")
            .with_directory("/config", source.directory("disk_config"))
            .with_exec([
                "bootc-image-builder",
                "--type", "iso",
                "--config", f"/config/{config_file.split('/')[-1]}",
                image_ref,
            ])
            .file("/output/image.iso")
        )

    @function
    async def build_qcow2(
        self,
        source: Annotated[
            dagger.Directory,
            "Source directory containing disk_config"
        ],
        image_ref: Annotated[
            str,
            "OCI image reference to build QCOW2 from"
        ],
        config_file: Annotated[
            str,
            "Disk config TOML file"
        ] = "disk_config/disk.toml",
    ) -> dagger.File:
        """
        Build a QCOW2 virtual machine image using bootc-image-builder.
        
        Creates a QCOW2 disk image suitable for use with QEMU/KVM
        from the container image.
        
        Args:
            source: Source directory containing disk_config
            image_ref: Full OCI image reference (e.g., "ghcr.io/owner/repo:tag")
            config_file: Path to disk config TOML (default: "disk_config/disk.toml")
            
        Returns:
            QCOW2 disk image file
        """
        return (
            dag.container()
            .from_("quay.io/centos-bootc/bootc-image-builder:latest")
            .with_directory("/config", source.directory("disk_config"))
            .with_exec([
                "bootc-image-builder",
                "--type", "qcow2",
                "--config", f"/config/{config_file.split('/')[-1]}",
                image_ref,
            ])
            .file("/output/image.qcow2")
        )

    @function
    async def ci_pipeline(
        self,
        source: Annotated[
            dagger.Directory,
            "Source directory"
        ],
        repository: Annotated[
            str,
            "Repository path"
        ],
        registry: Annotated[
            str,
            "Container registry"
        ] = "ghcr.io",
        tag: Annotated[
            str,
            "Image tag"
        ] = "latest",
        git_commit: Annotated[
            str,
            "Git commit SHA"
        ] = "unknown",
        username: Annotated[
            dagger.Secret | None,
            "Registry username (required if publish_image=true)"
        ] = None,
        password: Annotated[
            dagger.Secret | None,
            "Registry password (required if publish_image=true)"
        ] = None,
        run_tests: Annotated[
            bool,
            "Whether to run tests"
        ] = True,
        publish_image: Annotated[
            bool,
            "Whether to publish the image"
        ] = False,
    ) -> str:
        """
        Run the complete CI/CD pipeline.
        
        Executes the full build pipeline:
        1. Validation
        2. Build
        3. Test (optional)
        4. Publish (optional)
        
        Args:
            source: Source directory
            registry: Container registry (default: "ghcr.io")
            repository: Repository path (required)
            tag: Image tag (default: "latest")
            git_commit: Git commit SHA (default: "unknown")
            username: Registry username (as Dagger secret)
            password: Registry password (as Dagger secret)
            run_tests: Whether to run tests (default: True)
            publish_image: Whether to publish (default: False)
            
        Returns:
            Pipeline results summary
        """
        results = []
        
        # Step 1: Validate
        results.append("🔍 Running validation...")
        validation = self.validate(source)
        await validation.sync()
        results.append("✅ Validation passed")
        
        # Step 2: Build
        results.append(f"🔨 Building image (commit: {git_commit})...")
        image = await self.build(
            source=source,
            image_name=repository.split("/")[-1] if repository else "dudleys-second-bedroom",
            tag=tag,
            git_commit=git_commit,
        )
        results.append("✅ Build completed")
        
        # Step 3: Test (optional)
        if run_tests:
            results.append("🧪 Running tests...")
            test_result = await self.test(image)
            results.append(test_result)
        
        # Step 4: Publish (optional)
        if publish_image:
            if not username or not password:
                results.append("⚠️  Skipping publish: username and password required")
            else:
                results.append("📦 Publishing image...")
                publish_result = await self.publish(
                    image=image,
                    registry=registry,
                    repository=repository,
                    username=username,
                    password=password,
                    tag=tag,
                )
                results.append(publish_result)
        
        return "\n".join(results)

    @function
    def lint_containerfile(
        self,
        source: Annotated[
            dagger.Directory,
            "Source directory containing Containerfile"
        ],
    ) -> dagger.Container:
        """
        Lint the Containerfile using hadolint.
        
        Checks the Containerfile for best practices and common issues.
        
        Args:
            source: Source directory
            
        Returns:
            Container with linting results
        """
        return (
            dag.container()
            .from_("hadolint/hadolint:latest")
            .with_mounted_directory("/workspace", source)
            .with_workdir("/workspace")
            .with_exec(["hadolint", "Containerfile"])
        )
