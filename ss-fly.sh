#! /bin/bash
# Copyright (c) 2018 flyzyСվ

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

os='ossystem'
password='flyzy2005.com'
port='1024'
libsodium_file="libsodium-1.0.16"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/1.0.16/libsodium-1.0.16.tar.gz"

fly_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

kernel_ubuntu_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.10.2/linux-image-4.10.2-041002-generic_4.10.2-041002.201703120131_amd64.deb"
kernel_ubuntu_file="linux-image-4.10.2-041002-generic_4.10.2-041002.201703120131_amd64.deb"

usage () {
        cat $fly_dir/sshelp
}

DIR=`pwd`

wrong_para_prompt() {
    echo -e "[${red}����${plain}] �����������!$1"
}

install_ss() {
        if [[ "$#" -lt 1 ]]
        then
          wrong_para_prompt "����������һ��������Ϊ����"
          return 1
        fi
        password=$1
        if [[ "$#" -ge 2 ]]
        then
          port=$2
        fi
        if [[ $port -le 0 || $port -gt 65535 ]]
        then
          wrong_para_prompt "�˿ں������ʽ����������1��65535"
          exit 1
        fi
        check_os
        check_dependency
        download_files
        ps -ef | grep -v grep | grep -i "ssserver" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
                ssserver -c /etc/shadowsocks.json -d stop
        fi
        generate_config $password $port
        if [ ${os} == 'centos' ]
        then
                firewall_set
        fi
        install
        cleanup
}

uninstall_ss() {
        read -p "ȷ��Ҫж��ss��(y/n) :" option
        [ -z ${option} ] && option="n"
        if [ "${option}" == "y" ] || [ "${option}" == "Y" ]
        then
                ps -ef | grep -v grep | grep -i "ssserver" > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        ssserver -c /etc/shadowsocks.json -d stop
                fi
                case $os in
                        'ubuntu'|'debian')
                                update-rc.d -f ss-fly remove
                                ;;
                        'centos')
                                chkconfig --del ss-fly
                                ;;
                esac
                rm -f /etc/shadowsocks.json
                rm -f /var/run/shadowsocks.pid
                rm -f /var/log/shadowsocks.log
                if [ -f /usr/local/shadowsocks_install.log ]; then
                        cat /usr/local/shadowsocks_install.log | xargs rm -rf
                fi
                echo "ssж�سɹ���"
        else
                echo
                echo "ж��ȡ��"
        fi
}

install_bbr() {
	[[ -d "/proc/vz" ]] && echo -e "[${red}����${plain}] ���ϵͳ��OpenVZ�ܹ��ģ���֧�ֿ���BBR��" && exit 1
	check_os
	check_bbr_status
	if [ $? -eq 0 ]
	then
		echo -e "[${green}��ʾ${plain}] TCP BBR�����Ѿ������ɹ���"
		exit 0
	fi
	check_kernel_version
	if [ $? -eq 0 ]
	then
		echo -e "[${green}��ʾ${plain}] ���ϵͳ�汾����4.9��ֱ�ӿ���BBR���١�"
		sysctl_config
		echo -e "[${green}��ʾ${plain}] TCP BBR���ٿ����ɹ�"
		exit 0
	fi

	if [[ x"${os}" == x"centos" ]]; then
        	install_elrepo
        	yum --enablerepo=elrepo-kernel -y install kernel-ml kernel-ml-devel
        	if [ $? -ne 0 ]; then
            		echo -e "[${red}����${plain}] ��װ�ں�ʧ�ܣ������м�顣"
            		exit 1
        	fi
    	elif [[ x"${os}" == x"debian" || x"${os}" == x"ubuntu" ]]; then
        	[[ ! -e "/usr/bin/wget" ]] && apt-get -y update && apt-get -y install wget
        	#get_latest_version
        	#[ $? -ne 0 ] && echo -e "[${red}����${plain}] ��ȡ�����ں˰汾ʧ�ܣ���������" && exit 1
       		 #wget -c -t3 -T60 -O ${deb_kernel_name} ${deb_kernel_url}
        	#if [ $? -ne 0 ]; then
            	#	echo -e "[${red}����${plain}] ����${deb_kernel_name}ʧ�ܣ������м�顣"
            	#	exit 1
       		#fi
        	#dpkg -i ${deb_kernel_name}
        	#rm -fv ${deb_kernel_name}
		wget ${kernel_ubuntu_url}
		if [ $? -ne 0 ]
		then
			echo -e "[${red}����${plain}] �����ں�ʧ�ܣ������м�顣"
			exit 1
		fi
		dpkg -i ${kernel_ubuntu_file}
    	else
       	 	echo -e "[${red}����${plain}] �ű���֧�ָò���ϵͳ�����޸�ϵͳΪCentOS/Debian/Ubuntu��"
        	exit 1
    	fi

    	install_config
    	sysctl_config
    	reboot_os
}

install_ssr() {
        check_os
        case $os in
                'ubuntu'|'debian')
		     apt-get -y update
                     apt-get -y install wget
                     ;;
                'centos')
                     yum install -y wget
                     ;;
        esac
	wget --no-check-certificate https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocksR.sh
	chmod +x shadowsocksR.sh
	./shadowsocksR.sh 2>&1 | tee shadowsocksR.log
}

check_os_() {
        source /etc/os-release
	local os_tmp=$(echo $ID | tr [A-Z] [a-z])
        case $os_tmp in
                ubuntu|debian)
                os='ubuntu'
                ;;
                centos)
                os='centos'
                ;;
                *)
                echo -e "[${red}����${plain}] ���ű���ʱֻ֧��Centos/Ubuntu/Debianϵͳ�������ñ��ű��������޸����ϵͳ����"
                exit 1
                ;;
        esac
}

check_os() {
    if [[ -f /etc/redhat-release ]]; then
        os="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        os="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        os="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        os="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        os="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        os="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        os="centos"
    fi
}

check_bbr_status() {
    local param=$(sysctl net.ipv4.tcp_available_congestion_control | awk '{print $3}')
    if [[ x"${param}" == x"bbr" ]]; then
        return 0
    else
        return 1
    fi
}

version_ge(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

check_kernel_version() {
    local kernel_version=$(uname -r | cut -d- -f1)
    if version_ge ${kernel_version} 4.9; then
        return 0
    else
        return 1
    fi
}

sysctl_config() {
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
}

install_elrepo() {
    if centosversion 5; then
        echo -e "[${red}����${plain}] �ű���֧��CentOS 5��"
        exit 1
    fi

    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org

    if centosversion 6; then
        rpm -Uvh http://www.elrepo.org/elrepo-release-6-8.el6.elrepo.noarch.rpm
    elif centosversion 7; then
        rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
    fi

    if [ ! -f /etc/yum.repos.d/elrepo.repo ]; then
        echo -e "[${red}����${plain}] ��װelrepoʧ�ܣ������м�顣"
        exit 1
    fi
}

get_latest_version() {

    latest_version=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/ | awk -F'\"v' '/v[4-9]./{print $2}' | cut -d/ -f1 | grep -v -  | sort -V | tail -1)

    [ -z ${latest_version} ] && return 1

    if [[ `getconf WORD_BIT` == "32" && `getconf LONG_BIT` == "64" ]]; then
        deb_name=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/amd64.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_name}"
        deb_kernel_name="linux-image-${latest_version}-amd64.deb"
    else
        deb_name=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/i386.deb/{print $2}' | cut -d'<' -f1 | head -1)
        deb_kernel_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_name}"
        deb_kernel_name="linux-image-${latest_version}-i386.deb"
    fi

    [ ! -z ${deb_name} ] && return 0 || return 1
}

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

opsy=$( get_opsy )
arch=$( uname -m )
lbit=$( getconf LONG_BIT )
kern=$( uname -r )

check_dependency() {
        case $os in
                'ubuntu'|'debian')
                apt-get -y update
                apt-get -y install python python-dev python-setuptools openssl libssl-dev curl wget unzip gcc automake autoconf make libtool
                ;;
                'centos')
                yum install -y python python-devel python-setuptools openssl openssl-devel curl wget unzip gcc automake autoconf make libtool
        esac
}

install_config() {
    if [[ x"${os}" == x"centos" ]]; then
        if centosversion 6; then
            if [ ! -f "/boot/grub/grub.conf" ]; then
                echo -e "[${red}����${plain}] û���ҵ�/boot/grub/grub.conf�ļ���"
                exit 1
            fi
            sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
        elif centosversion 7; then
            if [ ! -f "/boot/grub2/grub.cfg" ]; then
                echo -e "[${red}����${plain}] û���ҵ�/boot/grub2/grub.cfg�ļ���"
                exit 1
            fi
            grub2-set-default 0
        fi
    elif [[ x"${os}" == x"debian" || x"${os}" == x"ubuntu" ]]; then
        /usr/sbin/update-grub
    fi
}

reboot_os() {
    echo
    echo -e "[${green}��ʾ${plain}] ϵͳ��Ҫ����BBR������Ч��"
    read -p "�Ƿ��������� [y/n]" is_reboot
    if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
        reboot
    else
        echo -e "[${green}��ʾ${plain}] ȡ��������������ִ��reboot���"
        exit 0
    fi
}

download_files() {
        if ! wget --no-check-certificate -O ${libsodium_file}.tar.gz ${libsodium_url}
        then
                echo -e "[${red}����${plain}] ����${libsodium_file}.tar.gzʧ��!"
                exit 1
        fi
        if ! wget --no-check-certificate -O shadowsocks-master.zip https://github.com/shadowsocks/shadowsocks/archive/master.zip
        then
                echo -e "[${red}����${plain}] shadowsocks��װ���ļ�����ʧ�ܣ�"
                exit 1
        fi
}

generate_config() {
    cat > /etc/shadowsocks.json<<-EOF
{
    "server":"0.0.0.0",
    "server_port":$2,
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"$1",
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open":false
}
EOF
}

firewall_set(){
    echo -e "[${green}��Ϣ${plain}] �������÷���ǽ..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i ${port} > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo -e "[${green}��Ϣ${plain}] port ${port}�Ѿ����š�"
            fi
        else
            echo -e "[${yellow}����${plain}] ����ǽ��iptables�������Ѿ�ֹͣ��û�а�װ��������Ҫ���ֶ��رշ���ǽ��"
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=${port}/tcp
            firewall-cmd --permanent --zone=public --add-port=${port}/udp
            firewall-cmd --reload
        else
            echo -e "[${yellow}����${plain}] ����ǽ��iptables�������Ѿ�ֹͣ��û�а�װ��������Ҫ���ֶ��رշ���ǽ��"
        fi
    fi
    echo -e "[${green}��Ϣ${plain}] ����ǽ���óɹ���"
}

centosversion(){
    if [ ${os} == 'centos' ]
    then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

install() {
        if [ ! -f /usr/lib/libsodium.a ]
        then 
                cd ${DIR}
                tar zxf ${libsodium_file}.tar.gz
                cd ${libsodium_file}
                ./configure --prefix=/usr && make && make install
                if [ $? -ne 0 ] 
                then 
                        echo -e "[${red}����${plain}] libsodium��װʧ��!"
                        cleanup
                exit 1  
                fi
        fi      
        ldconfig

        cd ${DIR}
        unzip -q shadowsocks-master.zip
        if [ $? -ne 0 ]
        then 
                echo -e "[${red}����${plain}] ��ѹ��ʧ�ܣ�����unzip����"
                cleanup
                exit 1
        fi      
        cd ${DIR}/shadowsocks-master
        python setup.py install --record /usr/local/shadowsocks_install.log
        if [ -f /usr/bin/ssserver ] || [ -f /usr/local/bin/ssserver ]
        then 
                cp $fly_dir/ss-fly /etc/init.d/
                chmod +x /etc/init.d/ss-fly
                case $os in
                        'ubuntu'|'debian')
                                update-rc.d ss-fly defaults
                                ;;
                        'centos')
                                chkconfig --add ss-fly
                                chkconfig ss-fly on
                                ;;
                esac            
                ssserver -c /etc/shadowsocks.json -d start
        else    
                echo -e "[${red}����${plain}] ss��������װʧ�ܣ�����ϵflyzyСվ��https://www.flyzy2005.com��"
                cleanup
                exit 1
        fi      
        echo -e "[${green}�ɹ�${plain}] ��װ�ɹ�������ˣ�"
        echo -e "��ķ�������ַ��IP����\033[41;37m $(get_ip) \033[0m"
        echo -e "�������            ��\033[41;37m ${password} \033[0m"
        echo -e "��Ķ˿�            ��\033[41;37m ${port} \033[0m"
        echo -e "��ļ��ܷ�ʽ        ��\033[41;37m aes-256-cfb \033[0m"
        echo -e "��ӭ����flyzyСվ   ��\033[41;37m https://www.flyzy2005.com \033[0m"
        get_ss_link
}

cleanup() {
        cd ${DIR}
        rm -rf shadowsocks-master.zip shadowsocks-master ${libsodium_file}.tar.gz ${libsodium_file}
}

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_ss_link(){
    if [ ! -f "/etc/shadowsocks.json" ]; then
        echo 'shdowsocks�����ļ������ڣ����飨/etc/shadowsocks.json��'
        exit 1
    fi
    local tmp=$(echo -n "`get_config_value method`:`get_config_value password`@`get_ip`:`get_config_value server_port`" | base64 -w0)
    echo -e "���ss���ӣ�\033[41;37m ss://${tmp} \033[0m"
}

get_config_value(){
    cat /etc/shadowsocks.json | grep "\"$1\":"|awk -F ":" '{print $2}'| sed 's/\"//g;s/,//g;s/ //g'
}

if [ "$#" -eq 0 ]; then
	usage
	exit 0
fi

case $1 in
	-h|h|help )
		usage
		exit 0;
		;;
	-v|v|version )
		echo 'ss-fly Version 1.0, 2018-01-20, Copyright (c) 2018 flyzy2005'
		exit 0;
		;;
esac

if [ "$EUID" -ne 0 ]; then
	echo -e "[${red}����${plain}] ������root������У���ʹ��sudo����"
	exit 1;
fi

case $1 in
	-i|i|install )
        	install_ss $2 $3
		;;
        -bbr )
        	install_bbr
                ;;
        -ssr )
        	install_ssr
                ;;
	-uninstall )
		uninstall_ss
		;;
        -sslink )
                get_ss_link
                ;;
	* )
		usage
		;;
esac