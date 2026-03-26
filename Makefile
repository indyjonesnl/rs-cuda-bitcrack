# Bitcoin Puzzle Solver - Makefile
# Run individual puzzles with: make puzzle1, make puzzle2, etc.
#
# Solver Selection:
#   SOLVER=rust   - Use Rust/CUDA solver (default, fast)
#   SOLVER=python - Use Python solver (cross-check reference)
#
# Examples:
#   make puzzle1               - Run puzzle 1 with Rust (default)
#   make puzzle1 SOLVER=python - Run puzzle 1 with Python
#   make puzzle10 SOLVER=python - Cross-check puzzle 10 with Python

# Solver selection (default: rust)
SOLVER ?= rust

# Solver commands
ifeq ($(SOLVER),python)
    SOLVE_CMD = ./puzzle_solver.py --address
else
    SOLVE_CMD = cargo run --release -- --address
endif

.PHONY: all help puzzle1 puzzle2 puzzle3 puzzle4 puzzle5 puzzle6 puzzle7 puzzle8 puzzle9 puzzle10 \
        puzzle11 puzzle12 puzzle13 puzzle14 puzzle15 puzzle16 puzzle17 puzzle18 puzzle19 puzzle20 \
        puzzle21 puzzle22 puzzle23 puzzle24 puzzle25 puzzle26 puzzle27 puzzle28 puzzle29 puzzle30 \
        puzzle31 puzzle32 puzzle33 puzzle34 puzzle35 puzzle36 puzzle37 puzzle38 puzzle39 puzzle40 \
        puzzle41 puzzle42 puzzle43 puzzle44 puzzle45 puzzle46 puzzle47 puzzle48 puzzle49 puzzle50 \
        puzzle51 puzzle52 puzzle53 puzzle54 puzzle55 puzzle56 puzzle57 puzzle58 puzzle59 puzzle60 \
        puzzle61 puzzle62 puzzle63 puzzle64 puzzle65 puzzle66 puzzle67 puzzle68 puzzle69 puzzle70

help:
	@echo "Bitcoin Puzzle Solver - Makefile"
	@echo ""
	@echo "Usage: make puzzleN [SOLVER=rust|python]"
	@echo ""
	@echo "Solver Options:"
	@echo "  SOLVER=rust   - Rust/CUDA solver (default, GPU-accelerated)"
	@echo "  SOLVER=python - Python solver (CPU-only, cross-check reference)"
	@echo ""
	@echo "Examples:"
	@echo "  make puzzle1                - Search puzzle 1 with Rust (default)"
	@echo "  make puzzle1 SOLVER=python  - Search puzzle 1 with Python"
	@echo "  make puzzle10 SOLVER=python - Cross-check puzzle 10 with Python"
	@echo "  make puzzle20               - Search puzzle 20 with Rust"

all:
	@echo "Use 'make puzzleN' to run a specific puzzle (N = 1-70)"

first10: puzzle1 puzzle2 puzzle3 puzzle4 puzzle5 puzzle6 puzzle7 puzzle8 puzzle9 puzzle10

10to20: puzzle11 puzzle12 puzzle13 puzzle14 puzzle15 puzzle16 puzzle17 puzzle18 puzzle19 puzzle20

first20: first10 10to20

20to30: puzzle21 puzzle22 puzzle23 puzzle24 puzzle25 puzzle26 puzzle27 puzzle28 puzzle29 puzzle30

first30: first20 20to30

puzzle1:
	$(SOLVE_CMD) 1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH --min 1 --max 1

puzzle2:
	$(SOLVE_CMD) 1CUNEBjYrCn2y1SdiUMohaKUi4wpP326Lb --min 2 --max 3

puzzle3:
	$(SOLVE_CMD) 19ZewH8Kk1PDbSNdJ97FP4EiCjTRaZMZQA --min 4 --max 7

puzzle4:
	$(SOLVE_CMD) 1EhqbyUMvvs7BfL8goY6qcPbD6YKfPqb7e --min 8 --max f

puzzle5:
	$(SOLVE_CMD) 1E6NuFjCi27W5zoXg8TRdcSRq84zJeBW3k --min 10 --max 1f

puzzle6:
	$(SOLVE_CMD) 1PitScNLyp2HCygzadCh7FveTnfmpPbfp8 --min 20 --max 3f

puzzle7:
	$(SOLVE_CMD) 1McVt1vMtCC7yn5b9wgX1833yCcLXzueeC --min 40 --max 7f

puzzle8:
	$(SOLVE_CMD) 1M92tSqNmQLYw33fuBvjmeadirh1ysMBxK --min 80 --max ff

puzzle9:
	$(SOLVE_CMD) 1CQFwcjw1dwhtkVWBttNLDtqL7ivBonGPV --min 100 --max 1ff

puzzle10:
	$(SOLVE_CMD) 1LeBZP5QCwwgXRtmVUvTVrraqPUokyLHqe --min 200 --max 3ff

puzzle11:
	$(SOLVE_CMD) 1PgQVLmst3Z314JrQn5TNiys8Hc38TcXJu --min 400 --max 7ff

puzzle12:
	$(SOLVE_CMD) 1DBaumZxUkM4qMQRt2LVWyFJq5kDtSZQot --min 800 --max fff

puzzle13:
	$(SOLVE_CMD) 1Pie8JkxBT6MGPz9Nvi3fsPkr2D8q3GBc1 --min 1000 --max 1fff

puzzle14:
	$(SOLVE_CMD) 1ErZWg5cFCe4Vw5BzgfzB74VNLaXEiEkhk --min 2000 --max 3fff

puzzle15:
	$(SOLVE_CMD) 1QCbW9HWnwQWiQqVo5exhAnmfqKRrCRsvW --min 4000 --max 7fff

puzzle16:
	$(SOLVE_CMD) 1BDyrQ6WoF8VN3g9SAS1iKZcPzFfnDVieY --min 8000 --max ffff

puzzle17:
	$(SOLVE_CMD) 1HduPEXZRdG26SUT5Yk83mLkPyjnZuJ7Bm --min 10000 --max 1ffff

puzzle18:
	$(SOLVE_CMD) 1GnNTmTVLZiqQfLbAdp9DVdicEnB5GoERE --min 20000 --max 3ffff

puzzle19:
	$(SOLVE_CMD) 1NWmZRpHH4XSPwsW6dsS3nrNWfL1yrJj4w --min 40000 --max 7ffff

puzzle20:
	$(SOLVE_CMD) 1HsMJxNiV7TLxmoF6uJNkydxPFDog4NQum --min 80000 --max fffff

puzzle21:
	$(SOLVE_CMD) 14oFNXucftsHiUMY8uctg6N487riuyXs4h --min 100000 --max 1fffff

puzzle22:
	$(SOLVE_CMD) 1CfZWK1QTQE3eS9qn61dQjV89KDjZzfNcv --min 200000 --max 3fffff

puzzle23:
	$(SOLVE_CMD) 1L2GM8eE7mJWLdo3HZS6su1832NX2txaac --min 400000 --max 7fffff

puzzle24:
	$(SOLVE_CMD) 1rSnXMr63jdCuegJFuidJqWxUPV7AtUf7 --min 800000 --max ffffff

puzzle25:
	$(SOLVE_CMD) 15JhYXn6Mx3oF4Y7PcTAv2wVVAuCFFQNiP --min 1000000 --max 1ffffff

puzzle26:
	$(SOLVE_CMD) 1JVnST957hGztonaWK6FougdtjxzHzRMMg --min 2000000 --max 3ffffff

puzzle27:
	$(SOLVE_CMD) 128z5d7nN7PkCuX5qoA4Ys6pmxUYnEy86k --min 4000000 --max 7ffffff

puzzle28:
	$(SOLVE_CMD) 12jbtzBb54r97TCwW3G1gCFoumpckRAPdY --min 8000000 --max fffffff

puzzle29:
	$(SOLVE_CMD) 19EEC52krRUK1RkUAEZmQdjTyHT7Gp1TYT --min 10000000 --max 1fffffff

puzzle30:
	$(SOLVE_CMD) 1LHtnpd8nU5VHEMkG2TMYYNUjjLc992bps --min 20000000 --max 3fffffff

puzzle31:
	$(SOLVE_CMD) 1LhE6sCTuGae42Axu1L1ZB7L96yi9irEBE --min 40000000 --max 7fffffff

puzzle32:
	$(SOLVE_CMD) 1FRoHA9xewq7DjrZ1psWJVeTer8gHRqEvR --min 80000000 --max ffffffff

puzzle33:
	$(SOLVE_CMD) 187swFMjz1G54ycVU56B7jZFHFTNVQFDiu --min 100000000 --max 1ffffffff

puzzle34:
	$(SOLVE_CMD) 1PWABE7oUahG2AFFQhhvViQovnCr4rEv7Q --min 200000000 --max 3ffffffff

puzzle35:
	$(SOLVE_CMD) 1PWCx5fovoEaoBowAvF5k91m2Xat9bMgwb --min 400000000 --max 7ffffffff

puzzle36:
	$(SOLVE_CMD) 1Be2UF9NLfyLFbtm3TCbmuocc9N1Kduci1 --min 800000000 --max fffffffff

puzzle37:
	$(SOLVE_CMD) 14iXhn8bGajVWegZHJ18vJLHhntcpL4dex --min 1000000000 --max 1fffffffff

puzzle38:
	$(SOLVE_CMD) 1HBtApAFA9B2YZw3G2YKSMCtb3dVnjuNe2 --min 2000000000 --max 3fffffffff

puzzle39:
	$(SOLVE_CMD) 122AJhKLEfkFBaGAd84pLp1kfE7xK3GdT8 --min 4000000000 --max 7fffffffff

puzzle40:
	$(SOLVE_CMD) 1EeAxcprB2PpCnr34VfZdFrkUWuxyiNEFv --min 8000000000 --max ffffffffff

puzzle41:
	$(SOLVE_CMD) 1L5sU9qvJeuwQUdt4y1eiLmquFxKjtHr3E --min 10000000000 --max 1ffffffffff

puzzle42:
	$(SOLVE_CMD) 1E32GPWgDyeyQac4aJxm9HVoLrrEYPnM4N --min 20000000000 --max 3ffffffffff

puzzle43:
	$(SOLVE_CMD) 1PiFuqGpG8yGM5v6rNHWS3TjsG6awgEGA1 --min 40000000000 --max 7ffffffffff

puzzle44:
	$(SOLVE_CMD) 1CkR2uS7LmFwc3T2jV8C1BhWb5mQaoxedF --min 80000000000 --max fffffffffff

puzzle45:
	$(SOLVE_CMD) 1NtiLNGegHWE3Mp9g2JPkgx6wUg4TW7bbk --min 100000000000 --max 1fffffffffff

puzzle46:
	$(SOLVE_CMD) 1F3JRMWudBaj48EhwcHDdpeuy2jwACNxjP --min 200000000000 --max 3fffffffffff

puzzle47:
	$(SOLVE_CMD) 1Pd8VvT49sHKsmqrQiP61RsVwmXCZ6ay7Z --min 400000000000 --max 7fffffffffff

puzzle48:
	$(SOLVE_CMD) 1DFYhaB2J9q1LLZJWKTnscPWos9VBqDHzv --min 800000000000 --max ffffffffffff

puzzle49:
	$(SOLVE_CMD) 12CiUhYVTTH33w3SPUBqcpMoqnApAV4WCF --min 1000000000000 --max 1ffffffffffff

puzzle50:
	$(SOLVE_CMD) 1MEzite4ReNuWaL5Ds17ePKt2dCxWEofwk --min 2000000000000 --max 3ffffffffffff

puzzle51:
	$(SOLVE_CMD) 1NpnQyZ7x24ud82b7WiRNvPm6N8bqGQnaS --min 4000000000000 --max 7ffffffffffff

puzzle52:
	$(SOLVE_CMD) 15z9c9sVpu6fwNiK7dMAFgMYSK4GqsGZim --min 8000000000000 --max fffffffffffff

puzzle53:
	$(SOLVE_CMD) 15K1YKJMiJ4fpesTVUcByoz334rHmknxmT --min 10000000000000 --max 1fffffffffffff

puzzle54:
	$(SOLVE_CMD) 1KYUv7nSvXx4642TKeuC2SNdTk326uUpFy --min 20000000000000 --max 3fffffffffffff

puzzle55:
	$(SOLVE_CMD) 1LzhS3k3e9Ub8i2W1V8xQFdB8n2MYCHPCa --min 40000000000000 --max 7fffffffffffff

puzzle56:
	$(SOLVE_CMD) 17aPYR1m6pVAacXg1PTDDU7XafvK1dxvhi --min 80000000000000 --max ffffffffffffff

puzzle57:
	$(SOLVE_CMD) 15c9mPGLku1HuW9LRtBf4jcHVpBUt8txKz --min 100000000000000 --max 1ffffffffffffff

puzzle58:
	$(SOLVE_CMD) 1Dn8NF8qDyyfHMktmuoQLGyjWmZXgvosXf --min 200000000000000 --max 3ffffffffffffff

puzzle59:
	$(SOLVE_CMD) 1HAX2n9Uruu9YDt4cqRgYcvtGvZj1rbUyt --min 400000000000000 --max 7ffffffffffffff

puzzle60:
	$(SOLVE_CMD) 1Kn5h2qpgw9mWE5jKpk8PP4qvvJ1QVy8su --min 800000000000000 --max fffffffffffffff

puzzle61:
	$(SOLVE_CMD) 1AVJKwzs9AskraJLGHAZPiaZcrpDr1U6AB --min 1000000000000000 --max 1fffffffffffffff

puzzle62:
	$(SOLVE_CMD) 1Me6EfpwZK5kQziBwBfvLiHjaPGxCKLoJi --min 2000000000000000 --max 3fffffffffffffff

puzzle63:
	$(SOLVE_CMD) 1NpYjtLira16LfGbGwZJ5JbDPh3ai9bjf4 --min 4000000000000000 --max 7fffffffffffffff

puzzle64:
	$(SOLVE_CMD) 16jY7qLJnxb7CHZyqBP8qca9d51gAjyXQN --min 8000000000000000 --max ffffffffffffffff

puzzle65:
	$(SOLVE_CMD) 18ZMbwUFLMHoZBbfpCjUJQTCMCbktshgpe --min 10000000000000000 --max 1ffffffffffffffff

puzzle66:
	$(SOLVE_CMD) 13zb1hQbWVsc2S7ZTZnP2G4undNNpdh5so --min 20000000000000000 --max 3ffffffffffffffff

puzzle67:
	$(SOLVE_CMD) 1BY8GQbnueYofwSuFAT3USAhGjPrkxDdW9 --min 40000000000000000 --max 7ffffffffffffffff

puzzle68:
	$(SOLVE_CMD) 1MVDYgVaSN6iKKEsbzRUAYFrYJadLYZvvZ --min 80000000000000000 --max fffffffffffffffff

puzzle69:
	$(SOLVE_CMD) 19vkiEajfhuZ8bs8Zu2jgmC6oqZbWqhxhG --min 100000000000000000 --max 1fffffffffffffffff

puzzle70:
	$(SOLVE_CMD) 19YZECXj3SxEZMoUeJ1yiPsw8xANe7M7QR --min 200000000000000000 --max 3fffffffffffffffff
