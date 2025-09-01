# Pre-PR Action Plan: Tests Bundle Integration

## Status
✅ Tests bundle copied to EdgeInfer directory  
✅ Scripts made executable  
⏳ Ready for Package.swift update (after your current sprint)

## What's Been Added
- `Tests/AppTests/ClientMock.swift` - HTTP client mock for sidecar
- `Tests/AppTests/AnalysisRealPathTests.swift` - Real path tests with mocks
- `Tests/AppTests/LinuxMain.swift` - Linux test entrypoint
- `Tests/AppTests/XCTestManifests.swift` - Test manifests
- `scripts/test-docker.sh` - Docker test runner with caching
- `.gitignore` - Prevent root-level LinuxMain conflicts

## Missing from PR Body
The PR body looks complete. All mentioned files are present and match the descriptions.

## Next Steps for You (Post-Sprint)
1. **Enable tests in Package.swift**: Uncomment the testTarget section and add `path: "Tests/AppTests"`
2. **Test the setup**: Run `bash scripts/test-docker.sh` to verify
3. **Optional**: Add sessionId query param support to the test for more realistic scenarios

## Immediate Action
Files are staged and ready to push. The PR body accurately describes what's included.

## Kill-Switch Documentation

**🔴 USE_REAL_MODEL=false** is your emergency kill-switch:
- **Default**: `false` (safe stub mode)
- **Production**: Keep as `false` until thorough testing
- **Rollback**: Simply set to `false` and redeploy (no rebuild needed)
- **Performance**: Stub mode ~5ms vs real inference ~45ms

See `ROLLBACK.md` for complete emergency procedures.

**Note**: Avoided Package.swift changes to prevent conflicts with your current sprint work.