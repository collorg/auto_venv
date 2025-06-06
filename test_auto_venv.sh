#!/bin/bash
# test_auto_venv.sh - Safe test suite for auto_venv.sh (avoids virtual env activation)

#set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_DIR="/tmp/auto_venv_test_$$"
ORIGINAL_DIR="$PWD"

# Mock functions to avoid actual virtual environment operations
mock_activate() {
    echo "Mock: would activate $1"
}

mock_deactivate() {
    echo "Mock: would deactivate virtual environment"
    unset VIRTUAL_ENV
}

# Override cd function to avoid the complex logic during testing
test_cd() {
    builtin cd "$@"
    OLD_AUTO_VENV_BASE_DIR=$AUTO_VENV_BASE_DIR
    unset AUTO_VENV
    __find_auto_venv_file
}

# Setup test environment
setup_test_env() {
    echo -e "${YELLOW}Setting up test environment...${NC}"
    
    # Create test directory structure
    mkdir -p "$TEST_DIR"/{project1,project2,nested/subproject}
    cd "$TEST_DIR"
    
    # Create a minimal version of the auto_venv functions for testing
    # Source only the core functions we want to test
    source "$ORIGINAL_DIR/auto_venv.sh"
    
    # Override problematic functions with mocks
    alias deactivate='mock_deactivate'
    
    # Mock Python installations for testing
    export AUTO_VENV_PYTHON_SEARCH_PATH="/usr/bin"
    
    echo -e "${GREEN}Test environment ready in $TEST_DIR${NC}"
}

# Cleanup test environment
cleanup_test_env() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_DIR"
    unalias deactivate 2>/dev/null || true
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local description="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local description="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo -e "  File does not exist: $file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_variable_set() {
    local var_name="$1"
    local description="$2"
    local value="${!var_name}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ -n "$value" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo -e "  Variable $var_name is not set or empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_function_exists() {
    local func_name="$1"
    local description="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if declare -f "$func_name" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo -e "  Function $func_name is not defined"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test cases

test_initial_setup() {
    echo -e "\n${YELLOW}=== Testing Initial Setup ===${NC}"
    
    # Test that AUTO_VENV_PYTHON_SEARCH_PATH is set
    assert_variable_set "AUTO_VENV_PYTHON_SEARCH_PATH" "AUTO_VENV_PYTHON_SEARCH_PATH should be set"
    
    # Test that functions are defined
    assert_function_exists "__find_auto_venv_file" "__find_auto_venv_file function should be defined"
    assert_function_exists "__auto_venv_show" "__auto_venv_show function should be defined"
    assert_function_exists "__auto_venv_activate" "__auto_venv_activate function should be defined"
    assert_function_exists "__auto_venv_deactivate" "__auto_venv_deactivate function should be defined"
    assert_function_exists "auto_venv" "auto_venv function should be defined"
}

test_auto_venv_file_creation() {
    echo -e "\n${YELLOW}=== Testing .auto_venv File Creation ===${NC}"
    
    cd "$TEST_DIR/project1"
    
    # Create a simple .auto_venv file
    echo "./venv" > .auto_venv
    assert_file_exists ".auto_venv" ".auto_venv file should be created"
    
    # Test file content
    local content=$(cat .auto_venv)
    assert_equals "./venv" "$content" ".auto_venv should contain correct path"
}

test_auto_venv_file_discovery() {
    echo -e "\n${YELLOW}=== Testing .auto_venv File Discovery ===${NC}"
    
    # Clear any existing state
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    
    # Create .auto_venv in project1
    cd "$TEST_DIR/project1"
    echo "./project1_venv" > .auto_venv
    
    # Test discovery from same directory
    __find_auto_venv_file
    assert_equals "$TEST_DIR/project1" "$AUTO_VENV_BASE_DIR" "Should find .auto_venv in current directory"
    assert_equals "$TEST_DIR/project1/./project1_venv" "$AUTO_VENV" "Should set correct AUTO_VENV path"
    
    # Test discovery from nested directory
    mkdir -p subdir
    cd subdir
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    __find_auto_venv_file
    assert_equals "$TEST_DIR/project1" "$AUTO_VENV_BASE_DIR" "Should find .auto_venv in parent directory"
}

test_absolute_vs_relative_paths() {
    echo -e "\n${YELLOW}=== Testing Absolute vs Relative Paths ===${NC}"
    
    cd "$TEST_DIR/project2"
    
    # Test relative path
    echo "./relative_venv" > .auto_venv
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    __find_auto_venv_file
    assert_equals "$TEST_DIR/project2/./relative_venv" "$AUTO_VENV" "Relative path should be resolved correctly"
    
    # Test absolute path
    echo "/tmp/absolute_venv" > .auto_venv
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    __find_auto_venv_file
    assert_equals "/tmp/absolute_venv" "$AUTO_VENV" "Absolute path should be used as-is"
}

test_file_discovery_logic() {
    echo -e "\n${YELLOW}=== Testing File Discovery Logic ===${NC}"
    
    # Setup test environments
    cd "$TEST_DIR/project1"
    echo "./venv1" > .auto_venv
    
    cd "$TEST_DIR/project2"
    echo "./venv2" > .auto_venv
    
    # Test discovery in project1
    cd "$TEST_DIR/project1"
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    __find_auto_venv_file
    assert_equals "$TEST_DIR/project1" "$AUTO_VENV_BASE_DIR" "Should find project1's .auto_venv"
    
    # Test discovery in project2
    cd "$TEST_DIR/project2"
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    __find_auto_venv_file
    assert_equals "$TEST_DIR/project2" "$AUTO_VENV_BASE_DIR" "Should find project2's .auto_venv"
    
    # Test no discovery in directory without .auto_venv
    cd "$TEST_DIR"
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    __find_auto_venv_file
    if [ -z "$AUTO_VENV" ]; then
        echo -e "${GREEN}✓ PASS${NC}: AUTO_VENV should be unset when no .auto_venv found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: AUTO_VENV should be unset when no .auto_venv found"
        echo -e "  AUTO_VENV is: '$AUTO_VENV'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_nested_directories() {
    echo -e "\n${YELLOW}=== Testing Nested Directory Structure ===${NC}"
    
    # Create .auto_venv in root
    cd "$TEST_DIR"
    echo "./root_venv" > .auto_venv
    
    # Create .auto_venv in nested project
    cd "$TEST_DIR/nested/subproject"
    echo "./sub_venv" > .auto_venv
    
    # Test that nested .auto_venv takes precedence
    cd "$TEST_DIR/nested/subproject"
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    __find_auto_venv_file
    assert_equals "$TEST_DIR/nested/subproject" "$AUTO_VENV_BASE_DIR" "Nested .auto_venv should take precedence"
    
    # Test that parent .auto_venv is found when nested one doesn't exist
    cd "$TEST_DIR/nested"
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    __find_auto_venv_file
    assert_equals "$TEST_DIR" "$AUTO_VENV_BASE_DIR" "Parent .auto_venv should be found when no local one exists"
}

test_auto_venv_show_function() {
    echo -e "\n${YELLOW}=== Testing auto_venv Show Function ===${NC}"
    
    cd "$TEST_DIR/project1"
    echo "./test_venv" > .auto_venv
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    __find_auto_venv_file
    
    # Capture output of __auto_venv_show
    local output=$(__auto_venv_show)
    
    # Check that output contains expected information
    if [[ "$output" == *"auto_venv"* ]] && [[ "$output" == *"test_venv"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: __auto_venv_show displays correct information"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: __auto_venv_show output is incorrect"
        echo -e "  Output: '$output'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_deactivate_function() {
    echo -e "\n${YELLOW}=== Testing Deactivate Function ===${NC}"
    
    # Set some variables
    AUTO_VENV="/tmp/test"
    AUTO_VENV_BASE_DIR="/tmp"
    OLD_AUTO_VENV_BASE_DIR="/tmp/old"
    
    # Call deactivate function
    __auto_venv_deactivate
    
    # Check that variables are unset
    if [ -z "$AUTO_VENV" ] && [ -z "$AUTO_VENV_BASE_DIR" ] && [ -z "$OLD_AUTO_VENV_BASE_DIR" ]; then
        echo -e "${GREEN}✓ PASS${NC}: __auto_venv_deactivate clears all variables"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: __auto_venv_deactivate did not clear all variables"
        echo -e "  AUTO_VENV: '$AUTO_VENV'"
        echo -e "  AUTO_VENV_BASE_DIR: '$AUTO_VENV_BASE_DIR'"  
        echo -e "  OLD_AUTO_VENV_BASE_DIR: '$OLD_AUTO_VENV_BASE_DIR'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Main test runner
run_tests() {
    echo -e "${YELLOW}Starting auto_venv test suite (safe mode)...${NC}\n"
    
    setup_test_env
    
    test_initial_setup
    test_auto_venv_file_creation
    test_auto_venv_file_discovery
    test_absolute_vs_relative_paths
    test_file_discovery_logic
    test_nested_directories
    test_auto_venv_show_function
    test_deactivate_function
    
    cleanup_test_env
    
    # Print summary
    echo -e "\n${YELLOW}=== Test Summary ===${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Check if script is being run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_tests
fi
