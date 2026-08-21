(function () {
  "use strict";

  const state = {
    root: document.documentElement,
    body: document.body,
    shell: document.getElementById("engine-shell"),
    status: document.getElementById("engine-state"),
    statusLabel: document.getElementById("engine-state-label"),
    result: document.getElementById("connection-result"),
    panel: document.getElementById("capabilities"),
    badge: document.getElementById("platform-badge"),
    runtimeState: document.getElementById("runtime-state")
  };

  const knownPlatforms = new Map([
    ["linux", "Linux"],
    ["windows", "Windows"],
    ["macos", "macOS"],
    ["unknown", "Unknown platform"]
  ]);

  const knownArchitectures = new Map([
    ["x64", "x64"],
    ["arm64", "ARM64"],
    ["unknown", "Unknown architecture"]
  ]);

  const knownToolIds = [
    "ffmpeg",
    "ffprobe",
    "vapoursynth",
    "avisynth-plus",
    "mkvtoolnix",
    "nvenc"
  ];
  const knownFeatureIds = [
    "local-engine",
    "web-shell",
    "media-inspection",
    "encoding",
    "persistence",
    "remote-access",
    "plugins",
    "project-import"
  ];
  const bootstrapAvailableFeatures = new Set([
    "local-engine",
    "web-shell"
  ]);

  function setEngineState(nextState, statusText, resultText) {
    state.root.dataset.engineState = nextState;
    state.body.dataset.engineState = nextState;
    state.shell.dataset.engineState = nextState;
    state.status.dataset.status = nextState;
    state.statusLabel.textContent = statusText;
    state.result.dataset.result = nextState;
    state.result.textContent = resultText;
    state.panel.dataset.loadState = nextState === "connected" ? "ready" : nextState;
    state.panel.setAttribute("aria-busy", "false");
  }

  function boundedText(value, fallback, maximumLength) {
    if (typeof value !== "string") {
      return fallback;
    }

    const normalized = value.trim();
    if (normalized.length === 0 || normalized.length > maximumLength) {
      return fallback;
    }

    return normalized;
  }

  function knownLabel(value, catalog, fallback) {
    if (typeof value !== "string") {
      return fallback;
    }

    return catalog.get(value.trim().toLowerCase()) || fallback;
  }

  function processorLabel(value) {
    return Number.isInteger(value) && value > 0 && value <= 4096 ? String(value) : "Not reported";
  }

  function hasExactKeys(value, expected) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      return false;
    }

    const actual = Object.keys(value).sort();
    const required = [...expected].sort();
    return actual.length === required.length && actual.every((key, index) => key === required[index]);
  }

  function hasSafeText(value, maximumLength) {
    return typeof value === "string" && value.length > 0 && value.length <= maximumLength;
  }

  function validateCatalogRow(row, expectedId, expectedAvailability, expectedReason) {
    return hasExactKeys(row, ["id", "displayName", "availability", "reasonCode"]) &&
      row.id === expectedId &&
      hasSafeText(row.displayName, 64) &&
      row.availability === expectedAvailability &&
      row.reasonCode === expectedReason;
  }

  function validateToolRow(row, expectedId) {
    return hasExactKeys(row, ["id", "displayName", "compatibility", "reasonCode"]) &&
      row.id === expectedId &&
      hasSafeText(row.displayName, 64) &&
      row.compatibility === "unverified" &&
      row.reasonCode === "compatibility-not-tested";
  }

  function validateCapabilities(payload) {
    if (!hasExactKeys(payload, ["schemaVersion", "apiVersion", "engineVersion", "host", "features", "tools"]) ||
        payload.schemaVersion !== "1" ||
        payload.apiVersion !== "v1" ||
        payload.engineVersion !== "0.1.0-bootstrap" ||
        !hasExactKeys(payload.host, ["platformId", "architectureId", "runtimeVersion", "logicalProcessorCount"]) ||
        !knownPlatforms.has(payload.host.platformId) ||
        !knownArchitectures.has(payload.host.architectureId) ||
        !/^[A-Za-z0-9._-]{1,32}$/.test(payload.host.runtimeVersion) ||
        !Number.isInteger(payload.host.logicalProcessorCount) ||
        payload.host.logicalProcessorCount < 1 ||
        payload.host.logicalProcessorCount > 4096 ||
        !Array.isArray(payload.features) ||
        payload.features.length !== knownFeatureIds.length ||
        !Array.isArray(payload.tools) ||
        payload.tools.length !== knownToolIds.length) {
      return false;
    }

    for (let index = 0; index < knownFeatureIds.length; index += 1) {
      const id = knownFeatureIds[index];
      const row = payload.features[index];

      if (id === "media-inspection") {
        // The one capability with a real activation condition: a configured server
        // legitimately publishes it available, and the shell must accept and render
        // either honest state rather than pinning the bootstrap default forever.
        if (!validateCatalogRow(row, id, "available", "inspection-configured") &&
            !validateCatalogRow(row, id, "unavailable", "bootstrap-unavailable")) {
          return false;
        }
        continue;
      }

      const available = bootstrapAvailableFeatures.has(id);
      if (!validateCatalogRow(
        row,
        id,
        available ? "available" : "unavailable",
        available ? "bootstrap-ready" : "bootstrap-unavailable"
      )) {
        return false;
      }
    }

    for (let index = 0; index < knownToolIds.length; index += 1) {
      if (!validateToolRow(payload.tools[index], knownToolIds[index])) {
        return false;
      }
    }

    return true;
  }

  function renderFeatures(features) {
    for (const row of features) {
      const featureId = row.id;

      const card = document.querySelector('[data-feature-id="' + featureId + '"]');
      if (!card) {
        continue;
      }

      const badge = card.querySelector(".availability");
      if (badge) {
        // Validation already constrained which features may claim availability, so
        // the render trusts the accepted row instead of re-clamping it to the
        // bootstrap default.
        const isAvailable = row.availability === "available";
        badge.textContent = isAvailable ? "Available" : "Unavailable";
        badge.classList.remove("availability-pending", "availability-on", "availability-off");
        badge.classList.add(isAvailable ? "availability-on" : "availability-off");
      }
    }
  }

  function renderTools(tools) {
    for (const tool of tools) {
      const toolId = tool.id;

      const row = document.querySelector('[data-tool-id="' + toolId + '"]');
      const label = row ? row.querySelector(".tool-state") : null;
      if (label) {
        label.textContent = "Unverified";
      }
    }
  }

  function renderCapabilities(payload) {
    const platform = knownLabel(payload.host.platformId, knownPlatforms, "Not reported");
    const architecture = knownLabel(payload.host.architectureId, knownArchitectures, "Not reported");
    const engineVersion = boundedText(payload.engineVersion, "Preview", 32);
    const runtimeLabel = boundedText(payload.host.runtimeVersion, ".NET 10", 32);
    const logicalProcessors = payload.host.logicalProcessorCount;

    document.getElementById("engine-version").textContent = engineVersion;
    document.getElementById("platform-value").textContent = platform;
    document.getElementById("architecture-value").textContent = architecture;
    document.getElementById("runtime-value").textContent = runtimeLabel;
    document.getElementById("processor-value").textContent = processorLabel(logicalProcessors);
    state.badge.textContent = platform === "Not reported" ? "Local platform" : platform + (architecture === "Not reported" ? "" : " / " + architecture);
    state.runtimeState.textContent = "Ready";
    state.runtimeState.classList.remove("availability-pending");
    state.runtimeState.classList.add("availability-on");

    renderFeatures(payload.features);
    renderTools(payload.tools);
  }

  async function connect() {
    try {
      const response = await fetch("/api/v1/capabilities", {
        method: "GET",
        credentials: "same-origin",
        headers: {
          "X-StaxRip-Client": "web"
        },
        cache: "no-store",
        redirect: "error"
      });

      if (!response.ok || response.status !== 200 || response.redirected ||
          response.headers.get("content-type") !== "application/json; charset=utf-8") {
        throw new Error("capability request rejected");
      }

      const payload = await response.json();
      if (!validateCapabilities(payload)) {
        throw new Error("capability response invalid");
      }

      renderCapabilities(payload);
      setEngineState(
        "connected",
        "Local engine ready",
        "Connected. The local engine returned its bounded capability contract; no media work ran."
      );
    } catch (error) {
      setEngineState(
        "error",
        "Local engine unavailable",
        "Connection failed. No work ran and no media or project data was sent."
      );
    }
  }

  connect();
}());
