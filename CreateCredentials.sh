#!/bin/bash

OutFile='FtpCredentials.sh'
rm -f "${OutFile=}"

echo "#!/bin/bash" >> "${OutFile=}"
echo -e "\n#Please put you user name and password in this file\n" >> "${OutFile=}"
echo "ftpuser=''" >> "${OutFile=}"
echo "ftppass=''" >> "${OutFile=}"

chmod 755 "${OutFile=}"
echo "${OutFile=}" created.
