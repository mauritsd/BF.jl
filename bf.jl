using ArgParse

# Simple wrapper to insert our translated brainfuck code into a Julia function
# that defines the heap (a), heap size (l) and the data pointer (dp).
function _construct_function(body_expr)
    fun_expr = quote
        function _bf()
            # Heap
            a = Char[0]
            # Heap size
            l = 1
            # Data pointer
            dp = 1

            $body_expr
        end
    end

    fun_expr
end

# Translate brainfuck operations into equivalent Julia code, taking advantage
# of Julia's decent metaprogramming support.
function _construct_body_expr(program)
    body_expr = :(begin end)
    skip_until = 0

    for (n, op) in enumerate(program)
        # Skip operations up to and including the requested operation.
        if n <= skip_until
            continue
        end

        if op == '+'
            subprogram = program[n:end]
            num_incs = _scan_num_ops(subprogram, '+')
            skip_until = n + num_incs - 1

            inc_expr = quote
                a[dp] += $num_incs
            end

            # Append the expression to the body.
            body_expr.args = [body_expr.args; inc_expr.args]
        elseif op == '-'
            subprogram = program[n:end]
            num_decs = _scan_num_ops(subprogram, '-')
            skip_until = n + num_decs - 1

            dec_expr = quote
                a[dp] -= $num_decs
            end

            # Append the expression to the body.
            body_expr.args = [body_expr.args; dec_expr.args]
        elseif op == '<'
            dp_left_expr = quote
                if dp == 1
                    unshift!(a, 0)
                    l += 1
                else
                    dp -= 1
                end
            end

            # Append the expression to the body.
            body_expr.args = [body_expr.args; dp_left_expr.args]
        elseif op == '>'
            dp_right_expr = quote
                if dp == l
                    push!(a, 0)
                    l += 1
                end

                dp += 1
            end

            # Append the expression to the body.
            body_expr.args = [body_expr.args; dp_right_expr.args]
        elseif op == '.'
            out_expr = quote
                write(STDOUT, a[dp])
            end

            # Append the expression to the body.
            body_expr.args = [body_expr.args; out_expr.args]
        elseif op == ','
            in_expr = quote
                c = read(STDIN, Char)
                a[dp] = c
            end

            # Append the expression to the body.
            body_expr.args = [body_expr.args; in_expr.args]
        elseif op == '['
            # Look for the matching closing bracket. Every time we see an
            # opening bracket we increment a counter keeping track of how
            # many closing brackets we need to read until we found 'our'
            # closing bracket.
            matching_bracket_pos = 0
            depth = 0
            for (m, mbr) in enumerate(program[n:end])
                if mbr == '['
                    depth += 1
                elseif mbr == ']'
                    depth -= 1
                    if depth == 0
                        matching_bracket_pos = m
                        break
                    elseif depth < 0
                        error("closing bracket found without matching opening bracket")
                    end
                end
            end

            if matching_bracket_pos > 0
                # Since the recursive call will translate the subprogram
                # within the loop for us we don't want to do it in this call.
                # Set skip_until to the position of the closing bracket so we
                # skip all those ops.
                skip_until = n + matching_bracket_pos - 1

                # Get everything within (but not including) the opening and
                # closing brackets.
                subprogram = program[n + 1:n + matching_bracket_pos - 2]
                subbody_expr = _construct_body_expr(subprogram)

                # Insert the translated subprogram in a loop that is equivalent
                # to the brainfuck [] semantics.
                loop_expr = quote
                    while a[dp] > 0
                        $subbody_expr
                    end
                end

                # Append the expression to the body.
                body_expr.args = [body_expr.args; loop_expr.args]
            else
                error("no closing bracket for opening bracket at pos $n")
            end
        end
    end

    body_expr
end

_all_ops = Set(['+', '-', '<', '>', '[', ']', '.', ','])

function _scan_num_ops(program, search_op)
    count_ = 0
    for (n, op) in enumerate(program)
        if op == search_op
            count_ += 1
        elseif op in _all_ops
            break
        end
    end

    if count_ == 0
        error("subprogram should start with the requested operation!")
    end

    count_
end

# Main function. Execution starts here.
function main()
    # Parse arguments. No fancy options yet.
    s = ArgParseSettings()
    @add_arg_table s begin
        "input"
            help = "input file holding brainfuck source to run"
            required = true
    end
    args = parse_args(ARGS, s)

    # Read program from the input file.
    input_file = open(args["input"])
    program = readall(input_file)
    close(input_file)

    # Perform the brainfuck-to-julia translation.
    body_expr = _construct_body_expr(program)
    fun_expr = _construct_function(body_expr)

    # Evaluate the function, resulting in its JIT compilation.
    eval(fun_expr)

    # Run the brainfuck program.
    _bf()
end

# Start at the main function.
main()
