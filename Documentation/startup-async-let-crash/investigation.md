# Production launch crash investigation

Build: Hackers Compete 1.0.0 (2026.10.22.1).

Five downloaded Xcode reports show the same main-thread SIGABRT, 2.7–9.7 seconds after launch, across iPhone18,1 / iOS26.6.2 and iPhone16,1 / iOS26.6.

The failing sequence is `swift_Concurrency_fatalError` → `_swift_task_dealloc_specific` → `asyncLet_finish_after_task_completion`. This establishes a fatal Swift concurrency task-allocator check during async-let cleanup. No application-specific fatal-error message is included.

The archived application dSYM UUID 4B05FE18-4EC1-3113-84CA-B02511B6F789 matches the crash image. Local symbolication confirms that the immediate app return frame is compiler-deduplicated; many async continuations share that address. The report cannot identify one source function or line with certainty.

Likely cause: an optimized-build async-let teardown problem. Swift tracks this crash family at https://github.com/swiftlang/swift/issues/87481 and Firebase documents the corresponding SDK trigger at https://github.com/firebase/firebase-ios-sdk/issues/15974. This is a strong signature match, not a proven exact compiler/SDK trigger for this app.

Startup candidates in the shipped source include DashboardView.swift:80–82 (parallel round/Series loading). The pinned Firebase SDK is 11.15.0; its AuthBackend.swift also uses async-let during backend token work, and FirebaseFunctions FunctionsContext.swift uses three async-let children. PersonalHandicapSection.swift has a second UI loading pair. The stack alone cannot distinguish these paths.

The fix removes startup UI async-let pairs and upgrades Firebase to the compatible release containing its Auth/Functions workaround. Optimized simulator regression tests and repeated cold launches validate the available environment. An affected physical iPhone is unavailable; confirmation on iOS 26.6/26.6.2 remains a tester follow-up. The simulator cannot establish exact reproduction or resolution on those devices.

The original crash analysis and reports.json are preserved under the original checkout’s build-artifacts/production-commissioner-2026-10-22/crash-analysis directory. See README.md and validation.json in this directory for fix and validation status.
