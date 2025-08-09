wit_bindgen::generate!({
    world: "scryer-cli",
    path: "wit",
    with: {
        "scryer:prolog/core@0.9.4": generate,
    },
});

use std::io::{self, Write};

struct Component;

// This implements the WASI CLI command world's run export
impl Guest for Component {
    fn run() -> Result<(), ()> {
        // Call our implementation
        match run_impl() {
            Ok(()) => Ok(()),
            Err(e) => {
                eprintln!("Error: {}", e);
                Err(())
            }
        }
    }
}

fn run_impl() -> Result<(), String> {
    // Get command line arguments
    let args = std::env::args().collect::<Vec<_>>();
    
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
                // Skip unknown arguments for now
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
        return Ok(());
    }

    // Handle version
    if version {
        println!("Scryer Prolog CLI (WASI Component) v0.1.0");
        println!("Based on Scryer Prolog v0.9.4");
        return Ok(());
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
        
        // Read file contents
        match std::fs::read_to_string(&file) {
            Ok(contents) => {
                // Use a module name based on the file name
                let module_name = file.trim_end_matches(".pl");
                
                match machine.consult_module_string(module_name, &contents) {
                    Ok(_) => eprintln!("✓ Loaded: {}", file),
                    Err(e) => eprintln!("✗ Failed to load {}: {}", file, e),
                }
            }
            Err(e) => {
                eprintln!("✗ Could not read file {}: {}", file, e);
            }
        }
    }

    // Execute query if provided
    if let Some(query_str) = query {
        eprintln!("Executing query: {}", query_str);
        
        match machine.run_query(&query_str) {
            Ok(query_result) => {
                let mut solution_count = 0;
                
                loop {
                    match query_result.next() {
                        Ok(Some(solution)) => {
                            solution_count += 1;
                            match solution {
                                scryer::prolog::core::Solution::True => {
                                    println!("true.");
                                    break;
                                }
                                scryer::prolog::core::Solution::False => {
                                    if solution_count == 1 {
                                        println!("false.");
                                    }
                                    break;
                                }
                                scryer::prolog::core::Solution::Exception(msg) => {
                                    eprintln!("Exception: {}", msg);
                                    break;
                                }
                                scryer::prolog::core::Solution::Bindings(bindings) => {
                                    // Print variable bindings
                                    let vars = bindings.variables();
                                    if !vars.is_empty() {
                                        for var in vars {
                                            if let Some(term) = bindings.get_binding(&var) {
                                                println!("{} = {}", var, term.to_string());
                                            }
                                        }
                                    }
                                    
                                    // For now, just take the first solution
                                    println!(".");
                                    break;
                                }
                            }
                        }
                        Ok(None) => {
                            if solution_count == 0 {
                                println!("false.");
                            }
                            break;
                        }
                        Err(e) => {
                            eprintln!("Query error: {}", e);
                            break;
                        }
                    }
                }
            }
            Err(e) => {
                eprintln!("Failed to run query: {}", e);
            }
        }
    } else if repl {
        // Run REPL mode
        println!("Scryer Prolog v0.9.4 (WASI Component)");
        println!("Type queries followed by '.' or 'exit.' to quit");
        println!();
        
        let stdin = io::stdin();
        let mut stdout = io::stdout();
        
        loop {
            print!("?- ");
            stdout.flush().unwrap();
            
            let mut input = String::new();
            if stdin.read_line(&mut input).is_err() {
                break;
            }
            
            let input = input.trim();
            if input.is_empty() {
                continue;
            }
            
            if input == "exit." || input == "halt." {
                break;
            }
            
            // Execute the query
            match machine.run_query(input) {
                Ok(query_result) => {
                    match query_result.next() {
                        Ok(Some(solution)) => {
                            match solution {
                                scryer::prolog::core::Solution::True => {
                                    println!("true.");
                                }
                                scryer::prolog::core::Solution::False => {
                                    println!("false.");
                                }
                                scryer::prolog::core::Solution::Exception(msg) => {
                                    eprintln!("Exception: {}", msg);
                                }
                                scryer::prolog::core::Solution::Bindings(bindings) => {
                                    let vars = bindings.variables();
                                    if !vars.is_empty() {
                                        for var in vars {
                                            if let Some(term) = bindings.get_binding(&var) {
                                                println!("{} = {}", var, term.to_string());
                                            }
                                        }
                                    }
                                    println!(".");
                                }
                            }
                        }
                        Ok(None) => {
                            println!("false.");
                        }
                        Err(e) => {
                            eprintln!("Query error: {}", e);
                        }
                    }
                }
                Err(e) => {
                    eprintln!("Failed to run query: {}", e);
                }
            }
        }
        
        println!("Goodbye!");
    }

    Ok(())
}

// Export the component
export!(Component);