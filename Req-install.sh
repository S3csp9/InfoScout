#!/bin/bash
sudo apt-get -y update
sudo apt-get -y upgrade

sudo apt-get install -y libcurl4-openssl-dev
sudo apt-get install -y libssl-dev
sudo apt-get install -y jq
sudo apt-get install -y ruby-full
sudo apt-get install -y libcurl4-openssl-dev libxml2 libxml2-dev libxslt1-dev ruby-dev build-essential libgmp-dev zlib1g-dev
sudo apt-get install -y build-essential libssl-dev libffi-dev python-dev
sudo apt-get install -y python-setuptools
sudo apt-get install -y libldns-dev
sudo apt-get install -y python3-pip
sudo apt-get install -y python-pip
sudo apt-get install -y python-dnspython
sudo apt-get install -y git
sudo apt-get install -y rename
sudo apt-get install -y xargs

echo "Installing bash_profile aliases from recon_profile"
git clone https://github.com/nahamsec/recon_profile.git
cd recon_profile
cat bash_profile >> ~/.bash_profile
source ~/.bash_profile
cd ~/tools/
echo "done"

#install go
if [[ -z "$GOPATH" ]];then
echo "It looks like go is not installed, would you like to install it now"
PS3="Please select an option : "
choices=("yes" "no")
select choice in "${choices[@]}"; do
    case $choice in
        yes)
			echo "Installing Golang"
			wget https://dl.google.com/go/go1.13.4.linux-amd64.tar.gz
			sudo tar -xvf go1.13.4.linux-amd64.tar.gz
			sudo mv go /usr/local
			export GOROOT=/usr/local/go
			export GOPATH=$HOME/go
			export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
			echo 'export GOROOT=/usr/local/go' >> ~/.bash_profile
			echo 'export GOPATH=$HOME/go'	>> ~/.bash_profile			
			echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.bash_profile	
			source ~/.bash_profile
			sleep 1
			break
			;;
		no)
			echo "Please install go and rerun this script"
			echo "Aborting installation..."
			exit 1
			;;
    esac	
done
fi

#Creating a tools folder in ~/
mkdir ~/tools
cd ~/tools/

echo "Installing Aquatone"
go get github.com/michenriksen/aquatone
echo "done"

echo "Installing Chromium"
sudo snap install chromium
echo "done"

echo "Installing JSParser"
git clone https://github.com/nahamsec/JSParser.git
cd JSParser*
sudo python setup.py install
cd ~/tools/
echo "done"

echo "Installing Sublist3r"
git clone https://github.com/aboul3la/Sublist3r.git
cd Sublist3r*
pip install -r requirements.txt
cd ~/tools/
echo "done"

echo "Installing Dirsearch"
git clone https://github.com/maurosoria/dirsearch.git
cd ~/tools/
echo "done"

echo "Installing massdns"
git clone https://github.com/blechschmidt/massdns.git
cd ~/tools/massdns
make
cd ~/tools/
echo "done"

echo "Installing httprobe"
go get -u github.com/tomnomnom/httprobe 
echo "done"

echo "Installing unfurl"
go get -u github.com/tomnomnom/unfurl 
echo "done"

echo "Installing waybackurls"
go get github.com/tomnomnom/waybackurls
echo "done"


echo -e "\n\n\n\n\n\n\n\n\n\n\nDone! All tools are set up required to run the InfoScout in ~/tools"
ls -la