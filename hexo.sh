echo "download images"
sh img.sh
echo "replace to local"
sh replace_img.sh
#only sync images
#ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./source/images/ oss://plantegg/images/ -u

hexo g -d

#sync all blog to oss
ossutil --config-file=~/src/script/mac/.ossutilconfig sync ./public/ oss://plantegg/ -u --output-dir=/tmp/
