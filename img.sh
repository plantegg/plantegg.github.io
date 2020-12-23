rm -f ./ossimg/

grep "img.oss-cn-zhangjiakou.aliyuncs.com" source/_posts/*.md  | grep "img src=" | awk -F '"' '{ print $2 }' >img.list

grep "img.oss-cn-zhangjiakou.aliyuncs.com" source/_posts/*.md  | grep -v "img src=" | awk -F "(" '{ print $NF '} | sed 's/)//g' >>img.list

dos2unix img.list
cat img.list | sort | uniq >img_uniq.list
while read line; do echo $line ; wget -q $line -P ./ossimg/ ; done <./img_uniq.list

cp ossimg/* source/images/ 
