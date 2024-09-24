#rm -f ./ossimg/*
dest="./source/_posts/"
#dest="/Users/ren/TeamFile/case/"

#find $dest -type f -name "*.md" -exec grep -E  "intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com" {} \; | grep "img src=" | awk -F '"' '{ print $2 }' >img.list

# https://cdn.jsdelivr.net/gh/plantegg/plantegg.github.io/images
# ata2-img.oss-cn-zhangjiakou.aliyuncs.com/neweditor
find $dest -type f -name "*.md" -exec gsed -i -E 's/https*:\/\/ata2-img.cn-hangzhou.oss-pub.aliyun-inc.com/https:\/\/cdn.jsdelivr.net\/gh\/plantegg\/plantegg.github.io\/images\/oss/g;s/https*:\/\/ata2-img.oss-cn-zhangjiakou.aliyuncs.com\/neweditor/https:\/\/cdn.jsdelivr.net\/gh\/plantegg\/plantegg.github.io\/images\/oss/g;s/https*:\/\/ata2-img.oss-cn-zhangjiakou.aliyuncs.com/https:\/\/cdn.jsdelivr.net\/gh\/plantegg\/plantegg.github.io\/images\/oss/g;s/https*:\/\/intranetproxy.alipay.com\/skylark\/lark\/0\/20[0-9][0-9]\/...\/33359/https:\/\/cdn.jsdelivr.net\/gh\/plantegg\/plantegg.github.io\/images\/oss/g;s/https*:\/\/cdn.nlark.com\/yuque\/.\/20[0-9][0-9]\/...\/162611/https:\/\/cdn.jsdelivr.net\/gh\/plantegg\/plantegg.github.io\/images\/oss/g;s/file:\/\/\/Users\/ren\/src\/blog\/951413iMgBlog/https:\/\/cdn.jsdelivr.net\/gh\/plantegg\/plantegg.github.io\/images\/951413iMgBlog/g;s/\/Users\/ren\/src\/blog\/951413iMgBlog/https:\/\/cdn.jsdelivr.net\/gh\/plantegg\/plantegg.github.io\/images\/951413iMgBlog/g;s/file:\/\/\/Users\/ren\/case\/ossimg/https:\/\/cdn.jsdelivr.net\/gh\/plantegg\/plantegg.github.io\/images\/oss/g;s/\/Users\/ren\/case\/ossimg/https:\/\/cdn.jsdelivr.net\/gh\/plantegg\/plantegg.github.io\/images\/oss/g' {} \;

#find /Users/ren/TeamFile/case/ -type f -name "*.md" -exec grep -E "intranetproxy.alipay.com|cn-hangzhou.oss-pub.aliyun-inc.com|img.oss-cn-zhangjiakou.aliyuncs.com"  {} \; | grep -v "img src=" | awk -F "(" '{ print $NF }' | sed 's/)//g' >>img.list

cp -r 951413iMgBlog/* source/images/951413iMgBlog/

# %s#3306/server#3307/server#g
