#! /bin/sh

# Install simple-obfs plugin for shadowsocks-libev for CentOS 6 or 7
# Please install https://github.com/teddysun/shadowsocks_install/raw/master/shadowsocks-libev.sh first

red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!" && exit 1

cur_dir=$( pwd )

simple_obfs_url="https://github.com/shadowsocks/simple-obfs.git"

getversion() {
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

centosversion() {
    local code=$1
    local version="$(getversion)"
    local main_ver=${version%%.*}
    if [ "$main_ver" == "$code" ]; then
        return 0
    else
        return 1
    fi
}

error_detect_depends(){
    local command=$1
    local depend=`echo "${command}" | awk '{print $4}'`
    ${command}
    if [ $? != 0 ]; then
        echo -e "${red}Error:${plain} Failed to install ${red}${depend}${plain}"
        exit 1
    fi
}

get_obfs_ver(){
    obfs_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/simple-obfs/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z ${obfs_ver} ] && echo "${red}Error:${plain} Get simple-obfs latest version failed" && exit 1
}

download_files() {
    get_obfs_ver
    simple_obfs_file="simple-obfs-$(echo ${obfs_ver} | sed -e 's/^[a-zA-Z]//g')"

    git clone --depth 1 --branch ${obfs_ver} ${simple_obfs_url} ${simple_obfs_file}
    cd ${simple_obfs_file}
    git submodule update --init --recursive
    if centosversion 6; then
        sed -i "s/autoreconf /autoreconf268 /g" autogen.sh
    fi
}

install_dependencies() {
    depends=(git)
    if centosversion 6; then
        depends+=(autoconf268)
    fi
    for depend in ${depends[@]}; do
        error_detect_depends "yum -y install ${depend}"
    done
}

install_simple_obfs() {
    cd ${cur_dir}/${simple_obfs_file}
    ./autogen.sh && CFLAGS="-I/usr/include/libev/" ./configure && make && make install
    if [ ! $? -eq 0 ]; then
        echo
        echo -e "${red}Error:${plain} ${simple_obfs_file} install failed."
        install_cleanup
        exit 1
    fi
}

install_cleanup() {
    cd ${cur_dir}
    rm -rf ${simple_obfs_file}
}

install_main() {
    download_files
    install_dependencies
    install_simple_obfs
    install_cleanup
}

uninstall_simple_obfs() {
    printf "Are you sure uninstall ${red}${simple_obfs_file}${plain}? [y/n]\n"
    read -p "(default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        rm -f /usr/local/bin/obfs-local
        rm -f /usr/local/bin/obfs-server
        rm -f /usr/local/share/man/man1/obfs-local.1
        rm -f /usr/local/share/man/man1/obfs-server.1
        rm -rf /usr/local/share/doc/simple-obfs
        echo -e "${green}Info:${plain} ${simple_obfs_file} uninstall success"
    else
        echo
        echo -e "${green}Info:${plain} ${simple_obfs_file} uninstall cancelled, nothing to do..."
        echo
    fi
}

uninstall_main() {
    uninstall_simple_obfs
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall)
        ${action}_main
        ;;
    *)
        echo "Arguments error! [${action}]"
        echo "Usage: `basename $0` [install|uninstall]"
        ;;
esac