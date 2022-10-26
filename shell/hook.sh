
export PATH=$HOME/bin:$PATH

if [ -d $HOME/.aws-private/bin -a ! -a $HOME/bin ]; then
    ln -s $HOME/.aws-private/bin $HOME/bin
fi

cd $HOME
if [ ! -d private ]; then
    mkdir private
fi

if [ ! -f private/.placeholder ]; then
    echo "***** Mounting encrypted private direcotory from github *****"
    sleep 2
    chmod 600 $HOME/.aws-private/private/dot-ssh/id_rsa
    sudo mount -t ecryptfs -r $HOME/.aws-private/private $HOME/private

    if [ ! "`cat private/.placeholder 2>/dev/null`" = "placeholder" ]; then
        echo "private mount failed."
        sudo umount private
        return
    fi
fi

if [ -f $HOME/private/private-setup.sh ]; then
    echo "Running ~/private/private-setup.sh"
    . $HOME/private/private-setup.sh
fi

if [ -d $HOME/private/dot-aws -a ! -a $HOME/.aws ]; then
    echo "Linking .aws to ~/private/dot-aws"
    ln -s $HOME/private/dot-aws $HOME/.aws
fi

if [ -f $HOME/private/dot-ssh/id_rsa -a ! -f $HOME/.ssh/id_rsa ]; then
    echo "Linking ssh private key to ~/.ssh"
    ln -s $HOME/private/dot-ssh/id_rsa $HOME/.ssh/id_rsa
fi
