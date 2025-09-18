# Recon :
This is my own custom automated recon script for bug bounties

2 modes :
1. fast
2. full

Note : Using fast mode will be 55% faster than full mode

Note : You must have Seclist downloaded and in the same directory as ur script



## Tools Used :
1. subfinder<br>
2. dnsx<br>
3. httpx<br>
4. katana<br>
5. naabu<br>
6. nmap<br>
7. git<br>



## Working of script :
First the subdomains are discovered using :
```bash
#In full mode:
subfinder -silent -all -recursive -t 50 -timeout 10 -d (domain) -o subdomains_raw.txt

#In fast mode:
subfinder -silent -d (domains) -o subdomains_raw.txt
```

After that all duplicates and empty lines r removed and stored in targets.txt

After that DNSX reslution is done with dsnx:
```bash
dnsx -l "targets.txt" -silent -a -aaaa -resp -t 50 \
    -o "dnsx_tmp.txt"
```
then from that file only the subdomains are extracted and kept in dnsx_subdomains.txt and the other file is deleted

After that this dnsx_subdomains.txt is probed by httpx and make 2 files :
```bash
# In fast mode it uses predefined ports
httpx -l dnsx_subdomains.txt -silent -follow-redirects -random-agent \
    -ports "$HTTPX_PORTS" -timeout 10 -retries 2 -threads 50 \
    -o live_urls.txt

# and 
httpx -l dnsx_subdomains.txt -silent -follow-redirects -random-agent \
    -ports "$HTTPX_PORTS" -timeout 10 -retries 2 -threads 50 \
    -status-code -title -tech-detect -ip -cdn -web-server -location \
    -o httpx_report.txt
```

After that the live_urls.txt for web crawling by katana (depending on fast or full mode parameters change) :
```bash
katana -list live_urls.txt \
    -d "$KATANA_DEPTH" \
    -c "$KATANA_CONC" \
    -p "$KATANA_PARALLEL" \
    -rl "$KATANA_RATE" \
    -timeout 10 \
    -silent \
    -no-color \
    -ef png,jpg,jpeg,gif,svg,woff,woff2,css,ico,ttf,otf,mp4 \
    -o katana_raw.txt
```
and then filtering takes place creating a url, api and js files

After that the port scanning happens with naabu :
```bash
naabu -list "$targets_file" -silent $NAABU_FLAGS \
    | grep -vE ':(80|443)$' \
    > dnsx_subdomains.txt
```
it also ignores 80 and 443 stauts codes


After that it runs nmap (only in full mode) :
```shell
nmap -sV -sC -O -T4 -p "$ports" -iL dnsx_subdomains.txt -oN nmap_results.txt
```


## Files created :

subdomains_raw.txt : raw subfinder output <br>
targets.txt : root domain + de-duplicated subdomains_raw.txt <br>
dsnx_subdomains.txt : Resolvable subdomains from targets.txt <br>
live_urls.txt : httpx probed/rechable URL's from dnsx_subdomains.txt <br>
httpx_report.txt : detailed httpx output of live_urls.txt <br>
katana_raw.txt : raw katana URL's <br>
katana_urls.txt : unique and sorted URL's from katana_raw.txt <br>
katana_js.txt : .js URL'S from katana_urls.txt <br>
katana_api.txt : /api/ or /v1 etc. from katana_urls.txt <br>
naabu_ports.txt : naabu port scan on domains from targets.txt except http & https <br>
nmap_results : detailed NMAP scan on targets.txt <br>
