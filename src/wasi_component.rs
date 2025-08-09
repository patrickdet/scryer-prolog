//! WASI Component Model implementation for Scryer Prolog
//!
//! This module provides the WebAssembly Component Model interface for Scryer Prolog,
//! allowing it to be used as a WASI component in server-side WebAssembly runtimes.

#![allow(missing_docs)]

use crate::{LeafAnswer, Term as ScryerTerm};
use crate::{Machine as ScryerMachine, MachineBuilder, QueryState as ScryerQueryState};

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

// Component state management
struct ComponentState {
    machines: HashMap<u32, Rc<RefCell<ScryerMachine>>>,
    query_states: HashMap<u32, Rc<RefCell<QueryStateWrapper>>>,
    binding_sets: HashMap<u32, Rc<BindingSetData>>,
    term_refs: HashMap<u32, Rc<TermData>>,
}

impl Default for ComponentState {
    fn default() -> Self {
        Self {
            machines: HashMap::new(),
            query_states: HashMap::new(),
            binding_sets: HashMap::new(),
            term_refs: HashMap::new(),
        }
    }
}

// Thread-local storage for component state
thread_local! {
    static STATE: RefCell<ComponentState> = RefCell::new(ComponentState::default());
}

// Wrapper for QueryState to handle lifetime issues
struct QueryStateWrapper {
    machine: Rc<RefCell<ScryerMachine>>,
    query_state: Option<ScryerQueryState<'static>>,
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
            let machine_rc = Rc::new(RefCell::new(machine));

            let id = next_id();
            state.machines.insert(id, machine_rc);

            MachineResource { id }
        })
    }

    fn consult_module_string(&self, module_name: String, program: String) -> Result<(), String> {
        STATE.with(|state| {
            let state = state.borrow_mut();
            let machine_rc = state
                .machines
                .get(&self.id)
                .ok_or_else(|| "Machine not found".to_string())?
                .clone();

            let mut machine = machine_rc.borrow_mut();

            // Consult the module - this is synchronous
            machine.consult_module_string(&module_name, program);

            // TODO: Proper error handling when Machine API provides it
            Ok(())
        })
    }

    fn run_query(&self, query: String) -> Result<QueryState, String> {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            let machine_rc = state
                .machines
                .get(&self.id)
                .ok_or_else(|| "Machine not found".to_string())?
                .clone();

            // Create a query state wrapper
            let wrapper = QueryStateWrapper {
                machine: machine_rc.clone(),
                query_state: None,
            };

            let query_id = next_id();
            state
                .query_states
                .insert(query_id, Rc::new(RefCell::new(wrapper)));

            // Initialize the query
            let _query_state_rc = state.query_states.get(&query_id).unwrap().clone();

            // We need to handle the lifetime issue here
            // This is a simplified approach - in production, we'd need better lifetime management
            {
                let mut machine = machine_rc.borrow_mut();
                // Run query within runtime context
                let query_state = machine.run_query(query.clone());

                // Store the query state (this is where we'd need unsafe or better design)
                // For now, we'll initialize it when first calling next()
                drop(query_state); // Can't store it directly due to lifetime
            }

            Ok(QueryState::new(QueryStateResource {
                id: query_id,
                query: query.clone(),
            }))
        })
    }
}

/// Resource implementation for query state iteration in WASI
pub struct QueryStateResource {
    /// Unique identifier for this query state
    id: u32,
    /// The query string to re-run when needed
    query: String,
}

impl GuestQueryState for QueryStateResource {
    fn next(&self) -> Result<Option<Solution>, String> {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            let wrapper_rc = state
                .query_states
                .get(&self.id)
                .ok_or_else(|| "QueryState not found".to_string())?
                .clone();

            let mut wrapper = wrapper_rc.borrow_mut();

            // If query_state is None, initialize it
            if wrapper.query_state.is_none() {
                // Run query in a separate scope to ensure machine borrow is dropped
                let query_state_static = {
                    let mut machine = wrapper.machine.borrow_mut();
                    let query_state = machine.run_query(self.query.clone());

                    // This is a workaround for the lifetime issue
                    // In a real implementation, we'd need a better solution
                    unsafe {
                        std::mem::transmute::<ScryerQueryState<'_>, ScryerQueryState<'static>>(
                            query_state,
                        )
                    }
                }; // machine borrow is dropped here

                wrapper.query_state = Some(query_state_static);
            }

            // Get the next answer
            if let Some(ref mut query_state) = wrapper.query_state {
                match query_state.next() {
                    Some(Ok(leaf_answer)) => {
                        let solution = convert_leaf_answer(leaf_answer, &mut state);
                        Ok(Some(solution))
                    }
                    Some(Err(error)) => Err(format!("Query error: {:?}", error)),
                    None => Ok(None),
                }
            } else {
                Err("Query state not initialized".to_string())
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
            state.machines.remove(&self.id);
        });
    }
}

impl Drop for QueryStateResource {
    fn drop(&mut self) {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            state.query_states.remove(&self.id);
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

// Export the component implementation
export!(Component);

impl Guest for Component {
    type Machine = MachineResource;
    type QueryState = QueryStateResource;
    type BindingSet = BindingSetResource;
    type TermRef = TermRefResource;
}
