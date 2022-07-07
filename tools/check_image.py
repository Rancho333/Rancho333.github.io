#This python script help me to check the images used in Markdown files. Follow the steps to finsh check:

import os

os.system("bash get_images.sh")
from images import images

for i in images:
	my_image = '/mnt/blog/public/pictures/'+i
	if os.path.isfile(my_image):
		continue
	else:
		print my_image

