#!/usr/bin/env node

/**
 * Test script for Scryer Prolog WASI Component using jco
 *
 * Prerequisites:
 *   npm install -g @bytecodealliance/jco
 *   npm install @bytecodealliance/preview2-shim
 *
 * Usage:
 *   1. First transpile the component: jco transpile target/wasi-component/scryer_prolog_component.wasm -o scryer-prolog-js/
 *   2. Run this script: node test_component.js
 */

import { readFile } from 'fs/promises';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// This assumes you've already transpiled the component with:
// jco transpile target/wasi-component/scryer_prolog_component.wasm -o scryer-prolog-js/

async function testScryerProlog() {
    console.log('=== Scryer Prolog WASI Component Test (Node.js) ===\n');

    try {
        // Import the transpiled component
        console.log('Loading transpiled component...');
        const { core } = await import('./scryer-prolog-js/scryer_prolog_component.js');

        // Create a Prolog machine
        console.log('Creating Prolog machine...');
        const machine = core.Machine({
            heapSize: undefined,
            stackSize: undefined
        });

        // Test 1: Basic facts and queries
        console.log('\n--- Test 1: Basic Facts ---');
        const program1 = `
            % Facts about programming languages
            language(prolog).
            language(javascript).
            language(rust).
            language(python).

            paradigm(prolog, logic).
            paradigm(javascript, multiparadigm).
            paradigm(rust, systems).
            paradigm(python, multiparadigm).

            year(prolog, 1972).
            year(javascript, 1995).
            year(rust, 2010).
            year(python, 1991).
        `;

        const consultResult = machine.consultModuleString('languages', program1);
        if (consultResult.tag === 'err') {
            console.error('Failed to load module:', consultResult.val);
            return;
        }
        console.log('Loaded languages module');

        // Query for all languages
        console.log('\nQuery: language(X).');
        const queryResult = machine.runQuery('language(X).');
        if (queryResult.tag === 'err') {
            console.error('Failed to run query:', queryResult.val);
            return;
        }

        const queryState = queryResult.val;
        let solutionCount = 0;

        while (true) {
            const nextResult = queryState.next();
            if (nextResult.tag === 'err') {
                console.error('Error getting next solution:', nextResult.val);
                break;
            }

            const solution = nextResult.val;
            if (!solution) break;

            if (solution.tag === 'bindings') {
                solutionCount++;
                const bindings = solution.val;
                const vars = bindings.variables();

                process.stdout.write(`  Solution ${solutionCount}: `);
                for (const varName of vars) {
                    const binding = bindings.getBinding(varName);
                    if (binding) {
                        console.log(`${varName} = ${binding.toString()}`);
                    }
                }
            } else if (solution.tag === 'true') {
                console.log('  true.');
                break;
            } else if (solution.tag === 'false') {
                console.log('  false.');
                break;
            } else if (solution.tag === 'exception') {
                console.log(`  Exception: ${solution.val}`);
                break;
            }
        }

        // Test 2: Rules and queries
        console.log('\n--- Test 2: Rules ---');
        const program2 = `
            % Rules about old languages
            old_language(L) :- language(L), year(L, Y), Y < 2000.

            % Logic languages
            logic_language(L) :- language(L), paradigm(L, logic).
        `;

        machine.consultModuleString('rules', program2);
        console.log('Loaded rules module');

        console.log('\nQuery: old_language(L).');
        const query2 = machine.runQuery('old_language(L).');
        if (query2.tag === 'ok') {
            const queryState2 = query2.val;
            console.log('Old languages (created before 2000):');

            while (true) {
                const result = queryState2.next();
                if (result.tag === 'err' || !result.val) break;

                const solution = result.val;
                if (solution.tag === 'bindings') {
                    const bindings = solution.val;
                    const L = bindings.getBinding('L');
                    if (L) {
                        console.log(`  - ${L.toString()}`);
                    }
                }
            }
        }

        // Test 3: Arithmetic
        console.log('\n--- Test 3: Arithmetic ---');
        const program3 = `
            % Fibonacci sequence
            fib(0, 0).
            fib(1, 1).
            fib(N, F) :-
                N > 1,
                N1 is N - 1,
                N2 is N - 2,
                fib(N1, F1),
                fib(N2, F2),
                F is F1 + F2.
        `;

        machine.consultModuleString('math', program3);
        console.log('Loaded math module');

        console.log('\nQuery: fib(10, F).');
        const query3 = machine.runQuery('fib(10, F).');
        if (query3.tag === 'ok') {
            const queryState3 = query3.val;
            const result = queryState3.next();

            if (result.tag === 'ok' && result.val && result.val.tag === 'bindings') {
                const bindings = result.val.val;
                const F = bindings.getBinding('F');
                if (F) {
                    console.log(`  The 10th Fibonacci number is: ${F.toString()}`);
                }
            }
        }

        // Test 4: Lists
        console.log('\n--- Test 4: Lists ---');
        const program4 = `
            % List utilities
            length([], 0).
            length([_|T], N) :- length(T, N1), N is N1 + 1.

            sum([], 0).
            sum([H|T], S) :- sum(T, S1), S is S1 + H.
        `;

        machine.consultModuleString('lists', program4);
        console.log('Loaded lists module');

        console.log('\nQuery: sum([1,2,3,4,5], S).');
        const query4 = machine.runQuery('sum([1,2,3,4,5], S).');
        if (query4.tag === 'ok') {
            const queryState4 = query4.val;
            const result = queryState4.next();

            if (result.tag === 'ok' && result.val && result.val.tag === 'bindings') {
                const bindings = result.val.val;
                const S = bindings.getBinding('S');
                if (S) {
                    console.log(`  Sum of [1,2,3,4,5] = ${S.toString()}`);
                }
            }
        }

        console.log('\n=== All tests completed successfully! ===');

    } catch (error) {
        console.error('\nERROR:', error.message);
        console.log('\nMake sure you have:');
        console.log('1. Built the component: ./wasi-build.sh build');
        console.log('2. Installed jco: npm install -g @bytecodealliance/jco');
        console.log('3. Transpiled the component: jco transpile target/wasi-component/scryer_prolog_component.wasm -o scryer-prolog-js/');
        console.log('4. Installed dependencies: npm install @bytecodealliance/preview2-shim');
    }
}

// Run the test
testScryerProlog().catch(console.error);
