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
 
def run_cmd(cmd, capture_output=True):
    return subprocess.run(cmd, shell=True, capture_output=capture_output, text=True).stdout.strip()
 
def main(target):
    outdir = target
    os.makedirs(outdir, exist_ok=True)
 
    print(f"{YELLOW}[1] Crawling with katana...{NC}")
    js_urls = run_cmd(f'katana -u "{target}" -d 5 -jc | grep "\\.js$"')
    with open(f'{outdir}/alljs.txt', 'w') as f:
        f.write(js_urls + '\n')
 
    print(f"{YELLOW}[2] Gathering archived URLs with gauplus...{NC}")
    gau_urls = run_cmd(f'echo "{target}" | gauplus | grep "\\.js"')
    with open(f'{outdir}/alljs.txt', 'a') as f:
        f.write(gau_urls + '\n')
 
    print(f"{YELLOW}[3] Filtering JavaScript files starting with 'main.'...{NC}")
    with open(f'{outdir}/alljs.txt', 'r') as f:
        all_js = set(line.strip() for line in f if re.search(r'/main\.[^/]+\.js$', line))
    filtered_path = f'{outdir}/filtered_js.txt'
    with open(filtered_path, 'w') as f:
        for url in sorted(all_js):
            f.write(url + '\n')
 
    print(f"{YELLOW}[4] Validating URLs with httpx...{NC}")
    httpx_output = run_cmd(f'cat "{filtered_path}" | httpx-toolkit -mc 200 -t 50')
    valid_path = f'{outdir}/valid_js.txt'
    with open(valid_path, 'w') as f:
        f.write(httpx_output + '\n')
 
    valid_count = sum(1 for _ in open(valid_path))
    print(f"{GREEN}[✓] Valid JS Files: {valid_count}{NC}")
 
    print(f"{YELLOW}[5] Scanning JS files...{NC}")
    with open(valid_path, 'r') as f:
        for jsurl in f:
            jsurl = jsurl.strip()
            filename = os.path.basename(urlparse(jsurl).path)
 
            if re.match(r'^main\.[a-fA-F0-9]+\.js$', filename):
                print(f"\n{RED}[*] {jsurl}{NC}")
                try:
                    resp = requests.get(jsurl, timeout=10)
                    content = resp.text
                    with open(f"{outdir}/temp_js.txt", 'w') as temp_file:
                        temp_file.write(content)
 
                    secrets = {
                        "API Key": re.findall(r"api[_-]?key[ =:\"']+[A-Za-z0-9_\-]{16,}", content, re.IGNORECASE),
                        "Token": re.findall(r"token[ =:\"']+[A-Za-z0-9_\-]{16,}", content, re.IGNORECASE),
                        "Secret": re.findall(r"secret[ =:\"']+[A-Za-z0-9_\-]{16,}", content, re.IGNORECASE),
                        "AWS Key": re.findall(r"AKIA[0-9A-Z]{16}", content),
                        "Email": re.findall(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", content),
                        "S3 Bucket": re.findall(r'\b(?:[a-z0-9.-]+\.s3\.amazonaws\.com|s3\.[a-z0-9.-]+\.amazonaws\.com|s3\.[a-z0-9.-]+\.com)\b', content, re.IGNORECASE),
 
                        # GCP Buckets
                        "GCP Bucket": re.findall(r'\b(?:storage\.googleapis\.com/[a-z0-9._-]+|[a-z0-9._-]+\.storage\.googleapis\.com)\b', content, re.IGNORECASE),
 
                        # Azure Blobs
                        "Azure Blob": re.findall(r'\b[a-z0-9]{3,24}\.blob\.core\.windows\.net\b', content, re.IGNORECASE),
 
                        # DigitalOcean Spaces
                        "DO Space": re.findall(r'\b[a-z0-9.-]+\.digitaloceanspaces\.com\b', content, re.IGNORECASE),
 
                        # Alibaba OSS
                        "Alibaba OSS": re.findall(r'\b[a-z0-9.-]+\.oss-[a-z0-9-]+\.aliyuncs\.com\b', content, re.IGNORECASE),
                    }
 
                    for key, matches in secrets.items():
                        if matches:
                            print(f"  [!] {key}")
                except Exception as e:
                    print(f"{RED}[!] Error fetching {jsurl}: {e}{NC}")
 
if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"{RED}Usage: python3 script.py <target_url>{NC}")
        sys.exit(1)
    main(sys.argv[1])