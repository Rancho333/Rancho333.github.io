find ../_posts -name "*md" | xargs sed -n '/gitee/p' | grep png | cut -d '/' -f 5 | cut -d ')' -f 1 > images.py
sed -i -e 's/^/"/' -e 's/$/"/' -e 's/$/,/' -e '$s/,//' -e '1i images=[' -e '$a ]' images.py
