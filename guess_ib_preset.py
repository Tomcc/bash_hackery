from xml.dom import minidom
import sys

if len(sys.argv) != 2:
	quit(1)

try:
	with minidom.parse(sys.argv[1]) as xmldoc:
		itemlist = xmldoc.getElementsByTagName('Preset')
		if len(itemlist) == 0:
			quit(1)

		print(itemlist[0].attributes['Name'].value)		
except Exception as e:
	quit(1)


quit(0)