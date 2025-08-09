wit_bindgen::generate!({
    world: "scryer-cli",
    path: "wit",
    with: {
        "scryer:prolog/core@0.9.4": generate,
    },
});

use exports::scryer::prolog_cli::cli_interface::Guest;

struct Component;

impl Guest for Component {
    fn run(args: Vec<String>) -> Result<u32, String> {
        // Parse command line arguments
        let mut help = false;
        let mut version = false;
        let mut query = None;
        let mut files = Vec::new();
        let mut repl = true;

        let mut i = 1; // Skip program name
        while i < args.len() {
            match args[i].as_str() {
                "-h" | "--help" => {
                    help = true;
                    repl = false;
                }
                "-v" | "--version" => {
                    version = true;
                    repl = false;
                }
                "-q" | "--query" => {
                    i += 1;
                    if i < args.len() {
                        query = Some(args[i].clone());
                        repl = false;
                    } else {
                        return Err("--query requires an argument".to_string());
                    }
                }
                "-f" | "--file" => {
                    i += 1;
                    if i < args.len() {
                        files.push(args[i].clone());
                    } else {
                        return Err("--file requires an argument".to_string());
                    }
                }
                arg if arg.ends_with(".pl") => {
                    files.push(arg.to_string());
                }
                _ => {
                    return Err(format!("Unknown argument: {}", args[i]));
                }
            }
            i += 1;
        }

        // Handle help
        if help {
            println!("Scryer Prolog CLI (WASI Component) v0.1.0");
            println!();
            println!("USAGE:");
            println!("    scryer-prolog-cli [OPTIONS] [FILES...]");
            println!();
            println!("OPTIONS:");
            println!("    -h, --help             Show this help message");
            println!("    -v, --version          Show version information");
            println!("    -q, --query <QUERY>    Execute a query and exit");
            println!("    -f, --file <FILE>      Load a Prolog file");
            println!();
            println!("FILES:");
            println!("    Any argument ending in .pl is treated as a file to load");
            return Ok(0);
        }

        // Handle version
        if version {
            println!("Scryer Prolog CLI (WASI Component) v0.1.0");
            println!("Based on Scryer Prolog v0.9.4");
            return Ok(0);
        }

        // Create machine configuration
        let config = scryer::prolog::core::MachineConfig {
            heap_size: None,
            stack_size: None,
        };

        // Create the Prolog machine
        let machine = scryer::prolog::core::Machine::new(config);

        // Load files
        for file in files {
            eprintln!("Loading file: {}", file);

            // In a real implementation, we would read the file contents
            // For now, we'll just show a placeholder
            eprintln!("Note: File loading not yet implemented in WASI component");

            // Example of how it would work:
            // let content = read_file(&file)?;
            // match machine.consult_module_string(&file, &content) {
            //     Ok(_) => eprintln!("Loaded successfully"),
            //     Err(e) => {
            //         eprintln!("Error loading {}: {}", file, e);
            //         return Ok(1);
            //     }
            // }
        }

        // Execute query if provided
        if let Some(query_str) = query {
            eprintln!("Executing query: {}", query_str);

            match machine.run_query(&query_str) {
                Ok(query_result) => {
                    let mut found_solution = false;

                    while let Ok(Some(solution)) = query_result.next() {
                        found_solution = true;
                        match solution {
                            scryer::prolog::core::Solution::True => {
                                println!("true.");
                                break;
                            }
                            scryer::prolog::core::Solution::False => {
                                println!("false.");
                                break;
                            }
                            scryer::prolog::core::Solution::Exception(msg) => {
                                eprintln!("ERROR: {}", msg);
                                return Ok(1);
                            }
                            scryer::prolog::core::Solution::Bindings(bindings) => {
                                // Print variable bindings
                                let vars = bindings.variables();
                                if vars.is_empty() {
                                    println!("true.");
                                } else {
                                    for (i, var) in vars.iter().enumerate() {
                                        if i > 0 {
                                            print!(", ");
                                        }
                                        if let Some(term) = bindings.get_binding(&var) {
                                            print!("{} = {}", var, term.to_string());
                                        }
                                    }
                                    println!();
                                }
                            }
                        }
                    }

                    if !found_solution {
                        println!("false.");
                    }
                }
                Err(e) => {
                    eprintln!("Failed to run query: {}", e);
                    return Ok(1);
                }
            }
        } else if repl {
            // Run REPL mode
            eprintln!("Scryer Prolog v0.9.4 (WASI Component)");
            eprintln!("Interactive REPL not yet implemented in WASI component");
            eprintln!("Use -q to execute queries or -h for help");

            // In a real implementation, we would:
            // 1. Read input from stdin
            // 2. Parse queries
            // 3. Execute them
            // 4. Print results
            // 5. Loop until exit
        }

        Ok(0)
    }
}

// Export the component implementation
export!(Component);
