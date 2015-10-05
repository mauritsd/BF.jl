using Brainfuck
using ArgParse

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

    # Interpret program
    brainfuck(program)
end

main()
