#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

install_azure() {
    os=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')

    if [ "$os" == "ubuntu" ] || [ "$os" == "debian" ]; then
        sudo apt-get update -y
        sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg jq sshpass screen -y

        if [ ! -d "/etc/apt/keyrings" ]; then
            echo -e "${RED}目录不存在，现在创建${NC}"
            sudo mkdir -p /etc/apt/keyrings
        else
            echo -e "${GREEN}目录已存在${NC}"
        fi
        
        echo -e "${GREEN}下载并安装 Microsoft 签名密钥${NC}"
        curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
        gpg --dearmor |
        sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

        echo -e "${GREEN}添加 Azure CLI 软件存储库${NC}"
        AZ_DIST=$(lsb_release -cs)
        echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_DIST main" |
        sudo tee /etc/apt/sources.list.d/azure-cli.list

        echo -e "${GREEN}更新存储库信息并安装 Azure CLI 包${NC}"
        sudo apt-get update -y
        sudo apt-get install azure-cli -y
    else
        echo -e "${RED}没有适配系统${NC}"
    fi
    menu
}


select_azure_account() {
    echo "可用的Azure账户："
    local i=1
    local accounts=($(ls -d ~/.azure-*))
    for acc in "${accounts[@]}"; do
        echo "$i) ${acc##*/}"
        ((i++))
    done

    read -p "选择账户的序号（如果需要新账户，请输入n）: " input

    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#accounts[@]}" ]; then
        local account_name=${accounts[$input-1]##*/}
        export AZURE_CONFIG_DIR=~/$account_name
        echo -e "${GREEN}已选择账户：$account_name${NC}"
    elif [[ "$input" == "n" ]]; then
        read -p "输入新Azure账户名称： " new_account
        export AZURE_CONFIG_DIR=~/.azure-$new_account
        if [ ! -d "$AZURE_CONFIG_DIR" ]; then
            mkdir -p $AZURE_CONFIG_DIR
            echo -e "${GREEN}为新账户 $new_account 创建配置目录${NC}"
        else
            echo -e "${GREEN}使用现有账户 $new_account 的配置目录${NC}"
        fi
    else
        echo -e "${RED}输入无效，请重新选择${NC}"
        select_azure_account
    fi
}

login() {
    select_azure_account
    if command -v az > /dev/null 2>&1; then
        output=$(az login --use-device-code)
        if echo "$output" | jq -e . > /dev/null 2>&1; then
            echo -e "${GREEN}登录成功${NC}"
        else
            echo -e "${RED}登录失败，请重试${NC}"
        fi
    else
        echo -e "${RED}未安装 Azure CLI 请先安装${NC}"
    fi
    menu
}



change_vm_ip() {
    select_azure_account
    check_azure

    # 列出所有虚拟机
    echo -e "${GREEN}正在列出所有虚拟机...${NC}"
    local vms=($(az vm list --query "[].name" -o tsv))
    
    if [ ${#vms[@]} -eq 0 ]; then
        echo -e "${RED}没有找到虚拟机${NC}"
        menu
        return
    fi

    local i=1
    for vm in "${vms[@]}"; do
        echo "$i) $vm"
        ((i++))
    done

    # 用户选择虚拟机
    read -p "选择要更换 IP 的虚拟机序号: " vm_index
    if [[ "$vm_index" =~ ^[0-9]+$ ]] && [ "$vm_index" -ge 1 ] && [ "$vm_index" -le "${#vms[@]}" ]; then
        local selected_vm=${vms[$vm_index-1]}
        echo -e "${GREEN}你选择了虚拟机：$selected_vm${NC}"

        # 获取虚拟机的网络接口
        local nic=$(az vm show --name $selected_vm --query "networkProfile.networkInterfaces[0].id" -o tsv)

        # 解除现有公共 IP 地址的关联
        echo -e "${GREEN}正在解除现有公共 IP 地址的关联...${NC}"
        az network nic ip-config update --ids $nic --clear-public-ip-address

        # 创建新的公共 IP 地址（动态）
        echo -e "${GREEN}正在创建新的动态公共 IP 地址...${NC}"
        local new_ip_name="${selected_vm}-ip"
        az network public-ip create --name $new_ip_name --allocation-method Dynamic

        # 关联新的公共 IP 地址
        echo -e "${GREEN}正在将新的公共 IP 地址关联到虚拟机...${NC}"
        az network nic ip-config update --ids $nic --public-ip-address $new_ip_name

        echo -e "${GREEN}虚拟机 $selected_vm 的 IP 地址已更新为动态 IP${NC}"
    else
        echo -e "${RED}无效的选择，请重新选择.${NC}"
        change_vm_ip
    fi

    menu
}





list_resource_groups() {
    select_azure_account
    check_azure
    echo -e "${GREEN}正在列出当前账户下的资源组...${NC}"
    az group list --output table
    menu
}

delete_resource_group() {
    select_azure_account
    check_azure

    # 获取当前账户下的所有资源组及其地区
    echo -e "${GREEN}正在获取当前账户下的资源组地区...${NC}"
    local rg_locations=($(az group list --query "[].location" -o tsv | sort -u))
    
    if [ ${#rg_locations[@]} -eq 0 ]; then
        echo -e "${RED}当前账户下没有资源组${NC}"
        menu
        return
    fi

    local i=1
    for loc in "${rg_locations[@]}"; do
        echo "$i) $loc"
        ((i++))
    done

    # 用户选择地区
    read -p "选择要删除的资源组的地区序号: " loc_index
    if [[ "$loc_index" =~ ^[0-9]+$ ]] && [ "$loc_index" -ge 1 ] && [ "$loc_index" -le "${#rg_locations[@]}" ]; then
        local selected_location=${rg_locations[$loc_index-1]}
        echo -e "${GREEN}你选择了地区：$selected_location${NC}"

        # 删除该地区下的所有资源组
        local resource_groups=($(az group list --query "[?location=='$selected_location'].name" -o tsv))
        for rg in "${resource_groups[@]}"; do
            echo -e "${RED}正在删除资源组：$rg...${NC}"
            az group delete --name $rg --yes --no-wait
        done
        echo -e "${GREEN}在 $selected_location 地区的所有资源组已被删除${NC}"
    else
        echo -e "${RED}无效的选择，请重新选择.${NC}"
        delete_resource_group
    fi

    menu
}


uninstall_azure() {
    if command -v az > /dev/null 2>&1; then
        echo -e "${GREEN}正在卸载 Azure CLI${NC}"
        sudo apt-get remove -y azure-cli
        sudo rm /etc/apt/sources.list.d/azure-cli.list
        sudo rm /etc/apt/trusted.gpg.d/microsoft.gpg
        sudo apt autoremove -y
        rm -rf ~/.azure
        echo -e "${GREEN}Azure CLI 卸载完成${NC}"
    else
        echo -e "${RED}未检测到 Azure CLI 无需卸载${NC}"
    fi

    menu
}

check_azure() {
    if ! command -v az &> /dev/null; then
        echo -e "\e[31m错误: Azure CLI 没有安装. 请先安装 Azure CLI.\e[0m"
        exit 1
    fi

    if ! az account show &> /dev/null; then
        echo -e "\e[31m错误: 你还没有登录 Azure. 请先运行 'az login' 来登录你的 Azure 账户.\e[0m"
        exit 1
    fi
}


create_vm() {
    select_azure_account
    LOCATIONS=("westus3" "australiaeast" "uksouth" "southeastasia" "swedencentral" "centralus" "centralindia" "eastasia" "japaneast" "koreacentral" "canadacentral" "francecentral" "germanywestcentral" "italynorth" "norwayeast" "polandcentral" "switzerlandnorth" "brazilsouth" "northcentralus" "westus" "japanwest" "australiacentral" "canadaeast" "ukwest" "southcentralus" "northeurope" "southafricanorth" "australiasoutheast" "southindia" "uaenorth")

    echo "可选的地区："
    select LOCATION in "${LOCATIONS[@]}"; do
        if [[ -n $LOCATION ]]; then
            break
        else
            echo -e "${RED}无效的选择，请重新选择.${NC}"
        fi
    done

    # 直接定义用户名和密码
    USERNAME="azure"
    PASSWORD="hp6#dT0#s4t5t"

    echo -e "${GREEN}用户名: $USERNAME, 密码: $PASSWORD${NC}"

    # 检查资源组是否存在，不存在则创建
    groupInfo=$(az group show --name "$LOCATION" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "\e[33m资源组已存在 $LOCATION\e[0m"
    else
        az group create --name "$LOCATION" --location "$LOCATION"
        if [ $? -eq 0 ]; then
            echo -e "\e[32m资源组创建成功 $LOCATION\e[0m"
        else
            echo -e "\e[31m资源组创建失败 $LOCATION\e[0m"
            exit 1
        fi
    fi

    nohup az vm create --resource-group "$LOCATION" --name "$LOCATION" --location "$LOCATION" --image Debian:debian-10:10:latest --admin-username "$USERNAME" --admin-password "$PASSWORD" --size Standard_B1s --storage-sku Premium_LRS --os-disk-size-gb 64 > /dev/null 2>&1 &
    pid=$!
    echo -e "\e[36m已在后台执行 az vm create 命令\e[0m"

    wait $pid
    if [ $? -eq 0 ]; then
        echo -e "\e[32mVM创建成功 $LOCATION\e[0m"
        sleep 20

        # 添加网络安全组规则允许所有端口流量
        echo -e "${GREEN}添加网络安全组规则...${NC}"
        az network nsg rule create --resource-group "$LOCATION" --nsg-name "$LOCATION"NSG --name "AllowAll" --priority 100 --access Allow --direction Inbound --protocol '*' --source-address-prefix '*' --source-port-range '*' --destination-address-prefix '*' --destination-port-range '*'

        ips=$(az network public-ip list --query "[].ipAddress" -o tsv)
        for ip in $ips; do
        {
            nohup sshpass -p "$PASSWORD" ssh -tt -o StrictHostKeyChecking=no $USERNAME@$ip 'sudo bash -c "curl -s -L https://raw.githubusercontent.com/joker-na/reploy/main/dd.sh | LC_ALL=en_US.UTF-8 bash -s '$WALLERT'"'
            exit_status=$?
            if [ $exit_status -eq 0 ]; then
                echo -e "\e[32m$ip 成功启动\e[0m"
            else
                echo -e "\e[31m$ip 启动失败\e[0m"
            fi
        } &
        done
        wait
    fi
}

menu() {
    echo -e


    echo -e "${GREEN}1. 安装 Azure CLI${NC}"
    echo -e "${GREEN}2. 登录 Azure CLI${NC}"
    echo -e "${GREEN}3. 列出当前账户下的资源组${NC}"
    echo -e "${GREEN}4. 卸载 Azure CLI${NC}"
    echo -e
    echo -e "${GREEN}5. 创建实例${NC}"
    echo -e "${GREEN}6. 删除特定资源组${NC}"
    echo -e "${GREEN}7. 更换实例IP${NC}"
    echo -e "${GREEN}0. 退出${NC}"
    read -p "输入您的选择: " choice

    case $choice in
        1)
            install_azure
            ;;
        2)
            login
            ;;
        
        3)
            list_resource_groups
            ;;
        4)
            uninstall_azure
            ;;
        5)
            check_azure
            create_vm
            ;;
        6)
            delete_resource_group
            ;;
        
        7)
            change_vm_ip
            ;;
        0)
            echo -e "${RED}退出...${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}选择无效${NC}"
            menu
            ;;
    esac
}
menu
