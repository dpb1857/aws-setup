#!/bin/bash
#

# Let's use a git command that doesn't do host key checking to remove the user prompt
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

##################################################
# Base packages, dev user setup
##################################################

function init() {
    apt-get update
    apt-get upgrade -y
    apt-get install -y make mg postgresql-client jq nfs-common awscli
    apt-get install -y ecryptfs-utils

    # Set the locale
    sudo update-locale LANG=en_US.UTF-8

    # Setup packages so pyenv can build python
    apt-get install -y gcc
    apt-get install -y libbz2-dev zlib1g-dev liblzma-dev
    apt-get install -y libsqlite3-dev libgdbm-dev
    apt-get install -y libncurses-dev libreadline-dev uuid-dev libffi-dev libssl-dev
}

function add-user() {
    USER=$1
    if [ -z "${USER}" ]; then
        echo "username unspecified."
        help
        exit 1
    fi
    sudo adduser ${USER}
    sudo adduser ${USER} sudo
    sudo bash -c "echo \"${USER} ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers.d/90-cloud-init-users"

    sudo bash -c "echo \"${USER} ALL=(root) NOPASSWD: /bin/mount *\" > /etc/sudoers.d/mount"
    sudo bash -c "echo \"${USER} ALL=(root) NOPASSWD: /bin/umount *\" >> /etc/sudoers.d/mount"

    sudo addgroup docker
    echo "configure user"
    set -x
    sudo adduser ${USER} docker
    sudo rsync -a /home/ubuntu/ /home/${USER}
    sudo chown -R ${USER}:${USER} /home/${USER}

    sudo rsync -a /usr/local/aws-setup /home/${USER}
    sudo chown -R ${USER}:${USER} /home/${USER}/aws-setup
    sudo -u ${USER} bash -c "(cd /home/${USER}/aws-setup && sudo -u ${USER} git checkout -b ${USER} origin/${USER})"

    sudo bash -c "echo '. /usr/local/aws-setup/shell/hook.sh' >> /home/${USER}/.bashrc"
    set +x
}

##################################################
# Desktop setup
##################################################

function setup_desktop() {
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cinnamon # cinnamon-desktop-environment
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fonts-dejavu-core # don uses in emacs

    # Disable lightdm, install nx (from nomachine)
    sudo systemctl stop lightdm
    sudo systemctl disable lightdm
    file=nomachine_8.1.2_1_amd64.deb
    (cd /tmp && wget https://download.nomachine.com/download/8.1/Linux/$file)
    sudo dpkg -i /tmp/$file

    # Install Chrome
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install google-chrome-stable

    echo "*** Need to reboot to enable remote desktop login with nx ***"
    read -p "Reboot now? (Y/n) " response
    if [ -z "$response" -o "$response" = "Y" ]; then
        echo "rebooting now"
        sudo reboot
    fi
}

##################################################
# Docker setup
##################################################

function setup_docker() {
    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        echo "Docker already installed"
        return
    fi
    # from https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
    # Add official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    # Setup repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    # Update and install
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

##################################################
# Pyenv for user
##################################################

function setup_pyenv() {
    if [ -d ~/.pyenv ]; then
        echo "pyenv already installed"
        return
    fi

    # install pyenv
    git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc
    (cd ~/.pyenv && src/configure && make -C src)

    # install versions 3.6.8, 3.10.7
    # pyenv install 3.6.8 # 3.6.8 pyenv install fails!
    export PATH="$HOME/.pyenv/bin:$PATH"
    pyenv install 3.10.7
}

##################################################
# Barb builds
##################################################

function barb_checkout() {
    if [ -d code/barb ]; then
        echo "barb already checked out"
        exit 1
    fi
    git clone git@github.com:Synthego/barb.git code/barb
}

function barb_local() {
    if [ "$GEMFURY_USERNAME" = "" ]; then
      echo "must have GEMFURY_USERNAME set"
      exit 1
    fi
    if ! command -v pyenv >/dev/null; then
       echo "pyenv not found; re-source .bashrc?"
       exit 1
    fi

    barb_checkout
    (cd $HOME/code/barb && pyenv local 3.10.7)
    (cd $HOME/code/barb && python -m venv venv)
    (cd $HOME/code/barb && venv/bin/pip install --upgrade pip)
    (cd $HOME/code/barb && venv/bin/pip install wheel)

    # Support for modules in python requirements
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y libcurl4-openssl-dev libldap-dev libsasl2-dev

    (cd $HOME/code/barb && venv/bin/pip install -r requirements.txt)
}

function barb_docker() {
    if [ "$GEMFURY_USERNAME" = "" ]; then
      echo "must have GEMFURY_USERNAME set"
      exit 1
    fi

    barb_checkout
    (cd $HOME/code/barb && make build)
    (cd $HOME/code/barb && make dbsync)
}

##################################################
# QCDucks local setup
##################################################

function qcducks_local() {
    if [ "$GEMFURY_USERNAME" = "" ]; then
      echo "must have GEMFURY_USERNAME set"
      exit 1
    fi
    if ! command -v pyenv >/dev/null; then
       echo "pyenv not found; re-source .bashrc?"
       exit 1
    fi

    git clone git@github.com:Synthego/qcducks.git code/qcducks
    (cd code/qcducks && git checkout -b requirements origin/don-update-requirements)
    (cd $HOME/code/qcducks && pyenv local 3.10.7)
    (cd $HOME/code/qcducks && python -m venv venv)
    (cd $HOME/code/qcducks && venv/bin/pip install --upgrade pip)
    (cd $HOME/code/qcducks && venv/bin/pip install wheel)

    # Support for modules in python requirements
    # sudo apt-get install libcurl4-openssl-dev libldap-dev libsasl2-dev
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pkgconf libpq-dev libcurl4-openssl-dev

    (cd $HOME/code/qcducks && venv/bin/pip install -r requirements.txt)
}

##################################################
# Special: don customizations
##################################################

function setup_dpb() {
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y httpie

    cd $HOME
    git clone git@github.com:dpb1857/synced
    if [ $? -ne 0 ]; then
      echo "You probably forgot to do 'ssh -A'"
      exit 1
    fi

    ./synced/setup/02-LinkDotFilesSynth.sh
    git config --global user.email "don.bennett@synhtego.com"
    git config --global user.name "Don Bennett"

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y emacs
}

function setup_dpb_all() {
    (setup_dpb)
    (setup_pyenv)
    . ~/.bashrc
    (barb_local)
    (qcducks_local)
    (setup_desktop)
}


function help() {
    echo "Subcommands:"
    echo "  add-user <username>"
    echo "  docker"
    echo "  desktop"
    echo "  barb_docker"
    echo "  pyenv"
    echo "  barb_local"
    echo "  qcducks_local"
    echo "  dpb"
    echo "  dpb-all"
}

command=$1
shift
case $command in
    init) init
        ;;
    add-user)
        user=$1
        add-user $user
        ;;
    docker) setup_docker
        ;;
    desktop) setup_desktop
        ;;
    pyenv) setup_pyenv
        ;;
    dpb) setup_dpb
        ;;
    dpb-all) setup_dpb_all
        ;;
    barb_local) barb_local
        ;;
    barb_docker) barb_docker
        ;;
    qcducks_local) qcducks_local
        ;;
    *) help
        ;;
esac
