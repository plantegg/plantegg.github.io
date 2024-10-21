source ~/.bashrc

echo "download images"
#从本地markdown 文档中捞取内网或者别的地址图片，下载到本地
sh download_img.sh
echo "replace to local"
#替换图片地址到oss地址，快，爽的一逼
#sh replace_img.sh
#替换markdown中img到jsdelivr cdn
#sh replace_to_local_url.sh
sh replace_to_jsdeliver_cdn.sh

#hexo 一个静态博客发布系统，将markdown生成静态页面并上传
hexo g -d

#only sync images
#ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./source/images/ oss://plantegg/images/ -u

#cp ossimg/ to small 忽略已存在，准备压缩图片，保留原图
rsync -v --ignore-existing -r -a ossimg/ ossimg_small
rsync -v --ignore-existing -r -a 951413iMgBlog/ 951413iMgBlog_small

#压缩图片大小
find ossimg_small -size +1024k -type f -exec sips -Z 1024 {} \;
find 951413iMgBlog_small -size +1024k -type f -exec sips -Z 1024 {} \;

#用压缩后的图片覆盖原图
rsync -v --existing -r -a 951413iMgBlog_small/ public/images/951413iMgBlog
rsync -v --existing -r -a ossimg_small/ public/images/oss
#上传图片到 oss
ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./public/images/ oss://plantegg/images/ -u --output-dir=/tmp/
#上传整个静态网站（含图片）到 oss
ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./public/ oss://plantegg/ -u --output-dir=/tmp/
