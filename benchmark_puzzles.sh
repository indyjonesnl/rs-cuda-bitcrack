#!/bin/bash
# Bitcoin Puzzle Benchmark Script
# Runs puzzles 1-25 individually using cargo run and records execution times

# Force C locale for consistent decimal separator
export LC_NUMERIC=C

# Create timestamp for filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="benchmark_results_${TIMESTAMP}.txt"

# Get git commit info if available
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
else
    GIT_COMMIT="unknown"
    GIT_BRANCH="unknown"
fi

# Print header
echo "========================================" | tee "$OUTPUT_FILE"
echo "Bitcoin Puzzle Benchmark Results" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$OUTPUT_FILE"
echo "Git Branch: $GIT_BRANCH" | tee -a "$OUTPUT_FILE"
echo "Git Commit: $GIT_COMMIT" | tee -a "$OUTPUT_FILE"
echo "Hostname: $(hostname)" | tee -a "$OUTPUT_FILE"
echo "CUDA Version: $(nvcc --version 2>/dev/null | grep release | awk '{print $5}' | tr -d ',')" | tee -a "$OUTPUT_FILE"
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'Not available')" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Build in release mode first
echo "Building project in release mode..." | tee -a "$OUTPUT_FILE"
cargo build --release 2>&1 | grep -E "(Compiling|Finished)" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Puzzle data: address, min, max
declare -a PUZZLES=(
    "1:1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH:1:1"
    "2:1CUNEBjYrCn2y1SdiUMohaKUi4wpP326Lb:2:3"
    "3:19ZewH8Kk1PDbSNdJ97FP4EiCjTRaZMZQA:4:7"
    "4:1EhqbyUMvvs7BfL8goY6qcPbD6YKfPqb7e:8:f"
    "5:1E6NuFjCi27W5zoXg8TRdcSRq84zJeBW3k:10:1f"
    "6:1PitScNLyp2HCygzadCh7FveTnfmpPbfp8:20:3f"
    "7:1McVt1vMtCC7yn5b9wgX1833yCcLXzueeC:40:7f"
    "8:1M92tSqNmQLYw33fuBvjmeadirh1ysMBxK:80:ff"
    "9:1CQFwcjw1dwhtkVWBttNLDtqL7ivBonGPV:100:1ff"
    "10:1LeBZP5QCwwgXRtmVUvTVrraqPUokyLHqe:200:3ff"
    "11:1PgQVLmst3Z314JrQn5TNiys8Hc38TcXJu:400:7ff"
    "12:1DBaumZxUkM4qMQRt2LVWyFJq5kDtSZQot:800:fff"
    "13:1Pie8JkxBT6MGPz9Nvi3fsPkr2D8q3GBc1:1000:1fff"
    "14:1ErZWg5cFCe4Vw5BzgfzB74VNLaXEiEkhk:2000:3fff"
    "15:1QCbW9HWnwQWiQqVo5exhAnmfqKRrCRsvW:4000:7fff"
    "16:1BDyrQ6WoF8VN3g9SAS1iKZcPzFfnDVieY:8000:ffff"
    "17:1HduPEXZRdG26SUT5Yk83mLkPyjnZuJ7Bm:10000:1ffff"
    "18:1GnNTmTVLZiqQfLbAdp9DVdicEnB5GoERE:20000:3ffff"
    "19:1NWmZRpHH4XSPwsW6dsS3nrNWfL1yrJj4w:40000:7ffff"
    "20:1HsMJxNiV7TLxmoF6uJNkydxPFDog4NQum:80000:fffff"
    "21:14oFNXucftsHiUMY8uctg6N487riuyXs4h:100000:1fffff"
    "22:1CfZWK1QTQE3eS9qn61dQjV89KDjZzfNcv:200000:3fffff"
    "23:1L2GM8eE7mJWLdo3HZS6su1832NX2txaac:400000:7fffff"
    "24:1rSnXMr63jdCuegJFuidJqWxUPV7AtUf7:800000:ffffff"
    "25:15JhYXn6Mx3oF4Y7PcTAv2wVVAuCFFQNiP:1000000:1ffffff"
    "26:1JVnST957hGztonaWK6FougdtjxzHzRMMg:2000000:3ffffff"
    "27:128z5d7nN7PkCuX5qoA4Ys6pmxUYnEy86k:4000000:7ffffff"
    "28:12jbtzBb54r97TCwW3G1gCFoumpckRAPdY:8000000:fffffff"
    "29:19EEC52krRUK1RkUAEZmQdjTyHT7Gp1TYT:10000000:1fffffff"
    "30:1LHtnpd8nU5VHEMkG2TMYYNUjjLc992bps:20000000:3fffffff"
)

# Run puzzles 1-30
TOTAL_TIME=0
PASSED=0
FAILED=0

for puzzle_data in "${PUZZLES[@]}"; do
    IFS=':' read -r puzzle_num address min_range max_range <<< "$puzzle_data"
    PUZZLE_NUM=$(printf "%02d" $puzzle_num)

    echo -n "Puzzle $PUZZLE_NUM... " | tee -a "$OUTPUT_FILE"

    # Run puzzle and capture time
    START=$(date +%s.%N)

    # Run with timeout and capture output
    if timeout 600 cargo run --release -- --address "$address" --min "$min_range" --max "$max_range" > /tmp/puzzle_${PUZZLE_NUM}_output.txt 2>&1; then
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        TOTAL_TIME=$(echo "$TOTAL_TIME + $ELAPSED" | bc)

        # Check if key was found
        if grep -q "Found! Key:" /tmp/puzzle_${PUZZLE_NUM}_output.txt; then
            FOUND_KEY=$(grep "Found! Key:" /tmp/puzzle_${PUZZLE_NUM}_output.txt | awk '{print $3}')
            printf "PASS (%.2fs) - Key: %s\n" "$ELAPSED" "$FOUND_KEY" | tee -a "$OUTPUT_FILE"
            PASSED=$((PASSED + 1))
        else
            printf "FAIL (%.2fs) - Key not found\n" "$ELAPSED" | tee -a "$OUTPUT_FILE"
            FAILED=$((FAILED + 1))
        fi
    else
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        printf "FAIL (%.2fs) - Timeout or error\n" "$ELAPSED" | tee -a "$OUTPUT_FILE"
        FAILED=$((FAILED + 1))
    fi

    # Clean up temp file
    rm -f /tmp/puzzle_${PUZZLE_NUM}_output.txt
done

# Print summary
echo "" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"
echo "Summary" | tee -a "$OUTPUT_FILE"
echo "========================================" | tee -a "$OUTPUT_FILE"
echo "Total puzzles tested: 25" | tee -a "$OUTPUT_FILE"
echo "Passed: $PASSED" | tee -a "$OUTPUT_FILE"
echo "Failed: $FAILED" | tee -a "$OUTPUT_FILE"
printf "Total time: %.2fs\n" "$TOTAL_TIME" | tee -a "$OUTPUT_FILE"
if [ $PASSED -gt 0 ]; then
    AVG_TIME=$(echo "scale=2; $TOTAL_TIME / $PASSED" | bc)
    printf "Average time per puzzle: %.2fs\n" "$AVG_TIME" | tee -a "$OUTPUT_FILE"
fi
echo "========================================" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"
echo "Results saved to: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"

# Create symlink to latest results
ln -sf "$OUTPUT_FILE" benchmark_results_latest.txt
echo "Symlink created: benchmark_results_latest.txt -> $OUTPUT_FILE"
