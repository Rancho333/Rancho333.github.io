#!/bin/bash

# check image exist
find ./source/_posts/ -name "*.md" | xargs grep -rn png | grep -v "使用优化" | grep -v asset_im > file
sed -i 's/)//g' file
cut -d '/' -f 8 file > images
image_miss="false"

echo -e "\nStart check image\n"
while read line
do
    if [ ! -e ./source/pictures/$line ]; then
        echo "$line does't exist"
        image_miss="true"
    fi
done < images

rm ./file
rm ./ images

if [ "$image_miss" = "true" ]; then
    echo -e "\nImage miss, please check it!\n"
    exit -1
fi
echo -e "\nNo image miss\n"
# end check image exist

if [[ -z $1 ]];then
    COMMENT="default comment info"
else
    COMMENT=$1
fi

hexo g -d

git add .
git commit -m "$COMMENT"
git push
