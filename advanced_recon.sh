#!/bin/bash

# === CONFIGURATION ===
DOMAIN=$1
WORDLIST="/usr/share/wordlists/seclists/Discovery/Web-Content/burp-parameter-names.txt"
NUCLEI_JS_TEMPLATES="exposures/"
HEADERS="User-Agent: Mozilla/5.0"
THREADS=200

# === SETUP ===
mkdir -p recon/$DOMAIN
cd recon/$DOMAIN || exit 1

echo "[*] Subdomain Enumeration..."
subfinder -d "$DOMAIN" -all -recursive -o "sub_$DOMAIN.txt"

echo "[*] Checking Alive Subdomains..."
httpx-toolkit -l "sub_$DOMAIN.txt" -ports 80,443,8080,8000,8888 -threads "$THREADS" -silent -o "${DOMAIN}_alive.txt"

echo "[*] Subdomain Takeover Scan..."
if [ -s "${DOMAIN}_alive.txt" ]; then
    subzy run --targets "${DOMAIN}_alive.txt" --concurrency 100 --hide_fails --verify_ssl
else
    echo "[-] No alive subdomains found. Skipping subzy."
fi

echo "[*] URL Collection from Alive Subdomains with Katana..."
katana -u "${DOMAIN}_alive.txt" -d 5 -kf -jc -fx \
  -ef woff,css,png,svg,jpg,woff2,jpeg,gif,svg -o allurls.txt

echo "[*] URL Collection from Domain..."
echo "$DOMAIN" | katana -d 5 -f qurl | urldedupe > output.txt
katana -u "https://$DOMAIN" -d 5 | grep '=' | urldedupe | anew output.txt
cat output.txt | sed 's/=.*/=/' > final_urls.txt

echo "[*] URL Collection using GAU..."
echo "$DOMAIN" | gau --mc 200 | urldedupe > gau_urls.txt
cat gau_urls.txt | grep -E ".php|.asp|.aspx|.jspx|.jsp" | grep '=' | sort > gau_params.txt
cat gau_params.txt | sed 's/=.*/=/' >> final_urls.txt

echo "[*] Sensitive Data Discovery in URLs..."
grep -E "\.xls|\.xml|\.xlsx|\.json|\.pdf|\.sql|\.doc|\.docx|\.pptx|\.txt|\.zip|\.tar\.gz|\.tgz|\.bak|\.7z|\.rar|\.log|\.cache|\.secret|\.db|\.backup|\.yml|\.gz|\.config|\.csv|\.yaml|\.md|\.md5" allurls.txt > sensitive_files.txt

echo "[*] Probing for exposed .git directories..."
httpx-toolkit -l "${DOMAIN}_alive.txt" -sc -server -cl -path "/.git/" -mc 200 -location -ms "Index of" -probe -o exposed_git.txt

echo "[*] Historical URLs for Sensitive Files with GAU..."
echo "https://$DOMAIN" | gau | grep -E "\.(xls|xml|xlsx|json|pdf|sql|doc|docx|pptx|txt|zip|tar\.gz|tgz|bak|7z|rar|log|cache|secret|db|backup|yml|gz|config|csv|yaml|md|md5|tar|xz|7zip|p12|pem|key|crt|csr|sh|pl|py|java|class|jar|war|ear|sqlitedb|sqlite3|dbf|db3|accdb|mdb|sqlcipher|gitignore|env|ini|conf|properties|plist|cfg)$" > gau_sensitive.txt

echo "[*] S3 Bucket Discovery..."
echo "$DOMAIN" | sed 's/\./-/g' | tee potential_buckets.txt
s3scanner scan -bucket-file potential_buckets.txt > s3_results.txt

echo "[*] Extracting JavaScript Files and Scanning for Secrets..."
if [ -s allurls.txt ]; then
    grep -E "\.js$" allurls.txt | httpx-toolkit -mc 200 -content-type | \
    grep -E "application/javascript|text/javascript" | cut -d' ' -f1 | tee alljs.txt | \
    xargs -I% curl -s % | grep -Ei "(API_KEY|api_key|apikey|secret|token|password)" > js_secrets.txt
else
    echo "[-] allurls.txt not found or empty. Skipping JS extraction."
fi

echo "[*] Passive Parameter Discovery using Arjun..."
arjun -u "https://$DOMAIN/endpoint.php" -oT arjun_passive.txt -t 10 --rate-limit 10 --passive -m GET,POST --headers "$HEADERS"

echo "[*] Wordlist-based Parameter Discovery using Arjun..."
arjun -u "https://$DOMAIN/endpoint.php" -oT arjun_active.txt -m GET,POST -w "$WORDLIST" -t 10 --rate-limit 10 --headers "$HEADERS"

echo "[*] JavaScript Vulnerability Scanning with Nuclei..."
if [ -s alljs.txt ]; then
    cat alljs.txt | nuclei -t "$NUCLEI_JS_TEMPLATES" -c 30 -o nuclei_alljs_scan.txt
fi

echo "$DOMAIN" | katana -d 5 | grep -E "\.js$" | nuclei -t "$NUCLEI_JS_TEMPLATES" -c 30 -o nuclei_js_scan.txt

echo "[+] Recon Completed. All results saved in recon/$DOMAIN/"
