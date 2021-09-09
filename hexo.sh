echo "download images"
sh img.sh
echo "replace to local"
sh replace_img.sh
#sh replace_to_local_url.sh
hexo g -d

#only sync images
#ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./source/images/ oss://plantegg/images/ -u
#sync all blog to oss
ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./public/ oss://plantegg/ -u --output-dir=/tmp/
