#!/bin/bash

function remote() {
    user=$1
    cmd=$2
    msg=$3

    echo ${msg}
    ssh -t ${user}@${ip} ./${scriptname} $cmd
}

function machine_config() {
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get install -y make mg postgresql-client jq nfs-common awscli

    # Set the locale
    sudo update-locale LANG=en_US.UTF-8

    # Install vault
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install vault
}

function add_user() {
    USER=$1
    if [ -z "${USER}" ]; then
        echo "username unspecified."
        exit 1
    fi
    echo "Creating user..."
    sudo adduser ${USER}
    echo "Adding user to sudo group..."
    sudo adduser ${USER} sudo
    sudo bash -c "echo \"${USER} ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers.d/90-cloud-init-users"

    # Just in case we decide to use docker...
    echo "Adding user to docker group..."
    sudo addgroup docker
    sudo adduser ${USER} docker

    # Copy the ubuntu user pub key into our new user
    echo "Copy ubuntu authorized keys to ${USER}..."
    sudo mkdir /home/${USER}/.ssh
    sudo rsync -a /home/ubuntu/.ssh/authorized_keys /home/${USER}/.ssh
    sudo chown -R ${USER}:${USER} /home/${USER}/.ssh
}

function setup_user() {
    # Logged in as the user, complete setup

    # Add startup hook into .bashrc
    # sudo bash -c "echo '. /usr/local/aws-setup/shell/hook.sh' >> /home/${USER}/.bashrc"

    # Configure global gitignore
    echo "Configure global gitignore for user..."
    mkdir -p ~/.config/git
    curl -s \
      https://raw.githubusercontent.com/github/gitignore/master/{Global/JetBrains,Global/Vim,Global/VisualStudioCode,Global/macOS,Python,Terraform}.gitignore \
      > ~/.config/git/ignore
}

function clone_jormungand() {
    echo "Clone jormungand"
    # Checkout & configure jormungand
    # See https://synthego.atlassian.net/wiki/spaces/CS/pages/721617002/Coding+environment+setup#Vault

    if [ ! -d $HOME/code/jormungand ]; then
        echo "Downloading jormungand"
        mkdir -p $HOME/code  # Or create a symlink to your favorite alternative location
        export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
        git clone git@github.com:Synthego/ansible-common.git $HOME/code/jormungand  # Rename in progress

        # run_commands_file="$HOME/.$(basename $(ps -p $$ -oargs= | sed s/-//))rc"
        run_commands_file=.bashrc
        echo >> $run_commands_file
        echo '. ~/code/jormungand/shell_includes.sh' >> $run_commands_file

        # Load them here the first time
        . ~/code/jormungand/shell_includes.sh
    fi
}

function source_awsdev_config() {
    if [ -f $HOME/.awsdev_config ]; then
        . $HOME/.awsdev_config
    fi
}

function save_awsdev_config() {
    echo "ip=\"${ip}\"" > $HOME/.awsdev_config
    echo "username=\"${username}\"" >> $HOME/.awsdev_config
    echo "sshkeys=\"${sshkeys}\"" >> $HOME/.awsdev_config
}

function get_ip() {
    read -p "IP address of remote host? (${ip}) " new_ip
    if [ ! -z ${new_ip} ]; then
        ip=${new_ip}
    fi

    echo "checking for ssh listener at ${ip}..."
    if command -v nc >/dev/null && ! nc ${ip} 22 -z -w 2; then
        echo "No ssh listener at ip address ${ip}" 1>&2
        exit 1
    fi

    echo "checking our ssh login at ${ip}..."
    homedir=$(ssh $ip -l ubuntu pwd)
    if [ $? -ne 0 -o "${homedir}" != "/home/ubuntu" ]; then
        echo "could not connect to remote host at ${ip}" 1>&2
        exit 1
    fi

    save_awsdev_config
}

function get_username() {
    username=`whoami`
    read -p "our username on the remote host? (${username}) " new_username
    if [ ! -z ${new_username} ]; then
        username=${new_username}
    fi
}

function get_sshkeys_dir() {
    if [ -z "$sshkeys" ]; then
        sshkeys="$HOME/.ssh"
    fi
    read -p "dirname with id_rsa, id_rsa.pub to push to remote host? (${sshkeys}) " new_sshkeys
    if [ ! -z ${new_sshkeys} ]; then
        sshkeys=${new_sshkeys}
    fi

    if [ ! -d ${sshkeys} -o ! -f ${sshkeys}/id_rsa ]; then
        echo "sshkeys not found" 1>&2
        exit 2
    fi
}

function confirm() {
    echo "Creating user on remote host"
    echo "Host: ${ip}"
    echo "Username: ${username}"
    echo "ssh keys copied from ${sshkeys}"
    read -p "Continue? (Y/n) " confirm
    if [ "$confirm" = "n" -o "$confirm" = "no" ]; then
        exit 3
    fi
}

function main() {
    source_awsdev_config
    get_ip
    get_username
    get_sshkeys_dir
    save_awsdev_config
    confirm

    scriptname=$(basename ${scriptpath})

    echo "Upload setup script & settings to remote"
    rsync -a ${scriptpath} ~/.awsdev_config ubuntu@${ip}:~

    remote ubuntu machine_config "*** Running machine_config on remote host:"
    remote ubuntu add_user "*** Running adduser on remote host:"
    echo "Pushing credentials & setup script to remote user:"
    set -x
    rsync -a $HOME/.aws/ ${username}@${ip}:~/.aws
    rsync -a ${sshkeys}/ ${username}@${ip}:~/.ssh
    rsync -a ${scriptpath} ${username}@${ip}:~
    set +x

    remote ${username} setup_user "*** Run setup user command:"
    remote ${username} clone_jormungand "*** Cloning jormungand on remote host:"

    return
}

scriptpath=$(readlink -f -- "$0")

if [ $# -eq 0 ]; then
    main
    exit 0
fi

case $1 in
    machine_config)
        machine_config
        ;;
    add_user)
        source_awsdev_config
        add_user ${username}
        setup_user
        ;;
    setup_user)
        setup_user
        ;;
    clone_jormungand)
        clone_jormungand
        ;;
    *)
        echo "Unknown subcommand: $1"
        ;;
esac
