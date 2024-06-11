```
_________ _        _______  _______  _______  _______  _______          _________
\__   __/| \    /||  ____ \/  ___  \/  ____ \/  ____ \/  ___  \|\     /|\__   __/
   | |   |  \  | || |    \/| /   \ || /    \/| /    \/| /   \ || |   | |   | |   
   | |   |   \ | || |__    | |   | || \_____ | |      | |   | || |   | |   | |   
   | |   | |\ \| ||  __)   | |   | |\_____  \| |      | |   | || |   | |   | |   
   | |   | | \   || |      | |   | |      \ || |      | |   | || |   | |   | |   
___| |___| |  \  || |      | \___/ |/\____/ || \____/\| \___/ || \___/ |   | |   
\_______/|/    \_||/       \_______/\_______/\_______/\_______/\_______/   |_|   

```

# Usage

- cd InfoScout
- chmod +x InfoScout.sh

`./InfoScout.sh -d domain.com`

To exclude particular subdomains:

`./InfoScout.sh -d domain.com -e excluded.domain.com,other.domain.com`

# About

InfoScout is a script written in Bash, it is intended to automate some tedious tasks of reconnaissance and information gathering.
This tool is designed to streamline the often time-consuming information-gathering process. Automating data collection reduces the manual effort involved and provides valuable insights, helping to determine the next steps efficiently. Its capabilities ensure that users receive timely and relevant information, facilitating more informed decision-making.


# Main Features 
- Create a dated folder with recon notes
- Grab subdomains using:
      * Sublist3tr, Subscraper, Assetfinder, Certspotter, Crt.sh, Subbrute
      * Dns bruteforcing using massdns
- Find any CNAME records pointing to unused cloud services like aws
- Grab a screenshots of responsive hosts 
- Scrape wayback for data:
      * Extract javascript files
      * Build custom parameter wordlist, ready to be loaded later into Burp intruder or any other tool
      * Extract any urls with .jsp, .php or .aspx and store them for further inspection
- Perform nmap on specific ports 
- Get dns information about every subdomain
- Perform dirsearch for all subdomains 
- Generate a HTML report with output from the tools above
- Light and Dark mode for html reports
- Directory search module is now MULTITHREADED (up to 10 subdomains scanned at a time)
- Enhanced html reports with the ability to search for strings, endpoints, reponse sizes or status codes
- Subdomain exclusion by using option `-e` like this: `-e excluded.domain.com,other.domain.com`

# Installation & Requirements
- Install script Req-install.sh.
- Go version 1.10 or later.

# Installing
- cd InfoScout
- chmod +x Req-install.sh
- ./Req-install.sh

### System Requirements
- Recommended to run on vps with 1VCPU and 2GB ram.

# Authors and Thanks
This script makes use of tools developped by the following people
- [Tom Hudson - Tomonomnom](https://github.com/tomnomnom)
- [Ahmed Aboul-Ela - Aboul3la](https://github.com/aboul3la)
- [Ben Sadeghipour - nahamsec](https://github.com/nahamsec)
- [B. Blechschmidt - Blechschmidt](https://github.com/blechschmidt)


**Warning:** This code was originally created for personal use, it generates a substantial amount of traffic, please use with caution.