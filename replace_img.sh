#rm -f ./ossimg/*
dest="./source/_posts/"
#dest="/Users/ren/TeamFile/case/"

#find $dest -type f -name "*.md" -exec grep -E  "intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com" {} \; | grep "img src=" | awk -F '"' '{ print $2 }' >img.list

oss_url="https:\/\/plantegg.oss-cn-beijing.aliyuncs.com"

# ata2-img.oss-cn-zhangjiakou.aliyuncs.com/neweditor
find $dest -type f -name "*.md" -exec gsed -i -E 's/https*:\/\/ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/https:\/\/plantegg.oss-cn-beijing.aliyuncs.com\/images\/oss/g;s/https*:\/\/ata2-img.oss-cn-zhangjiakou.aliyuncs.com\/neweditor/https:\/\/plantegg.oss-cn-beijing.aliyuncs.com\/images\/oss/g;s/https*:\/\/ata2-img.oss-cn-zhangjiakou.aliyuncs.com/https:\/\/plantegg.oss-cn-beijing.aliyuncs.com\/images\/oss/g;s/https*:\/\/intranetproxy.alipay.com\/skylark\/lark\/0\/20[0-9][0-9]\/...\/33359/https:\/\/plantegg.oss-cn-beijing.aliyuncs.com\/images\/oss/g;s/https*:\/\/cdn.nlark.com\/yuque\/.\/20[0-9][0-9]\/...\/162611/https:\/\/plantegg.oss-cn-beijing.aliyuncs.com\/images\/oss/g;s/:\/\/\/Users\/ren\/src\/blog\/951413iMgBlog/https:\/\/plantegg.oss-cn-beijing.aliyuncs.com\/images\/951413iMgBlog/g;s/\/Users\/ren\/src\/blog\/951413iMgBlog/https:\/\/plantegg.oss-cn-beijing.aliyuncs.com\/images\/951413iMgBlog/g;s/file:\/\/\/Users\/ren\/case\/ossimg/https:\/\/plantegg.oss-cn-beijing.aliyuncs.com\/images\/oss/g;s/\/Users\/ren\/case\/ossimg/https:\/\/plantegg.oss-cn-beijing.aliyuncs.com\/images\/oss/g' {} \;

#find /Users/ren/TeamFile/case/ -type f -name "*.md" -exec grep -E "intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com"  {} \; | grep -v "img src=" | awk -F "(" '{ print $NF }' | sed 's/)//g' >>img.list

#cp 951413iMgBlog/* source/images/951413iMgBlog/
rsync -a 951413iMgBlog/ source/images/951413iMgBlog/
