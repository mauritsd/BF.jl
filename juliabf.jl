using ArgParse

function main()
    s = ArgParseSettings()
    @add_arg_table s begin
        "input"
            help = "input file holding brainfuck source to run"
            required = true
    end
    args = parse_args(ARGS, s)

    input_path = args["input"]
    input_file = open(input_path)
    program = readall(input_file)
    close(input_file)

    body_expr = _construct_body_expr(program)
    fun_expr = _construct_function(body_expr)
    #info("$fun_expr")

    eval(fun_expr)
    _bf()
end

function _append_expr_to_fun(fun_expr, append_expr)
end

function _construct_function(body_expr)
    fun_expr = quote
        function _bf()
            a = Char[0]
            dp = 1

            $body_expr
        end
    end

    fun_expr
end

function _construct_body_expr(program)
    body_expr = :(begin end)
    skip_until = 0

    for (n, op) in enumerate(program)
        if n <= skip_until
            continue
        end

        if op == '+'
            inc_expr = quote
                a[dp] += 1
            end

            body_expr.args = [body_expr.args; inc_expr.args]
        elseif op == '-'
            dec_expr = quote
                a[dp] -= 1
            end

            body_expr.args = [body_expr.args; dec_expr.args]
        elseif op == '<'
            dp_left_expr = quote
                if dp == 1
                    unshift!(a, 0)
                else
                    dp -= 1
                end
            end

            body_expr.args = [body_expr.args; dp_left_expr.args]
        elseif op == '>'
            dp_right_expr = quote
                if dp == length(a)
                    push!(a, 0)
                end

                dp += 1
            end

            body_expr.args = [body_expr.args; dp_right_expr.args]
        elseif op == '.'
            out_expr = quote
                write(STDOUT, a[dp])
            end

            body_expr.args = [body_expr.args; out_expr.args]
        elseif op == ','
            in_expr = quote
                c = read(STDIN, Char)
                a[dp] = c
            end

            body_expr.args = [body_expr.args; in_expr.args]
        elseif op == '['
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
                skip_until = n + matching_bracket_pos - 1

                subprogram = program[n + 1:n + matching_bracket_pos - 2]
                subbody_expr = _construct_body_expr(subprogram)

                loop_expr = quote
                    while a[dp] > 0
                        $subbody_expr
                    end
                end

                body_expr.args = [body_expr.args; loop_expr.args]
            else
                error("no closing bracket for opening bracket at pos $n")
            end
        end
    end

    body_expr
end

main()
