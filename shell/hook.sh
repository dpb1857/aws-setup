
cd $HOME
if [ ! -d vault ]; then
    mkdir vault
fi
if [ ! -f vault/.placeholder ]; then
    echo "Mounting encrypted vault from github"
    sleep 1
    sudo mount -t ecryptfs $HOME/aws-setup/vault $HOME/vault
fi
