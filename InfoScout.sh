#!/bin/bash

source ~/.profile
export PATH="$PATH:$HOME/go/bin"

red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

#############################################################################################
#         ///             You can edit your configuration here             \\\
#############################################################################################
auquatoneThreads=5
subdomainThreads=10
dirsearchThreads=50
dirsearchWordlist=/usr/share/wordlists/seclists/Discovery/Web-Content/dirsearch.txt
massdnsWordlist=/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-20000.txt
chromiumPath=/usr/bin/chromium
#############################################################################################
# ///  As the world becomes more digitized, there are more entry points for hackers  \\\
#############################################################################################
# Tools Used - Sublist3tr, Subscraper, Assetfinder, Certspotter, Crt.sh, Subbrute,
# massdns, HTTProbe, Aquatone, Waybackurls, Dirsearch, Nmap
# Language Used - HTML, Python, Bash Scripting

SECONDS=0

domain=
subreport=
usage() { echo -e "Usage: ./InfoScout.sh -d domain.com [-e] [excluded.domain.com,other.domain.com]\nOptions:\n  -e\t-\tspecify excluded subdomains\n " 1>&2; exit 1; }

while getopts ":d:e:r:" o; do
    case "${o}" in
        d)
            # Main Doamin of the Organization
            domain=${OPTARG}
        ;;
        e)
            # The Subdomains which should be Excluded
            set -f
            IFS=","
            excluded+=($OPTARG)
            unset IFS
        ;;
        r)
            subreport+=("$OPTARG")
        ;;
        *)
            usage
        ;;
    esac
done
shift $((OPTIND - 1)) 

if [ -z "${domain}" ] && [[ -z ${subreport[@]} ]]; then
    usage; exit 1;
fi

recon(){
    echo "Recon started on $domain"
    echo ""
    echo "${green}Sub-Domain Gathering Started${reset}"
    echo ""
    echo "${yellow}[+] Finding Sub-Domains using Sublist3r : ${reset}"
    sublist3r -d $domain -o ./$domain/$foldername/Recon-Tools-Data/Sublister-subdomains.txt > /dev/null
    echo "${yellow}[+] Finding Sub-Domains using SubScraper : ${reset}"
    ~/tools/subscraper/subscraper.py -d $domain -o ./$domain/$foldername/Recon-Tools-Data/SubScapper-subdomains.txt > /dev/null
    echo "${yellow}[+] Finding Sub-Domains using Assetfinder : ${reset}"
    assetfinder -subs-only $domain > ./$domain/$foldername/Recon-Tools-Data/Assetfinder-subdomains.txt
    echo "${yellow}[+] Finding Sub-Domains using Certspotter : ${reset}"
    curl -s https://api.certspotter.com/v1/issuances\?domain\=$domain\&expand\=dns_names\&expand\=issuer | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep $domain >> ./$domain/$foldername/Recon-Tools-Data/Certspotter-subdomains.txt
    echo "${yellow}[+] Finding Sub-Domains using Crt.sh : ${reset}"
    ~/tools/massdns/scripts/ct.py $domain 2>/dev/null > ./$domain/$foldername/Recon-Tools-Data/Crtsh-subdomains.txt
    echo "${yellow}[+] Finding Sub-Domains using Subbrute : ${reset}"
    ~/tools/massdns/scripts/subbrute.py $domain $massdnsWordlist > ./$domain/$foldername/Recon-Tools-Data/Subbrute-subdomains.txt

    cat ./$domain/$foldername/Recon-Tools-Data/Sublister-subdomains.txt > ./$domain/$foldername/$domain.txt
    cat ./$domain/$foldername/Recon-Tools-Data/SubScapper-subdomains.txt > ./$domain/$foldername/$domain.txt
    cat ./$domain/$foldername/Recon-Tools-Data/Assetfinder-subdomains.txt >> ./$domain/$foldername/$domain.txt
    cat ./$domain/$foldername/Recon-Tools-Data/Certspotter-subdomains.txt >> ./$domain/$foldername/$domain.txt
    cat ./$domain/$foldername/Recon-Tools-Data/Crtsh-subdomains.txt >> ./$domain/$foldername/$domain.txt
    cat ./$domain/$foldername/Recon-Tools-Data/Subbrute-subdomains.txt >> ./$domain/$foldername/$domain.txt
    cat ./$domain/$foldername/$domain.txt | sort -u > ./$domain/$foldername/all-subdomains.txt

    nsrecords $domain
    excludedomains
    echo "${green}Starting Discovery :${reset}"
    discovery $domain
    cat ./$domain/$foldername/$domain.txt | sort -u > ./$domain/$foldername/$domain.txt
}

nsrecords(){
    echo ""
    echo "${green}Starting Massdns Subdomain discovery this may take a while${reset}"
    # mass $domain > /dev/null
    # ~/tools/massdns/bin/massdns -r ~/tools/massdns/lists/resolvers.txt -t A -q -o S > ./$domain/$foldername/mass.txt
    cat ./$domain/$foldername/$domain.txt | ~/tools/massdns/bin/massdns -r ~/tools/massdns/lists/resolvers.txt -t A -q -o S -w ./$domain/$foldername/temp.txt
    echo "${yellow}MassDNS Finished...${reset}"
    echo ""
    echo "${green}Started DNS Records Check...${reset}"
    echo "${yellow}Looking into CNAME Records...${reset}"
    cat ./$domain/$foldername/temp.txt | awk '{print $3}' | sort -u | while read line; do
        wildcard=$(cat ./$domain/$foldername/temp.txt | grep -m 1 $line)
        echo "$wildcard" >> ./$domain/$foldername/cleantemp.txt
    done

    cat ./$domain/$foldername/cleantemp.txt | grep CNAME > ./$domain/$foldername/cnames.txt
    cat ./$domain/$foldername/cnames.txt | sort -u | while read line; do
        hostrec=$(echo "$line" | awk '{print $1}')
        if [[ $(host $hostrec | grep NXDOMAIN) != "" ]]
        then
            echo "Check the following domain for NS Takeover: $line "
            echo "$line" >> ./$domain/$foldername/pos.txt
        else
            echo -ne "Nothing found for NS Takeover.\r"
        fi
    done
    sleep 1
    cat ./$domain/$foldername/$domain.txt > ./$domain/$foldername/alldomains.txt
    cat ./$domain/$foldername/cleantemp.txt | awk  '{print $1}' | while read line; do
        x="$line"
        echo "${x%?}" >> ./$domain/$foldername/alldomains.txt
    done
    sleep 1
    echo ""
}

excludedomains(){
    echo "${yellow}Excluding domains :${reset}"
    IFS=$'\n'
    # prints the $excluded array to excluded.txt with newlines 
    printf "%s\n" "${excluded[*]}" > ./$domain/$foldername/excluded.txt
    # this form of grep takes two files, reads the input from the first file, finds in the second file and removes
    grep -vFf ./$domain/$foldername/excluded.txt ./$domain/$foldername/alldomains.txt > ./$domain/$foldername/alldomains2.txt
    mv ./$domain/$foldername/alldomains2.txt ./$domain/$foldername/alldomains.txt
    #rm ./$domain/$foldername/excluded.txt # uncomment to remove excluded.txt, I left for testing purposes
    echo "${red}Subdomains that have been excluded from discovery : ${reset}"
    printf "%s\n" "${excluded[@]}"
    unset IFS
}

discovery(){
	cleandirsearch $domain
	hostalive $domain
	aqua $domain
	cleanup $domain
	waybackrecon $domain
	# dirsearcher
}

cleandirsearch(){
	cat ./$domain/$foldername/urllist.txt | sed 's/\http\:\/\///g' |  sed 's/\https\:\/\///g' | sort -u | while read line; do
        [ -d ~/tools/dirsearch/reports/$line/ ] && ls ~/tools/dirsearch/reports/$line/ | grep -v old | while read i; do
            mv ~/tools/dirsearch/reports/$line/$i ~/tools/dirsearch/reports/$line/$i.old
        done
    done
}

hostalive(){
    echo "${yellow}Probing for live hosts...${reset}"
    cat ./$domain/$foldername/$domain.txt | sort -u | httprobe -c 50 -t 3000 > ./$domain/$foldername/responsive.txt
    cat ./$domain/$foldername/responsive.txt | sed 's/\http\:\/\///g' |  sed 's/\https\:\/\///g' | sort -u | while read line; do
        probeurl=$(cat ./$domain/$foldername/responsive.txt | sort -u | grep -m 1 $line)
        echo "$probeurl" >> ./$domain/$foldername/urllist.txt
    done
    echo "$(cat ./$domain/$foldername/urllist.txt | sort -u)" > ./$domain/$foldername/urllist.txt
    echo  "${yellow}Total of $(wc -l ./$domain/$foldername/urllist.txt | awk '{print $1}') live subdomains were found${reset}"
    echo ""
}

aqua(){
    echo "${green}Starting Aquatone Scan :${reset}"
    echo "${yellow}Looking for the Website Urls...${reset}"
    echo "${yellow}Working on the Website Headers...${reset}"
    echo "${yellow}Taking Screenshoots and HTML Data...${reset}"
    cat ./$domain/$foldername/urllist.txt | aquatone -chrome-path $chromiumPath -out ./$domain/$foldername/aqua_out -threads $auquatoneThreads -silent
    echo ""
}

cleanup(){
    cd ./$domain/$foldername/screenshots/
    rename 's/_/-/g' -- *
    cd $path
}

waybackrecon () {
    echo "${green}Scraping wayback for data...${reset}"
    cat ./$domain/$foldername/urllist.txt | waybackurls > ./$domain/$foldername/wayback-data/waybackurls.txt
    cat ./$domain/$foldername/wayback-data/waybackurls.txt  | sort -u | unfurl --unique keys > ./$domain/$foldername/wayback-data/paramlist.txt
    [ -s ./$domain/$foldername/wayback-data/paramlist.txt ] && echo "${yellow}Wordlist saved to /$domain/$foldername/wayback-data/paramlist.txt${reset}"

    cat ./$domain/$foldername/wayback-data/waybackurls.txt  | sort -u | grep -P "\w+\.js(\?|$)" | sort -u > ./$domain/$foldername/wayback-data/jsurls.txt
    [ -s ./$domain/$foldername/wayback-data/jsurls.txt ] && echo "${yellow}JS Urls saved to /$domain/$foldername/wayback-data/jsurls.txt${reset}"

    cat ./$domain/$foldername/wayback-data/waybackurls.txt  | sort -u | grep -P "\w+\.php(\?|$)" | sort -u > ./$domain/$foldername/wayback-data/phpurls.txt
    [ -s ./$domain/$foldername/wayback-data/phpurls.txt ] && echo "${yellow}PHP Urls saved to /$domain/$foldername/wayback-data/phpurls.txt${reset}"

    cat ./$domain/$foldername/wayback-data/waybackurls.txt  | sort -u | grep -P "\w+\.aspx(\?|$)" | sort -u > ./$domain/$foldername/wayback-data/aspxurls.txt
    [ -s ./$domain/$foldername/wayback-data/aspxurls.txt ] && echo "${yellow}ASP Urls saved to /$domain/$foldername/wayback-data/aspxurls.txt${reset}"

    cat ./$domain/$foldername/wayback-data/waybackurls.txt  | sort -u | grep -P "\w+\.jsp(\?|$)" | sort -u > ./$domain/$foldername/wayback-data/jspurls.txt
    [ -s ./$domain/$foldername/wayback-data/jspurls.txt ] && echo "${yellow}JSP Urls saved to /$domain/$foldername/wayback-data/jspurls.txt${reset}"

    echo ""
}

dirsearcher(){
    echo "${green}Starting Dirsearch :${reset}"
    echo ""
    cat ./$domain/$foldername/urllist.txt | while read line; do
        url_name=`echo $line | cut -d'/' -f3`
        mkdir ./$domain/$foldername/Dirsearch-Reports/${url_name}
        touch ./$domain/$foldername/Dirsearch-Reports/${url_name}/${url_name}
        echo "${red}Target - ${line}${reset}"
        # python3 ~/tools/dirsearch/dirsearch.py -e conf,config,bak,backup,swp,old,db,sql,asp,aspx,aspx~,asp~,py,py~,rb,rb~,php,php~,bak,bkp,cache,cgi,conf,csv,html,inc,jar,js,json,jsp,jsp~,lock,log,rar,old,sql,sql.gz,sql.zip,sql.tar.gz,sql~,swp,swp~,tar,tar.bz2,tar.gz,txt,wadl,zip,log,xml,js,json -t $dirsearchThreads -w $dirsearchWordlist -o ./$domain/$foldername/Dirsearch-Reports/${url_name}/${url_name} -u $line
        python3 ~/tools/dirsearch/dirsearch.py -e php,asp,aspx,jsp,html,zip,jar -t $dirsearchThreads -w $dirsearchWordlist -o ./$domain/$foldername/Dirsearch-Reports/${url_name}/${url_name} -u $line 
    done
}

logo(){
    #Cannot use a bash script without a cool logo :)
    echo "${red}  
    _________ _        _______  _______  _______  _______  _______          _________
    \__   __/| \    /||  ____ \/  ___  \/  ____ \/  ____ \/  ___  \|\     /|\__   __/
       | |   |  \  | || |    \/| /   \ || /    \/| /    \/| /   \ || |   | |   | |   
       | |   |   \ | || |__    | |   | || \_____ | |      | |   | || |   | |   | |   
       | |   | |\ \| ||  __)   | |   | |\_____  \| |      | |   | || |   | |   | |   
       | |   | | \   || |      | |   | |      \ || |      | |   | || |   | |   | |   
    ___| |___| |  \  || |      | \___/ |/\____/ || \____/\| \___/ || \___/ |   | |   
    \_______/|/    \_||/       \_______/\_______/\_______/\_______/\_______/   |_|   
    ${reset}
    "
}

report(){
    subdomain=$(echo $subd | sed 's/\http\:\/\///g' |  sed 's/\https\:\/\///g')
    echo "[+] Generating report for $subdomain"

    cat ./$domain/$foldername/aqua_out/aquatone_session.json | jq --arg v "$subd" -r '.pages[$v].headers[] | keys[] as $k | "\($k), \(.[$k])"' | grep -v "decreasesSecurity\|increasesSecurity" >> ./$domain/$foldername/aqua_out/parsedjson/$subdomain.headers
    # dirsearchfile=$(ls ./$domain/$foldername/Dirsearch-Reports/$subdomain/ | grep -v old)

    touch ./$domain/$foldername/reports/$subdomain.html
    echo '<html><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">' >> ./$domain/$foldername/reports/$subdomain.html
    echo "<head>" >> ./$domain/$foldername/reports/$subdomain.html
    echo "<title>Recon Report for $subdomain</title>
    <style>.status.fourhundred{color:#00a0fc}
    .status.redirect{color:#d0b200}.status.fivehundred{color:#DD4A68}.status.jackpot{color:#0dee00}.status.weird{color:#cc00fc}img{padding:5px;width:360px}img:hover{box-shadow:0 0 2px 1px rgba(0,140,186,.5)}pre{font-family:Inconsolata,monospace}pre{margin:0 0 20px}pre{overflow-x:auto}article,header,img{display:block}#wrapper:after,.blog-description:after,.clearfix:after{content:}.container{position:relative}html{line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}h1{margin:.67em 0}h1,h2{margin-bottom:20px}a{background-color:transparent;-webkit-text-decoration-skip:objects;text-decoration:none}.container,table{width:100%}.site-header{overflow:auto}.post-header,.post-title,.site-header,.site-title,h1,h2{text-transform:uppercase}p{line-height:1.5em}pre,table td{padding:10px}h2{padding-top:40px;font-weight:900}a{color:#00a0fc}body,html{height:100%}body{margin:0;background:#fefefe;color:#424242;font-family:Raleway,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Oxygen,Ubuntu,'Helvetica Neue',Arial,sans-serif;font-size:24px}h1{font-size:35px}h2{font-size:28px}p{margin:0 0 30px}pre{background:#f1f0ea;border:1px solid #dddbcc;border-radius:3px;font-size:16px}.row{display:flex}.column{flex:100%}table tbody>tr:nth-child(odd)>td,table tbody>tr:nth-child(odd)>th{background-color:#f7f7f3}table th{padding:0 10px 10px;text-align:left}.post-header,.post-title,.site-header{text-align:center}table tr{border-bottom:1px dotted #aeadad}::selection{background:#fff5b8;color:#000;display:block}::-moz-selection{background:#fff5b8;color:#000;display:block}.clearfix:after{display:table;clear:both}.container{max-width:100%}#wrapper{height:auto;min-height:100%;margin-bottom:-265px}#wrapper:after{display:block;height:265px}.site-header{padding:40px 0 0}.site-title{float:left;font-size:14px;font-weight:600;margin:0}.site-title a{float:left;background:#00a0fc;color:#fefefe;padding:5px 10px 6px}.post-container-left{width:49%;float:left;margin:auto}.post-container-right{width:49%;float:right;margin:auto}.post-header{border-bottom:1px solid #333;margin:0 0 50px;padding:0}.post-title{font-size:55px;font-weight:900;margin:15px 0}.blog-description{color:#aeadad;font-size:14px;font-weight:600;line-height:1;margin:25px 0 0;text-align:center}.single-post-container{margin-top:50px;padding-left:15px;padding-right:15px;box-sizing:border-box}body.dark{background-color:#1e2227;color:#fff}body.dark pre{background:#282c34}body.dark table tbody>tr:nth-child(odd)>td,body.dark table tbody>tr:nth-child(odd)>th{background:#282c34} table tbody>tr:nth-child(even)>th{background:#1e2227} input{font-family:Inconsolata,monospace} body.dark .status.redirect{color:#ecdb54} body.dark input{border:1px solid ;border-radius: 3px; background:#282c34;color: white} body.dark label{color:#f1f0ea} body.dark pre{color:#fff}</style>
    <script>
    document.addEventListener('DOMContentLoaded', (event) => {
    ((localStorage.getItem('mode') || 'dark') === 'dark') ? document.querySelector('body').classList.add('dark') : document.querySelector('body').classList.remove('dark')
    })
    </script>" >> ./$domain/$foldername/reports/$subdomain.html
    echo '<link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/material-design-lite/1.1.0/material.min.css">
    <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.19/css/dataTables.material.min.css">
    <script type="text/javascript" src="https://code.jquery.com/jquery-3.3.1.js"></script>
    <script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.10.19/js/jquery.dataTables.js"></script><script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.10.19/js/dataTables.material.min.js"></script>'>> ./$domain/$foldername/reports/$subdomain.html
    echo '<script>$(document).ready( function () {
        $("#myTable").DataTable({
            "paging":   true,
            "ordering": true,
            "info":     true,
            "autoWidth": true,
            "columns": [{ "width": "5%" },{ "width": "5%" },null],
            "lengthMenu": [[10, 25, 50,100, -1], [10, 25, 50,100, "All"]],
        });
    });</script></head>'>> ./$domain/$foldername/reports/$subdomain.html

    echo '<body class="dark"><header class="site-header">
    <div class="site-title"><p>' >> ./$domain/$foldername/reports/$subdomain.html
    echo "<a style=\"cursor: pointer\" onclick=\"localStorage.setItem('mode', (localStorage.getItem('mode') || 'dark') === 'dark' ? 'bright' : 'dark'); localStorage.getItem('mode') === 'dark' ? document.querySelector('body').classList.add('dark') : document.querySelector('body').classList.remove('dark')\" title=\"Switch to light or dark theme\">🌓 Light|dark mode</a>
    </p>
    </div>
    </header>" >> ./$domain/$foldername/reports/$subdomain.html
    echo '<div id="wrapper"><div id="container">'  >> ./$domain/$foldername/reports/$subdomain.html
    echo "<h1 class=\"post-title\" itemprop=\"name headline\">Recon Report for <a href=\"http://$subdomain\">$subdomain</a></h1>" >> ./$domain/$foldername/reports/$subdomain.html
    echo "<p class=\"blog-description\">Generated by infoScout on $(date) </p>" >> ./$domain/$foldername/reports/$subdomain.html
    echo '<div class="container single-post-container">
    <article class="post-container-left" itemscope="" itemtype="http://schema.org/BlogPosting">
    <header class="post-header">
    </header>
    <div class="post-content clearfix" itemprop="articleBody">
    <h2>Content Discovery</h2>' >> ./$domain/$foldername/reports/$subdomain.html
    echo "<table id='myTable' class='stripe'>" >> ./$domain/$foldername/reports/$subdomain.html
    echo "<thead><tr>
    <th>Status Code</th>
    <th>Content-Length</th>
    <th>Url</th>
    </tr></thead><tbody>" >> ./$domain/$foldername/reports/$subdomain.html

    cat ./$domain/$foldername/Dirsearch-Reports/$subdomain/$dirsearchfile | while read nline; do
        status_code=$(echo "$nline" | awk '{print $1}')
        size=$(echo "$nline" | awk '{print $2}')
        url=$(echo "$nline" | awk '{print $3}')
        path=${url#*[0-9]/}
        echo "<tr>" >> ./$domain/$foldername/reports/$subdomain.html
        if [[ "$status_code" == *20[012345678]* ]]; then
            echo "<td class='status jackpot'>$status_code</td><td class='status jackpot'>$size</td><td><a class='status jackpot' href='$url'>/$path</a></td>" >> ./$domain/$foldername/reports/$subdomain.html
        elif [[ "$status_code" == *30[012345678]* ]]; then
            echo "<td class='status redirect'>$status_code</td><td class='status redirect'>$size</td><td><a class='status redirect' href='$url'>/$path</a></td>" >> ./$domain/$foldername/reports/$subdomain.html
        elif [[ "$status_code" == *40[012345678]* ]]; then
            echo "<td class='status fourhundred'>$status_code</td><td class='status fourhundred'>$size</td><td><a class='status fourhundred' href='$url'>/$path</a></td>" >> ./$domain/$foldername/reports/$subdomain.html
        elif [[ "$status_code" == *50[012345678]* ]]; then
            echo "<td class='status fivehundred'>$status_code</td><td class='status fivehundred'>$size</td><td><a class='status fivehundred' href='$url'>/$path</a></td>" >> ./$domain/$foldername/reports/$subdomain.html
        else
            echo "<td class='status weird'>$status_code</td><td class='status weird'>$size</td><td><a class='status weird' href='$url'>/$path</a></td>" >> ./$domain/$foldername/reports/$subdomain.html
        fi
        echo "</tr>">> ./$domain/$foldername/reports/$subdomain.html
    done
    echo "</tbody></table></div>" >> ./$domain/$foldername/reports/$subdomain.html

    echo '</article><article class="post-container-right" itemscope="" itemtype="http://schema.org/BlogPosting">
    <header class="post-header">
    </header>
    <div class="post-content clearfix" itemprop="articleBody">
    <h2>Screenshots</h2>
    <pre style="max-height: 340px;overflow-y: scroll">' >> ./$domain/$foldername/reports/$subdomain.html
    echo '<div class="row">
    <div class="column">
    Port 80' >> ./$domain/$foldername/reports/$subdomain.html
    scpath=$(echo "$subdomain" | sed 's/\./_/g')
    httpsc=$(ls ./$domain/$foldername/aqua_out/screenshots/http__$scpath*  2>/dev/null)
    echo "<a href=\"../../../$httpsc\"><img/src=\"../../../$httpsc\"></a> " >> ./$domain/$foldername/reports/$subdomain.html
    echo '</div>
    <div class="column">
    Port 443' >> ./$domain/$foldername/reports/$subdomain.html
    httpssc=$(ls ./$domain/$foldername/aqua_out/screenshots/https__$scpath*  2>/dev/null)
    echo "<a href=\"../../../$httpssc\"><img/src=\"../../../$httpssc\"></a>" >> ./$domain/$foldername/reports/$subdomain.html
    echo "</div></div></pre>" >> ./$domain/$foldername/reports/$subdomain.html
    echo "<h2>Dig Info</h2><pre>$(dig $subdomain)</pre>" >> ./$domain/$foldername/reports/$subdomain.html
    echo "<h2>Host Info</h2><pre>$(host $subdomain)</pre>" >> ./$domain/$foldername/reports/$subdomain.html
    echo "<h2>Response Headers</h2><pre>" >> ./$domain/$foldername/reports/$subdomain.html

    cat ./$domain/$foldername/aqua_out/parsedjson/$subdomain.headers | while read ln;do
        check=$(echo "$ln" | awk '{print $1}')
        [ "$check" = "name," ] && echo -n "$ln : " | sed 's/name, //g' >> ./$domain/$foldername/reports/$subdomain.html
        [ "$check" = "value," ] && echo " $ln" | sed 's/value, //g' >> ./$domain/$foldername/reports/$subdomain.html
    done

    echo "</pre>" >> ./$domain/$foldername/reports/$subdomain.html
    echo "<h2>NMAP Results</h2>
    <pre>
    $(nmap -sV -T3 -Pn -p2075,2076,6443,3868,3366,8443,8080,9443,9091,3000,8000,5900,8081,6000,10000,8181,3306,5000,4000,8888,5432,15672,9999,161,4044,7077,4040,9000,8089,443,7447,7080,8880,8983,5673,7443,19000,19080 $subdomain  |  grep -E 'open|filtered|closed')
    </pre>
    </div></article></div>
    </div></div></body></html>" >> ./$domain/$foldername/reports/$subdomain.html
}

master_report(){

    #this code will generate the html report for target it will have an overview of the scan
    echo '<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">' >> ./$domain/$foldername/master_report.html
    echo "<title>Recon Report for $domain</title>
    <style>.status.redirect{color:#d0b200}.status.fivehundred{color:#DD4A68}.status.jackpot{color:#0dee00}img{padding:5px;width:360px}img:hover{box-shadow:0 0 2px 1px rgba(0,140,186,.5)}pre{font-family:Inconsolata,monospace}pre{margin:0 0 20px}pre{overflow-x:auto}article,header,img{display:block}#wrapper:after,.blog-description:after,.clearfix:after{content:}.container{position:relative}html{line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}h1{margin:.67em 0}h1,h2{margin-bottom:20px}a{background-color:transparent;-webkit-text-decoration-skip:objects;text-decoration:none}.container,table{width:100%}.site-header{overflow:auto}.post-header,.post-title,.site-header,.site-title,h1,h2{text-transform:uppercase}p{line-height:1.5em}pre,table td{padding:10px}h2{padding-top:40px;font-weight:900}a{color:#00a0fc}body,html{height:100%}body{margin:0;background:#fefefe;color:#424242;font-family:Raleway,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Oxygen,Ubuntu,'Helvetica Neue',Arial,sans-serif;font-size:24px}h1{font-size:35px}h2{font-size:28px}p{margin:0 0 30px}pre{background:#f1f0ea;border:1px solid #dddbcc;border-radius:3px;font-size:16px}.row{display:flex}.column{flex:100%}table tbody>tr:nth-child(odd)>td,table tbody>tr:nth-child(odd)>th{background-color:#f7f7f3}table th{padding:0 10px 10px;text-align:left}.post-header,.post-title,.site-header{text-align:center}table tr{border-bottom:1px dotted #aeadad}::selection{background:#fff5b8;color:#000;display:block}::-moz-selection{background:#fff5b8;color:#000;display:block}.clearfix:after{display:table;clear:both}.container{max-width:100%}#wrapper{height:auto;min-height:100%;margin-bottom:-265px}#wrapper:after{display:block;height:265px}.site-header{padding:40px 0 0}.site-title{float:left;font-size:14px;font-weight:600;margin:0}.site-title a{float:left;background:#00a0fc;color:#fefefe;padding:5px 10px 6px}.post-container-left{width:49%;float:left;margin:auto}.post-container-right{width:49%;float:right;margin:auto}.post-header{border-bottom:1px solid #333;margin:0 0 50px;padding:0}.post-title{font-size:55px;font-weight:900;margin:15px 0}.blog-description{color:#aeadad;font-size:14px;font-weight:600;line-height:1;margin:25px 0 0;text-align:center}.single-post-container{margin-top:50px;padding-left:15px;padding-right:15px;box-sizing:border-box}body.dark{background-color:#1e2227;color:#fff}body.dark pre{background:#282c34}body.dark table tbody>tr:nth-child(odd)>td,body.dark table tbody>tr:nth-child(odd)>th{background:#282c34}input{font-family:Inconsolata,monospace} body.dark .status.redirect{color:#ecdb54} body.dark input{border:1px solid ;border-radius: 3px; background:#282c34;color: white} body.dark label{color:#f1f0ea} body.dark pre{color:#fff}</style>
    <script>
    document.addEventListener('DOMContentLoaded', (event) => {
    ((localStorage.getItem('mode') || 'dark') === 'dark') ? document.querySelector('body').classList.add('dark') : document.querySelector('body').classList.remove('dark')
    })
    </script>" >> ./$domain/$foldername/master_report.html
    echo '<link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/material-design-lite/1.1.0/material.min.css">
    <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.19/css/dataTables.material.min.css">
    <script type="text/javascript" src="https://code.jquery.com/jquery-3.3.1.js"></script>
    <script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.10.19/js/jquery.dataTables.js"></script><script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.10.19/js/dataTables.material.min.js"></script>'>> ./$domain/$foldername/master_report.html
    echo '<script>$(document).ready( function () {
        $("#myTable").DataTable({
            "paging":   true,
            "ordering": true,
            "info":     false,
            "lengthMenu": [[10, 25, 50,100, -1], [10, 25, 50,100, "All"]],
        });
    });</script></head>'>> ./$domain/$foldername/master_report.html

    echo '<body class="dark"><header class="site-header">
    <div class="site-title"><p>' >> ./$domain/$foldername/master_report.html
    echo "<a style=\"cursor: pointer\" onclick=\"localStorage.setItem('mode', (localStorage.getItem('mode') || 'dark') === 'dark' ? 'bright' : 'dark'); localStorage.getItem('mode') === 'dark' ? document.querySelector('body').classList.add('dark') : document.querySelector('body').classList.remove('dark')\" title=\"Switch to light or dark theme\">🌓 Light|dark mode</a>
    </p>
    </div>
    </header>" >> ./$domain/$foldername/master_report.html

    echo '<div id="wrapper"><div id="container">' >> ./$domain/$foldername/master_report.html
    echo "<h1 class=\"post-title\" itemprop=\"name headline\">Recon Report for <a href=\"http://$domain\">$domain</a></h1>" >> ./$domain/$foldername/master_report.html
    echo "<p class=\"blog-description\">Generated by InfoScout on $(date) </p>" >> ./$domain/$foldername/master_report.html
    echo '<div class="container single-post-container">
    <article class="post-container-left" itemscope="" itemtype="http://schema.org/BlogPosting">
    <header class="post-header">
    </header>
    <div class="post-content clearfix" itemprop="articleBody">
    <h2>Total scanned subdomains</h2>
    <table id="myTable" class="stripe">
    <thead>
    <tr>
    <th>Subdomains</th>
    <th>Scanned Urls</th>
    </tr>
    </thead>
    <tbody>' >> ./$domain/$foldername/master_report.html

    cat ./$domain/$foldername/urllist.txt |  sed 's/\http\:\/\///g' |  sed 's/\https\:\/\///g'  | while read nline; do
        # diresults=$(ls ./$domain/$foldername/Dirsearch-Reports/$nline/ | grep -v old)
        echo "<tr>
        <td><a href='./reports/$nline.html'>$nline</a></td>
        <td>$(wc -l ./$domain/$foldername/Dirsearch-Reports/$nline/$diresults | awk '{print $1}')</td>
        </tr>" >> ./$domain/$foldername/master_report.html
    done
    echo "</tbody></table>
    <div><h2>Possible NS Takeovers</h2></div>
    <pre>" >> ./$domain/$foldername/master_report.html
    cat ./$domain/$foldername/pos.txt >> ./$domain/$foldername/master_report.html

    echo "</pre><div><h2>Wayback data</h2></div>" >> ./$domain/$foldername/master_report.html
    echo "<table><tbody>" >> ./$domain/$foldername/master_report.html
    [ -s ./$domain/$foldername/wayback-data/paramlist.txt ] && echo "<tr><td><a href='./wayback-data/paramlist.txt'>Params wordlist</a></td></tr>" >> ./$domain/$foldername/master_report.html
    [ -s ./$domain/$foldername/wayback-data/jsurls.txt ] && echo "<tr><td><a href='./wayback-data/jsurls.txt'>Javscript files</a></td></tr>" >> ./$domain/$foldername/master_report.html
    [ -s ./$domain/$foldername/wayback-data/phpurls.txt ] && echo "<tr><td><a href='./wayback-data/phpurls.txt'>PHP Urls</a></td></tr>" >> ./$domain/$foldername/master_report.html
    [ -s ./$domain/$foldername/wayback-data/aspxurls.txt ] && echo "<tr><td><a href='./wayback-data/aspxurls.txt'>ASP Urls</a></td></tr>" >> ./$domain/$foldername/master_report.html
    echo "</tbody></table></div>" >> ./$domain/$foldername/master_report.html

    echo '</article><article class="post-container-right" itemscope="" itemtype="http://schema.org/BlogPosting">
    <header class="post-header">
    </header>
    <div class="post-content clearfix" itemprop="articleBody">' >> ./$domain/$foldername/master_report.html
    echo "<h2><a href='./aqua_out/aquatone_report.html'>View Aquatone Report</a></h2>" >> ./$domain/$foldername/master_report.html
    #cat ./$domain/$foldername/ipaddress.txt >> ./$domain/$foldername/master_report.html
    echo "<h2>Dig Info</h2>
    <pre>
    $(dig $domain)
    </pre>" >> ./$domain/$foldername/master_report.html
    echo "<h2>Host Info</h2>
    <pre>
    $(host $domain)
    </pre>" >> ./$domain/$foldername/master_report.html

    echo "<h2>NMAP Results</h2>
    <pre>
    $(nmap -sV -T3 -Pn $domain |  grep -E 'open|filtered|closed')
    </pre>
    </div></article></div>
    </div></div></body></html>" >> ./$domain/$foldername/master_report.html
}

cleantemp(){
    echo ""
    # rm ./$domain/$foldername/temp.txt
    # rm ./$domain/$foldername/domaintemp.txt
    # rm ./$domain/$foldername/cleantemp.txt
}

main(){
    if [ -z "${domain}" ]; then
    domain=${subreport[1]}
    foldername=${subreport[2]}
    subd=${subreport[3]}
    report $domain $subdomain $foldername $subd; exit 1;
    fi
    clear
    logo
    if [ -d "./$domain" ]
    then
        echo "This is a known target."
    else
        mkdir ./$domain
    fi
    mkdir ./$domain/$foldername
    mkdir ./$domain/$foldername/aqua_out
    mkdir ./$domain/$foldername/reports/
    mkdir ./$domain/$foldername/screenshots/
    mkdir ./$domain/$foldername/wayback-data/
    mkdir ./$domain/$foldername/Recon-Tools-Data
    mkdir ./$domain/$foldername/Dirsearch-Reports
    mkdir ./$domain/$foldername/aqua_out/parsedjson
    touch ./$domain/$foldername/pos.txt
    touch ./$domain/$foldername/cnames.txt
    touch ./$domain/$foldername/urllist.txt
    touch ./$domain/$foldername/ipaddress.txt
    touch ./$domain/$foldername/cleantemp.txt
    touch ./$domain/$foldername/alldomains.txt
    touch ./$domain/$foldername/master_report.html
    # touch ./$domain/$foldername/temp.txt
    # touch ./$domain/$foldername/mass.txt
    # touch ./$domain/$foldername/crtsh.txt
    # touch ./$domain/$foldername/domaintemp.txt
    # cleantemp
    # cd ./$domain/$foldername
    recon $domain
    master_report $domain
    echo "========================================="
    echo "Scan for $domain finished successfully"
    echo "========================================="
    duration=$SECONDS
    echo "Scan completed in : $(($duration / 60)) minutes and $(($duration % 60)) seconds."
    cleantemp
    stty sane
    tput sgr0
}

todate=$(date +%d-%b-%Y_%H:%M)
path=$(pwd)
foldername=Recon_$todate
source ~/.bash_profile
main $domain