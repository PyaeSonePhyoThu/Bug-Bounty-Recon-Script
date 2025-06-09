🧩 Subdomain Enumeration
Tool	Description
subfinder	Fast passive subdomain enumeration tool.
httpx-toolkit	Fast and multi-purpose HTTP toolkit for probing domains.
subzy	Subdomain takeover vulnerability checker.

🌐 URL Collection
Tool	Description
katana	Web crawling and URL enumeration tool.
urldedupe	Removes duplicate URLs.
anew	Appends unique lines to a file.
gau (GetAllURLs)	Fetches known URLs from services like Wayback, CommonCrawl.

🔐 Sensitive Data Discovery
Tool	Description
gf	Pattern-based search tool for filtering URLs (e.g., for .git).
httpx-toolkit	Used again here to probe specific paths and look for exposed services.
s3scanner	Scans for open AWS S3 buckets associated with a domain.
curl	Fetches JavaScript files to search for secrets like API keys.
grep	Used to filter by file extensions or keyword matches.

📊 Parameter Discovery
Tool	Description
arjun	Finds GET and POST parameters of web applications.

📜 JavaScript Analysis
Tool	Description
nuclei	Vulnerability scanner based on customizable templates (used for JS exposure detection).

🛠️ Other Utilities
Tool	Description
sed	Stream editor used to trim URLs to base format (e.g., removing values).
sort	Sorts lines of text (used with URL lists).
cut	Extracts fields from lines (used for parsing JS probe output).
xargs	Runs a command on each input item (used with curl).