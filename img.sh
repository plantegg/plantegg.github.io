#rm -f ./ossimg/*
grep -E "intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com" source/_posts/*.md  | grep "img src=" | awk -F '"' '{ print $2 }' >img.list

grep -E "intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com" source/_posts/*.md  | grep -v "img src=" | awk -F "(" '{ print $NF }' | sed 's/)//g' >>img.list

/usr/local/Cellar/dos2unix/7.4.2/bin/dos2unix img.list
cat img.list | sort | uniq >img_uniq.list
while read line; do echo $line ; wget -nc -q $line -P ./ossimg/ ; done <./img_uniq.list

cp ossimg/* source/images/ 
