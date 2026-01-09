#!/bin/bash
# Find consecutive blank lines in files (does not modify files)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_usage() {
    echo "Usage: $0 [OPTIONS] [FILE]"
    echo ""
    echo "Find consecutive blank lines in files (does not modify files)"
    echo ""
    echo "Options:"
    echo "  -r, --recursive    Check all files recursively in subdirectories"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Arguments:"
    echo "  FILE               Specific file to check"
    echo "  (none)             Check all .md, .yml, .yaml, .sh files in current directory"
    echo ""
    echo "Examples:"
    echo "  $0                          # Check files in current directory only"
    echo "  $0 -r                       # Check files recursively"
    echo "  $0 README.md                # Check single file"
    echo ""
}

process_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    echo -n "Checking $file... "
    
    # Find consecutive blank lines and report their locations
    local line_num=0
    local prev_blank=false
    local found_issues=false
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        
        if [[ -z "$line" ]]; then
            if [[ "$prev_blank" == true ]]; then
                if [[ "$found_issues" == false ]]; then
                    echo ""  # New line after "Checking..."
                fi
                echo "  Line $line_num: consecutive blank line"
                found_issues=true
            fi
            prev_blank=true
        else
            prev_blank=false
        fi
    done < "$file"
    
    if [[ "$found_issues" == false ]]; then
        echo "✓"
    fi
}

main() {
    local recursive=false
    local target_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            *)
                target_file="$1"
                shift
                ;;
        esac
    done
    
    if [[ -n "$target_file" ]]; then
        # Check single file
        process_file "$target_file"
    else
        # Check all relevant files
        if [[ "$recursive" == true ]]; then
            log_info "Checking all files recursively..."
        else
            log_info "Checking files in current directory only..."
        fi
        echo ""
        
        local count=0
        local maxdepth_option=""
        
        if [[ "$recursive" == false ]]; then
            maxdepth_option="-maxdepth 1"
        fi
        
        # Find all relevant files
        while IFS= read -r -d '' file; do
            process_file "$file"
            ((count++))
        done < <(find . $maxdepth_option -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" \) -print0 2>/dev/null)
        
        echo ""
        log_info "Checked $count file(s)"
    fi
}

main "$@"
