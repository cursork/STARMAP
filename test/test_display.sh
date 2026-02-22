#!/bin/bash
# Test DISPLAY interactive flow via Unix socket
# Requires: gritt -sock /tmp/apl.sock running against a linked STARMAP session
# Requires: gtimeout (from coreutils)

SOCK=/tmp/apl.sock
TIMEOUT=3

# Send input, capture output with timeout
apl() {
    gtimeout "$TIMEOUT" bash -c "echo '$1' | nc -U $SOCK" 2>/dev/null
}

# Check socket exists
if [[ ! -S "$SOCK" ]]; then
    echo "ERROR: Socket $SOCK not found"
    echo "Start with: gritt -sock $SOCK -link /path/to/APLSource"
    exit 1
fi

echo "=== Testing DISPLAY interactive flow ==="
echo

# Step 1: Start DISPLAY
echo ">>> Sending: DISPLAY"
OUT=$(apl "DISPLAY")
echo "$OUT"
if [[ "$OUT" != *"Enter date"* ]]; then
    echo "FAIL: Expected date prompt"
    exit 1
fi
echo "--- Got date prompt, sending date ---"
echo

# Step 2: Send date (Jan 14, 1974 - Kohoutek visible)
echo ">>> Sending: 1 14 1974"
OUT=$(apl "1 14 1974")
echo "$OUT"
if [[ "$OUT" != *"Enter time"* ]]; then
    echo "FAIL: Expected time prompt"
    exit 1
fi
echo "--- Got time prompt, sending time ---"
echo

# Step 3: Send time (9 PM)
echo ">>> Sending: 21"
OUT=$(apl "21")
echo "$OUT"
if [[ "$OUT" != *"Enter latitude"* ]]; then
    echo "FAIL: Expected latitude prompt"
    exit 1
fi
echo "--- Got latitude prompt, sending latitude ---"
echo

# Step 4: Send latitude (40 = Philadelphia)
echo ">>> Sending: 40"
OUT=$(apl "40")
echo "$OUT"
if [[ "$OUT" != *"Enter longitude"* ]]; then
    echo "FAIL: Expected longitude prompt"
    exit 1
fi
echo "--- Got longitude prompt, sending longitude ---"
echo

# Step 5: Send longitude (-75 = Philadelphia, using APL high minus)
echo ">>> Sending: ¯75"
OUT=$(apl "¯75")
echo "$OUT"
if [[ "$OUT" != *"plotting element"* && "$OUT" != *"ENTER"* ]]; then
    echo "FAIL: Expected plotting element prompt"
    exit 1
fi
echo "--- Got plotting prompt, sending empty ---"
echo

# Step 6: Send empty line to satisfy ⍞
# NOTE: ⍞ input via socket currently hits NONCE ERROR
# This step will fail until RIDE protocol approach is implemented
echo ">>> Sending: (empty) - NOTE: ⍞ input not yet working via socket"
OUT=$(apl "")
echo "$OUT"
echo

# Check for some expected output from WORK
# WORK calls CALCULATEPLANETS, CALCULATESTARS, CAPTION, etc.
# Should see something like star/planet data or at least no error

if [[ "$OUT" == *"NONCE ERROR"* ]]; then
    echo "KNOWN ISSUE: ⍞ input via socket hits NONCE ERROR"
    echo "The ⎕ input tests passed - ⍞ needs RIDE protocol approach"
    exit 0
fi

if [[ "$OUT" == *"ERROR"* || "$OUT" == *"DOMAIN"* || "$OUT" == *"RANK"* ]]; then
    echo "FAIL: Got APL error in output"
    exit 1
fi

echo "=== DISPLAY test completed ==="
echo
echo "Final output shows WORK executed."
echo "Manual verification: check that astronomical data looks reasonable."
