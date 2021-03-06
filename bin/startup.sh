# 安装net-tools
sudo apt install net-tools &

# 启动rabbitmq及添加rabbitmq环境变量
sudo service rabbitmq-server start
if [ $? != 0 ]; then
  echo "Error: failed to startup rabbitmq"
  exit 1
fi
# 启动ES
sudo systemctl start elasticsearch.service
# 创建metadata索引和映射
curl -XPUT localhost:9200/metadata -H 'Content-Type:application/json' -d '{
  "mappings": {
    "properties": {
      "name": {"type": "keyword"},
      "version": {"type": "integer"},
      "size": {"type": "integer"},
      "hash": {"type": "keyword"}
    }
  }
}'
echo ""
echo "INFO: finish start elasticsearch && create index 'metadata' and mappings"

export RABBITMQ_SERVER=amqp://test:test@localhost:5672
echo "INFO: finish startup RabbitMQ & set RABBITMQ_SERVER environment"
export ES_SERVER=localhost:9200

# -----------START: 网络配置，需根据自己的机器自行修改-----------
port=12345  # 服务端口号
netCard=wlp2s0  # 网卡名
netID=192.168.0  # 网络标识，指的是某一个物理网络的网络标识，所有连接在该网络中的主机共用相同的网络标识
hostID=101  # 主机标识，指的是为连接在某一个物理网络上的主机分配的用于区分其他主机的标识
gateway=24  # 网关
# -----------END: 网络配置，需根据自己的机器自行修改-----------

# 各节点存储数据的公共路径
commonStoragePath=/home/${USER}/storage-system/storage/

# REST接口服务层与数据服务层的启动路径
apiServerStartupPath=../api_server/api_server.go
dataServerStartupPath=../data_server/data_server.go

# 每一个服务节点分配不同的IP(虚拟网卡IP)
apiServerNodeAmount=2  # 接口服务层节点数
dataServerNodeAmount=6  # 数据服务层节点数
serverNodeAmount=$((${apiServerNodeAmount} + ${dataServerNodeAmount}))  # 服务节点总数

# IP:PORT信息存储
ipAddrFilePath=.ipAddrs
# 删除缓存IP:PORT信息的文件
if [ -e ${ipAddrFilePath} ]; then
  rm ${ipAddrFilePath}
fi

# 启动各个服务节点
for i in `seq 1 ${serverNodeAmount}` ; do
  hostID=$((${hostID} + 1))
  newIP="${netID}.${hostID}"
  newListenAddr="${newIP}:${port}"

  # 根据拼接的新IP配置新的虚拟网卡
  sudo ifconfig ${netCard}:${i} ${newIP}/${gateway}

  # 启动数据服务节点
  if [ ${i} -le ${dataServerNodeAmount} ]; then
    nodeStorageRoot="${commonStoragePath}dataNode${i}"
    # 创建存储对象的objects文件夹
    mkdir -p ${nodeStorageRoot}/objects
    # 创建对象数据临时缓存区temp
    mkdir -p ${nodeStorageRoot}/temp
    # 启动数据服务器
    go run ${dataServerStartupPath} -storageRoot "${nodeStorageRoot}" -listenAddr "${newListenAddr}" &
    echo "INFO: new dataServer started. storageRoot=${nodeStorageRoot}, listenAddr=${newListenAddr}"
  # 启动接口服务
  else
    go run ${apiServerStartupPath} -listenAddr "${newListenAddr}" &
    echo "INFO: new apiServer started. listenAddr=${newListenAddr}"
  fi

  # 存储每个服务节点的IP:PORT信息
  echo ${newListenAddr} >> ${ipAddrFilePath}
done;

chmod +x ./client.sh
echo ""
echo "---------------------------------------operation manual---------------------------------------"
echo 'PUT:'
echo '    ./client.sh put objectName -content "objectContent..."'
echo '    ./client.sh put objectName -path object-file-path'
echo "GET: ./client.sh get objectName"
echo "DELETE: ./client.sh delete objectName"
echo "---------------------------------------operation manual---------------------------------------"
echo ""
