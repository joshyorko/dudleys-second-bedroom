# Feature Specification: Configurable Base Image

**Feature Branch**: `003-configurable-base-image`
**Created**: 2025-11-21
**Status**: Draft
**Input**: User description: "We currently use ghcr.io/ublue-os/bluefin-dx:stable as our base image. To make it easier to switch to any Universal Blue image, we should allow the base image to be set via an environment variable or as an input in GitHub Actions. The default should remain ghcr.io/ublue-os/bluefin-dx:stable, but this approach will provide flexibility for future changes."

## Clarifications

### Session 2025-11-21
- Q: How should the CI workflow input default be handled? → A: Empty/Null (Defer to Containerfile).
- Q: What environment variable name should be used for local overrides? → A: `BASE_IMAGE`.
- Q: What validation should be applied to the custom image string? → A: No validation (allow any string to support forks/testing).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Default Build Configuration (Priority: P1)

As a developer, I want the build system to use the standard Bluefin DX image by default so that I don't have to configure anything for standard builds.

**Why this priority**: Ensures backward compatibility and ease of use for the most common case.

**Independent Test**: Run a standard build command without arguments and verify the resulting image is based on `bluefin-dx`.

**Acceptance Scenarios**:

1. **Given** a clean build environment and no configuration overrides, **When** I initiate a build, **Then** the build completes successfully using the standard stable base image.
2. **Given** an automated CI workflow run with no inputs, **When** the build job executes, **Then** it uses the standard stable base image.

---

### User Story 2 - Custom Base Image via Environment Variable (Priority: P2)

As a developer experimenting with different upstreams, I want to override the base image using standard environment configuration so that I can test my changes against Aurora or other UBlue images locally.

**Why this priority**: Enables local testing and flexibility for developers.

**Independent Test**: Set the designated environment variable and run a build, verifying the output.

**Acceptance Scenarios**:

1. **Given** I have configured the environment to use `ghcr.io/ublue-os/aurora-dx:stable`, **When** I initiate a build, **Then** the build uses `aurora-dx` as the base image.
2. **Given** I have configured the environment with an invalid image, **When** I initiate a build, **Then** the build fails at the initialization stage (fail-fast).

---

### User Story 3 - Custom Base Image via CI Input (Priority: P2)

As a release manager, I want to trigger a build in the CI system with a specific base image so that I can produce variants or test upgrades without modifying code.

**Why this priority**: Allows CI/CD flexibility and automated testing of different bases.

**Independent Test**: Trigger a manual pipeline run with a custom base image input.

**Acceptance Scenarios**:

1. **Given** a manual pipeline trigger with the base image input set to `ghcr.io/ublue-os/bazzite:stable`, **When** the workflow runs, **Then** the resulting image is built on top of Bazzite.

## Functional Requirements

1. **Build Parameterization**: The build system must accept a parameter to specify the source of the base image.
2. **Default Value**: The default value for this parameter must be the standard stable Bluefin DX image.
3. **Tooling Support**: The local build tools must support passing this parameter via the `BASE_IMAGE` environment variable.
4. **CI Integration**: The Continuous Integration pipeline must accept an optional user input for the base image. If left empty, the build process must default to the value defined in the `Containerfile` (single source of truth).
5. **Validation**: The system must accept any string as the base image to allow for maximum flexibility (e.g., testing forks or private registries). It must rely on the container runtime to fail if the image cannot be retrieved.

## Success Criteria

*   **Default Behavior Preserved**: Builds without configuration produce identical results to the current system.
*   **Flexibility**: A developer can successfully build an image based on alternative upstream images (e.g., Aurora, Bazzite) by changing only configuration.
*   **Transparency**: The build logs clearly indicate which base image is being used.

## Assumptions

*   The target base images are OCI-compatible and follow the Universal Blue structure (so existing modules work).
*   The user has permissions to pull the specified custom base image.


### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: System MUST [specific capability, e.g., "allow users to create accounts"]
- **FR-002**: System MUST [specific capability, e.g., "validate email addresses"]
- **FR-003**: Users MUST be able to [key interaction, e.g., "reset their password"]
- **FR-004**: System MUST [data requirement, e.g., "persist user preferences"]
- **FR-005**: System MUST [behavior, e.g., "log all security events"]

*Example of marking unclear requirements:*

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

### Key Entities *(include if feature involves data)*

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]
