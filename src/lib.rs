//! A free software ISO Prolog system.
#![recursion_limit = "4112"]
#![deny(missing_docs)]

#[macro_use]
extern crate static_assertions;

#[macro_use]
pub(crate) mod macros;
#[macro_use]
pub(crate) mod atom_table;
#[macro_use]
pub(crate) mod arena;
#[macro_use]
pub(crate) mod parser;
mod allocator;
mod arithmetic;
pub(crate) mod codegen;
mod debray_allocator;
#[cfg(all(feature = "ffi", not(target_arch = "wasm32")))]
mod ffi;
mod forms;
mod heap_iter;
pub(crate) mod heap_print;
#[cfg(all(feature = "http", not(target_arch = "wasm32")))]
mod http;
mod indexing;
mod variable_records;
#[macro_use]
pub(crate) mod instructions {
    include!(concat!(env!("OUT_DIR"), "/instructions.rs"));
}
mod iterators;
pub(crate) mod machine;
mod raw_block;
pub(crate) mod read;
#[cfg(all(feature = "repl", not(target_arch = "wasm32")))]
mod repl_helper;
mod targets;
pub(crate) mod types;

// Re-exports
pub use machine::config::*;
pub use machine::lib_machine::*;
pub use machine::Machine;

#[cfg(all(target_arch = "wasm32", target_os = "unknown"))]
pub mod wasm;

#[cfg(all(target_arch = "wasm32", target_os = "wasi", feature = "wasi-component"))]
pub mod wasi_component;

#[cfg(not(target_arch = "wasm32"))]
/// The entry point for the Scryer Prolog CLI.
pub fn run_binary() -> std::process::ExitCode {
    use crate::atom_table::Atom;
    use crate::machine::INTERRUPT;

    #[cfg(feature = "repl")]
    ctrlc::set_handler(move || {
        INTERRUPT.store(true, std::sync::atomic::Ordering::Relaxed);
    })
    .unwrap();

    #[cfg(target_arch = "wasm32")]
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();

    #[cfg(not(target_arch = "wasm32"))]
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap();

    runtime.block_on(async move {
        let mut wam = MachineBuilder::default()
            .with_streams(StreamConfig::stdio())
            .build();
        wam.run_module_predicate(atom!("$toplevel"), (atom!("$repl"), 0))
    })
}
