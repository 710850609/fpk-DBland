build_version="001"

declare -A PARAMS

# 默认值
PARAMS[build_all]="false"
PARAMS[build_pre]="false"
PARAMS[arch]="amd64"
PARAMS[download_proxy_url]="https://gh.llkk.cc"

# 解析 key=value 格式的参数
for arg in "$@"; do
  if [[ "$arg" == *=* ]]; then
    key="${arg%%=*}"
    value="${arg#*=}"
    PARAMS["$key"]="$value"
  else
    # 处理标志参数
    case "$arg" in
      --pre)
        PARAMS[pre]="true"
        ;;
      *)
        echo "忽略未知参数: $arg"
        ;;
    esac
  fi
done

bin_file="DBland/app/bin/dbland"
build_all="${PARAMS[build_all]}"
build_pre="${PARAMS[build_pre]}"
download_proxy_url="${PARAMS[download_proxy_url]}"
arch="${PARAMS[arch]}"
echo "build_all: ${build_all}"
echo "arch: ${arch}"
echo "download_proxy_url: ${download_proxy_url}"
echo "pre: ${build_pre}"

# platform 取值 x86, arm, risc-v, all
platform="unknown"
dbland_arch="unknown"
os_min_version="1.0.0"
if [ "${arch}" == "amd64" ]; then
    platform="x86"
    os_min_version="1.1.8"
    dbland_arch="linux-amd64"
elif [ "${arch}" == "aarch64" ]; then
    platform="arm"
    os_min_version="1.0.2"
    dbland_arch="linux-arm64"
else
    echo "未知的 arch 参数: ${arch}"
    exit 1
fi
echo "设置 platform 为: ${platform}"

get_last_dbland_version(){
    # GitHub API URL
    api_url="https://api.github.com/repos/m9d2/dbland/releases/latest"
    # 使用 curl 获取 JSON 数据
    json_data=$(curl -s "$api_url")
    # 使用 grep 和 sed 提取版本号
    latest_version=$(echo "$json_data" | grep -oP '"tag_name": "\Kv[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    # 去除版本号前的 'v'
    latest_version=${latest_version#v}
    # 输出最新版本号
    echo "$latest_version"
}

if [ "${build_all}" == "true" ] || [ ! -f "${bin_file}" ]; then
    echo "dbland 预编译文件不存在: $bin_file, 开始下载预编译版本..."
    # https://github.com/m9d2/dbland/releases/download/v1.1.1/dbland-linux-amd64.tar.gz
    download_url="https://github.com/m9d2/dbland/releases/latest/download/dbland-${dbland_arch}.tar.gz"
    if [ -n "${download_proxy_url}" ]; then
      echo "使用下载代理: ${download_proxy_url}"
      download_url="${download_proxy_url}/${download_url}"
    fi
    echo "开始下载dbland: ${download_url}"
    mkdir -p temp
    wget -O "temp/dbland-${arch}.tar.gz" "${download_url}" || { echo "下载文件失败"; exit 1; }
    echo "下载完成，开始解压文件"
    tar -xzf temp/dbland-${arch}.tar.gz -C "temp" || { echo "解压文件失败"; exit 1; }
    # echo "$(ls -lh)"
    mkdir -p DBland/app/bin/
    echo "移动文件到 $bin_file 位置"
    mv temp/dbland "$bin_file" || { echo "移动文件失败"; exit 1; }
    # echo "删除下载的压缩包"
    # rm -f dbland.tar.gz
else
    echo "使用已有的 dbland 预编译文件: $bin_file"
fi

# 改用api获取最新版本号，支持多架构打包
dbland_version=$(get_last_dbland_version)
echo "当前dbland版本: ${dbland_version}"
fpk_version="${dbland_version}-${build_version}"
if [ "$build_pre" == 'true' ];then 
    cur_time=$(date +"%Y%m%d_%H%M%S")
    echo "当前时间：$cur_time"
    fpk_version="${fpk_version}-${cur_time}"
fi

sed -i "s|^[[:space:]]*version[[:space:]]*=.*|version=${fpk_version}|" 'DBland/manifest'
echo "设置 manifest 的 version 为: ${fpk_version}"
sed -i "s|^[[:space:]]*platform[[:space:]]*=.*|platform=${platform}|" 'DBland/manifest'
echo "设置 manifest 的 platform 为: ${platform}"
sed -i "s|^[[:space:]]*os_min_version[[:space:]]*=.*|os_min_version=${os_min_version}|" 'DBland/manifest'
echo "设置 manifest 的 os_min_version 为: ${os_min_version}"

# jq ".[0].items |= map(if .field == \"dbland_version\" then .initValue = \"$dbland_version\" else . end)" DBland/wizard/config > temp.json \
#   && mv temp.json DBland/wizard/config
# echo "更新配置向导中的dbland版本号为: ${dbland_version}"

echo "开始打包 DBland.fpk"


if command -v fnpack >/dev/null 2>&1; then
    echo "使用系统已安装的 fnpack $(fnpack | grep Version) 进行打包"
    fnpack build --directory DBland/ || { echo "打包失败"; exit 1; }
else
    echo "使用本地 fnpack 脚本进行打包"
    ./fnpack.sh build --directory DBland || { echo "打包失败"; exit 1; }
fi 

fpk_name="DBland-${fpk_version}-${arch}.fpk"
mv DBland.fpk "${fpk_name}"
echo "打包完成: ${fpk_name}"
