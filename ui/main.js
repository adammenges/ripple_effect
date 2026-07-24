const invoke = window.__TAURI__?.core?.invoke;
const appWindow = window.__TAURI__?.window?.getCurrentWindow?.();

const elements = {
    titlebar: document.getElementById("titlebar"),
    beforeButton: document.getElementById("choose-before"),
    afterButton: document.getElementById("choose-after"),
    beforeName: document.getElementById("before-name"),
    afterName: document.getElementById("after-name"),
    beforeMeta: document.getElementById("before-meta"),
    afterMeta: document.getElementById("after-meta"),
    clearButton: document.getElementById("clear-images"),
    renderButton: document.getElementById("render-video"),
    status: document.getElementById("status"),
    statusDot: document.getElementById("status-dot"),
    progress: document.getElementById("progress-track"),
    result: document.getElementById("render-result"),
    resultFile: document.getElementById("result-file"),
    resultFrame: document.getElementById("result-frame"),
    resultVideo: document.getElementById("result-video"),
    resultSize: document.getElementById("result-size"),
    shortcutsButton: document.getElementById("show-shortcuts"),
    shortcutsDialog: document.getElementById("shortcuts-dialog"),
    closeShortcuts: document.getElementById("close-shortcuts"),
};

const selections = {
    before: null,
    after: null,
};

let busyMode = null;
let elapsedTimer = null;
let renderStartedAt = 0;

function startWindowDrag(event) {
    if (!appWindow || event.button !== 0) return;

    event.preventDefault();
    appWindow.startDragging().catch(() => {
        setStatus("The window could not be moved from this area.", "warning");
    });
}

function formatBytes(bytes) {
    if (!Number.isFinite(bytes) || bytes <= 0) return "0 KB";

    const units = ["B", "KB", "MB", "GB"];
    const unitIndex = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
    const amount = bytes / (1024 ** unitIndex);
    const digits = unitIndex > 0 && amount < 10 ? 1 : 0;
    return `${amount.toFixed(digits)} ${units[unitIndex]}`;
}

function setStatus(message, state = "ready") {
    elements.status.textContent = message;
    elements.statusDot.dataset.state = state;
}

function updateSlot(slot) {
    const selection = selections[slot];
    const isBefore = slot === "before";
    const button = isBefore ? elements.beforeButton : elements.afterButton;
    const name = isBefore ? elements.beforeName : elements.afterName;
    const meta = isBefore ? elements.beforeMeta : elements.afterMeta;
    const label = isBefore ? "before" : "after";

    button.dataset.selected = String(Boolean(selection));
    name.textContent = selection?.fileName ?? `Choose ${label} image`;
    meta.textContent = selection
        ? `${formatBytes(selection.bytes)} · click to replace`
        : `The ${isBefore ? "starting" : "ending"} frame`;
    button.setAttribute(
        "aria-label",
        selection
            ? `${selection.fileName}, selected as ${label} image. Click to replace.`
            : `Choose ${label} image`
    );
}

function updateControls() {
    const hasBefore = Boolean(selections.before);
    const hasAfter = Boolean(selections.after);
    const isBusy = Boolean(busyMode);

    elements.beforeButton.disabled = isBusy;
    elements.afterButton.disabled = isBusy;
    elements.clearButton.disabled = isBusy || (!hasBefore && !hasAfter);
    elements.renderButton.disabled = isBusy || !hasBefore || !hasAfter;
}

function setBusy(mode) {
    busyMode = mode;
    elements.progress.hidden = mode !== "render";
    updateControls();
}

function hideResult() {
    elements.result.hidden = true;
}

function setSelection(slot, selection) {
    selections[slot] = selection;
    updateSlot(slot);
    updateControls();
    hideResult();
}

async function chooseImage(slot) {
    if (busyMode) return false;
    if (!invoke) {
        setStatus("Browser preview mode. Run ./scripts/dev.sh to choose local images.", "warning");
        return true;
    }

    setBusy("picker");
    setStatus(`Opening the ${slot} image picker…`, "busy");
    try {
        const selection = await invoke("choose_image", { slot });
        if (!selection) {
            setStatus(`No ${slot} image selected.`, "ready");
            return true;
        }

        setSelection(slot, selection);
        if (selections.before && selections.after) {
            setStatus("Both frames are ready. Render the MP4 when you are set.", "success");
        } else {
            const next = slot === "before" ? "after" : "before";
            setStatus(`${selection.fileName} selected. Choose the ${next} image.`, "success");
        }
    } catch (error) {
        setStatus(String(error), "error");
    } finally {
        setBusy(null);
    }
    return true;
}

function startElapsedStatus() {
    renderStartedAt = performance.now();
    window.clearInterval(elapsedTimer);
    elapsedTimer = window.setInterval(() => {
        const seconds = ((performance.now() - renderStartedAt) / 1000).toFixed(1);
        setStatus(`Rendering 180 frames with Metal… ${seconds}s elapsed.`, "busy");
    }, 250);
}

function stopElapsedStatus() {
    window.clearInterval(elapsedTimer);
    elapsedTimer = null;
}

function showResult(result) {
    elements.resultFile.textContent = result.outputFileName;
    elements.resultFrame.textContent = `${result.width} × ${result.height}`;
    elements.resultVideo.textContent = `${result.durationSeconds.toFixed(1)}s · ${result.framesPerSecond} fps`;
    elements.resultSize.textContent = formatBytes(result.outputBytes);
    elements.result.hidden = false;
}

async function renderVideo() {
    if (busyMode || !selections.before || !selections.after) return false;
    if (!invoke) {
        setStatus("Browser preview mode. Run ./scripts/dev.sh to render with Metal.", "warning");
        return true;
    }

    setBusy("render");
    hideResult();
    setStatus("Choose where to save the MP4.", "busy");
    startElapsedStatus();
    try {
        const result = await invoke("render_ripple_video");
        stopElapsedStatus();
        if (!result) {
            setStatus("Export canceled. Your two images are still selected.", "ready");
            return true;
        }

        showResult(result);
        const elapsed = (result.renderMilliseconds / 1000).toFixed(1);
        setStatus(`${result.outputFileName} saved successfully in ${elapsed}s.`, "success");
    } catch (error) {
        stopElapsedStatus();
        setStatus(String(error), "error");
    } finally {
        setBusy(null);
    }
    return true;
}

async function clearImages() {
    if (busyMode || (!selections.before && !selections.after)) return false;

    if (invoke) {
        try {
            await invoke("clear_images");
        } catch (error) {
            setStatus(String(error), "error");
            return true;
        }
    }

    selections.before = null;
    selections.after = null;
    updateSlot("before");
    updateSlot("after");
    updateControls();
    hideResult();
    setStatus("Images cleared. Choose the before image.", "ready");
    elements.beforeButton.focus();
    return true;
}

function toggleShortcuts() {
    if (elements.shortcutsDialog.open) {
        elements.shortcutsDialog.close();
    } else {
        elements.shortcutsDialog.showModal();
    }
    return true;
}

async function restoreSelections() {
    if (!invoke) {
        setStatus("Browser preview mode. Run ./scripts/dev.sh to choose local images.", "warning");
        return;
    }

    try {
        const snapshot = await invoke("get_selection_state");
        setSelection("before", snapshot.before);
        setSelection("after", snapshot.after);
        if (snapshot.before && snapshot.after) {
            setStatus("Both frames are ready. Render the MP4 when you are set.", "success");
        } else if (snapshot.before || snapshot.after) {
            setStatus(`Choose the ${snapshot.before ? "after" : "before"} image.`, "ready");
        }
    } catch (error) {
        setStatus(String(error), "error");
    }
}

elements.beforeButton.addEventListener("click", () => chooseImage("before"));
elements.afterButton.addEventListener("click", () => chooseImage("after"));
elements.renderButton.addEventListener("click", renderVideo);
elements.clearButton.addEventListener("click", clearImages);
elements.shortcutsButton.addEventListener("click", toggleShortcuts);
elements.closeShortcuts.addEventListener("click", () => elements.shortcutsDialog.close());
elements.titlebar.addEventListener("mousedown", startWindowDrag);

elements.shortcutsDialog.addEventListener("click", (event) => {
    if (event.target === elements.shortcutsDialog) elements.shortcutsDialog.close();
});

document.addEventListener("keydown", (event) => {
    if (!event.metaKey) return;

    const key = event.key.toLowerCase();
    let action = null;
    if (key === "1" && !busyMode) action = () => chooseImage("before");
    if (key === "2" && !busyMode) action = () => chooseImage("after");
    if (key === "enter" && !busyMode && selections.before && selections.after) {
        action = renderVideo;
    }
    if (key === "k" && !busyMode && (selections.before || selections.after)) {
        action = clearImages;
    }
    if (key === "/") action = toggleShortcuts;

    if (action) {
        event.preventDefault();
        void action();
    }
});

updateSlot("before");
updateSlot("after");
updateControls();
restoreSelections();
