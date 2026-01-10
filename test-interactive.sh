#!/bin/bash

echo "=== LazyC Terminal Command Execution Test ==="
echo ""

# Clean up any running instances
killall lazycat-terminal 2>/dev/null || true
sleep 1

echo "Test 1: Execute 'ls' command"
echo "Command: ./build/lazycat-terminal -e ls"
echo "Expected: Terminal opens, runs ls, shows files, displays exit message, waits for Enter"
echo ""
read -p "Press Enter to start Test 1..."

./build/lazycat-terminal -e ls

echo ""
echo "Test 1 completed."
echo ""

sleep 2
killall lazycat-terminal 2>/dev/null || true
sleep 1

echo "Test 2: Execute 'echo' command"
echo "Command: ./build/lazycat-terminal -e echo 'Hello World'"
echo "Expected: Terminal opens, shows 'Hello World', displays exit message, waits for Enter"
echo ""
read -p "Press Enter to start Test 2..."

./build/lazycat-terminal -e echo "Hello World"

echo ""
echo "Test 2 completed."
echo ""

sleep 2
killall lazycat-terminal 2>/dev/null || true
sleep 1

echo "Test 3: Execute without -e flag (normal shell)"
echo "Command: ./build/lazycat-terminal"
echo "Expected: Terminal opens with normal shell, type 'exit' should close without exit message"
echo ""
read -p "Press Enter to start Test 3..."

./build/lazycat-terminal

echo ""
echo "Test 3 completed."
echo ""

echo "=== All tests completed ==="
