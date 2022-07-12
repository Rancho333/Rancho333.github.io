#!/bin/bash
if [[ -z $1 ]];then
    COMMNET="default comment info"
else
    COMMENT=$1
fi

hexo g -d

git add .
git commit -m $COMMENT
git push
