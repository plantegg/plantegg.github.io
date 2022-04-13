echo "download images"
#从本地markdown 文档中捞取内网或者别的地址图片，下载到本地
sh download_img.sh
echo "replace to local"
#替换图片地址到oss地址，快，爽的一逼
sh replace_img.sh
#替换markdown中img到相对地址, 比如蹭github存储图片
#sh replace_to_local_url.sh

#hexo 一个静态博客发布系统，将markdown生成静态页面并上传
hexo g -d

#only sync images
#ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./source/images/ oss://plantegg/images/ -u
#上传整个静态网站（含图片）到 oss
ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./public/ oss://plantegg/ -u --output-dir=/tmp/
