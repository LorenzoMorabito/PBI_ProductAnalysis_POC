# Lifecycle

Recommended lifecycle:

1. Author a package in a domain repo.
2. Publish a versioned package.
3. Install that version into a consumer project.
4. Persist the installed version and applied mappings.
5. Upgrade explicitly when a new compatible version is available.

Rules:
- patch releases should stay backward compatible
- minor releases may add optional capabilities
- major releases may require remapping or manual review
- installed assets in consumer projects are managed artifacts and should not be edited casually
