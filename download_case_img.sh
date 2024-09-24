#rm -f ./ossimg/*
#dest="source/_posts/*.md"
dest="/Users/ren/TeamFile/case/"

#grep -E "intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com" $dest  | grep "img src=" | awk -F '"' '{ print $2 }' >img.list

find /Users/ren/TeamFile/case/ -type f -name "*.md" -exec grep -E  "intranetproxy.alipay.com|oss-ata.alibaba.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com" {} \; | grep "img src=" | awk -F '"' '{ print $2 }' >img.list

find /Users/ren/TeamFile/case/ -type f -name "*.md" -exec grep -E "cdn.nlark.com|intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com"  {} \; | grep -v "img src=" | grep "(" | awk -F "(" '{ print $NF }' | sed 's/)//g' >>img.list

find /Users/ren/TeamFile/case/ -type f -name "*.md" -exec grep -E  "intranetproxy.alipay.com|oss-ata.alibaba.com" {} \; |grep "\!\[\](http" | grep "(" | awk -F "(" '{ print $NF }' | sed 's/)//g' >>img.list

#find /Users/ren/TeamFile/case/ -type f -name "*.md" -exec grep -E "https*:\/\/cdn.nlark.com/yuque/0/20[0-9][0-9]/.../162611"  {} \; | grep -v "img src=" | awk -F ":" '{ print $NF }' | sed 's/)//g' >>img.list

dos2unix img.list
#/usr/local/Cellar/dos2unix/7.4.2/bin/dos2unix img.list
cat img.list | sort | uniq >img_uniq.list
while read line; do  wget -nc -q $line -P /Users/ren/case/951413iMgBlog/ ; done <./img_uniq.list
