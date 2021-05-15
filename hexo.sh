echo "download images"
sh img.sh
echo "replace to local"
sh replace_img.sh
hexo g -d
