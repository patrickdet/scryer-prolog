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
    
    // Load essential libraries that the native REPL loads by default
    // These are loaded in toplevel.pl for the native version
    let essential_libraries = [
        "charsio",
        "error", 
        "files",
        "iso_ext",
        "lambda",
        "lists",
        "si",
        "os",
        "format",
    ];
    
    for lib in &essential_libraries {
        let query = format!("use_module(library({})).", lib);
        match machine.run_query(&query) {
            Ok(mut query_state) => {
                // Just run the query to load the module, don't need the result
                let _ = query_state.next();
            }
            Err(e) => {
                eprintln!("Warning: Failed to load library {}: {}", lib, e);
            }
        }
    }

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
    println!("PRE-LOADED LIBRARIES:");
    println!("    The following libraries are loaded automatically:");
    println!("    charsio, error, files, iso_ext, lambda, lists, si, os, format");
    println!();
    println!("    Additional libraries can be loaded with use_module/1:");
    println!("    Example: use_module(library(between)).");
    println!();
    println!("EXAMPLES:");
    println!("    scryer-prolog -q \"assertz(parent(tom, bob)), parent(tom, X).\"");
    println!("    scryer-prolog -q \"member(X, [1,2,3]).\"  # lists is pre-loaded");
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
            loop {
                match query_state.next() {
                    Ok(Some(solution)) => {
                        print_solution(solution);
                        
                        // For non-interactive mode, just show first solution
                        break;
                    }
                    Ok(None) => {
                        println!("false.");
                        break;
                    }
                    Err(e) => {
                        print_error(&e);
                        std::process::exit(1);
                    }
                }
            }
        }
        Err(e) => {
            // Clean up error messages for better UX
            if e.contains("Syntax error") {
                eprintln!("{}", e);
                eprintln!("Please check your query syntax.");
            } else {
                eprintln!("Error: {}", e);
            }
            std::process::exit(1);
        }
    }
}

fn run_repl(machine: &Machine) {
    println!("Scryer Prolog v0.9.4 (WASI Component)");
    println!("Type queries followed by '.' or 'exit.' to quit");
    println!("Pre-loaded: charsio, error, files, iso_ext, lambda, lists, si, os, format");
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
                        print_error(&e);
                    }
                }
            }
            Err(e) => {
                // Clean up error messages for better UX
                if e.contains("Syntax error") {
                    eprintln!("{}", e);
                } else {
                    eprintln!("Error: {}", e);
                }
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

fn print_error(error_msg: &str) {
    // Clean up common error patterns for better UX
    if error_msg.starts_with("Undefined procedure:") {
        eprintln!("Error: {}", error_msg);
        eprintln!("Hint: The predicate might not be defined or imported.");
    } else if error_msg.starts_with("Undefined") {
        eprintln!("Error: {}", error_msg);
        eprintln!("Hint: Check that all predicates are defined before use.");
    } else if error_msg.contains("Type error") {
        eprintln!("Error: {}", error_msg);
        eprintln!("Hint: Check that arguments have the correct types.");
    } else if error_msg.contains("Instantiation error") {
        eprintln!("Error: {}", error_msg);
        eprintln!("Hint: Some variables need to be bound before this operation.");
    } else if error_msg.contains("Domain error") {
        eprintln!("Error: {}", error_msg);
        eprintln!("Hint: The value is outside the expected range.");
    } else if error_msg.contains("Syntax error") {
        eprintln!("{}", error_msg);
        eprintln!("Hint: Check your query syntax - ensure proper parentheses and operators.");
    } else {
        // Generic error
        eprintln!("Error: {}", error_msg);
    }
}