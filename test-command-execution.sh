#!/bin/bash

echo "=== Testing lazycat-terminal command execution ==="
echo ""
echo "This script demonstrates the new command execution feature."
echo ""

echo "Test 1: Execute 'ls -la' command"
echo "Command: ./build/lazycat-terminal -e ls -la"
echo "Expected: Terminal opens, runs ls -la, shows exit prompt, press Enter to close"
echo ""

echo "Test 2: Execute 'sleep 3 && echo Done' command"
echo "Command: ./build/lazycat-terminal -e sh -c 'sleep 3 && echo Done'"
echo "Expected: Terminal opens, waits 3 seconds, shows 'Done', shows exit prompt"
echo ""

echo "Test 3: Execute command in specific directory"
echo "Command: ./build/lazycat-terminal -w /tmp -e ls -la"
echo "Expected: Terminal opens in /tmp, runs ls -la, shows exit prompt"
echo ""

echo "Usage examples:"
echo "  ./build/lazycat-terminal -e <command> [args...]"
echo "  ./build/lazycat-terminal -w <directory> -e <command> [args...]"
echo ""

echo "Press Enter to run Test 1 (ls -la), or Ctrl+C to exit..."
read

./build/lazycat-terminal -e ls -la

echo ""
echo "Test completed. You can run other tests manually using the commands above."
