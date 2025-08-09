// Full CLI for Scryer Prolog WASI Component
wit_bindgen::generate!({
    world: "cli",
    path: "wit",
    with: {
        "scryer:prolog/core@0.9.4": generate,
    },
});

use scryer::prolog::core::{Machine, MachineConfig, Solution};
use std::io::{self, Write};

fn main() {
    // Get command line arguments
    let args: Vec<String> = std::env::args().collect();
    
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
                    eprintln!("Error: --query requires an argument");
                    std::process::exit(1);
                }
            }
            "-f" | "--file" => {
                i += 1;
                if i < args.len() {
                    files.push(args[i].clone());
                } else {
                    eprintln!("Error: --file requires an argument");
                    std::process::exit(1);
                }
            }
            arg if arg.ends_with(".pl") => {
                files.push(arg.to_string());
            }
            arg if arg.starts_with("-") => {
                eprintln!("Unknown option: {}", arg);
                std::process::exit(1);
            }
            _ => {
                // Treat as a query if no query specified yet
                if query.is_none() && !args[i].starts_with("-") {
                    query = Some(args[i].clone());
                    repl = false;
                }
            }
        }
        i += 1;
    }

    // Handle help
    if help {
        print_help();
        return;
    }

    // Handle version
    if version {
        print_version();
        return;
    }

    // Create the Prolog machine
    let config = MachineConfig {
        heap_size: None,
        stack_size: None,
    };
    
    let machine = Machine::new(config);
    
    // Note: Libraries are not auto-loaded due to memory constraints in WASI
    // Users should load libraries explicitly using use_module/1
    // For example: use_module(library(between))

    // Load files
    for file_path in &files {
        match std::fs::read_to_string(file_path) {
            Ok(contents) => {
                // Use file name without extension as module name
                let module_name = file_path
                    .rsplit('/')
                    .next()
                    .unwrap_or(file_path)
                    .trim_end_matches(".pl");
                
                match machine.consult_module_string(module_name, &contents) {
                    Ok(_) => eprintln!("✓ Loaded: {}", file_path),
                    Err(e) => {
                        eprintln!("✗ Failed to load {}: {}", file_path, e);
                        std::process::exit(1);
                    }
                }
            }
            Err(e) => {
                eprintln!("✗ Could not read file {}: {}", file_path, e);
                std::process::exit(1);
            }
        }
    }

    // Execute query if provided
    if let Some(query_str) = query {
        execute_query(&machine, &query_str);
    } else if repl {
        run_repl(&machine);
    } else if !files.is_empty() {
        // Files loaded, but no query - just exit successfully
        println!("Files loaded successfully.");
    }
}

fn print_help() {
    println!("Scryer Prolog v0.9.4 (WASI Component)");
    println!();
    println!("USAGE:");
    println!("    scryer-prolog [OPTIONS] [QUERY]");
    println!();
    println!("OPTIONS:");
    println!("    -h, --help             Show this help message");
    println!("    -v, --version          Show version information");
    println!("    -q, --query <QUERY>    Execute a query and exit");
    println!("    -f, --file <FILE>      Load a Prolog file before running");
    println!();
    println!("NOTE:");
    println!("    Libraries must be loaded explicitly using use_module/1.");
    println!("    Example: use_module(library(between)), between(1, 5, X).");
    println!();
    println!("EXAMPLES:");
    println!("    scryer-prolog -q \"assertz(parent(tom, bob)), parent(tom, X).\"");
    println!("    scryer-prolog -q \"use_module(library(between)), between(1, 5, X).\"");
    println!("    scryer-prolog -f facts.pl -q \"parent(john, X).\"");
}

fn print_version() {
    println!("Scryer Prolog v0.9.4");
    println!("WASI Component Edition");
    println!("Based on the Warren Abstract Machine");
}

fn execute_query(machine: &Machine, query_str: &str) {
    match machine.run_query(query_str) {
        Ok(query_state) => {
            let mut found_solution = false;
            
            loop {
                match query_state.next() {
                    Ok(Some(solution)) => {
                        found_solution = true;
                        print_solution(solution);
                        
                        // For non-interactive mode, just show first solution
                        break;
                    }
                    Ok(None) => {
                        if !found_solution {
                            println!("false.");
                        }
                        break;
                    }
                    Err(e) => {
                        eprintln!("Query error: {}", e);
                        std::process::exit(1);
                    }
                }
            }
        }
        Err(e) => {
            eprintln!("Failed to run query: {}", e);
            std::process::exit(1);
        }
    }
}

fn run_repl(machine: &Machine) {
    println!("Scryer Prolog v0.9.4 (WASI Component)");
    println!("Type queries followed by '.' or 'exit.' to quit");
    println!("Note: Load libraries with: use_module(library(name)).");
    println!();
    
    let stdin = io::stdin();
    let mut stdout = io::stdout();
    
    loop {
        print!("?- ");
        stdout.flush().unwrap();
        
        let mut input = String::new();
        match stdin.read_line(&mut input) {
            Ok(0) => break, // EOF
            Ok(_) => {},
            Err(_) => break,
        }
        
        let input = input.trim();
        if input.is_empty() {
            continue;
        }
        
        if input == "exit." || input == "halt." {
            println!("Goodbye!");
            break;
        }
        
        // Ensure query ends with a period
        let query = if input.ends_with('.') {
            input.to_string()
        } else {
            format!("{}.", input)
        };
        
        // Execute the query
        match machine.run_query(&query) {
            Ok(query_state) => {
                // Get first solution only to avoid memory issues
                match query_state.next() {
                    Ok(Some(solution)) => {
                        print_solution(solution);
                        println!(".");
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
}

fn print_solution(solution: Solution) {
    match solution {
        Solution::True => {
            print!("true");
        }
        Solution::False => {
            print!("false");
        }
        Solution::Exception(msg) => {
            print!("exception: {}", msg);
        }
        Solution::Bindings(bindings) => {
            let vars = bindings.variables();
            if vars.is_empty() {
                print!("true");
            } else {
                let mut first = true;
                for var in vars {
                    if !first {
                        print!(", ");
                    }
                    first = false;
                    
                    if let Some(term) = bindings.get_binding(&var) {
                        print!("{} = {}", var, term.to_string());
                    }
                }
            }
        }
    }
}