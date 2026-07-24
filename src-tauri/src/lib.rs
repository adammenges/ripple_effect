use serde::Serialize;

const MAX_APP_NAME_CHARS: usize = 64;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CommandPreview {
    command: String,
    summary: &'static str,
}

#[tauri::command]
#[allow(clippy::needless_pass_by_value)] // Tauri deserializes command arguments into owned values.
fn get_build_command(app_name: String, bundle_id: String) -> Result<CommandPreview, String> {
    let app_name = validate_app_name(&app_name)?;
    let bundle_id = validate_bundle_id(&bundle_id)?;

    Ok(CommandPreview {
        command: format!(
            "$ APP_NAME={} APP_BUNDLE_ID={} ./scripts/build_macos_app.sh",
            shell_quote(app_name),
            shell_quote(bundle_id)
        ),
        summary: "Build command ready. Copy it into a terminal from the repository root.",
    })
}

#[tauri::command]
fn get_check_command() -> CommandPreview {
    CommandPreview {
        command: "$ ./scripts/check.sh".to_owned(),
        summary: "Check command ready. It formats, lints, and tests the workspace.",
    }
}

fn validate_app_name(value: &str) -> Result<&str, String> {
    let value = value.trim();
    let length = value.chars().count();

    if length == 0 {
        return Err("App name cannot be empty.".to_owned());
    }
    if length > MAX_APP_NAME_CHARS {
        return Err(format!(
            "App name must be {MAX_APP_NAME_CHARS} characters or fewer."
        ));
    }

    let starts_with_alphanumeric = value
        .chars()
        .next()
        .is_some_and(|character| character.is_ascii_alphanumeric());
    let ends_with_alphanumeric = value
        .chars()
        .next_back()
        .is_some_and(|character| character.is_ascii_alphanumeric());
    let contains_only_allowed_characters = value
        .chars()
        .all(|character| character.is_ascii_alphanumeric() || " ._-".contains(character));

    if !starts_with_alphanumeric || !ends_with_alphanumeric || !contains_only_allowed_characters {
        return Err(
            "App name must start and end with a letter or number and may contain spaces, dots, hyphens, and underscores."
                .to_owned(),
        );
    }

    Ok(value)
}

fn validate_bundle_id(value: &str) -> Result<&str, String> {
    let value = value.trim();
    let components: Vec<_> = value.split('.').collect();

    if value.len() > 255 || components.len() < 2 {
        return Err(
            "Bundle ID must be a reverse-DNS identifier such as com.example.my-app.".to_owned(),
        );
    }

    let valid = components.iter().all(|component| {
        !component.is_empty()
            && component
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-')
            && component
                .as_bytes()
                .first()
                .is_some_and(u8::is_ascii_alphanumeric)
            && component
                .as_bytes()
                .last()
                .is_some_and(u8::is_ascii_alphanumeric)
    });

    if !valid {
        return Err(
            "Bundle ID components must start and end with a letter or number and may contain hyphens."
                .to_owned(),
        );
    }

    Ok(value)
}

fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\"'\"'"))
}

/// Starts the Tauri application and blocks until its event loop exits.
///
/// # Panics
///
/// Panics if Tauri cannot initialize or its event loop exits with an error.
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            get_build_command,
            get_check_command
        ])
        .run(tauri::generate_context!())
        .expect("error while running Tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_human_readable_app_names() {
        assert_eq!(validate_app_name("  My Cool-App_2  "), Ok("My Cool-App_2"));
    }

    #[test]
    fn rejects_unsafe_app_names() {
        assert!(validate_app_name("My \"App\"").is_err());
        assert!(validate_app_name("-My App").is_err());
        assert!(validate_app_name("").is_err());
    }

    #[test]
    fn validates_reverse_dns_bundle_ids() {
        assert_eq!(
            validate_bundle_id("com.example.my-app"),
            Ok("com.example.my-app")
        );
        assert!(validate_bundle_id("my-app").is_err());
        assert!(validate_bundle_id("com.example.-app").is_err());
        assert!(validate_bundle_id("com.example.my_app").is_err());
    }

    #[test]
    fn quotes_shell_values_defensively() {
        assert_eq!(shell_quote("Adam's App"), "'Adam'\"'\"'s App'");
    }

    #[test]
    fn build_preview_contains_validated_values() {
        let preview = get_build_command("My App".to_owned(), "com.example.my-app".to_owned())
            .expect("valid values should produce a command");

        assert_eq!(
            preview.command,
            "$ APP_NAME='My App' APP_BUNDLE_ID='com.example.my-app' ./scripts/build_macos_app.sh"
        );
    }
}
