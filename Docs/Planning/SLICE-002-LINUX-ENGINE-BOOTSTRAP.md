# StaxRip Community Slice Brief: SLICE-002 Linux Engine Bootstrap

Version: 0.2 Final. Date: 2026-08-16. Status: Confirmed by D-041; local acceptance complete with LNX-019 blocked by R-S2-039.

Companion documents: `ARCHITECTURE.md`, `DECISION-LOG.md`, `PORTABILITY-ROADMAP.md`, `../Architecture/Portability-System-Map.md`, `../Architecture/Platform-Matrix.md`, `../Architecture/Repo-Slices.md`, and `../Unknowns/Portability-Unknowns.md`.

This document is the build boundary. It authorizes a separate capability-only runtime and local web shell. It does not authorize changes to current Windows projects, current persistence, external-tool execution, native frame serving, packaging, or public release.

## 1. Central claim

The verified local slice shows that a separate .NET 10 host builds without third-party project packages, publishes for Linux x64 with recorded and signature-verified Microsoft runtime packs, runs as a non-root Linux process, binds only to loopback, serves a first-party StaxRip shell, and returns privacy-bounded health and capability contracts. The tested workload starts no external tool, writes no observed product or runtime state, and changes no current Windows application file.

This is a foundation build, not a usable encoder and not a Linux support release.

## 2. In scope

| Unit | Allowed responsibility |
|---|---|
| `StaxRip.Contracts` | Stable .NET 10 DTOs, capability ids, availability values, and versioned error shape; future .NET Framework consumption remains unverified and separate |
| `StaxRip.Core` | Pure capability catalog, platform normalization, and safe response construction |
| `StaxRip.Platform` | Bounded operating-system, architecture, runtime, and processor facts behind a core interface; no path search, executable probe, process start, or raw platform text |
| `StaxRip.Server` | ASP.NET Core host, IPv4 loopback random port, Host and Origin policy, process-local browser session, `/healthz`, `/api/v1/capabilities`, exact embedded web-asset allowlist, graceful shutdown |
| `StaxRip.ContractTests` | Custom executable test harness for contracts, security helpers, serialization, boundaries, and embedded asset rules |
| Build entrypoints | Separate cross-platform solution and bounded PowerShell and Bash verification scripts under root-level `CrossPlatform/`; no existing solution or release-script edits |
| Documentation | Decisions, map, matrix, unknowns, verification report, adversarial review, and rollback notes |

## 3. Required product behavior

- Startup chooses an unused IPv4 loopback port by default and prints only the safe local URL.
- `/healthz` returns a minimal versioned readiness response without a session.
- Loading `/` creates a manual 256-bit process-local session in a per-instance `HttpOnly`, `SameSite=Strict` cookie with `Path=/api/v1`. It sets no Domain, Expires, or Max-Age attribute. It deliberately omits `Secure` because this approved slice uses plain HTTP on numeric IPv4 loopback and adds no TLS boundary. ASP.NET authentication and Data Protection are not used. The token is never placed in the URL, page source, JavaScript-readable storage, API body, or console.
- `/api/v1/capabilities` requires the valid cookie and an exact `X-StaxRip-Client: web` header.
- Every request must use exactly the printed `127.0.0.1:<actual-port>` Host. An Origin, when present, must contain that exact scheme, host, and port. Malformed, multiple, `null`, and mismatched values fail before endpoint execution.
- The host does not enable CORS.
- The capability response exposes only allowlisted platform, architecture, runtime, logical-processor, feature, and fixed tool-catalog fields.
- The response reports `media-inspection`, `encoding`, `persistence`, `remote-access`, `plugins`, and `project-import` as unavailable.
- Every tool catalog row reports compatibility as `unverified`. The bootstrap does not inspect PATH, search the filesystem, resolve an executable, or start a probe. P-004 owns discovery.
- The implemented source defines no child or worker-process launch path and no product, settings, project, job, media, temp, or application-log writer. LNX-013 observed zero children across 200 samples, and LNX-014 observed an unchanged application tree and zero runtime-state writes in the supported sandbox. These results are bounded to the tested workload. Runtime tests isolate and inspect working, HOME, XDG, and temporary directories and distinguish any documented runtime-owned diagnostic artifact.
- Shutdown cancels the web host and leaves no child process or listener.
- The web shell uses no third-party script, stylesheet, font, image, analytics, telemetry, or external network request. Its only request after page load is the same-origin capability API.
- The page states plainly that the build is a Linux foundation preview and cannot open or encode media.

## 4. Security, privacy, and failure rules

1. Bind only to `127.0.0.1`. Ignore ambient `--urls`, `--contentRoot`, `ASPNETCORE_URLS`, `ASPNETCORE_HTTP_PORTS`, `ASPNETCORE_HTTPS_PORTS`, `DOTNET_HTTP_PORTS`, `DOTNET_HTTPS_PORTS`, `Kestrel__Endpoints__*`, and hosting-startup or environment settings. After startup, fail closed unless Kestrel reports one address with the selected IPv4 loopback authority.
2. Use a manual cryptographically random 256-bit token held only in process memory and a per-instance HttpOnly, SameSite=Strict cookie with `Path=/api/v1`; set no Domain, Expires, or Max-Age attribute. Omit `Secure` only because this slice serves plain HTTP on exact numeric loopback and adds no TLS boundary. Do not add ASP.NET authentication or Data Protection, which can add persistence and key-management behavior.
3. Reject any Host except exact `127.0.0.1:<local-port>`. Reject malformed, multiple, `null`, wrong-scheme, wrong-host, or wrong-port Origin values. No `Access-Control-Allow-*` response header is emitted.
4. Allow only bodyless, queryless `GET` on `/`, `/app.css`, `/app.js`, `/healthz`, and `/api/v1/capabilities`. Reject `HEAD`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`, `TRACE`, `CONNECT`, query strings, request bodies, transfer encoding, trailing-route variants, and encoded traversal before endpoint logic. Kestrel can reject malformed transport input before application errors exist.
5. Return stable error codes and generic messages. Do not return exception text, stack traces, paths, environment variables, command lines, tokens, or request bodies.
6. Do not accept a user path, URL, upload, script, serialized object, command, executable, plugin, or environment mutation.
7. Use this canonical policy: `default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; font-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; worker-src 'none'; manifest-src 'none'`. Set `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, same-origin opener and resource policies, and a restrictive Permissions Policy.
8. Bound request headers and response collections through Kestrel limits and fixed catalogs.
9. Construct the host with `CreateEmptyBuilder`, register Kestrel explicitly with `UseKestrelCore`, prevent hosting startup, clear configuration sources, add only reviewed in-memory configuration, and set Production explicitly. Serve only an embedded, exact asset allowlist rooted in the assembly. Fail startup if the bind cannot remain inside the allowed loopback policy. A hostile launch directory, `appsettings.json`, argument, or environment value cannot replace assets or endpoints.
10. Keep the logging-provider set empty and add no request logging. Catch unexpected request failures at one boundary and return a fixed error without printing a path, stack trace, request, token, or environment value. Keep console output bounded to startup state, safe URL, and shutdown state. No application log file is added.
11. Treat a hostile process running as the same operating-system user and a shared multi-user host as outside this session model. Any stronger local isolation requires a separate operating-system and IPC decision.

## 5. Explicit exclusions

| Excluded | Reason and future owner |
|---|---|
| Existing `Source/StaxRip.sln`, `.vbproj`, `.vcxproj`, or Windows scripts | Current build compatibility; later Windows adapter slice |
| Project, settings, template, profile, job, or recovery reads and writes | P-002 and a critical persistence slice |
| Media path selection, upload, probing, thumbnailing, or metadata | S-PORT-02 |
| External process start, encoding, muxing, demuxing, or script execution | P-003 and S-PORT-05 |
| Tool download, update, replacement, or version support claim | P-004 and release approval |
| FrameServer or other native ABI work | P-005 and native-boundary approval |
| Queue, job persistence, retry, recovery, or concurrency | S-PORT-06 |
| LAN, remote, multi-user, account, TLS, or cloud behavior | Separate threat model and explicit approval |
| Arbitrary plugins, custom server code, or ComfyUI-style nodes | Separate extension and sandbox decision |
| Database or cache | No bootstrap need; D-011 remains active |
| Installer, package manager, container, update, public archive, or release automation | P-009 and S-PORT-10 |
| Native GUI framework | P-010 and S-PORT-08 |
| macOS artifact or support claim | P-008 and S-PORT-09 |

## 6. Build and dependency rules

- Target the installed .NET 10 LTS SDK through a checked-in `global.json` scoped to `CrossPlatform/`.
- Add no project `PackageReference`, npm, CDN, container, database, telemetry, or runtime external service dependency.
- Use SDK and ASP.NET Core shared-framework assemblies. The self-contained Linux publish may restore only `Microsoft.AspNetCore.App.Runtime.linux-x64`, `Microsoft.NETCore.App.Host.linux-x64`, and `Microsoft.NETCore.App.Runtime.linux-x64` at the exact evaluated .NET 10 patch from the sole scoped official NuGet source into ignored `CrossPlatform/artifacts/nuget/`.
- Require signed packages, source-map only `Microsoft.*`, pin the reviewed Microsoft author certificate fingerprint, and run `dotnet nuget verify` over every retained archive. A future package, version, source, or signer change fails closed until reviewed.
- Derive the final closure from exactly five reviewed `project.assets.json` files and five matching `packages.lock.json` files. Require only the reviewed `net10.0` and `net10.0/linux-x64` targets, project-only libraries, and the exact three `[10.0.11, 10.0.11]` package downloads.
- Record restored dependency ids, versions, five-project membership, source, NuGet registry content hashes, author fingerprint, verified archive count, raw archive length and SHA-256 and SHA-512, and a canonical complete extracted disk inventory SHA-256, file count, and total bytes. Keep these identities distinct. Retain the exact archives inside the ignored cache for signature verification. Isolate NuGet packages, HTTP cache, CLI home, plugin cache, and task temp paths under ignored `CrossPlatform/artifacts/`; do not repurpose HOME, install a runtime or SDK into WSL, or write the user's global NuGet cache.
- Treat warnings as errors, enable nullable analysis, deterministic builds, invariant globalization compatibility, and analyzers supplied by the SDK.
- Keep output, intermediate files, and the repository-local package cache below ignored `CrossPlatform/artifacts/` and `CrossPlatform/obj/` paths.
- Build project references in one direction: Server -> Platform -> Core -> Contracts. ContractTests may reference the units it verifies.
- Contracts may not reference ASP.NET Core, WinForms, filesystem, process, registry, reflection-based legacy serialization, or server assets.
- Core may not reference WinForms, registry, legacy project types, `System.Diagnostics.Process`, or ASP.NET Core.
- No current project may reference a cross-platform project in this slice.

## 7. Visual direction

The shell should feel like StaxRip, not a generic admin dashboard:

- dark graphite work surface with restrained blue and amber accents;
- a compact top brand bar, local-engine state, and platform badge;
- a left workflow rail that names future stages without pretending they work;
- a main capability panel with explicit available and unavailable states;
- a lower activity area that says no work has run;
- readable system fonts, visible keyboard focus, semantic landmarks, reduced-motion support, high contrast, and a useful narrow layout;
- no node graph in this slice. A later workflow canvas must represent typed engine state rather than arbitrary code execution.

## 8. Acceptance criteria

| ID | Criterion | Evidence |
|---|---|---|
| LNX-001 | The separate solution restores and builds Debug and Release with no project package reference. The scoped restore derives only the three pinned Microsoft runtime and host packs from exactly five reviewed asset and lock pairs. | Project and NuGet config inspection, exact asset and lock derivation, recorded restore, and `dotnet build --no-restore` output |
| LNX-002 | Contract tests pass in Debug and Release with exact assertion and failure counts. | Test runner output and verification report |
| LNX-003 | Existing Windows solution, project, build, package, release, persistence, process, and native files have no diff. | Bounded `git diff --name-only` and prohibited-path check |
| LNX-004 | `dotnet publish` produces a self-contained `linux-x64` tree and `file` identifies the host as an x86-64 ELF executable. Every artifact relative path, byte length, SHA-256, and Linux mode is recorded in a canonical whole-tree manifest, and its manifest hash identifies the test output. Required Microsoft registry, archive, signature, and canonical complete extracted-disk identities are recorded separately. | Publish command, dependency record and independent binder, whole-tree manifest and hash, `file`, `readelf`, and `ldd` output |
| LNX-005 | The exact artifact runs under WSL as a non-root process and serves the shell. | WSL `id -u`, HTTP status, title and marker checks |
| LNX-006 | The listener exists only on `127.0.0.1` for the selected port. Ambient URL, port, and Kestrel endpoint configuration cannot add or replace it, and the host verifies its sole post-start address. | Hostile-environment startup matrix and WSL socket inspection while the host is live |
| LNX-007 | `/healthz` succeeds without a session and reveals no host paths, environment, token, or tool detail. | Response schema and privacy-sentinel assertions |
| LNX-008 | The API rejects absent and wrong sessions and accepts the session cookie set by `/` only with the exact client header. | HTTP status matrix |
| LNX-009 | Wrong-host, wrong-port, malformed, multiple, `null`, and mismatched Origin requests fail, a CORS preflight gains no permission, and responses contain no CORS permission. | HTTP header and status matrix |
| LNX-010 | API write methods fail and no route accepts paths, URLs, files, scripts, commands, serialized objects, or plugins. | Endpoint inventory and method matrix |
| LNX-011 | Capability output uses stable ids, contains bounded values, and reports all non-bootstrap product features unavailable. | Schema snapshot and contract tests |
| LNX-012 | The fixed tool catalog stays `unverified`; the host performs no PATH, filesystem, executable, version, or compatibility probe and returns no raw path, command, environment, or exception. | Source guard, response assertions, read-only sandbox, and child-process observation |
| LNX-013 | The host has no child process while idle or serving the tested requests. | Linux `/proc/<pid>/task/<pid>/children` check |
| LNX-014 | Runtime requests and shutdown create no product or application file in isolated working, HOME, XDG, temporary, or publish directories. Any runtime-owned artifact is classified rather than silently ignored. | Before-and-after path manifests and source write-boundary scan |
| LNX-015 | Termination stops the exact host PID, releases the socket, and leaves no task-owned process. | Bounded shutdown and postflight process/socket checks |
| LNX-016 | Static assets have no external URL, inline executable script, JavaScript-readable storage, upload, file picker, or telemetry path. | Asset guard and DOM/source assertions |
| LNX-017 | Security headers include restrictive CSP, `nosniff`, referrer policy, permissions policy, and frame denial. | Response-header assertions |
| LNX-018 | The server and verification commands finish within a generous hang timeout. Elapsed time and resource samples are observational; no performance or leak budget is claimed. | Gate timeout and bounded observations |
| LNX-019 | The same immutable artifact passes on the independent Ubuntu peer, or R-S2-039 remains a named environment blocker without weakening other evidence. | Artifact SHA-256 and second-host report or blocker record |
| LNX-020 | The adversarial review records findings, remediations, untested boundaries, and rollback. | `Docs/Review/SLICE-002-Adversarial-Review.md` |
| LNX-021 | Two concurrent hosts use different cookie names and tokens; a session from one instance cannot authorize the other despite cookies being host-scoped rather than port-scoped. | Concurrent-instance HTTP matrix with secret values kept in disposable files |
| LNX-022 | A real installed browser confirms the intended cookie, same-site, CORS, and CSP enforcement, or P-006 remains explicitly inferred and blocks stronger security claims. | Headless browser probe or recorded environment blocker |

## 9. Verification order

1. G0: Run the static preflight, perform the approved initial restore, then rerun the static gate with the evaluated dependency closure, endpoint inventory, embedded assets, and prohibited current-path diff.
2. G1: Run the custom contract harness in Debug and Release.
3. G2: Build and start the server on Windows; run the endpoint, concurrent-instance, browser, and shutdown matrices.
4. G3: Publish once for `linux-x64`; hash the whole tree; run the same bytes in a WSL private-network and read-only-filesystem sandbox; inspect ELF, user, socket, HTTP, process, and filesystem state.
5. G4: Repeat G3 on an independent Ubuntu host whose unprivileged user units can obtain a private network namespace (R-S2-039).
6. G5: Run independent adversarial and evidence review and re-run every invalidated gate after fixes. A NO-GO remains open until its remediations pass the full producer sequence, final auditor, and an independent re-review.

The cheapest failed gate stops later runtime work. A missing host dependency is a toolchain or capability blocker, not a source defect. A request that never reached the intended middleware is an unexercised path, not a pass.

## 10. Rollback and compatibility

- Rollback deletes only the new root-level `CrossPlatform/` subtree and its documentation in one bounded revert.
- No current project or user file needs conversion to roll back.
- The bootstrap reads and writes no legacy state.
- It starts no encoder and publishes no media output.
- It changes no existing application listener, firewall, registry, file association, package, or update behavior.
- Public distribution remains blocked after local tests pass.

## 11. Stop gates

Stop and record a successor decision if the slice requires:

- an edit outside the approved new subtree other than planning and steering docs;
- any legacy deserialization or project data over HTTP;
- a fixed or non-loopback port by default;
- a token in a URL or JavaScript-readable storage;
- product runtime file writes, external processes, downloads, external requests, databases, project packages, containers, plugins, or any dependency outside the D-044 restore closure;
- a current Windows build or behavior change;
- a weaker security or privacy acceptance criterion;
- a public artifact or support statement.

## 12. Close-out record

The completed local record is `../Verification/SLICE-002/README.md`. It records:

- exact files and runtime units changed;
- Debug and Release build and contract evidence;
- Windows and Linux host tuples and artifact hashes;
- passed, failed, blocked, and untested criteria;
- security, privacy, logging, process, filesystem, and network impact;
- unknowns opened or resolved;
- approval gates crossed;
- rollback command or commit;
- anti-dark-code calibration and upstream lesson candidates.
