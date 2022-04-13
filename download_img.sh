#rm -f ./ossimg/*
#dest="source/_posts/*.md"
dest="/Users/ren/TeamFile/case/"

#grep -E "intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com" $dest  | grep "img src=" | awk -F '"' '{ print $2 }' >img.list

#https://cdn.nlark.com/yuque/0/2019/png/162611/1559027854127-2049facb-7708-49b5-a165-141549cc7e6b.png
#source/_posts/vxlan网络性能测试.md:![image.png](https://cdn.nlark.com/yuque/0/2020/png/162611/1589164443610-d5bb45a6-f688-4a6b-b697-8370387f4dd8.png)
#source/_posts/就是要你懂TCP--性能和发送接收Buffer的关系.md:[1]: https://cdn.nlark.com/yuque/0/2019/png/162611/1558603861745-190dadd2-cff2-49c9-8bc3-5856fdfb2d44.png#align=left&display=inline&height=627&originHeight=627&originWidth=1251&size=0&status=done&width=1251

find /Users/ren/TeamFile/case/ -type f -name "*.md" -exec grep -E  "intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com" {} \; | grep "img src=" | awk -F '"' '{ print $2 }' >img.list

find /Users/ren/TeamFile/case/ -type f -name "*.md" -exec grep -E "cdn.nlark.com|intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com"  {} \; | grep -v "img src=" | grep "(" | awk -F "(" '{ print $NF }' | sed 's/)//g' >>img.list

#find /Users/ren/TeamFile/case/ -type f -name "*.md" -exec grep -E "https*:\/\/cdn.nlark.com/yuque/0/20[0-9][0-9]/.../162611"  {} \; | grep -v "img src=" | awk -F ":" '{ print $NF }' | sed 's/)//g' >>img.list

/usr/local/Cellar/dos2unix/7.4.2/bin/dos2unix img.list
cat img.list | sort | uniq >img_uniq.list
while read line; do  wget -nc -q $line -P ./ossimg/ ; done <./img_uniq.list
