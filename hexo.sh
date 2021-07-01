echo "download images"
sh img.sh
echo "replace to local"
sh replace_img.sh
ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./source/images/ oss://plantegg/images/ -u
hexo g -d
