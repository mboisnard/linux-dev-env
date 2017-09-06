#!/bin/bash

# Configurations
DOWNLOAD_FOLDER=~/Téléchargements


## Packages Versions
JDK_VERSION=8
JETBRAINS_TOOLBOX_VERSION=1.4.2492
SLACK_VERSION=2.7.1
MYSQWORKBENCH_VERSION=6.3.9-1ubuntu16.04
PHP_VERSION=7.0

## Custom Install
GRADLE_VERSION_URL='http://services.gradle.org/versions/current'
NODE_INSTALL_URL='https://git.io/n-install'

## Mysql
MYSQL_ROOT_PWD='root'

GPG_URL=(
    'https://download.docker.com/linux/ubuntu/gpg'
    'https://repo.skype.com/data/SKYPE-GPG-KEY'
)

GPG_UBUNTU_KEYSERVER=(
    'B05498B7'
    'BA9EF27F'
    '3F055C03' # Grub Customizer
)

REPOSITORIES=(
    'deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable'
    'deb http://repo.steampowered.com/steam/ precise steam'
    'deb [arch=amd64] https://repo.skype.com/deb stable main'
)

UTILS_APT_PACKAGES=(
    'htop'
    'gparted'
    'bleachbit'
    'imagemagick'
    'pdfshuffler'
    'inkscape'
    'grub-customizer'
    'gir1.2-gtop-2.0'
    'steam-launcher'
    'skypeforlinux'
)

WGET_PACKAGES=(
    'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'
    "https://downloads.slack-edge.com/linux_releases/slack-desktop-$SLACK_VERSION-amd64.deb"
    "https://download.jetbrains.com/toolbox/jetbrains-toolbox-$JETBRAINS_TOOLBOX_VERSION.tar.gz"
)

DEV_APT_PACKAGES=(
    'sublime-text'
    'vim'
    'emacs24'
    'g++'
    'gcc-6'
    'g++-6'
    'git'
    'docker-ce'
    'jq'
    #'wireshark'
    'apache2'
    "php$PHP_VERSION"
    "libapache2-mod-php$PHP_VERSION"
    "php$PHP_VERSION-curl"
    'mysql-server'
    "openjdk-$JDK_VERSION-jdk"
    "openjdk-$JDK_VERSION-doc"
)

DEBCONF_SELECTIONS_CONFIG=(
    "mysql-server mysql-server/root_password password $MYSQL_ROOT_PWD"
    "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PWD"
)

_install_gpg_keys() {
    # GPG exists keys : http://stackoverflow.com/questions/29986413/gpg-key-exists-in-the-list
    echo -e "\n[~] Adding GPG Keys\n"
    
    for url in "${GPG_URL[@]}";
    do
        echo "[+] Installing GPG Key from : $url"
        curl -fsSL $url | apt-key add - > /dev/null
    done

    for key in "${GPG_UBUNTU_KEYSERVER[@]}";
    do
        echo "[+] Installing GPG Key from Ubuntu Key Server : $key"
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $key > /dev/null
    done
}

_install_repositories() {
    
    echo -e "\n[~] Adding Repositories\n"

    for repository in "${REPOSITORIES[@]}";
    do
        echo "[+] Adding Deb Repository : $repository"
        echo $repository >> /etc/apt/sources.list
    done

    echo "[+] Update dependencies"
    apt-get update > /dev/null

    echo "[+] Check for upgrade"
    apt-get upgrade -y > /dev/null
}

_install_utils() {
    
    echo -e "\n[~] Install Utils\n"

    for package in "${UTILS_APT_PACKAGES[@]}";
    do
        _install_package $package
    done

    echo -e "\n[~] Download Files"
    for wget_url in "${WGET_PACKAGES[@]}";
    do
        echo "[+] Wget File Url : $wget_url"
        wget -qP $DOWNLOAD_FOLDER $wget_url
    done

    echo -e "\n[~] Install DEB Download Files"
    dpkg -i $DOWNLOAD_FOLDER/*.deb
}

_pre_dev_packages_install() {
    
    echo -e "\n[~] Pre Install Dev Packages Configurations\n"

    for config in "${DEBCONF_SELECTIONS_CONFIG[@]}";
    do
        echo "[+] Adding Configuration : $config"
        debconf-set-selections <<< $config
    done
}

_install_dev_packages() {
    
    echo -e "\n[~] Install Dev Tools\n"

    for package in "${DEV_APT_PACKAGES[@]}";
    do
        _install_package $package
    done
}

_custom_web_configuration() {

    echo -e "\n[~] Custom Web Configuration\n"

    echo -e "[~] Enable Apache2 Modules\n"
    a2enmod rewrite > /dev/null

    echo -e "[~] Display PHP Errors\n"
    sed -i 's/display_errors = Off/display_errors = On/g' /etc/php/7.0/apache2/php.ini

    echo -e "[~] Disable Apache2 & MySQL AutoStart\n"
    update-rc.d apache2 disable > /dev/null
    update-rc.d mysql disable > /dev/null

    echo -e "[~] Install NodeJS Latest Version\n"
    curl -L $NODE_INSTALL_URL | N_PREFIX=/opt/n bash -s -- -y > /dev/null
    ln -s /opt/n/bin/node /usr/bin/node
    ln -s /opt/n/bin/npm /usr/bin/npm

    npm install -g @angular/cli
}

_custom_java_configuration() {
    
    echo -e "\n[~] Custom Java Configuration\n"

    echo -e "[~] Download Gradle Latest Version\n"
    GRADLE_DL_URL=$(curl -s $GRADLE_VERSION_URL | jq .downloadUrl | tr -d '"')
    wget -q -O $DOWNLOAD_FOLDER/gradle.zip $GRADLE_DL_URL
    
    echo -e "[~] Install Gradle in /opt/gradle\n"
    unzip $DOWNLOAD_FOLDER/gradle.zip -d /opt
    mv /opt/gradle* /opt/gradle
    
    # Path Variable
    echo "export GRADLE_HOME=\"/opt/gradle\"" >> ~/.bashrc
    echo 'export PATH=$GRADLE_HOME/bin:$PATH' >> ~/.bashrc

    # Intellij
    echo -e "[~] Install Jetbrains ToolBox in /opt/jetbrains-toolbox\n"
    tar xzvf $DOWNLOAD_FOLDER/jetbrains-toolbox-$JETBRAINS_TOOLBOX_VERSION.tar.gz -C /opt
    mv /opt/jetbrains-toolbox* /opt/jetbrains-toolbox
}

_install_package() {
    
    pkg_install=$(dpkg --get-selections | grep -v deinstall | grep -P "^$1\t")
    
    if [ -z "$pkg_install" ]; then
        echo "[+] Install Package : $1"
        apt-get -y install $1 > /dev/null
    fi
}

# _remove_packages() {
#     for i in `seq 1 ${#services_running[@]}`;
#     do
#         echo "[~] Removing package : ${packages[$i-1]}"
#         apt-get -y autoremove $1 > /dev/null 2> /dev/null
#     done
# }

_install_all() {

    _install_gpg_keys
    _install_repositories

    _install_utils

    _pre_dev_packages_install
    _install_dev_packages

    _custom_web_configuration
    _custom_java_configuration
}

_help() {
    echo "Options :"
    echo "-i / --install : Install All (Utils and Development Tools)"
    echo "-u / --uninstall : Uninstall (Utils, Development Tools, GPG Keys)"
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 254
fi

OPTS=$(getopt -o i,u,h -l install,uninstall,help -- "$@" )

if [ $? != 0 ]
then
    exit 1
fi
 
eval set -- "$OPTS"
 
while true ; do
    case "$1" in
    -h|--help) _help
        shift;;
    -i|--install) _install_all
        shift;;
    # -u|--uninstall) _remove_packages
    #     shift;;
    --) shift; break;;
    *) echo "Internal error !"; exit 1;;
    esac
done

exit 0