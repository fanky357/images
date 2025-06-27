#!/bin/bash
list="rancher-images.txt"
images="rancher-images.tar.gz"
source_registry=""
platform="linux/amd64"

usage () {
    echo "USAGE: $0 [--image-list rancher-images.txt] [--images rancher-images.tar.gz]"
    echo "  [-s|--source-registry] source registry (e.g., registry.cn-hangzhou.aliyuncs.com)"
    echo "  [-l|--image-list path] image list file, one image per line"
    echo "  [-i|--images path] path to save image tar.gz"
    echo "  [-p|--platform] image platform, e.g., linux/arm64 or linux/amd64"
    echo "  [-h|--help] Show help message"
}

# 参数解析
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--images)
        images="$2"
        shift; shift
        ;;
        -l|--image-list)
        list="$2"
        shift; shift
        ;;
        -s|--source-registry)
        source_registry="$2"
        shift; shift
        ;;
        -p|--platform)
        platform="$2"
        shift; shift
        ;;
        -h|--help)
        usage; exit 0
        ;;
        *)
        usage; exit 1
        ;;
    esac
done

# registry 处理
source_registry="${source_registry%/}"
if [ -n "$source_registry" ]; then
    source_registry="${source_registry}/"
fi

# 确保 buildx builder 存在
docker buildx create --name multiarch --use >/dev/null 2>&1 || docker buildx use multiarch

# 镜像拉取
pulled=()
failed=()
while IFS= read -r i; do
    [ -z "$i" ] && continue
    image="${source_registry}${i}"

    echo "Pulling image: $image for platform: $platform"
    if docker buildx imagetools inspect "$image" --format '{{json .}}' >/dev/null 2>&1; then
        if docker pull --platform "$platform" "$image"; then
            pulled+=("$image")
        else
            echo "Pull failed: $image"
            failed+=("$image")
        fi
    else
        echo "Image not found or failed: $image"
        failed+=("$image")
    fi
done < "$list"

# 保存镜像
echo "Saving ${#pulled[@]} images to ${images}"
#docker save "${pulled[@]}" | gzip > "$images"

# 保存镜像
if [ ${#pulled[@]} -gt 0 ]; then
    echo "Saving ${#pulled[@]} images to ${images}"
    docker save "${pulled[@]}" | gzip > "$images"
else
    echo "No images pulled successfully, nothing to save."
fi

# 输出失败镜像
if [ ${#failed[@]} -gt 0 ]; then
    echo ""
    echo "The following ${#failed[@]} images failed to pull:"
    for f in "${failed[@]}"; do
        echo "  $f"
    done
fi
