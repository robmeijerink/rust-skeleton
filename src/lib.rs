//! Application logic. Keep `main.rs` a thin entry point that only calls [`run`].

use std::error::Error;

/// Runs the application.
///
/// # Errors
///
/// Returns an error when the application fails; `main` reports it and exits non-zero.
pub fn run() -> Result<(), Box<dyn Error>> {
    println!("Hello from rust-skeleton!");
    Ok(())
}
