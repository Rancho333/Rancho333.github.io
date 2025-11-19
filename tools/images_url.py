# This script can generate the cmd of change images url

os.system("bash get_images.sh")
from images import images

for i in images:
    print "find ../posts -name '*.md' | xargs sed -i '/asset_img" + " " + i + "/c![](https://rancho333.gitee.io/pictures/" + i + ".png)'"
