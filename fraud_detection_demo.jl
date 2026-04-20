#ITCS 4102
# Devin Washington, Angel Villar Nolasco, Lavishia Crump

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

# Structure: Transaction
struct Transaction
    step::Int
    ttype::String
    amount::Float64
    nameOrig::String
    oldbalanceOrg::Float64
    newbalanceOrig::Float64
    nameDest::String
    oldbalanceDest::Float64
    newbalanceDest::Float64
    isFraud::Bool
    isFlaggedFraud::Bool
end

# Structure customer stats
mutable struct CustomerStats
    count::Int
    total_amount::Float64
    risky_count::Int
end

# Structure destination stats
mutable struct DestStats
    count::Int
    total_amount::Float64
    unique_senders::Set{String}
end

function parse_bool01(s::AbstractString)
    parse(Int, s) == 1
end

# PaySim columns
# Create transaction structure from CSV line
function parse_paysim_line(line::String)
    parts = split(strip(line), ",")

    #file error handling
    if length(parts) != 11
        throw(ArgumentError("Expected 11 columns, got $(length(parts))"))
    end

    return Transaction(
        parse(Int, parts[1]),
        parts[2],
        parse(Float64, parts[3]),
        parts[4],
        parse(Float64, parts[5]),
        parse(Float64, parts[6]),
        parts[7],
        parse(Float64, parts[8]),
        parse(Float64, parts[9]),
        parse_bool01(parts[10]),
        parse_bool01(parts[11]),
    )
end

# Grab csv and
function load_csv(path::String; max_rows::Int=20_000)
    txns = Transaction[]  # Vector(array) holds transactions

    open(path, "r") do io
        header = readline(io) # only need types

        # loop grabbing types
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
function is_suspicious(t::Transaction, threshold::Float64)
    (t.ttype == "TRANSFER" || t.ttype == "CASH_OUT") && t.amount >= threshold
end

function approx_equal(a::Float64, b::Float64; tol::Float64=1.0)
    abs(a - b) <= tol
end

# score transaction using multiple fraud indicators
function fraud_score(
    t::Transaction,
    sender_stats::Dict{String, CustomerStats},
    dest_stats::Dict{String, DestStats},
    threshold::Float64
)
    score = 0
    reasons = String[]

    sender = get(sender_stats, t.nameOrig, CustomerStats(0, 0.0, 0))
    dest = get(dest_stats, t.nameDest, DestStats(0, 0.0, Set{String}()))

    sender_avg = sender.count > 0 ? sender.total_amount / sender.count : 0.0
    risky_type = (t.ttype == "TRANSFER" || t.ttype == "CASH_OUT")
    large_amount = t.amount >= threshold
    medium_large_amount = t.amount >= threshold * 0.5
    drains_origin = t.oldbalanceOrg > 0 && t.newbalanceOrig <= t.oldbalanceOrg * 0.1 && t.amount > 0
    exact_balance_drain = t.oldbalanceOrg > 0 && approx_equal(t.oldbalanceOrg, t.amount) && approx_equal(t.newbalanceOrig, 0.0)
    above_sender_average = sender_avg > 0 && t.amount >= sender_avg * 3
    repeated_risky_sender = sender.risky_count >= 2 && risky_type
    suspicious_dest_balance = risky_type && t.oldbalanceDest == 0.0 && t.newbalanceDest == 0.0
    low_history_sender = sender.count <= 1

    if risky_type
        score += 3
        push!(reasons, "risky_type")
    end

    if risky_type && large_amount
        score += 2
        push!(reasons, "large_amount")
    elseif risky_type && medium_large_amount
        score += 1
        push!(reasons, "medium_large_amount")
    end

    if risky_type && exact_balance_drain
        score += 4
        push!(reasons, "exact_balance_drain")
    elseif risky_type && drains_origin
        score += 2
        push!(reasons, "drains_origin_balance")
    end

    if risky_type && suspicious_dest_balance
        score += 3
        push!(reasons, "destination_balance_anomaly")
    end

    if risky_type && above_sender_average
        score += 2
        push!(reasons, "above_sender_average")
    end

    if repeated_risky_sender
        score += 1
        push!(reasons, "repeated_risky_sender")
    end

    if risky_type && low_history_sender && (drains_origin || exact_balance_drain)
        score += 1
        push!(reasons, "low_history_sender")
    end

    return score, reasons
end

# convert score into risk label
function classify_risk(t::Transaction, score::Int)
    risky_type = (t.ttype == "TRANSFER" || t.ttype == "CASH_OUT")

    if risky_type && score >= 9
        return "HIGH"
    elseif risky_type && score >= 5
        return "MEDIUM"
    else
        return "LOW"
    end
end

# sample for testing without csv
function sample_from_prompt()
    return Transaction[
        Transaction(1, "PAYMENT", 9839.64, "C1231006815", 170136.0, 160296.36, "M1979787155", 0.0, 0.0, false, false),
        Transaction(1, "PAYMENT", 1864.28, "C1666544295", 21249.0, 19384.72, "M2044282225", 0.0, 0.0, false, false),
        Transaction(1, "TRANSFER", 181.0, "C1305486145", 181.0, 0.0, "C553264065", 0.0, 0.0, true, false),
        Transaction(1, "CASH_OUT", 181.0, "C840083671", 181.0, 0.0, "C38997010", 21182.0, 0.0, true, false),
        Transaction(1, "PAYMENT", 11668.14, "C2048537720", 41554.0, 29885.86, "M1230701703", 0.0, 0.0, false, false),
        Transaction(1, "DEBIT", 5337.77, "C712410124", 41898.0, 36560.23, "C195600860", 41898.0, 47235.77, false, false),
        Transaction(1, "CASH_OUT", 229133.94, "C905080434", 15325.0, 0.0, "C476402209", 5083.0, 51513.44, false, false)
    ]
end

function main()
    datatypes_methods()

    println("=== Simple PaySim Program ===")

    txns = if length(ARGS) >= 1
        path = ARGS[1]
        max_rows = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20_000
        println("Loading: $path (max_rows=$max_rows)")
        load_csv(path; max_rows=max_rows)
    else
        println("No CSV provided; using a small sample.")
        sample_from_prompt()
    end

    threshold = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 100000.0
    max_print = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 200

    println("\n--- Debug Info ---")
    println("Args count: ", length(ARGS))
    println("Threshold arg: ", threshold)
    println("Max print arg: ", max_print)
    println("Transactions loaded: ", length(txns))

    # Dict data structure
    #tracks data for output
    stats = Dict{String, CustomerStats}()
    dest_stats = Dict{String, DestStats}()

    suspicious = Transaction[]
    fraud_count = 0

    # store classifications for output
    classifications = NamedTuple[]

    high_risk_count = 0
    medium_risk_count = 0
    low_risk_count = 0

    tp = 0
    fp = 0
    tn = 0
    fn = 0

    # for loop
    for t in txns
        if t.isFraud
            #increase fraud count if fraud
            fraud_count += 1
        end

        if is_suspicious(t, threshold)
            #if suspicious, add to list
            push!(suspicious, t)
        end

        # score using prior history only
        score, reasons = fraud_score(t, stats, dest_stats, threshold)
        risk = classify_risk(t, score)

        if risk == "HIGH"
            high_risk_count += 1
        elseif risk == "MEDIUM"
            medium_risk_count += 1
        else
            low_risk_count += 1
        end

        predicted_fraud = (risk == "HIGH")

        if predicted_fraud && t.isFraud
            tp += 1
        elseif predicted_fraud && !t.isFraud
            fp += 1
        elseif !predicted_fraud && !t.isFraud
            tn += 1
        else
            fn += 1
        end

        if risk != "LOW"
            push!(classifications, (
                step=t.step,
                ttype=t.ttype,
                amount=round(t.amount, digits=2),
                nameOrig=t.nameOrig,
                nameDest=t.nameDest,
                isFraud=t.isFraud,
                score=score,
                risk=risk,
                reasons=join(reasons, "|")
            ))
        end

        # update per-customer stats
        cs = get!(stats, t.nameOrig) do
            CustomerStats(0, 0.0, 0)
        end
        cs.count += 1
        cs.total_amount += t.amount

        if t.ttype == "TRANSFER" || t.ttype == "CASH_OUT"
            cs.risky_count += 1
        end

        # update per-destination stats
        ds = get!(dest_stats, t.nameDest) do
            DestStats(0, 0.0, Set{String}())
        end
        ds.count += 1
        ds.total_amount += t.amount
        push!(ds.unique_senders, t.nameOrig)
    end

    # count suspicious transfers
    suspicious_transfer_count = sum(map(t -> (t.ttype == "TRANSFER" ? 1 : 0), suspicious))

    println("\n--- Output ---")
    println("Transactions processed: ", length(txns))
    println("Unique customers (nameOrig): ", length(stats))
    println("Fraud labels in data (isFraud==1): ", fraud_count)
    println("Suspicious by rule: ", length(suspicious))
    println("Suspicious that are TRANSFER: ", suspicious_transfer_count)
    println("Threshold used: ", threshold)
    println("Classification rows returned: ", min(length(classifications), max_print))
    println("Classification rows available: ", length(classifications))

    println("\nClassifications:")
    for c in classifications[1:min(length(classifications), max_print)]
        println(" step=", c.step,
                " type=", c.ttype,
                " amount=", c.amount,
                " orig=", c.nameOrig,
                " dest=", c.nameDest,
                " isFraud=", c.isFraud,
                " score=", c.score,
                " risk=", c.risk,
                " reasons=", c.reasons)
    end

    precision = (tp + fp) > 0 ? tp / (tp + fp) : 0.0
    recall = (tp + fn) > 0 ? tp / (tp + fn) : 0.0
    accuracy = (tp + tn + fp + fn) > 0 ? (tp + tn) / (tp + tn + fp + fn) : 0.0

    println("\n--- Risk Summary ---")
    println("High risk count: ", high_risk_count)
    println("Medium risk count: ", medium_risk_count)
    println("Low risk count: ", low_risk_count)

    println("\n--- Evaluation ---")
    println("True Positives: ", tp)
    println("False Positives: ", fp)
    println("True Negatives: ", tn)
    println("False Negatives: ", fn)
    println("Precision: ", round(precision, digits=4))
    println("Recall: ", round(recall, digits=4))
    println("Accuracy: ", round(accuracy, digits=4))

    println("\n--- Debug Counts ---")
    println("Stats entries: ", length(stats))
    println("Destination stats entries: ", length(dest_stats))
    println("Suspicious vector size: ", length(suspicious))
    println("Classification vector size: ", length(classifications))

    println("\n=== End ===")
end

main()