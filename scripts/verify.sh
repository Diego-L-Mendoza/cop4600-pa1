#!/bin/bash
# quick test script for PA1, run it inside the docker container from the repo root:
#   bash scripts/verify.sh [runs]   (default is 15 runs per test)
# the scheduler overwrites tests/*.out, so the original .out files get put back at the end
set -u
RUNS=${1:-15}
export WORKLOAD_PATH=${WORKLOAD_PATH:-./target/debug/workload}
BIN=./target/debug/scheduler-gpt

# build quietly, only show the output if it fails
cargo build -q 2>/dev/null || { cargo build; exit 1; }

EXPECTED=$(mktemp -d)
cp tests/*.out "$EXPECTED"/
restore() {
    # put the original .out files back and delete any new ones (like unfinished.out)
    for f in tests/*.out; do
        [ -e "$EXPECTED/$(basename "$f")" ] || rm -f "$f"
    done
    cp "$EXPECTED"/*.out tests/
    rm -rf "$EXPECTED"
}
trap restore EXIT

# timestamps are graded with some tolerance but event order has to match exactly,
# so strip out the numbers that depend on timing and just compare the order
order_only() {
    sed -E 's/^Time +[0-9]+ :/Time :/; s/^([A-Za-z0-9_]+) wait .*/\1 (stats)/' "$1"
}

for t in fcfs sjf rr sjf_preempt; do
    exact=0
    order=0
    shown=0
    for _ in $(seq "$RUNS"); do
        "$BIN" "tests/$t.in"
        if diff -q "$EXPECTED/$t.out" "tests/$t.out" >/dev/null; then
            exact=$((exact + 1))
        elif [ "$shown" -eq 0 ]; then
            echo "  first mismatch in $t (expected vs got):"
            diff "$EXPECTED/$t.out" "tests/$t.out" | sed 's/^/    /'
            shown=1
        fi
        diff -q <(order_only "$EXPECTED/$t.out") <(order_only "tests/$t.out") >/dev/null &&
            order=$((order + 1))
    done
    echo "$t: $exact/$RUNS exact, $order/$RUNS same event order"
done

echo "--- error handling (each should exit 1):"
"$BIN"; echo "  exit $?"
"$BIN" tests/missing_processcount.in; echo "  exit $?"
"$BIN" tests/missing_quantum.in; echo "  exit $?"

for _ in $(seq "$RUNS"); do "$BIN" tests/unfinished.in; done
zombies=$(ps -eo stat,comm | awk '$1 ~ /^Z/ && $2 == "workload"' | wc -l)
echo "--- unfinished.in x$RUNS: $zombies <defunct> workload processes left (want 0)"
