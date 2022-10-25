
export PATH=$HOME/bin:$PATH

if [ -d $HOME/.aws-vault/bin -a ! -f $HOME/bin ]; then
    ln -s $HOME/.aws-vault/bin $HOME/bin
fi

cd $HOME
if [ ! -d vault ]; then
    mkdir vault
fi

if [ ! -f vault/.placeholder ]; then
    echo "***** Mounting encrypted vault from github *****"
    sleep 2
    chmod 600 $HOME/.aws-vault/vault/dot-ssh/id_rsa
    sudo mount -t ecryptfs -r $HOME/.aws-vault/vault $HOME/vault

    if [ ! "`cat vault/.placeholder 2>/dev/null`" = "placeholder" ]; then
        echo "vault mount failed."
        sudo umount vault
        return
    fi
fi

if [ -f $HOME/vault/vault-setup.sh ]; then
    echo "Running ~/vault/vault-setup.sh"
    . $HOME/vault/vault-setup.sh
fi

if [ -d $HOME/vault/dot-aws -a ! -a $HOME/.aws ]; then
    echo "Linking .aws to ~/vault/dot-aws"
    ln -s $HOME/vault/dot-aws $HOME/.aws
fi

if [ -f $HOME/vault/dot-ssh/id_rsa -a ! -f $HOME/.ssh/id_rsa ]; then
    echo "Linking ssh private key to ~/.ssh"
    ln -s $HOME/vault/dot-ssh/id_rsa $HOME/.ssh/id_rsa
fi
