#!/bin/bash

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Input & Output Setup
TARGET=$1
if [ -z "$TARGET" ]; then
  echo -e "${RED}[!] Usage: $0 https://target.com${NC}"
  exit 1
fi

OUTDIR="${TARGET//[^a-zA-Z0-9]/_}_js_enum"
mkdir -p "$OUTDIR"
TEMP_JS="$OUTDIR/temp_js.txt"
SECRETS_FOUND="$OUTDIR/secrets_found.txt"
LINKFINDER_OUT="$OUTDIR/linkfinder_results.txt"
> "$SECRETS_FOUND"
> "$LINKFINDER_OUT"

# Tools Check
for tool in katana gauplus httpx-toolkit curl grep sort awk anew linkfinder; do
  if ! command -v $tool &> /dev/null; then
    echo -e "${RED}[!] Missing tool: $tool${NC}"
    exit 1
  fi
done

# Step 1: JS Enumeration
echo -e "${YELLOW}[1] Enumerating JS URLs with katana & gauplus...${NC}"
katana -u "$TARGET" -d 5 -jc | grep '\.js$' | anew "$OUTDIR/alljs.txt"
echo "$TARGET" | gauplus | grep '\.js' | anew "$OUTDIR/alljs.txt"

# Step 2: Filtering & Validating JS Files
sort -u "$OUTDIR/alljs.txt" > "$OUTDIR/filtered_js.txt"
cat "$OUTDIR/filtered_js.txt" | httpx-toolkit -mc 200 -t 50 > "$OUTDIR/valid_js.txt"
echo -e "${GREEN}[✓] Valid JS Files: $(wc -l < "$OUTDIR/valid_js.txt")${NC}"

# Step 3: Regex Patterns
declare -A PATTERNS
PATTERNS["api[_-]?key[ =:\"'']+[A-Za-z0-9_\-]{16,}"]="API Key"
PATTERNS["secret[ =:\"'']+[A-Za-z0-9_\-]{16,}"]="Secret"
PATTERNS["token[ =:\"'']+[A-Za-z0-9_\-]{16,}"]="Token"
PATTERNS["AKIA[0-9A-Z]{16}"]="AWS Access Key"
PATTERNS["AIza[0-9A-Za-z\-_]{35}"]="Google API Key"
PATTERNS["sk_live_[0-9a-zA-Z]{24}"]="Stripe Live Key"
PATTERNS["firebaseio\.com"]="Firebase Endpoint"
PATTERNS["[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"]="Email Address"

# Step 4: Scan JS Files
echo -e "${YELLOW}[2] Scanning JS files for secrets and endpoints...${NC}"
while read -r jsurl; do
  echo -e "\n${RED}[*] $jsurl${NC}"
  echo -e "\n[*] $jsurl" >> "$SECRETS_FOUND"
  curl -s "$jsurl" -o "$TEMP_JS"

  for regex in "${!PATTERNS[@]}"; do
    matches=$(grep -Eoi "$regex" "$TEMP_JS" | sort -u)
    if [ -n "$matches" ]; then
      echo -e "${GREEN}[!] Match for pattern: ${PATTERNS[$regex]} (${regex})${NC}"
      echo "[!] Match for pattern: ${regex}" >> "$SECRETS_FOUND"
      echo "$matches" | tee -a "$SECRETS_FOUND"
    fi
  done

  # LinkFinder Integration
  echo -e "${YELLOW}[→] Running LinkFinder on $jsurl${NC}"
  linkfinder -i "$TEMP_JS" -o cli | tee -a "$LINKFINDER_OUT"
done < "$OUTDIR/valid_js.txt"

# Cleanup
rm -f "$TEMP_JS"

echo -e "\n${GREEN}[✓] Scan complete. Results saved to:${NC}"
echo -e "   - Secrets: $SECRETS_FOUND"
echo -e "   - LinkFinder Endpoints: $LINKFINDER_OUT"
