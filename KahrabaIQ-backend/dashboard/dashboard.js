const fmt = new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 });
let overlayDismissedForAlertId = null;
let adminToken = sessionStorage.getItem("kahrabaiqAdminToken") || "";
let adminPressTimer = null;

function text(id, value) {
  document.getElementById(id).textContent = value;
}

function number(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function firstPresent(...values) {
  for (const value of values) {
    if (value !== null && value !== undefined && value !== "") return value;
  }
  return undefined;
}

function boolValue(value) {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") return ["true", "1", "yes", "on", "detected", "motion", "smoke", "gas"].includes(value.trim().toLowerCase());
  return false;
}

function valueOrDash(value, suffix = "") {
  if (value === null || value === undefined || value === "") return "--";
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return String(value);
  return `${fmt.format(parsed)}${suffix}`;
}

function currentSensorValue(online, value, suffix = "") {
  return online ? valueOrDash(value, suffix) : "Unavailable";
}

function timestampText(value) {
  const ms = number(value, 0);
  if (!ms) return "No timestamp";
  return new Date(ms).toLocaleString();
}

function deviceState(device) {
  if (device.online === false) return "offline";
  return device.display_state || device.state || "unknown";
}

function deviceStatusClass(device, state) {
  const normalized = String(state || "").toLowerCase();
  if (normalized === "offline") return "offline";
  if (normalized === "off") return "off";
  if (device.stale) return "stale";
  return "";
}

function hasMeterReadings(device) {
  const type = String(device.type || "");
  return type === "smart_breaker" && device.energy_supported !== false;
}

function canControl(device) {
  return device.controllable === true;
}

function sensorDevice(devices) {
  return Object.values(devices).find((device) => {
    const type = String(device.type || "");
    const id = String(device.id || device.device_id || "");
    return type === "sensor_hub" || type === "esp32_sensor" || id.startsWith("esp32");
  }) || {};
}

function deviceSortValue(device) {
  const explicit = Number(device.display_order ?? device.sort_order ?? device.order ?? device.position);
  if (Number.isFinite(explicit)) return explicit;
  const id = String(device.device_id || device.id || device._dashboardKey || "");
  const match = id.match(/([0-9]+)/);
  return match ? Number(match[1]) : Number.MAX_SAFE_INTEGER;
}

function deviceSortRank(device) {
  const type = String(device.type || "").toLowerCase();
  if (type.includes("breaker")) return 0;
  if (device.controllable === true) return 1;
  return 2;
}

function deviceSortText(device) {
  return [
    device.branch,
    device.name,
    device.device_id,
    device.id,
    device._dashboardKey,
  ].map((value) => String(value || "").trim().toLowerCase()).join("|");
}

function compareDevices(a, b) {
  const rankDiff = deviceSortRank(a) - deviceSortRank(b);
  if (rankDiff) return rankDiff;
  const valueDiff = deviceSortValue(a) - deviceSortValue(b);
  if (valueDiff) return valueDiff;
  return deviceSortText(a).localeCompare(deviceSortText(b), undefined, { numeric: true, sensitivity: "base" });
}

function dashboardPayload(data) {
  const raw = data.dashboard || {};
  return raw.dashboard && typeof raw.dashboard === "object" ? raw.dashboard : raw;
}

function render(data) {
  const dashboard = dashboardPayload(data);
  const energy = dashboard.energy || data.energy || {};
  const room = dashboard.room || data.room || {};
  const devices = dashboard.devices || data.devices || {};
  const sensorHub = sensorDevice(devices);
  const sensorPayload = Object.keys(sensorHub.sensors || {}).length ? sensorHub.sensors : room;
  const sensorStatus = sensorHub.status || {};
  const sensorTimestamp = firstPresent(sensorPayload.timestamp_ms, sensorPayload.timestampMs, sensorStatus.last_seen_ms, sensorStatus.lastSeenMs, room.timestamp_ms, room.timestampMs);
  const sensorOnline = boolValue(firstPresent(sensorHub.online, sensorPayload.sensorOnline, sensorPayload.sensor_online, sensorPayload.online, room.sensorOnline, room.sensor_online, room.online)) && sensorPayload.stale !== true && room.stale !== true;
  const deviceList = Object.entries(devices).map(([key, value]) => ({
    _dashboardKey: key,
    id: key,
    ...(value || {}),
  })).filter((device) => {
    const type = String(device.type || "");
    const id = String(device.id || device.device_id || "");
    return type !== "sensor_hub" && type !== "esp32_sensor" && !id.startsWith("esp32");
  }).sort(compareDevices);
  const breakers = deviceList.filter((device) => String(device.type || "").includes("breaker"));
  const activeBreakers = breakers.filter((device) => deviceState(device) === "on").length;

  text("subtitle", `${data.home_id || "home"} - ${dashboard.updated_at_iso || "waiting for live state"}`);
  text("statusText", data.paired ? "Live" : "Unpaired");
  text("energyTimestamp", timestampText(energy.timestampMs || energy.timestamp_ms || dashboard.updated_at_ms || data.updated_at_ms));
  text("power", fmt.format(number(energy.currentPowerW ?? energy.powerW ?? energy.current_power_w ?? energy.total_power_W)));
  text("energyToday", `${fmt.format(number(energy.energyTodayKwh ?? energy.totalEnergyKwh ?? energy.today_kwh ?? energy.total_energy_kWh))} kWh`);
  text("costToday", `${number(energy.costToday ?? energy.today_cost_bhd ?? energy.total_cost_BHD).toFixed(3)} BD`);
  text("breakerCount", `${activeBreakers}/${breakers.length || 0}`);
  text("roomStatus", sensorOnline ? "Online" : room.stale ? "Stale" : "Offline");
  document.getElementById("roomStatus").className = `state ${sensorOnline ? "" : room.stale ? "stale" : "offline"}`;
  text("temperature", currentSensorValue(sensorOnline, firstPresent(sensorPayload.temperature, room.temperature), " C"));
  text("humidity", currentSensorValue(sensorOnline, firstPresent(sensorPayload.humidity, room.humidity), " %"));
  text("motion", sensorOnline ? (firstPresent(sensorPayload.motion_text, room.motion_text) || (boolValue(firstPresent(sensorPayload.motion, sensorPayload.motionDetected, sensorPayload.motion_detected, room.motion)) ? "Motion" : "Clear")) : "Unavailable");
  text("smoke", sensorOnline ? (firstPresent(sensorPayload.smoke_text, sensorPayload.smoke_status, room.smoke_text, room.smoke_status) || (boolValue(firstPresent(sensorPayload.smoke, sensorPayload.smokeDetected, sensorPayload.smoke_detected, sensorPayload.gasDetected, sensorPayload.gas_detected, room.smoke)) ? "Detected" : "Clear")) : "Unavailable");
  text("sensorUpdated", timestampText(sensorTimestamp));
  text("aqi", currentSensorValue(sensorOnline, firstPresent(sensorPayload.aqi, sensorPayload.airQuality, sensorPayload.air_quality, room.aqi, room.airQuality, room.air_quality)));
  text("eco2", currentSensorValue(sensorOnline, firstPresent(sensorPayload.eco2, room.eco2), " ppm"));
  text("tvoc", currentSensorValue(sensorOnline, firstPresent(sensorPayload.tvoc, room.tvoc), " ppb"));
  text("light", currentSensorValue(sensorOnline, firstPresent(sensorPayload.light_raw, sensorPayload.lightLevel, sensorPayload.light_level, room.light_raw, room.lightLevel, room.light_level)));
  text("sound", currentSensorValue(sensorOnline, firstPresent(sensorPayload.sound_raw, sensorPayload.soundLevel, sensorPayload.sound_level, sensorPayload.noise, room.sound_raw, room.soundLevel, room.sound_level, room.noise)));
  text("sensorFeed", sensorOnline ? "Online" : room.stale ? "Stale" : "Offline");

  const devicesNode = document.getElementById("devices");
  devicesNode.innerHTML = "";
  if (!deviceList.length) {
    devicesNode.textContent = "No devices are available.";
  } else {
    for (const device of deviceList) {
      const state = deviceState(device);
      const card = document.createElement("div");
      card.className = "device";
      const readings = hasMeterReadings(device)
        ? `<div class="two-col"><div><div class="label">Power</div><div class="small-value">${valueOrDash(device.power_W ?? device.power_w, " W")}</div></div><div><div class="label">Energy</div><div class="small-value">${valueOrDash(device.energy_kWh ?? device.energy_kwh, " kWh")}</div></div><div><div class="label">Voltage</div><div class="small-value">${valueOrDash(device.voltage_V ?? device.voltage_v, " V")}</div></div><div><div class="label">Current</div><div class="small-value">${valueOrDash(device.current_A ?? device.current_a, " A")}</div></div></div>`
        : `<div class="muted">Control state only. This device does not report power, energy, voltage, or current readings.</div>`;
      const deviceId = device.device_id || device.id;
      const commandActions = canControl(device)
        ? `<div class="command-actions" data-device-id="${deviceId}"><button class="primary" type="button" data-command="turn_on">Turn On</button><button class="danger" type="button" data-command="turn_off">Turn Off</button></div><div class="command-status" id="commandStatus-${deviceId}"></div>`
        : "";
      card.innerHTML = `<div class="device-head"><div><div class="device-name">${device.name || device.id || "Device"}</div><div class="label">${device.branch || device.control_method || ""}</div></div><div class="state ${deviceStatusClass(device, state)}">${state}</div></div>${readings}${commandActions}`;
      devicesNode.appendChild(card);
    }
  }

  const alerts = dashboard.alerts || data.alerts || [];
  const aiNotifications = dashboard.ai_notifications || data.ai_notifications || [];
  const ai = dashboard.ai || {};
  const notes = [];
  if (ai.ai_status_summary || ai.summary) notes.push(`<span class="warn">AI: ${ai.ai_status_summary || ai.summary}</span>`);
  if (room.stale || room.online === false) notes.push('<span class="warn">Room sensors are offline or stale.</span>');
  for (const alert of alerts) notes.push(`<span class="error">${alert.title || alert.message || "Active alert"}</span>`);
  for (const notification of aiNotifications.filter((item) => ["critical", "high"].includes(String(item.severity || "info").toLowerCase())).slice(0, 3)) {
    const severity = String(notification.severity || "info").toLowerCase();
    notes.push(`<span class="${severity === "critical" || severity === "high" ? "error" : "warn"}">AI: ${notification.title || notification.message || "Notification"}</span>`);
  }
  document.getElementById("alerts").innerHTML = notes.length ? `<div class="notes-list">${notes.map((note) => `<div class="note">${note}</div>`).join("")}</div>` : "No active alerts.";

  const overlay = document.getElementById("alertOverlay");
  const overlayMessage = document.getElementById("alertOverlayMessage");
  const criticalAlert = [...alerts, ...aiNotifications].find((alert) => {
    const severity = String(alert.severity || alert.level || "").toLowerCase();
    const alertType = String(alert.alert_type || alert.type || alert.category || "").toLowerCase();
    const message = String(alert.message || alert.title || "").toLowerCase();
    return severity === "critical" || alertType.includes("smoke") || alertType.includes("gas") || message.includes("smoke") || message.includes("gas");
  });
  if (!criticalAlert) {
    overlay.classList.remove("visible");
    overlayDismissedForAlertId = null;
  } else {
    const alertId = String(criticalAlert.alert_id || criticalAlert.id || "critical_alert");
    overlayMessage.textContent = criticalAlert.message || criticalAlert.title || "Smoke or gas was detected. Check the area immediately.";
    if (overlayDismissedForAlertId !== alertId) overlay.classList.add("visible");
    document.getElementById("alertOverlayButton").onclick = () => {
      overlayDismissedForAlertId = alertId;
      overlay.classList.remove("visible");
    };
  }
}

async function jsonFetch(path, options = {}) {
  const response = await fetch(path, { cache: "no-store", ...options });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.success === false) throw new Error(data.message || data.detail || "Request failed");
  return data;
}

async function refresh() {
  try {
    render(await jsonFetch("/api/dashboard/kiosk/dashboard-data"));
  } catch (error) {
    text("statusText", "Offline");
    document.getElementById("alerts").innerHTML = `<span class="error">${error.message}</span>`;
  }
}

async function waitForCommand(commandId, label = "Command") {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const data = await jsonFetch(`/api/dashboard/commands/${commandId}`);
    const command = data.command || {};
    if (!["pending", "executing"].includes(command.status)) {
      const result = command.result && typeof command.result === "object" ? command.result : command;
      if (command.status === "failed") throw new Error(result.message || `${label} failed`);
      return result.result && typeof result.result === "object" ? result.result : result;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  throw new Error(`${label} is still pending.`);
}

async function generateInviteQr() {
  const button = document.getElementById("generateInviteQrButton");
  const status = document.getElementById("inviteQrStatus");
  const qrBox = document.getElementById("inviteQrBox");
  button.disabled = true;
  status.textContent = "Generating QR...";
  qrBox.textContent = "Loading";
  try {
    const data = await jsonFetch("/api/dashboard/kiosk/home-invite-qr", { method: "POST" });
    qrBox.innerHTML = data.qr_svg || "QR unavailable";
    const expiry = data.expires_at_ms ? new Date(data.expires_at_ms).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : "";
    status.textContent = expiry ? `Ready. Expires at ${expiry}.` : "Ready.";
  } catch (error) {
    qrBox.textContent = "--";
    status.textContent = error.message;
  } finally {
    button.disabled = false;
  }
}

async function executeDeviceCommand(deviceId, command, container) {
  const buttons = Array.from(container.querySelectorAll("button"));
  const status = document.getElementById(`commandStatus-${deviceId}`);
  buttons.forEach((button) => button.disabled = true);
  if (status) status.textContent = `${command === "turn_on" ? "Turning on" : "Turning off"}...`;
  try {
    const queued = await jsonFetch("/api/dashboard/kiosk/device-command", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ device_id: deviceId, command }),
    });
    const result = await waitForCommand(queued.command_id, "Device command");
    if (status) status.textContent = result.message || "Command completed.";
    setTimeout(refresh, 600);
  } catch (error) {
    if (status) status.textContent = error.message;
  } finally {
    buttons.forEach((button) => button.disabled = false);
  }
}

function showAdminOverlay() {
  document.getElementById("adminOverlay").classList.add("visible");
  document.getElementById("adminLogin").style.display = adminToken ? "none" : "block";
  document.getElementById("adminControls").style.display = adminToken ? "block" : "none";
  if (adminToken) refreshAdminStatus();
}

function hideAdminOverlay() {
  document.getElementById("adminOverlay").classList.remove("visible");
}

async function adminFetch(path, options = {}) {
  const headers = { ...(options.headers || {}) };
  if (adminToken) headers.Authorization = `Bearer ${adminToken}`;
  const data = await jsonFetch(path, { ...options, headers });
  if (data.queued && data.command_id) return waitForCommand(data.command_id, "Admin command");
  return data;
}

function adminLog(value) {
  document.getElementById("adminLog").textContent = typeof value === "string" ? value : JSON.stringify(value, null, 2);
}

async function refreshAdminStatus() {
  try {
    adminLog("Waiting for Pi status...");
    adminLog(await adminFetch("/api/dashboard/admin/status"));
  } catch (error) {
    adminLog(error.message);
  }
}

document.getElementById("adminHotspot").addEventListener("pointerdown", () => {
  clearTimeout(adminPressTimer);
  adminPressTimer = setTimeout(showAdminOverlay, 5000);
});
document.getElementById("adminHotspot").addEventListener("pointerup", () => clearTimeout(adminPressTimer));
document.getElementById("adminHotspot").addEventListener("pointercancel", () => clearTimeout(adminPressTimer));
document.addEventListener("keydown", (event) => {
  if (event.ctrlKey && event.altKey && event.key.toLowerCase() === "a") showAdminOverlay();
  if (event.key === "Escape") hideAdminOverlay();
});

document.getElementById("adminLoginButton").onclick = async () => {
  try {
    const payload = {
      email: document.getElementById("adminEmail").value,
      password: document.getElementById("adminPassword").value,
      pin: document.getElementById("adminPin").value,
    };
    const data = await adminFetch("/api/dashboard/admin/login", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
    adminToken = data.token;
    sessionStorage.setItem("kahrabaiqAdminToken", adminToken);
    showAdminOverlay();
  } catch (error) {
    document.getElementById("adminCopy").textContent = error.message;
  }
};

document.getElementById("devices").addEventListener("click", (event) => {
  const button = event.target.closest("button[data-command]");
  if (!button) return;
  const container = button.closest(".command-actions");
  if (!container) return;
  executeDeviceCommand(container.dataset.deviceId, button.dataset.command, container);
});

document.getElementById("lockDashboardButton").onclick = async () => {
  try { await adminFetch("/api/dashboard/admin/lock", { method: "POST" }); } catch (_) {}
  adminToken = "";
  sessionStorage.removeItem("kahrabaiqAdminToken");
  hideAdminOverlay();
};
document.getElementById("refreshAdminStatusButton").onclick = refreshAdminStatus;
document.getElementById("viewLogsButton").onclick = async () => {
  adminLog("Waiting for Pi logs...");
  const data = await adminFetch("/api/dashboard/admin/logs?lines=180");
  const output = [data.stdout || "", data.stderr ? `\n[stderr]\n${data.stderr}` : ""].join("").trim();
  adminLog(output || JSON.stringify(data, null, 2) || "No service logs returned.");
};
document.getElementById("restartDashboardButton").onclick = async () => adminLog(await adminFetch("/api/dashboard/admin/services/restart-dashboard", { method: "POST" }));
document.getElementById("exitKioskButton").onclick = async () => adminLog(await adminFetch("/api/dashboard/admin/kiosk/exit", { method: "POST" }));
document.getElementById("returnKioskButton").onclick = async () => adminLog(await adminFetch("/api/dashboard/admin/kiosk/start", { method: "POST" }));
document.getElementById("generateInviteQrButton").onclick = generateInviteQr;
document.getElementById("maintenanceButton").onclick = async () => {
  if (!confirm("This will stop the dashboard and return the Pi to setup mode. Continue?")) return;
  adminLog(await adminFetch("/api/dashboard/admin/maintenance/start", { method: "POST" }));
};

refresh();
setInterval(refresh, 5000);
