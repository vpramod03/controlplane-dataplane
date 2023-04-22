export node_ip=""
export k3s_url="https://${node_ip}:6443"
export k3s_token="SECRET"
if [[ $is_master eq 1 ]]
then
    echo " Installing K3s Master "
    curl -sfL https://get.k3s.io | sh -s - server --token=$K3S_TOKEN
    echo " K3s Installed "
else 
    echo " Installing k3s Worker "
    curl -sfL https://get.k3s.io | K3S_URL=${k3s_url} K3S_TOKEN=${K3S_TOKEN} sh - 
    echo " K3s Installed "
fi
