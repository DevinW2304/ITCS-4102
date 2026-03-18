
using Statistics

# ----------------------------
# Program 1: (4 types, 2 methods each = 8)
# ----------------------------
function datatypes_methods()

    # Int
    i::Int = -42
    println("\n[Int] i = ", i)
    println("  abs(i) = ", abs(i))                 # method 1
    println("  iseven(abs(i)) = ", iseven(abs(i))) # method 2

    # Float64
    x::Float64 = 123.456
    println("\n[Float64] x = ", x)
    println("  round(x, digits=1) = ", round(x, digits=1)) # method 1
    println("  ceil(x) = ", ceil(x))                       # method 2

    # String
    s::String = "paysim fraud"
    println("\n[String] s = ", s)
    println("  uppercase(s) = ", uppercase(s))            # method 1
    println("  replace(s, \"fraud\"=>\"FRAUD\") = ", replace(s, "fraud" => "FRAUD")) # method 2

    # Bool
    b::Bool = true
    println("\n[Bool] b = ", b)
    println("  !(b) = ", !(b))                            # method 1
    println("  xor(b, false) = ", xor(b, false))          # method 2

    # Manipulation (sum + average)
    nums = [10.0, 20.0, 30.0]
    println("\n[Manipulation] nums = ", nums)
    println("  sum(nums) = ", sum(nums))
    println("  mean(nums) = ", mean(nums))

    println("\n=== End Program 1 ===\n")
end

# ----------------------------
# Program 2: Data Structures & Control Structures
# ----------------------------


#Structure: Transaction
struct Transaction
    step::Int
    ttype::String
    amount::Float64
    nameOrig::String
    nameDest::String
    isFraud::Bool
end

# Structure customer stats
mutable struct CustomerStats
    count::Int
    total_amount::Float64
end

function parse_bool01(s::AbstractString)
    parse(Int, s) == 1
end

# PaySim columns 
# Create transaction structure from CSV line
function parse_paysim_line(line::String)
    parts = split(strip(line), ",")
    if length(parts) != 11
        throw(ArgumentError("Expected 11 columns, got $(length(parts))"))
    end

    return Transaction(
        parse(Int, parts[1]),
        parts[2],
        parse(Float64, parts[3]),
        parts[4],
        parts[7],
        parse_bool01(parts[10]),
    )
end
#Grab csv and 
function load_csv(path::String; max_rows::Int=20_000)
    txns = Transaction[]  # Vector to hold transactions

    open(path, "r") do io
        header = readline(io) # skip header, only need types

        # while loop to grab types
        while !eof(io) && length(txns) < max_rows
            line = readline(io)
            isempty(strip(line)) && continue

            # Program 3: exception handling
            try
                push!(txns, parse_paysim_line(line))
            catch e
                println("Skipping bad line: ", e)
            end
        end
    end

    return txns
end



# suspicious if type is TRANSFER or CASH_OUT AND amount is large
function is_suspicious(t::Transaction)
    (t.ttype == "TRANSFER" || t.ttype == "CASH_OUT") && t.amount >= 100000.0
end

function main()
    demo_datatypes_methods()

    println("=== Simple PaySim Program ===")

    txns = if length(ARGS) >= 1
        path = ARGS[1]
        max_rows = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20_000
        println("Loading: $path (max_rows=$max_rows)")
        load_csv_simple(path; max_rows=max_rows)
    else
        println("No CSV provided; using a small sample.")
        sample_from_prompt()
    end

    # Dict data structure
    stats = Dict{String, CustomerStats}()

    suspicious = Transaction[]
    fraud_count = 0

    # for loop + if/else
    for t in txns
        # update per-customer stats
        cs = get!(stats, t.nameOrig) do
            CustomerStats(0, 0.0)
        end
        cs.count += 1
        cs.total_amount += t.amount

        if t.isFraud
            fraud_count += 1
        end

        if is_suspicious(t)
            push!(suspicious, t)
        end
    end

    # Lambda (anonymous function) demo:
    # count suspicious transfers (uses map with a lambda)
    suspicious_transfer_count = sum(map(t -> (t.ttype == "TRANSFER" ? 1 : 0), suspicious))

    println("\n--- Output ---")
    println("Transactions processed: ", length(txns))
    println("Unique customers (nameOrig): ", length(stats))
    println("Fraud labels in data (isFraud==1): ", fraud_count)
    println("Suspicious by rule: ", length(suspicious))
    println("Suspicious that are TRANSFER: ", suspicious_transfer_count)

    println("\nExamples (up to 5 suspicious):")
    for t in Iterators.take(suspicious, 5)
        println(" step=", t.step,
                " type=", t.ttype,
                " amount=", round(t.amount, digits=2),
                " orig=", t.nameOrig,
                " dest=", t.nameDest,
                " isFraud=", t.isFraud)
    end

    println("\n=== End ===")
end

main()
