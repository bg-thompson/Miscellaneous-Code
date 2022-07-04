package collatz

//
// A simple program to run some experiments regarding program execution time
// and the number of threads used.
//
// The aim of the program is to find the integer with the largest Collatz
// length, searching up to some value UPPER_SEARCH_LIMIT. The Wikipedia page
// on the Collatz Conjecture (3n + 1 problem) contains plenty of background
// on the conjecture.
//
// Created by Benjamin Thompson (github: bg-thompson)
// Last updated: 2022.07.04
//
// Created for educational purposes. Used verbatim, it is
// probably unsuitable for production code.
//

import f "core:fmt"
import   "core:thread"
import   "core:time"
import   "core:os"

DB              :: "DEBUG"
OUTPUT_FILENAME :: "results.csv"

UPPER_SEARCH_LIMIT  :: i64(100_000_000)
MAX_LEN_SOLUTION    :: i64(949)
MAX_N_LEN_SOLUTION  :: i64(63_728_127)

UPPER_THREAD_NUMBER :: 12
NUMBER_OF_TRIALS    :: 3

calculate_collatz_length :: proc( n : i64 ) -> ( length : i64 ) {
    length = 0
    x := n
    for x != 1 {
        if x & 1 == 1 {
            // x is odd
            x = 3*x + 1
        } else {
            // x is even
            x = x >> 1
        }
        length += 1
    }
    return length
}

Collatz_Data :: struct {
    lower_limit, upper_limit, max_len, max_n_len : i64,
}

find_maximum_collatz :: proc( ptr : rawptr ) {
    collatz_ptr := cast(^Collatz_Data) ptr
    lower_limit := collatz_ptr.lower_limit
    upper_limit := collatz_ptr.upper_limit
    max_len     := collatz_ptr.max_len
    max_n_len   := collatz_ptr.max_n_len

    largest_length        := i64(1)
    n_with_largest_length := i64(1)

    n := lower_limit
    for n < upper_limit {
        length_n := calculate_collatz_length(n)
        if length_n > largest_length {
            largest_length        = length_n
            n_with_largest_length = n
        }
        n += 1
    }
    collatz_ptr.max_len   = largest_length
    collatz_ptr.max_n_len = n_with_largest_length
    return
}

Result :: struct {
    total_threads : int,
    time          : f32,
}

main :: proc() {
    // Compute the maximum Collatz length, varying the number of threads
    // from 1 to UPPER_THREAD_NUMBER and timing the results.
    // Do this NUMBER_OF_TRIALS times, and write the results to OUTPUT_FILENAME.

    calculations_correct := true
    watch : time.Stopwatch
    time.stopwatch_start(&watch)
    results := make([dynamic] Result)
    for trials in 1..NUMBER_OF_TRIALS {
        for N in 1..UPPER_THREAD_NUMBER {
            clock_start     := time.stopwatch_duration(watch)
            step                := UPPER_SEARCH_LIMIT / i64(N) + 1
            // Create array of data to be passed to threads.
            data_array   := make([dynamic] Collatz_Data, 0, N)
            for t_n in 1..N {
                collatz_data := Collatz_Data{lower_limit = max(step * i64(t_n - 1), 1),
                                             upper_limit = min(step * i64(t_n), UPPER_SEARCH_LIMIT),
                                             max_len = 0,
                                             max_n_len = 0}
                append(&data_array, collatz_data)
            }
            // Create N threads, and start computation for each.
            threads := make([dynamic] ^thread.Thread, 0, N)
            for t_n in 0..N-1 {
                //          f.println(DB,"data going into thread:",data_array[t_n]) // @debug
                new_thread := thread.create_and_start_with_data(cast(rawptr) &data_array[t_n], find_maximum_collatz)
                append(&threads, new_thread)
            }
            // Wait for all threads to stop.
            for t in threads { thread.join(t) }
            
            // Calculate maximum length and the maximum number which produces it.
            max_len   := i64(0)
            max_n_len := i64(0)
            for data in data_array {
                if data.max_len > max_len {
                    max_len   = data.max_len
                    max_n_len = data.max_n_len
                }
            }
            // Calculation ended! Stop time and print results.
            clock_end         := time.stopwatch_duration(watch)
            delta_sec         := f32(time.duration_seconds(clock_end - clock_start))

            if max_len == MAX_LEN_SOLUTION && max_n_len == MAX_N_LEN_SOLUTION {
                append(&results, Result{total_threads = N, time=delta_sec})
                f.printf("Time with %d threads (sec): %f\n", N, delta_sec)
            } else {
                calculations_correct = false
                f.println("ERROR: Calculated lengths / maximums are incorrect!")
                f.println("Expected:", MAX_LEN_SOLUTION, "got:", max_len)
                f.println("Expected:", MAX_N_LEN_SOLUTION, "got:", max_n_len)
            }
        }
    }
    
    output_buffer := make([dynamic] byte)
    defer delete(output_buffer)

    if calculations_correct {
        // Write a .txt file with the results (csv format) for use in a plotting program.
        output_buffer := make([dynamic] byte)
        for r in results {
            line := f.tprintf("%d,%f\n", r.total_threads, r.time)
            for b in transmute([]byte) line { append(&output_buffer, b) }
        }
        //      f.println(DB,"output_buffer:\n",string(output_buffer[:])) // @debug
        ok := os.write_entire_file(name = OUTPUT_FILENAME, data = output_buffer[:])
        if ok {
            f.println("Results written to:", OUTPUT_FILENAME)
        } else {
            f.println("Writing failed! Could not write to:", OUTPUT_FILENAME)
        }
    }
}
