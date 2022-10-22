
cd $HOME
if [ ! -d vault ]; then
    mkdir vault
fi

if [ ! -f vault/.placeholder ]; then
    echo "Mounting encrypted vault from github"
    sleep 1
    sudo mount -t ecryptfs $HOME/aws-setup/vault $HOME/vault
fi

if [ -f $HOME/vault/vault-setup.sh ]; then
    echo "Running ~/vault/vault-setup.sh"
    sleep 1
    . $HOME/vault/vault-setup.sh
fi

if [ -d $HOME/vault/dot-aws -a ! -a $HOME/.aws ]; then
    echo "Linking .aws to ~/vault/dot-aws"
    sleep 1
    ln -s $HOME/vault/dot-aws $HOME/.aws
fi
