//! WASI Component Model implementation for Scryer Prolog
//!
//! This module provides the WebAssembly Component Model interface for Scryer Prolog,
//! allowing it to be used as a WASI component in server-side WebAssembly runtimes.

#![allow(missing_docs)]

use crate::{LeafAnswer, Term as ScryerTerm};
use crate::{Machine as ScryerMachine, MachineBuilder, QueryState as ScryerQueryState};

use std::any::Any;
use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;
use std::sync::atomic::{AtomicU32, Ordering};

// Generate bindings from WIT files
wit_bindgen::generate!({
    world: "scryer-prolog",
    path: "wasi/wit",
});

use exports::scryer::prolog::core::{
    BindingSet, CompoundParts, Guest, GuestBindingSet, GuestMachine, GuestQueryState, GuestTermRef,
    MachineConfig, QueryState, Solution, TermRef, TermType,
};

struct Component;

// Global atomic counter for generating unique IDs
static NEXT_ID: AtomicU32 = AtomicU32::new(1);

fn next_id() -> u32 {
    NEXT_ID.fetch_add(1, Ordering::Relaxed)
}

// Type-erased storage for QueryState
struct StoredQueryState {
    // Store the actual QueryState with 'static lifetime
    // This is safe because:
    // 1. WASI is single-threaded
    // 2. We ensure the machine isn't dropped while query is active
    // 3. We properly clean up when QueryStateResource is dropped
    state: Box<dyn Any>,
}

impl StoredQueryState {
    unsafe fn from_query_state<'a>(qs: ScryerQueryState<'a>) -> Self {
        // Transmute to 'static - safe due to our invariants
        let static_qs: ScryerQueryState<'static> = std::mem::transmute(qs);
        StoredQueryState {
            state: Box::new(static_qs),
        }
    }
    
    fn as_mut(&mut self) -> &mut ScryerQueryState<'static> {
        self.state
            .downcast_mut::<ScryerQueryState<'static>>()
            .expect("StoredQueryState should always contain QueryState")
    }
}

// Machine state with optional active query
struct MachineState {
    machine: Rc<RefCell<ScryerMachine>>,
    // Track the active query for this machine (if any)
    active_query: Option<(u32, StoredQueryState)>, // (query_id, stored_state)
}

// Component state management
struct ComponentState {
    machines: HashMap<u32, Rc<RefCell<MachineState>>>,
    // Map query IDs to their machine IDs
    query_to_machine: HashMap<u32, u32>,
    binding_sets: HashMap<u32, Rc<BindingSetData>>,
    term_refs: HashMap<u32, Rc<TermData>>,
}

impl Default for ComponentState {
    fn default() -> Self {
        Self {
            machines: HashMap::new(),
            query_to_machine: HashMap::new(),
            binding_sets: HashMap::new(),
            term_refs: HashMap::new(),
        }
    }
}

// Thread-local storage for component state
thread_local! {
    static STATE: RefCell<ComponentState> = RefCell::new(ComponentState::default());
}

// Data for a binding set
struct BindingSetData {
    bindings: Vec<(String, ScryerTerm)>,
}

// Data for a term reference
struct TermData {
    term: ScryerTerm,
}

/// Resource implementation for a Scryer Prolog machine instance in WASI
pub struct MachineResource {
    /// Unique identifier for this machine instance
    id: u32,
}

impl GuestMachine for MachineResource {
    fn new(config: MachineConfig) -> Self {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            let builder = MachineBuilder::default();

            // Apply configuration if provided
            if let Some(heap_size) = config.heap_size {
                // TODO: Add heap size configuration when available in MachineBuilder
                let _ = heap_size; // Suppress unused warning for now
            }

            if let Some(stack_size) = config.stack_size {
                // TODO: Add stack size configuration when available in MachineBuilder
                let _ = stack_size; // Suppress unused warning for now
            }

            // Build machine with bootstrap libraries loaded - this is synchronous
            // The build() method already loads ops_and_meta_predicates and builtins
            let machine = builder.build();
            
            // Wrap in MachineState with no active query
            let machine_state = MachineState {
                machine: Rc::new(RefCell::new(machine)),
                active_query: None,
            };

            let id = next_id();
            state.machines.insert(id, Rc::new(RefCell::new(machine_state)));

            MachineResource { id }
        })
    }

    fn consult_module_string(&self, module_name: String, program: String) -> Result<(), String> {
        STATE.with(|state| {
            let state = state.borrow_mut();
            let machine_state_rc = state
                .machines
                .get(&self.id)
                .ok_or_else(|| "Machine not found".to_string())?
                .clone();

            let mut machine_state = machine_state_rc.borrow_mut();
            
            // Cannot consult if there's an active query
            if machine_state.active_query.is_some() {
                return Err("Cannot consult module while query is active".to_string());
            }
            
            let mut machine = machine_state.machine.borrow_mut();

            // Consult the module - this is synchronous
            machine.consult_module_string(&module_name, program);

            // TODO: Proper error handling when Machine API provides it
            Ok(())
        })
    }

    fn run_query(&self, query: String) -> Result<QueryState, String> {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            let machine_state_rc = state
                .machines
                .get(&self.id)
                .ok_or_else(|| "Machine not found".to_string())?
                .clone();

            // We need to handle this in a specific order to manage lifetimes
            let query_id = next_id();
            
            // This scope ensures proper lifetime management
            {
                let mut machine_state = machine_state_rc.borrow_mut();
                
                // If there's an active query, we need to clean it up first
                if let Some((old_query_id, _)) = machine_state.active_query.take() {
                    // Remove the old query mapping
                    state.query_to_machine.remove(&old_query_id);
                }
                
                // Get a raw pointer to the machine to bypass borrow checker
                // This is safe because:
                // 1. We're single-threaded
                // 2. We ensure the machine lives as long as the query
                let machine_ptr = machine_state.machine.as_ptr();
                let machine_ref = unsafe { &mut *machine_ptr };
                
                // Use run_query_safe to get proper error handling
                let query_state = match machine_ref.run_query_safe(query.clone()) {
                    Ok(qs) => qs,
                    Err(e) => {
                        // Clean up the error message to be more user-friendly
                        if e.contains("Parse error") {
                            // Extract just the error type from "Parse error: ErrorType(...)"
                            let error_detail = e.strip_prefix("Parse error: ").unwrap_or(&e);
                            return Err(format!("Syntax error: {}", error_detail));
                        } else {
                            return Err(e);
                        }
                    }
                };
                
                // Store the QueryState with extended lifetime
                let stored_state = unsafe { StoredQueryState::from_query_state(query_state) };
                
                // Store the query state in the machine
                machine_state.active_query = Some((query_id, stored_state));
            }
            
            // Map query ID to machine ID
            state.query_to_machine.insert(query_id, self.id);

            Ok(QueryState::new(QueryStateResource {
                id: query_id,
            }))
        })
    }
}

/// Resource implementation for query state iteration in WASI
pub struct QueryStateResource {
    /// Unique identifier for this query state
    id: u32,
}

impl GuestQueryState for QueryStateResource {
    fn next(&self) -> Result<Option<Solution>, String> {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            
            // Find which machine owns this query
            let machine_id = *state
                .query_to_machine
                .get(&self.id)
                .ok_or_else(|| "QueryState not found".to_string())?;
            
            let machine_state_rc = state
                .machines
                .get(&machine_id)
                .ok_or_else(|| "Machine not found".to_string())?
                .clone();

            let mut machine_state = machine_state_rc.borrow_mut();
            
            // Check if this query is still active
            match &mut machine_state.active_query {
                Some((query_id, stored_state)) if *query_id == self.id => {
                    // Get the next solution from the stored QueryState
                    let query_state = stored_state.as_mut();
                    
                    match query_state.next() {
                        Some(Ok(leaf_answer)) => {
                            // Need to drop machine_state before calling convert_leaf_answer
                            // to avoid borrow conflicts
                            drop(machine_state);
                            let solution = convert_leaf_answer(leaf_answer, &mut state);
                            Ok(Some(solution))
                        }
                        Some(Err(error)) => {
                            // Format the error in a user-friendly way
                            let error_msg = format_error_term(&error);
                            Err(error_msg)
                        }
                        None => {
                            // Query exhausted, clean up
                            machine_state.active_query = None;
                            state.query_to_machine.remove(&self.id);
                            Ok(None)
                        }
                    }
                }
                _ => {
                    // Query is no longer active (was replaced by another query)
                    Err("Query is no longer active".to_string())
                }
            }
        })
    }
}

/// Resource implementation for variable bindings in query results
pub struct BindingSetResource {
    /// Unique identifier for this binding set
    id: u32,
}

impl GuestBindingSet for BindingSetResource {
    fn variables(&self) -> Vec<String> {
        STATE.with(|state| {
            let state = state.borrow();
            state
                .binding_sets
                .get(&self.id)
                .map(|data| data.bindings.iter().map(|(var, _)| var.clone()).collect())
                .unwrap_or_default()
        })
    }

    fn get_binding(&self, var_name: String) -> Option<TermRef> {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            let binding_set = state.binding_sets.get(&self.id)?;

            // Find the binding for the variable
            let term = binding_set
                .bindings
                .iter()
                .find(|(var, _)| var == &var_name)
                .map(|(_, term)| term.clone())?;

            // Create a term reference
            let term_id = next_id();
            state.term_refs.insert(term_id, Rc::new(TermData { term }));

            Some(TermRef::new(TermRefResource { id: term_id }))
        })
    }
}

/// Resource implementation for references to Prolog terms
pub struct TermRefResource {
    /// Unique identifier for this term reference
    id: u32,
}

impl GuestTermRef for TermRefResource {
    fn term_type(&self) -> TermType {
        STATE.with(|state| {
            let state = state.borrow();
            state
                .term_refs
                .get(&self.id)
                .map(|data| match &data.term {
                    ScryerTerm::Atom(_) => TermType::Atom,
                    ScryerTerm::Integer(_) => TermType::Integer,
                    ScryerTerm::Float(_) => TermType::Float,
                    ScryerTerm::String(_) => TermType::Str,
                    ScryerTerm::List(_) => TermType::Lst,
                    ScryerTerm::Compound(_, _) => TermType::Compound,
                    ScryerTerm::Var(_) => TermType::Variable,
                    ScryerTerm::Rational(_) => TermType::Rational,
                })
                .unwrap_or(TermType::Atom)
        })
    }

    fn as_atom(&self) -> Option<String> {
        STATE.with(|state| {
            let state = state.borrow();
            state.term_refs.get(&self.id).and_then(|data| {
                if let ScryerTerm::Atom(s) = &data.term {
                    Some(s.clone())
                } else {
                    None
                }
            })
        })
    }

    fn as_integer(&self) -> Option<i64> {
        STATE.with(|state| {
            let state = state.borrow();
            state.term_refs.get(&self.id).and_then(|data| {
                if let ScryerTerm::Integer(i) = &data.term {
                    // Try to convert IBig to i64, returning None if out of range
                    // IBig doesn't have to_i64, but we can try to convert via string
                    let s = i.to_string();
                    s.parse::<i64>().ok()
                } else {
                    None
                }
            })
        })
    }

    fn as_float(&self) -> Option<f64> {
        STATE.with(|state| {
            let state = state.borrow();
            state.term_refs.get(&self.id).and_then(|data| {
                if let ScryerTerm::Float(f) = &data.term {
                    Some(*f)
                } else {
                    None
                }
            })
        })
    }

    fn as_string(&self) -> Option<String> {
        STATE.with(|state| {
            let state = state.borrow();
            state.term_refs.get(&self.id).and_then(|data| {
                if let ScryerTerm::String(s) = &data.term {
                    Some(s.clone())
                } else {
                    None
                }
            })
        })
    }

    fn as_variable(&self) -> Option<String> {
        STATE.with(|state| {
            let state = state.borrow();
            state.term_refs.get(&self.id).and_then(|data| {
                if let ScryerTerm::Var(v) = &data.term {
                    Some(v.clone())
                } else {
                    None
                }
            })
        })
    }

    fn as_rational(&self) -> Option<(String, String)> {
        STATE.with(|state| {
            let state = state.borrow();
            state.term_refs.get(&self.id).and_then(|data| {
                if let ScryerTerm::Rational(r) = &data.term {
                    Some((r.numerator().to_string(), r.denominator().to_string()))
                } else {
                    None
                }
            })
        })
    }

    fn as_list(&self) -> Option<Vec<TermRef>> {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            let term_data = state.term_refs.get(&self.id)?.clone();

            if let ScryerTerm::List(terms) = &term_data.term {
                let term_refs: Vec<_> = terms
                    .iter()
                    .map(|term| {
                        let term_id = next_id();
                        state
                            .term_refs
                            .insert(term_id, Rc::new(TermData { term: term.clone() }));
                        TermRef::new(TermRefResource { id: term_id })
                    })
                    .collect();
                Some(term_refs)
            } else {
                None
            }
        })
    }

    fn as_compound(&self) -> Option<CompoundParts> {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            let term_data = state.term_refs.get(&self.id)?.clone();

            if let ScryerTerm::Compound(functor, args) = &term_data.term {
                let arg_refs: Vec<_> = args
                    .iter()
                    .map(|term| {
                        let term_id = next_id();
                        state
                            .term_refs
                            .insert(term_id, Rc::new(TermData { term: term.clone() }));
                        TermRef::new(TermRefResource { id: term_id })
                    })
                    .collect();

                Some(CompoundParts {
                    functor: functor.clone(),
                    args: arg_refs,
                })
            } else {
                None
            }
        })
    }

    fn to_string(&self) -> String {
        STATE.with(|state| {
            let state = state.borrow();
            state
                .term_refs
                .get(&self.id)
                .map(|data| format!("{:?}", data.term))
                .unwrap_or_else(|| "?".to_string())
        })
    }
}

// Convert LeafAnswer to Solution
fn convert_leaf_answer(answer: LeafAnswer, state: &mut ComponentState) -> Solution {
    match answer {
        LeafAnswer::True => Solution::True,
        LeafAnswer::False => Solution::False,
        LeafAnswer::Exception(term) => Solution::Exception(format!("{:?}", term)),
        LeafAnswer::LeafAnswer { bindings } => {
            let binding_set_id = next_id();
            let binding_data = BindingSetData {
                bindings: bindings.into_iter().collect(),
            };
            state
                .binding_sets
                .insert(binding_set_id, Rc::new(binding_data));

            Solution::Bindings(BindingSet::new(BindingSetResource { id: binding_set_id }))
        }
    }
}

// Resource management helpers
impl Drop for MachineResource {
    fn drop(&mut self) {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            
            // Clean up any active query for this machine
            // Need to clone to avoid borrow issues
            let query_id_to_remove = state.machines.get(&self.id)
                .and_then(|machine_state_rc| {
                    let machine_state = machine_state_rc.borrow();
                    machine_state.active_query.as_ref().map(|(id, _)| *id)
                });
            
            if let Some(query_id) = query_id_to_remove {
                state.query_to_machine.remove(&query_id);
            }
            
            state.machines.remove(&self.id);
        });
    }
}

impl Drop for QueryStateResource {
    fn drop(&mut self) {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            
            // Find and clean up this query from its machine
            if let Some(machine_id) = state.query_to_machine.remove(&self.id) {
                if let Some(machine_state_rc) = state.machines.get(&machine_id) {
                    let mut machine_state = machine_state_rc.borrow_mut();
                    // Only remove if it's still the active query
                    if let Some((query_id, _)) = &machine_state.active_query {
                        if *query_id == self.id {
                            machine_state.active_query = None;
                        }
                    }
                }
            }
        });
    }
}

impl Drop for BindingSetResource {
    fn drop(&mut self) {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            state.binding_sets.remove(&self.id);
        });
    }
}

impl Drop for TermRefResource {
    fn drop(&mut self) {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            state.term_refs.remove(&self.id);
        });
    }
}

// Helper function to format error terms in a user-friendly way
fn format_error_term(term: &ScryerTerm) -> String {
    if let ScryerTerm::Compound(functor, args) = term {
        if functor == "error" && args.len() == 2 {
            // Standard Prolog error term: error(ErrorType, Context)
            // Handle both compound error types and atom error types
            match &args[0] {
                ScryerTerm::Atom(error_type) => {
                    // Simple error atoms like instantiation_error
                    match error_type.as_str() {
                        "instantiation_error" => {
                            return "Instantiation error: unbound variable in arithmetic or comparison".to_string();
                        }
                        _ => {
                            return format!("Error: {}", error_type);
                        }
                    }
                }
                ScryerTerm::Compound(error_type, error_args) => {
                match error_type.as_str() {
                    "existence_error" => {
                        if error_args.len() >= 2 {
                            if let (ScryerTerm::Atom(resource), ScryerTerm::Compound(name, name_args)) = 
                                (&error_args[0], &error_args[1]) {
                                if name == "/" && name_args.len() == 2 {
                                    if let (ScryerTerm::Atom(pred), ScryerTerm::Integer(arity)) = 
                                        (&name_args[0], &name_args[1]) {
                                        return format!("Undefined {}: {}/{}", resource, pred, arity);
                                    }
                                }
                            }
                        }
                    }
                    "type_error" => {
                        if error_args.len() >= 2 {
                            if let (ScryerTerm::Atom(expected), culprit) = (&error_args[0], &error_args[1]) {
                                return format!("Type error: expected {}, got {:?}", expected, culprit);
                            }
                        }
                    }
                    "instantiation_error" => {
                        return "Instantiation error: unbound variable in arithmetic or comparison".to_string();
                    }
                    "evaluation_error" => {
                        if error_args.len() >= 1 {
                            if let ScryerTerm::Atom(error_type) = &error_args[0] {
                                match error_type.as_str() {
                                    "zero_divisor" => return "Division by zero error".to_string(),
                                    "undefined" => return "Evaluation error: undefined arithmetic operation".to_string(),
                                    "float_overflow" => return "Evaluation error: floating point overflow".to_string(),
                                    "int_overflow" => return "Evaluation error: integer overflow".to_string(),
                                    _ => return format!("Evaluation error: {}", error_type),
                                }
                            }
                        }
                    }
                    "syntax_error" => {
                        if error_args.len() >= 1 {
                            if let ScryerTerm::Atom(msg) = &error_args[0] {
                                return format!("Syntax error: {}", msg);
                            }
                        }
                    }
                    "domain_error" => {
                        if error_args.len() >= 2 {
                            if let (ScryerTerm::Atom(domain), culprit) = (&error_args[0], &error_args[1]) {
                                return format!("Domain error: {} is not in domain {}", 
                                    format_term_simple(culprit), domain);
                            }
                        }
                    }
                    _ => {}
                }
                }
                _ => {}
            }
        }
    }
    
    // Fallback to debug format if we can't parse the error
    format!("Runtime error: {:?}", term)
}

// Helper to format terms simply for error messages
fn format_term_simple(term: &ScryerTerm) -> String {
    match term {
        ScryerTerm::Atom(s) => s.clone(),
        ScryerTerm::Integer(i) => i.to_string(),
        ScryerTerm::Float(f) => f.to_string(),
        ScryerTerm::String(s) => format!("\"{}\"", s),
        ScryerTerm::Var(v) => v.clone(),
        ScryerTerm::List(items) => {
            let items_str: Vec<_> = items.iter().map(format_term_simple).collect();
            format!("[{}]", items_str.join(", "))
        }
        ScryerTerm::Compound(name, args) => {
            if args.is_empty() {
                name.clone()
            } else {
                let args_str: Vec<_> = args.iter().map(format_term_simple).collect();
                format!("{}({})", name, args_str.join(", "))
            }
        }
        ScryerTerm::Rational(r) => r.to_string(),
    }
}

// Export the component implementation
export!(Component);

impl Guest for Component {
    type Machine = MachineResource;
    type QueryState = QueryStateResource;
    type BindingSet = BindingSetResource;
    type TermRef = TermRefResource;
}
