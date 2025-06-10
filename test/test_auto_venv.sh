#!/bin/bash
# test_auto_venv.sh - Safe test suite for auto_venv.sh (adapted for validation)

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

mock_deactivate() {
    echo "Mock: would deactivate virtual environment"
    unset VIRTUAL_ENV
}

# Helper function to create a minimal valid virtual environment structure
create_minimal_venv() {
    local venv_path="$1"
    local python_version="${2:-python3}"
    
    mkdir -p "$venv_path"/{bin,lib/python3.9/site-packages}
    
    # Create activate script
    cat > "$venv_path/bin/activate" << 'EOF'
#!/bin/bash
# Mock activate script for testing
export VIRTUAL_ENV="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export VIRTUAL_ENV="${VIRTUAL_ENV%/bin}"
export PATH="$VIRTUAL_ENV/bin:$PATH"
unset PYTHON_HOME
EOF
    
    # Create mock Python executable
    cat > "$venv_path/bin/python" << 'EOF'
#!/bin/bash
echo "Python 3.9.0 (mock)"
EOF
    chmod +x "$venv_path/bin/python"
    
    # Create pyvenv.cfg for Python 3+ or appropriate structure for Python 2.7
    if [[ "$python_version" == "python2.7" ]]; then
        mkdir -p "$venv_path/lib/python2.7"
        touch "$venv_path/lib/python2.7/site.py"
    else
        echo "home = /usr/bin" > "$venv_path/pyvenv.cfg"
        echo "include-system-site-packages = false" >> "$venv_path/pyvenv.cfg"
        echo "version = 3.9.0" >> "$venv_path/pyvenv.cfg"
    fi
}

# Override cd function to avoid the complex logic during testing
test_cd() {
    builtin cd "$@"
    OLD_AUTO_VENV_BASE_DIR=$AUTO_VENV_BASE_DIR
    unset AUTO_VENV
    if ! __find_auto_venv_file; then
        echo "Warning: __find_auto_venv_file returned error"
    fi
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

assert_function_returns() {
    local expected_code="$1"
    local func_call="$2"
    local description="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Execute function and capture return code
    eval "$func_call" >/dev/null 2>&1
    local actual_code=$?
    
    if [ "$expected_code" = "$actual_code" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo -e "  Expected return code: $expected_code"
        echo -e "  Actual return code:   $actual_code"
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
    assert_function_exists "__validate_venv" "__validate_venv function should be defined"
    assert_function_exists "__validate_python_version" "__validate_python_version function should be defined"
    assert_function_exists "auto_venv" "auto_venv function should be defined"
}

test_validation_functions() {
    echo -e "\n${YELLOW}=== Testing Validation Functions ===${NC}"
    
    cd "$TEST_DIR"
    
    # Test __validate_venv with invalid environment
    assert_function_returns 1 "__validate_venv /nonexistent/path" "__validate_venv should return 1 for nonexistent path"
    
    # Create minimal valid environment
    create_minimal_venv "$TEST_DIR/valid_venv"
    assert_function_returns 0 "__validate_venv $TEST_DIR/valid_venv" "__validate_venv should return 0 for valid environment"
    
    # Test __validate_venv with incomplete environment
    mkdir -p "$TEST_DIR/incomplete_venv"
    assert_function_returns 1 "__validate_venv $TEST_DIR/incomplete_venv" "__validate_venv should return 1 for incomplete environment"
}

test_auto_venv_file_creation() {
    echo -e "\n${YELLOW}=== Testing .auto_venv File Creation ===${NC}"
    
    cd "$TEST_DIR/project1"
    
    # Create valid virtual environment first
    create_minimal_venv "./venv"
    
    # Create a .auto_venv file pointing to valid environment
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
    
    # Create valid virtual environment and .auto_venv in project1
    cd "$TEST_DIR/project1"
    create_minimal_venv "./project1_venv"
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

test_invalid_environment_detection() {
    echo -e "\n${YELLOW}=== Testing Invalid Environment Detection ===${NC}"
    
    cd "$TEST_DIR/project2"
    
    # Create .auto_venv pointing to invalid environment
    echo "./invalid_venv" > .auto_venv
    
    # Test that __find_auto_venv_file returns error for invalid environment
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    assert_function_returns 1 "__find_auto_venv_file" "Should return error for invalid environment"
    
    # Check that variables are not set after finding invalid environment
    if [ -z "$AUTO_VENV" ] && [ -z "$AUTO_VENV_BASE_DIR" ]; then
        echo -e "${GREEN}✓ PASS${NC}: Variables should not be set for invalid environment"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Variables should not be set for invalid environment"
        echo -e "  AUTO_VENV: '$AUTO_VENV'"
        echo -e "  AUTO_VENV_BASE_DIR: '$AUTO_VENV_BASE_DIR'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_absolute_vs_relative_paths() {
    echo -e "\n${YELLOW}=== Testing Absolute vs Relative Paths ===${NC}"
    
    cd "$TEST_DIR/project2"
    
    # Create valid environments
    create_minimal_venv "./relative_venv"
    create_minimal_venv "/tmp/absolute_venv"
    
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
    
    # Setup test environments with valid venvs
    cd "$TEST_DIR/project1"
    create_minimal_venv "./venv1"
    echo "./venv1" > .auto_venv
    
    cd "$TEST_DIR/project2"
    create_minimal_venv "./venv2"
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
    
    # Create valid environments
    cd "$TEST_DIR"
    create_minimal_venv "./root_venv"
    echo "./root_venv" > .auto_venv
    
    cd "$TEST_DIR/nested/subproject"
    create_minimal_venv "./sub_venv"
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

test_empty_auto_venv_file() {
    echo -e "\n${YELLOW}=== Testing Empty .auto_venv File ===${NC}"
    
    cd "$TEST_DIR"
    mkdir -p empty_test
    cd empty_test
    
    # Create empty .auto_venv file
    touch .auto_venv
    
    unset AUTO_VENV AUTO_VENV_BASE_DIR
    assert_function_returns 1 "__find_auto_venv_file" "Should skip empty .auto_venv file and continue search"
}

test_auto_venv_show_function() {
    echo -e "\n${YELLOW}=== Testing auto_venv Show Function ===${NC}"
    
    cd "$TEST_DIR/project1"
    create_minimal_venv "./test_venv"
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
    alias deactivate=mock_deactivate
    # Set some variables
    AUTO_VENV="/tmp/test"
    AUTO_VENV_BASE_DIR="/tmp"
    AUTO_VENV_PATH="./test"
    OLD_AUTO_VENV_BASE_DIR="/tmp/old"
    
    # Call deactivate function
    __auto_venv_deactivate
    
    # Check that variables are unset
    if [ -z "$AUTO_VENV" ] && [ -z "$AUTO_VENV_BASE_DIR" ] && [ -z "$AUTO_VENV_PATH" ] && [ -z "$OLD_AUTO_VENV_BASE_DIR" ]; then
        echo -e "${GREEN}✓ PASS${NC}: __auto_venv_deactivate clears all variables"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: __auto_venv_deactivate did not clear all variables"
        echo -e "  AUTO_VENV: '$AUTO_VENV'"
        echo -e "  AUTO_VENV_BASE_DIR: '$AUTO_VENV_BASE_DIR'"
        echo -e "  AUTO_VENV_PATH: '$AUTO_VENV_PATH'"
        echo -e "  OLD_AUTO_VENV_BASE_DIR: '$OLD_AUTO_VENV_BASE_DIR'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    unalias deactivate
}

# Test for multi-environment support
test_multi_environment_parsing() {
    echo -e "\n${YELLOW}=== Testing Multi-Environment Parsing ===${NC}"
    
    cd "$TEST_DIR"
    mkdir -p multi_env
    cd multi_env
    
    # Create multi-environment .auto_venv file
    cat > .auto_venv << EOF
default:./venv_default
python3.9:./venv39
python3.10:./venv310
EOF
    
    # Create valid environments
    create_minimal_venv "./venv_default"
    create_minimal_venv "./venv39"
    create_minimal_venv "./venv310"
    
    # Test parsing
    __auto_venv_parse_file ".auto_venv"
    
    # Check default
    assert_equals "./venv_default" "$AUTO_VENV_DEFAULT" "Default environment should be set correctly"
    
    # Check environments
    assert_equals "./venv39" "${AUTO_VENV_ENVIRONMENTS[python3.9]}" "Python 3.9 environment should be parsed"
    assert_equals "./venv310" "${AUTO_VENV_ENVIRONMENTS[python3.10]}" "Python 3.10 environment should be parsed"
    
    # Check number of environments
    local env_count=${#AUTO_VENV_ENVIRONMENTS[@]}
    assert_equals "2" "$env_count" "Should have 2 environments (excluding default)"
}

test_old_format_conversion() {
    echo -e "\n${YELLOW}=== Testing Old Format Conversion ===${NC}"
    
    cd "$TEST_DIR"
    mkdir -p old_format
    cd old_format
    
    # Create old format .auto_venv file
    echo "./my_venv" > .auto_venv
    
    # Create valid environment
    create_minimal_venv "./my_venv"
    
    # Test parsing triggers conversion
    __auto_venv_parse_file ".auto_venv"
    
    # Check that file was converted
    local file_content=$(cat .auto_venv)
    if [[ "$file_content" == *"default:"* ]] && [[ "$file_content" == *"python:"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Old format file was converted to new format"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Old format file was not converted properly"
        echo -e "  File content: $file_content"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_environment_selection() {
    echo -e "\n${YELLOW}=== Testing Environment Selection ===${NC}"
    
    cd "$TEST_DIR"
    mkdir -p env_select
    cd env_select
    
    # Create multi-environment setup
    cat > .auto_venv << EOF
default:./venv_default
python3.9:./venv39
python3.10:./venv310
EOF
    
    create_minimal_venv "./venv_default"
    create_minimal_venv "./venv39"
    create_minimal_venv "./venv310"
    
    # Parse the file first
    __auto_venv_parse_file ".auto_venv"
    
    # Test default selection
    AUTO_VENV_BASE_DIR="$PWD"
    __select_environment ""
    assert_equals "./venv_default" "$AUTO_VENV_PATH" "Should select default when no preference"
    assert_equals "default" "$AUTO_VENV_SELECTED" "Should mark as default selection"
    
    # Test specific environment selection
    __select_environment "python3.9"
    assert_equals "./venv39" "$AUTO_VENV_PATH" "Should select python3.9 environment"
    assert_equals "python3.9" "$AUTO_VENV_SELECTED" "Should mark as python3.9 selection"
    
    # Test invalid environment selection
    assert_function_returns 1 "__select_environment python3.14159" "Should fail for non-existent environment"
}

test_preferred_environment() {
    echo -e "\n${YELLOW}=== Testing Preferred Environment ===${NC}"
    
    cd "$TEST_DIR"
    mkdir -p pref_env
    cd pref_env
    
    # Create multi-environment setup
    cat > .auto_venv << EOF
default:./venv_default
python3.9:./venv39
EOF
    
    create_minimal_venv "./venv_default"
    create_minimal_venv "./venv39"
    
    # Set preferred environment
    export AUTO_VENV_PREFERRED="python3.9"
    
    # Test that preferred environment is selected
    __find_auto_venv_file
    assert_equals "$PWD/./venv39" "$AUTO_VENV" "Should select preferred environment"
    assert_equals "python3.9" "$AUTO_VENV_SELECTED" "Should mark preferred environment as selected"
    
    # Clean up
    export AUTO_VENV_PREFERRED=""
}

test_empty_multi_env_file() {
    echo -e "\n${YELLOW}=== Testing Empty Lines in Multi-Env File ===${NC}"
    
    cd "$TEST_DIR"
    mkdir -p empty_lines
    cd empty_lines
    
    # Create file with empty lines and spaces
    cat > .auto_venv << EOF
default:./venv

python3.9:./venv39
  
python3.10: ./venv310  
EOF
    
    create_minimal_venv "./venv"
    create_minimal_venv "./venv39"
    create_minimal_venv "./venv310"
    
    # Test parsing handles empty lines and spaces
    __auto_venv_parse_file ".auto_venv"
    
    assert_equals "./venv" "$AUTO_VENV_DEFAULT" "Default should be parsed correctly"
    assert_equals "./venv39" "${AUTO_VENV_ENVIRONMENTS[python3.9]}" "Python 3.9 should be parsed"
    assert_equals "./venv310" "${AUTO_VENV_ENVIRONMENTS[python3.10]}" "Python 3.10 should be parsed with trimmed spaces"
}

test_cd_with_multi_environments() {
    echo -e "\n${YELLOW}=== Testing CD with Multi-Environments ===${NC}"
    
    # Create two projects with different environments
    cd "$TEST_DIR"
    mkdir -p proj_a proj_b
    
    # Project A with multi-env
    cd proj_a
    cat > .auto_venv << EOF
default:./venv_a
python3.9:./venv_a39
EOF
    create_minimal_venv "./venv_a"
    create_minimal_venv "./venv_a39"
    
    # Project B with single env (old format that will be converted)
    cd ../proj_b
    echo "./venv_b" > .auto_venv
    create_minimal_venv "./venv_b"
    
    # Test moving between projects
    cd "$TEST_DIR/proj_a"
    assert_equals "$TEST_DIR/proj_a" "$AUTO_VENV_BASE_DIR" "Should be in project A"
    
    cd "$TEST_DIR/proj_b"
    assert_equals "$TEST_DIR/proj_b" "$AUTO_VENV_BASE_DIR" "Should be in project B"
    
    # Check that proj_b file was converted
    local content=$(cat .auto_venv)
    if [[ "$content" == *"default:"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Project B .auto_venv was converted during cd"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: Project B .auto_venv was not converted"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_deactivate_with_virtual_env() {
    echo -e "\n${YELLOW}=== Testing Deactivate with VIRTUAL_ENV Set ===${NC}"
    
    # Use function instead of alias
    deactivate() {
        echo "Mock: would deactivate virtual environment"
        VIRTUAL_ENV=""
    }
    
    # Set VIRTUAL_ENV to simulate active environment
    export VIRTUAL_ENV="/some/path/venv"
    
    # Set auto_venv variables
    AUTO_VENV="/tmp/test"
    AUTO_VENV_BASE_DIR="/tmp"
    
    # Call deactivate function
    __auto_venv_deactivate
    
    # Check that VIRTUAL_ENV was unset by mock
    if [ -z "$VIRTUAL_ENV" ]; then
        echo -e "${GREEN}✓ PASS${NC}: __auto_venv_deactivate calls deactivate when VIRTUAL_ENV is set"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: __auto_venv_deactivate did not call deactivate"
        echo -e "  VIRTUAL_ENV still set: '$VIRTUAL_ENV'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    unset -f deactivate
}

# Main test runner
run_tests() {
    echo -e "${YELLOW}Starting auto_venv test suite (adapted for validation)...${NC}\n"
    
    setup_test_env
    
    test_initial_setup
    test_validation_functions
    test_auto_venv_file_creation
    test_auto_venv_file_discovery
    test_invalid_environment_detection
    test_absolute_vs_relative_paths
    test_file_discovery_logic
    test_nested_directories
    test_empty_auto_venv_file
    test_auto_venv_show_function
    test_deactivate_function
    # New tests for multi-environment support
    test_multi_environment_parsing
    test_old_format_conversion
    test_environment_selection
    test_preferred_environment
    test_empty_multi_env_file
    test_cd_with_multi_environments
    test_deactivate_with_virtual_env
    
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