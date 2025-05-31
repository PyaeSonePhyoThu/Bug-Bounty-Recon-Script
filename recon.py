import os
import re
import sys
import subprocess
from urllib.parse import urlparse
import requests

# ANSI colors
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
NC = '\033[0m'

def run_cmd(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

def extract_domain(url):
    return urlparse(url).netloc

def main(target):
    domain = extract_domain(target)
    outdir = f"output/{domain}"
    os.makedirs(outdir, exist_ok=True)

    # Subdomain Enumeration
    print(f"{YELLOW}[1] Enumerating subdomains...{NC}")
    subfinder = run_cmd(f'subfinder -d {domain}')
    assetfinder = run_cmd(f'assetfinder --subs-only {domain}')
    all_subs = set(subfinder.splitlines() + assetfinder.splitlines())
    with open(f'{outdir}/subdomains.txt', 'w') as f:
        for sub in sorted(all_subs):
            f.write(sub + '\n')
    print(f"{GREEN}[✓] {len(all_subs)} subdomains found.{NC}")

    # JavaScript File Discovery
    print(f"{YELLOW}[2] Crawling with katana...{NC}")
    katana_output = run_cmd(f'katana -u "{target}" -d 5 -jc | grep "\\.js$"')
    with open(f'{outdir}/alljs.txt', 'w') as f:
        f.write(katana_output + '\n')

    print(f"{YELLOW}[3] Getting archived JS URLs...{NC}")
    gau_output = run_cmd(f'echo "{target}" | gauplus | grep "\\.js"')
    wayback_output = run_cmd(f'echo "{target}" | waybackurls | grep "\\.js"')
    with open(f'{outdir}/alljs.txt', 'a') as f:
        f.write(gau_output + '\n')
        f.write(wayback_output + '\n')

    # Filter JS
    print(f"{YELLOW}[4] Filtering JS files (main.*.js)...{NC}")
    with open(f'{outdir}/alljs.txt', 'r') as f:
        js_urls = set(line.strip() for line in f if re.search(r'/main\.[^/]+\.js$', line))
    with open(f'{outdir}/filtered_js.txt', 'w') as f:
        for js in sorted(js_urls):
            f.write(js + '\n')

    # Validate JS URLs
    print(f"{YELLOW}[5] Validating JS URLs...{NC}")
    httpx_out = run_cmd(f'cat "{outdir}/filtered_js.txt" | httpx -mc 200 -t 50')
    with open(f'{outdir}/valid_js.txt', 'w') as f:
        f.write(httpx_out + '\n')
    valid_count = sum(1 for _ in open(f'{outdir}/valid_js.txt'))
    print(f"{GREEN}[✓] {valid_count} valid JS files found.{NC}")

    # Scan for secrets
    print(f"{YELLOW}[6] Scanning for secrets...{NC}")
    with open(f'{outdir}/valid_js.txt', 'r') as f:
        for jsurl in f:
            jsurl = jsurl.strip()
            print(f"\n{RED}[*] {jsurl}{NC}")
            try:
                resp = requests.get(jsurl, timeout=10)
                content = resp.text
                with open(f"{outdir}/temp.js", 'w') as tmp:
                    tmp.write(content)
                secrets = {
                    "API Key": re.findall(r"api[_-]?key[ =:\"']+[A-Za-z0-9_\-]{16,}", content, re.IGNORECASE),
                    "Token": re.findall(r"token[ =:\"']+[A-Za-z0-9_\-]{16,}", content, re.IGNORECASE),
                    "Secret": re.findall(r"secret[ =:\"']+[A-Za-z0-9_\-]{16,}", content, re.IGNORECASE),
                    "AWS Key": re.findall(r"AKIA[0-9A-Z]{16}", content),
                    "Email": re.findall(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", content),
                    "S3 Bucket": re.findall(r'\b[a-z0-9.-]+\.s3\.amazonaws\.com\b', content, re.IGNORECASE),
                    "GCP Bucket": re.findall(r'\b(?:storage\.googleapis\.com/[a-z0-9._-]+|[a-z0-9._-]+\.storage\.googleapis\.com)\b', content),
                    "Azure Blob": re.findall(r'\b[a-z0-9]{3,24}\.blob\.core\.windows\.net\b', content),
                    "DO Space": re.findall(r'\b[a-z0-9.-]+\.digitaloceanspaces\.com\b', content),
                    "Alibaba OSS": re.findall(r'\b[a-z0-9.-]+\.oss-[a-z0-9-]+\.aliyuncs\.com\b', content)
                }
                for key, hits in secrets.items():
                    if hits:
                        print(f"  [!] {key}: {len(hits)} found")
            except Exception as e:
                print(f"{RED}[!] Failed to fetch: {jsurl} - {e}{NC}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"{RED}Usage: python3 jsrecon.py <target_url>{NC}")
        sys.exit(1)
    main(sys.argv[1])
