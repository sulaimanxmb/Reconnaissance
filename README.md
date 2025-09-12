#### Tools Used :
1.subfinder
2.dnsx
3.httpx
4.katana
5.naabu
6.nmap


#### Working of script :
First the subdomains are discovered using :
```shell
#In full mode:
subfinder -silent -all -recursive -t 50 -timeout 10 -d (domain) -o subdomains_raw.txt

#In fast mode:
subfinder -silent -d (domains) -o subdomains_raw.txt
```

After that all duplicates and empty lines r removed and stored in targets.txt

After that DNSX reslution is done with dsnx:
```shell
dnsx -l "targets.txt" -silent -a -aaaa -resp -t 50 \
    -o "dnsx_tmp.txt"
```
then from that file only the subdomains are extracted and kept in dnsx_subdomains.txt and the other file is deleted

After that this dnsx_subdomains.txt is probed by httpx and make 2 files :
```shell
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
```shell
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
```shell
naabu -list "$targets_file" -silent $NAABU_FLAGS \
    | grep -vE ':(80|443)$' \
    > dnsx_subdomains.txt
```
it also ignores 80 and 443 stauts codes


After that it runs nmap (only in full mode) :
```shell
nmap -sV -sC -O -T4 -p "$ports" -iL dnsx_subdomains.txt -oN nmap_results.txt
```
