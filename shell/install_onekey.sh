#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS")
PACKAGE_UPDATE=("apt-get -y update" "apt-get -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "注意：請在root用户下執行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" 
    if [[ -n $SYS ]]; then
        break
    fi
done

back2menu() {
    echo ""
    green "所選命令操作執行完成"
    read -rp "請輸入“y”退出，或按任意鍵回到主菜單：" back2menuInput
    case "$back2menuInput" in
        y) exit 1 ;;
        *) menu ;;
    esac
}

install_docker_compose(){
    sudo apt-get install \
     ca-certificates \
     curl \
     gnupg \
     lsb-release -y

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
       "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
       $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install docker-ce docker-ce-cli containerd.io -y

    VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d') &&
    DESTINATION=/usr/local/bin/docker-compose &&

    sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION &&
    sudo chmod 755 $DESTINATION
    back2menu
}

install_compose(){
    sudo apt-get remove docker-compose-plugin -y &&

    VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d') &&
    DESTINATION=/usr/local/bin/docker-compose &&

    sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION &&
    sudo chmod 755 $DESTINATION
    back2menu
}

k8s_ipv4_setup(){
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter

    # 设置所需的 sysctl 参数，参数在重新启动后保持不变
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
EOF

    # 应用 sysctl 参数而不重新启动
    sudo sysctl --system
    back2menu
}

k8s_install_crio(){
    #注意os版本
    OS=Debian_11
    #注意CRIO版本
    CRIO_VERSION=1.26.1

    sudo apt install gnupg2 gnupg gnupg1 -y 

    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
    echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.26:/$CRIO_VERSION/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list

    curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/Release.key | sudo apt-key add -
    curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key add -

    sudo apt update
    sudo apt install cri-o cri-o-runc -y

    sudo systemctl start crio && sudo systemctl enable crio -y
    back2menu
}

k8s_install_node(){
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl

    mkdir -p /etc/apt/keyrings
    sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    sudo systemctl start kubelet
    sudo systemctl enable kubelet
    back2menu
}

k8s_install_helm(){
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm -y
    back2menu
}

install_autojump(){
    sudo apt-get update
    sudo apt-get install autojump -y
    echo '. /usr/share/autojump/autojump.sh' >> ~/.bashrc && source ~/.bashrc
    back2menu
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#                   ${RED}one key 一鍵安裝工具腳本${PLAIN}                #"
    echo -e "# ${GREEN}作者${PLAIN}: Frank.ku                                            #"
    echo "#############################################################"
    echo ""
    echo " -----------🚀 Docker相關 🚀----------"
    echo -e " ${GREEN}1.${PLAIN} 安装 Docker & Compose"
    echo -e " ${GREEN}2.${PLAIN} 移除docker預設Compose & 安裝新版V2 Compose"
    echo " -----------🔗 Kubernetes相關 🔗--------"
    echo -e " ${GREEN}3.${PLAIN} 設定kubernetes ipv4 ${PLAIN}"
    echo -e " ${GREEN}4.${PLAIN} 安裝CRI-O ${YELLOW}(Master & Node都需要)${PLAIN}"
    echo -e " ${GREEN}5.${PLAIN} 安裝kubernetes工具 ${YELLOW}(Master & Node都需要)${PLAIN} ${GREEN}(kubeadm,kubectl)${PLAIN}"
    echo -e " ${GREEN}6.${PLAIN} 安裝kubernetes包管理工具${YELLOW}(helm)${PLAIN}"
    echo " ------------👍 其他實用 👍-----------"
    echo -e " ${GREEN}7.${PLAIN} 安裝AutoJump並啟用${YELLOW}shell(bash)${PLAIN}"
    #echo -e " ${GREEN}8.${PLAIN} 手动续期已申请的证书"
    #echo -e " ${GREEN}9.${PLAIN} 切换证书颁发机构"
    #echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp "請輸入選項 [0-9]:" NumberInput
    case "$NumberInput" in
        1) install_docker_compose ;;
        2) install_compose ;;
        3) k8s_ipv4_setup ;;
        4) k8s_install_crio ;;
        5) k8s_install_node ;;
        6) k8s_install_helm ;;
        7) install_autojump ;;
        #8) renew_cert ;;
        #9) switch_provider ;;
        *) exit 1 ;;
    esac
}

menu