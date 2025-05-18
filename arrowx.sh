#!/bin/bash

# Print script header
cat << "EOF"

 █████╗ ██████╗ ██████╗  ██████╗ ██╗    ██╗     ██╗  ██╗
██╔══██╗██╔══██╗██╔══██╗██╔═══██╗██║    ██║     ╚██╗██╔╝
███████║██████╔╝██████╔╝██║   ██║██║ █╗ ██║█████╗╚███╔╝ 
██╔══██║██╔══██╗██╔══██╗██║   ██║██║███╗██║╚════╝██╔██╗ 
██║  ██║██║  ██║██║  ██║╚██████╔╝╚███╔███╔╝     ██╔╝ ██╗
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝      ╚═╝  ╚═╝                                             
+------------------------------------------------+
|         Author : Kiran John Boby               |
+------------------------------------------------+

EOF

# Function to display help
display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -t, --target <domain>    Scan a domain"
    echo "  -h, --help               Display this help message"
    exit 1
}

# Check if any arguments are provided
if [ "$#" -eq 0 ]; then
    display_help
fi

# Initialize variables
target_url=""
script_name="$(basename "$0" .sh)"
output_dir="${script_name}_output"
flag=1

# Parse the given arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        -t|--target)
            if [ -z "$2" ]; then
                echo "Error: Please provide a target domain in the GUI   OR   Provide the target domain after -t or --target if you are using shell script directly."
                display_help
                exit 1
            fi
            target_url="$2"
            shift 2
            ;;
        -h|--help)
            display_help
            ;;
        *)
            echo "Error: Unknown option $1"
            display_help
            ;;
    esac
done

# Function to check if a tool is installed
check_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo >&2 "Error: $1 is not installed. Please install it before running this script."
        flag=0
    fi
}

# Check for required tools
tools=("assetfinder" "subfinder" "jq" "httprobe" "nmap" "whatweb" "wafw00f")
for tool in "${tools[@]}"; do
    check_tool "$tool"
done

if [ "$flag" -eq 1 ]; then
    # Perform reconnaissance
    echo
    echo "#############################################"
    echo "########### Start - Reconnaissance ##########"
    echo "#############################################"
    echo

	# Function to create a directory for given domain
	create_domain_dir() {
		local domain="$1"
		mkdir -p "$output_dir/$domain"
		mkdir -p "$output_dir/$domain/subdomains" "$output_dir/$domain/scans" "$output_dir/$domain/httprobe" \
		"$output_dir/$domain/technology" "$output_dir/$domain/waf"
		}
    
    # Function to perform reconnaissance for the domain
    domain_recon() {
        local target="$1"
        
        # Change to the domain directory
        cd "$output_dir/$target" || { echo "Error: Failed to change to directory $output_dir/$target"; exit 1; }

    	# Harvesting subdomains with assetfinder
    	echo "[+] Harvesting subdomains with assetfinder..."
    	assetfinder "$target" >> "subdomains/final.txt"

    	# Harvesting subdomains with subfinder
    	echo "[+] Harvesting subdomains with subfinder..."
    	subfinder -d "$target" -silent >> "subdomains/final.txt"

    	# Harvesting subdomains using SSL cert with crt.sh
    	echo "[+] Harvesting subdomains using SSL cert with crt.sh..."
    	curl -s "https://crt.sh/?q=%.$target&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u >> "subdomains/final.txt"

    	# Making sure only unique subdomains are present in the final list
    	cat "subdomains/final.txt" | sort -u > "subdomains/unique.txt"
    	rm "subdomains/final.txt"

    	# Probing for alive domains
    	echo "[+] Probing for alive domains..."
    	cat "subdomains/unique.txt" | httprobe -prefer-https | sort -u > "httprobe/alive.txt"
    
    	# Creating input file for nmap from alive domains
    	cat "httprobe/alive.txt" | sed 's/https\?:\/\///' > "httprobe/nmap_input.txt"
    
    	# Scanning for Web technology
    	echo "[+] Scanning for Web technology...."
    	whatweb -i "httprobe/alive.txt" -a 3 -q --colour never --no-errors --log-verbose "technology/tech_detected.txt"

    	# Scanning for open ports with Nmap
    	echo "[+] Scanning for open ports with Nmap..."
    	nmap -iL "httprobe/nmap_input.txt" --reason -oN "scans/nmap.txt"

    	# Fingerprinting The Web Application Firewall
    	echo "[+] Fingerprinting The Web Application Firewall..."
    	wafw00f -i "httprobe/alive.txt" -f json -o "waf/waf_detected.json"

    	# Move back to the script directory
    	cd - > /dev/null || { echo "Error: Failed to change back to the script directory"; exit 1; }
    	}

	# Create a directory based on the domain name
    	create_domain_dir "$(basename "$target_url")"
    	domain_recon "$(basename "$target_url")"

	# Display completion message
	echo
	echo "#############################################"
	echo "############## Final - Results ##############"
	echo "#############################################"
	echo

	echo "[+] Harvested Subdomain results are saved in: $output_dir/$(basename "$target_url")/subdomains/unique.txt"

	echo "[+] Alive Subdomain results are saved in: $output_dir/$(basename "$target_url")/httprobe/alive.txt"

	echo "[+] Web technology information saved in: $output_dir/$(basename "$target_url")/technology/tech_detected.txt"

	echo "[+] All open ports information saved in: $output_dir/$(basename "$target_url")/scans/nmap.txt"

	echo "[+] Web Application Firewall Detection details are saved in: $output_dir/$(basename "$target_url")/waf/waf_detected.json"

	echo "[+] Script completed. & Thanks for using Arrow-X."
fi
