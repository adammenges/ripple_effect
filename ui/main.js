const DEFAULTS = Object.freeze({
    appName: "My Mac App",
    bundleId: "com.example.my-mac-app",
});

const invoke = window.__TAURI__?.core?.invoke;
const appWindow = window.__TAURI__?.window?.getCurrentWindow?.();
const titlebar = document.getElementById("titlebar");
const appNameInput = document.getElementById("app-name");
const bundleIdInput = document.getElementById("bundle-id");
const configForm = document.getElementById("config-form");
const statusEl = document.getElementById("status");
const statusDot = document.getElementById("status-dot");
const commandDeck = document.getElementById("command-deck");
const shortcutsDialog = document.getElementById("shortcuts-dialog");
const btnCheck = document.getElementById("btn-check");
const btnBuild = document.getElementById("btn-build");
const btnReset = document.getElementById("btn-reset");
const btnCopy = document.getElementById("btn-copy");
const btnShortcuts = document.getElementById("btn-shortcuts");
const btnCloseShortcuts = document.getElementById("btn-close-shortcuts");

let lastCommand = "";

function startWindowDrag(event) {
    if (!appWindow || event.button !== 0) return;

    event.preventDefault();
    appWindow.startDragging().catch((error) => {
        console.error("Unable to start window drag:", error);
    });
}

function setStatus(message, state = "ready") {
    statusEl.textContent = message;
    statusDot.dataset.state = state;
}

function showCommand(preview) {
    lastCommand = preview.command;
    commandDeck.textContent = preview.command;
    btnCopy.disabled = false;
    setStatus(preview.summary, "success");
}

function setBusy(isBusy) {
    btnCheck.disabled = isBusy;
    btnBuild.disabled = isBusy || !configForm.checkValidity();
    if (isBusy) setStatus("Requesting a command preview from Rust…", "busy");
}

function validateForm() {
    const appName = appNameInput.value.trim();
    const bundleId = bundleIdInput.value.trim();
    const appNameIsValid = /^[A-Za-z0-9](?:[A-Za-z0-9 ._-]{0,62}[A-Za-z0-9])?$/.test(appName);
    const bundleIdIsValid = bundleId.length <= 255
        && bundleId.split(".").length >= 2
        && bundleId.split(".").every((part) => /^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$/.test(part));

    appNameInput.setCustomValidity(appNameIsValid ? "" : "Enter a valid app name.");
    bundleIdInput.setCustomValidity(bundleIdIsValid ? "" : "Enter a reverse-DNS bundle ID.");
    btnBuild.disabled = !configForm.checkValidity();
}

async function requestPreview(command, arguments_ = {}) {
    if (!invoke) {
        setStatus("Browser preview mode. Run ./scripts/dev.sh to connect the Rust backend.", "warning");
        return;
    }

    setBusy(true);
    try {
        showCommand(await invoke(command, arguments_));
    } catch (error) {
        setStatus(String(error), "error");
    } finally {
        setBusy(false);
    }
}

function previewChecks() {
    return requestPreview("get_check_command");
}

function previewBuild() {
    validateForm();
    if (!configForm.reportValidity()) return;

    return requestPreview("get_build_command", {
        appName: appNameInput.value,
        bundleId: bundleIdInput.value,
    });
}

function resetAll() {
    appNameInput.value = DEFAULTS.appName;
    bundleIdInput.value = DEFAULTS.bundleId;
    lastCommand = "";
    commandDeck.textContent = "$ _";
    btnCopy.disabled = true;
    validateForm();
    setStatus("Configuration reset to template defaults.", "ready");
    appNameInput.focus();
    appNameInput.select();
}

function toggleShortcuts() {
    if (shortcutsDialog.open) {
        shortcutsDialog.close();
    } else {
        shortcutsDialog.showModal();
    }
}

async function copyCommand() {
    if (!lastCommand) return;

    try {
        await navigator.clipboard.writeText(lastCommand.replace(/^\$ /, ""));
        setStatus("Command copied to the clipboard.", "success");
        btnCopy.textContent = "copied";
        window.setTimeout(() => { btnCopy.textContent = "copy"; }, 1200);
    } catch {
        setStatus("Clipboard access failed. Select the command and copy it manually.", "error");
        commandDeck.focus();
        window.getSelection()?.selectAllChildren(commandDeck);
    }
}

btnCheck.addEventListener("click", previewChecks);
btnBuild.addEventListener("click", previewBuild);
btnReset.addEventListener("click", resetAll);
btnCopy.addEventListener("click", copyCommand);
btnShortcuts.addEventListener("click", toggleShortcuts);
btnCloseShortcuts.addEventListener("click", () => shortcutsDialog.close());
titlebar.addEventListener("mousedown", startWindowDrag);

for (const input of [appNameInput, bundleIdInput]) {
    input.addEventListener("input", () => {
        validateForm();
        setStatus("Configuration changed. Preview the build to generate a command.", "ready");
    });
}

shortcutsDialog.addEventListener("click", (event) => {
    if (event.target === shortcutsDialog) shortcutsDialog.close();
});

document.addEventListener("keydown", (event) => {
    if (!event.metaKey) return;

    const shortcuts = {
        "1": () => { appNameInput.focus(); appNameInput.select(); },
        "2": () => { bundleIdInput.focus(); bundleIdInput.select(); },
        "/": toggleShortcuts,
        "r": previewChecks,
        "b": previewBuild,
        "k": resetAll,
    };
    const action = shortcuts[event.key.toLowerCase()];

    if (action) {
        event.preventDefault();
        action();
    }
});

validateForm();
commandDeck.textContent = "$ _";
if (!invoke) setStatus("Browser preview mode. Run ./scripts/dev.sh to connect the Rust backend.", "warning");
