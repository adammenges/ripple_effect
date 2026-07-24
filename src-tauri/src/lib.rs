use serde::{Deserialize, Serialize};
use std::{
    fs,
    os::unix::fs::{MetadataExt, PermissionsExt},
    path::{Path, PathBuf},
    process::Command,
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    time::Instant,
};
use tauri::{AppHandle, Manager, State};
use tauri_plugin_dialog::DialogExt;

const MAX_IMAGE_BYTES: u64 = 100 * 1024 * 1024;
const IMAGE_EXTENSIONS: &[&str] = &["png", "jpg", "jpeg", "heic", "heif", "tif", "tiff"];
const RENDERER_BYTES: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/ripple-renderer"));

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
enum ImageSlot {
    Before,
    After,
}

#[derive(Clone)]
struct SelectedImage {
    path: PathBuf,
    file_name: String,
    bytes: u64,
}

#[derive(Default)]
struct SelectedImages {
    before: Option<SelectedImage>,
    after: Option<SelectedImage>,
}

#[derive(Default)]
struct RippleState {
    images: Mutex<SelectedImages>,
    rendering: Arc<AtomicBool>,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ImageSelection {
    file_name: String,
    bytes: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SelectionSnapshot {
    before: Option<ImageSelection>,
    after: Option<ImageSelection>,
}

#[derive(Clone, Copy, Debug, Deserialize)]
struct RenderOrigin {
    x: f64,
    y: f64,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NativeRenderSummary {
    width: usize,
    height: usize,
    frames: usize,
    duration_seconds: f64,
    frames_per_second: u32,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct RenderResult {
    output_file_name: String,
    output_bytes: u64,
    width: usize,
    height: usize,
    frames: usize,
    duration_seconds: f64,
    frames_per_second: u32,
    render_milliseconds: u128,
}

impl From<&SelectedImage> for ImageSelection {
    fn from(value: &SelectedImage) -> Self {
        Self {
            file_name: value.file_name.clone(),
            bytes: value.bytes,
        }
    }
}

struct RenderFlag(Arc<AtomicBool>);

impl Drop for RenderFlag {
    fn drop(&mut self) {
        self.0.store(false, Ordering::Release);
    }
}

#[tauri::command]
async fn choose_image(
    app: AppHandle,
    state: State<'_, RippleState>,
    slot: ImageSlot,
) -> Result<Option<ImageSelection>, String> {
    if state.rendering.load(Ordering::Acquire) {
        return Err("Wait for the current video to finish before changing images.".to_owned());
    }

    let dialog_app = app.clone();
    let picked = tauri::async_runtime::spawn_blocking(move || {
        let mut dialog = dialog_app
            .dialog()
            .file()
            .set_title(match slot {
                ImageSlot::Before => "Choose the before image",
                ImageSlot::After => "Choose the after image",
            })
            .add_filter("Images", IMAGE_EXTENSIONS);

        if let Some(window) = dialog_app.get_webview_window("main") {
            dialog = dialog.set_parent(&window);
        }

        dialog.blocking_pick_file()
    })
    .await
    .map_err(|_| "The image picker could not be opened.".to_owned())?;

    let Some(picked) = picked else {
        return Ok(None);
    };
    let path = picked
        .into_path()
        .map_err(|_| "The selected item is not a local image file.".to_owned())?;
    let image = validate_image(&path)?;
    let response = ImageSelection::from(&image);
    let mut images = state
        .images
        .lock()
        .map_err(|_| "The image selection state is unavailable.".to_owned())?;

    match slot {
        ImageSlot::Before => images.before = Some(image),
        ImageSlot::After => images.after = Some(image),
    }

    Ok(Some(response))
}

#[tauri::command]
#[allow(clippy::needless_pass_by_value)] // Tauri injects State as an owned command argument.
fn get_selection_state(state: State<'_, RippleState>) -> Result<SelectionSnapshot, String> {
    let images = state
        .images
        .lock()
        .map_err(|_| "The image selection state is unavailable.".to_owned())?;

    Ok(SelectionSnapshot {
        before: images.before.as_ref().map(ImageSelection::from),
        after: images.after.as_ref().map(ImageSelection::from),
    })
}

#[tauri::command]
#[allow(clippy::needless_pass_by_value)] // Tauri injects State as an owned command argument.
fn clear_images(state: State<'_, RippleState>) -> Result<(), String> {
    if state.rendering.load(Ordering::Acquire) {
        return Err("Wait for the current video to finish before clearing images.".to_owned());
    }

    let mut images = state
        .images
        .lock()
        .map_err(|_| "The image selection state is unavailable.".to_owned())?;
    *images = SelectedImages::default();
    Ok(())
}

#[tauri::command]
async fn render_ripple_video(
    app: AppHandle,
    state: State<'_, RippleState>,
    origin: RenderOrigin,
) -> Result<Option<RenderResult>, String> {
    let origin = validate_render_origin(origin)?;
    state
        .rendering
        .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
        .map_err(|_| "A ripple video is already rendering.".to_owned())?;
    let _render_flag = RenderFlag(Arc::clone(&state.rendering));

    let (before, after) = {
        let images = state
            .images
            .lock()
            .map_err(|_| "The image selection state is unavailable.".to_owned())?;
        let before = images
            .before
            .clone()
            .ok_or_else(|| "Choose a before image first.".to_owned())?;
        let after = images
            .after
            .clone()
            .ok_or_else(|| "Choose an after image first.".to_owned())?;
        (before, after)
    };

    // Revalidate immediately before rendering because files can change after selection.
    let before = validate_image(&before.path)?;
    let after = validate_image(&after.path)?;

    let dialog_app = app.clone();
    let output = tauri::async_runtime::spawn_blocking(move || {
        let mut dialog = dialog_app
            .dialog()
            .file()
            .set_title("Save ripple video")
            .set_file_name("ripple-transition.mp4")
            .add_filter("MPEG-4 video", &["mp4"]);

        if let Some(window) = dialog_app.get_webview_window("main") {
            dialog = dialog.set_parent(&window);
        }

        dialog.blocking_save_file()
    })
    .await
    .map_err(|_| "The save dialog could not be opened.".to_owned())?;

    let Some(output) = output else {
        return Ok(None);
    };
    let output = output
        .into_path()
        .map_err(|_| "Choose a local folder for the MP4.".to_owned())?;
    let output = validate_output_path(output, &before.path, &after.path)?;

    let render_result = tauri::async_runtime::spawn_blocking(move || {
        run_renderer(&before.path, &after.path, &output, origin)
    })
    .await
    .map_err(|_| "The Metal renderer stopped unexpectedly.".to_owned())??;

    Ok(Some(render_result))
}

fn validate_image(path: &Path) -> Result<SelectedImage, String> {
    let canonical = fs::canonicalize(path)
        .map_err(|_| "The selected image is no longer available.".to_owned())?;
    let metadata = fs::metadata(&canonical)
        .map_err(|_| "The selected image could not be inspected.".to_owned())?;

    if !metadata.is_file() {
        return Err("Choose an image file, not a folder.".to_owned());
    }
    if metadata.len() == 0 {
        return Err("The selected image is empty.".to_owned());
    }
    if metadata.len() > MAX_IMAGE_BYTES {
        return Err("Each image must be 100 MB or smaller.".to_owned());
    }
    if !has_supported_image_extension(&canonical) {
        return Err("Choose a PNG, JPEG, HEIC, HEIF, TIFF, or TIF image.".to_owned());
    }

    let file_name = canonical
        .file_name()
        .and_then(|name| name.to_str())
        .filter(|name| !name.is_empty())
        .ok_or_else(|| "The selected image needs a valid file name.".to_owned())?
        .to_owned();

    Ok(SelectedImage {
        path: canonical,
        file_name,
        bytes: metadata.len(),
    })
}

fn has_supported_image_extension(path: &Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| {
            IMAGE_EXTENSIONS
                .iter()
                .any(|allowed| extension.eq_ignore_ascii_case(allowed))
        })
}

fn validate_render_origin(origin: RenderOrigin) -> Result<RenderOrigin, String> {
    if !origin.x.is_finite()
        || !origin.y.is_finite()
        || !(0.0..=1.0).contains(&origin.x)
        || !(0.0..=1.0).contains(&origin.y)
    {
        return Err("Choose a ripple origin inside the frame.".to_owned());
    }
    Ok(origin)
}

fn validate_output_path(
    mut output: PathBuf,
    before: &Path,
    after: &Path,
) -> Result<PathBuf, String> {
    match output.extension().and_then(|extension| extension.to_str()) {
        None => {
            output.set_extension("mp4");
        }
        Some(extension) if extension.eq_ignore_ascii_case("mp4") => {}
        Some(_) => return Err("Save the video with an .mp4 extension.".to_owned()),
    }

    let parent = output
        .parent()
        .ok_or_else(|| "Choose a folder for the MP4.".to_owned())?;
    let parent = fs::canonicalize(parent)
        .map_err(|_| "The selected output folder is unavailable.".to_owned())?;
    let file_name = output
        .file_name()
        .filter(|name| !name.is_empty())
        .ok_or_else(|| "Enter a file name for the MP4.".to_owned())?;
    let output = parent.join(file_name);

    if output == before || output == after {
        return Err("The MP4 cannot replace one of the source images.".to_owned());
    }

    if let Ok(metadata) = fs::symlink_metadata(&output) {
        if metadata.file_type().is_symlink() {
            return Err("Choose a regular file instead of a symbolic link.".to_owned());
        }
        if !metadata.is_file() {
            return Err("The output location is not a regular file.".to_owned());
        }

        for input in [before, after] {
            if let Ok(input_metadata) = fs::metadata(input)
                && metadata.dev() == input_metadata.dev()
                && metadata.ino() == input_metadata.ino()
            {
                return Err("The MP4 cannot replace one of the source images.".to_owned());
            }
        }
    }

    Ok(output)
}

fn run_renderer(
    before: &Path,
    after: &Path,
    output: &Path,
    origin: RenderOrigin,
) -> Result<RenderResult, String> {
    let executable = materialize_renderer()?;
    let started = Instant::now();
    let process_result = Command::new(&executable)
        .arg(before)
        .arg(after)
        .arg(output)
        .arg(origin.x.to_string())
        .arg(origin.y.to_string())
        .output();
    let _ = fs::remove_file(&executable);
    let process_output =
        process_result.map_err(|_| "The bundled Metal renderer could not start.".to_owned())?;

    if !process_output.status.success() {
        return Err(sanitize_renderer_error(
            &process_output.stderr,
            [before, after, output],
        ));
    }

    let summary: NativeRenderSummary = serde_json::from_slice(&process_output.stdout)
        .map_err(|_| "The Metal renderer returned an invalid result.".to_owned())?;
    let metadata = fs::metadata(output)
        .map_err(|_| "The renderer finished without producing an MP4.".to_owned())?;
    if !metadata.is_file() || metadata.len() == 0 {
        return Err("The renderer finished without producing an MP4.".to_owned());
    }

    let output_file_name = output
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("ripple-transition.mp4")
        .to_owned();

    Ok(RenderResult {
        output_file_name,
        output_bytes: metadata.len(),
        width: summary.width,
        height: summary.height,
        frames: summary.frames,
        duration_seconds: summary.duration_seconds,
        frames_per_second: summary.frames_per_second,
        render_milliseconds: started.elapsed().as_millis(),
    })
}

fn materialize_renderer() -> Result<PathBuf, String> {
    let directory =
        std::env::temp_dir().join(format!("ripple-renderer-{}", env!("CARGO_PKG_VERSION")));
    fs::create_dir_all(&directory)
        .map_err(|_| "The Metal renderer could not be prepared.".to_owned())?;
    fs::set_permissions(&directory, fs::Permissions::from_mode(0o700))
        .map_err(|_| "The Metal renderer could not be prepared.".to_owned())?;

    let executable = directory.join(format!("renderer-{}", std::process::id()));
    fs::write(&executable, RENDERER_BYTES)
        .map_err(|_| "The Metal renderer could not be prepared.".to_owned())?;
    fs::set_permissions(&executable, fs::Permissions::from_mode(0o700))
        .map_err(|_| "The Metal renderer could not be prepared.".to_owned())?;
    Ok(executable)
}

fn sanitize_renderer_error<const N: usize>(stderr: &[u8], paths: [&Path; N]) -> String {
    let mut message = String::from_utf8_lossy(stderr).trim().to_owned();
    for path in paths {
        message = message.replace(&*path.to_string_lossy(), "selected file");
    }

    let message: String = message.chars().take(240).collect();
    if message.is_empty() {
        "The ripple video could not be rendered.".to_owned()
    } else {
        message
    }
}

/// Starts the Tauri application and blocks until its event loop exits.
///
/// # Panics
///
/// Panics if Tauri cannot initialize or its event loop exits with an error.
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(RippleState::default())
        .invoke_handler(tauri::generate_handler![
            choose_image,
            get_selection_state,
            clear_images,
            render_ripple_video
        ])
        .run(tauri::generate_context!())
        .expect("error while running Ripple");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_supported_image_extensions_case_insensitively() {
        assert!(has_supported_image_extension(Path::new("before.PNG")));
        assert!(has_supported_image_extension(Path::new("after.heic")));
        assert!(has_supported_image_extension(Path::new("photo.JpEg")));
    }

    #[test]
    fn rejects_unsupported_or_missing_image_extensions() {
        assert!(!has_supported_image_extension(Path::new("video.mp4")));
        assert!(!has_supported_image_extension(Path::new("image")));
        assert!(!has_supported_image_extension(Path::new("archive.zip")));
    }

    #[test]
    fn renderer_errors_do_not_echo_selected_paths() {
        let before = Path::new("/Users/example/private/before.png");
        let after = Path::new("/Users/example/private/after.png");
        let output = Path::new("/Users/example/Desktop/ripple.mp4");
        let error = sanitize_renderer_error(
            b"Could not read /Users/example/private/before.png",
            [before, after, output],
        );

        assert_eq!(error, "Could not read selected file");
        assert!(!error.contains("/Users"));
    }

    #[test]
    fn empty_renderer_errors_use_a_safe_message() {
        assert_eq!(
            sanitize_renderer_error(b"", [Path::new("/tmp/input.png")]),
            "The ripple video could not be rendered."
        );
    }

    #[test]
    fn accepts_origins_on_and_inside_frame_edges() {
        for origin in [
            RenderOrigin { x: 0.0, y: 0.0 },
            RenderOrigin { x: 0.5, y: 0.5 },
            RenderOrigin { x: 1.0, y: 1.0 },
        ] {
            assert!(validate_render_origin(origin).is_ok());
        }
    }

    #[test]
    fn rejects_origins_outside_the_frame_or_not_finite() {
        for origin in [
            RenderOrigin { x: -0.1, y: 0.5 },
            RenderOrigin { x: 0.5, y: 1.1 },
            RenderOrigin {
                x: f64::NAN,
                y: 0.5,
            },
            RenderOrigin {
                x: 0.5,
                y: f64::INFINITY,
            },
        ] {
            assert!(validate_render_origin(origin).is_err());
        }
    }
}
