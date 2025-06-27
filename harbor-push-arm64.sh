!/bin/bash

#docker load -i rancher-images-arm64.tar.gz

# Harbor配置
HARBOR_URL="192.168.203.25"  # 去掉http://前缀
HARBOR_USER="admin"
HARBOR_PASS="gw1admin"
HARBOR_PROJECT="rancher_arm64"

# 登录Harbor 
echo "Logging in to Harbor..."
docker login $HARBOR_URL -u $HARBOR_USER -p $HARBOR_PASS

# 获取有效镜像列表（排除<none>镜像）
docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | while read -r IMAGE; do
    # 提取镜像名称和标签
    REPO_NAME=$(echo $IMAGE | cut -d':' -f1 | awk -F'/' '{print $NF}')
    TAG=$(echo $IMAGE | cut -d':' -f2)
    
    # 构建Harbor标签
    HARBOR_TAG="$HARBOR_URL/$HARBOR_PROJECT/$REPO_NAME:$TAG"
    
    echo "Processing $IMAGE -> $HARBOR_TAG"
    
    # 标记并推送
    docker tag $IMAGE $HARBOR_TAG && \
    docker push $HARBOR_TAG && \
    docker rmi $HARBOR_TAG $IMAGE || echo "Failed to process $IMAGE"
    
done

# 删除所有本地镜像（包括原始镜像和临时标记的镜像）
echo "Cleaning up local images..."
docker system prune -a -f

echo "Operation completed."
