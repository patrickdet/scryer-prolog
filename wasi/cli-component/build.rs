fn main() {
    // Use wit-deps to manage WIT dependencies
    // This will read wit/deps.toml and populate wit/deps/
    wit_deps::lock!();
}
