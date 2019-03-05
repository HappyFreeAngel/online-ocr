#!/bin/bash

#确保shell 切换到当前shell 脚本文件夹
current_file_path=$(cd "$(dirname "$0")"; pwd)
cd ${current_file_path}

source java8
mvn clean compile package -e -X -DskipTests
export jarfile=$(ls target | grep -v .jar.original | grep .jar)

appname=$(basename "$PWD")
`rm -rf ${appname}`
mkdir  ${appname}
cp target/$jarfile ${appname}

cat << EOF >> ${appname}/run.sh
#!/bin/bash

pwd && ls -al

#source /etc/profile && java -jar ./TestWeb.jar --server.port=9090
source /etc/profile
java -jar ./${jarfile}
EOF

project_version=$(mvn -q \
    -Dexec.executable=echo \
    -Dexec.args='${project.version}' \
    --non-recursive \
    exec:exec)

app_tgz=${appname}-${project_version}.tgz

chmod +x ${appname}/run.sh
tar -czf ${appname}-${project_version}.tgz ${appname}

echo ${app_tgz}
#如果存在的话,直接删除,如果不存在忽略删除错误(会提示文件不存在).
`rm ansible-playbooks/files/${app_tgz}`
cp ${app_tgz}  ansible-playbooks/files/

#部署软件到目标机器
cd ${current_file_path}
branch_name=$(git status | grep 'On branch' | awk '{print $3}')
download_host=10.20.5.81
download_host_username=root
download_host_password=kaixin.com
download_host_path=/var/lib/rexray/volumes/demo-nginx-data/data/${branch_name}
#sshpass -p ${download_host_password} scp ${appname}-${project_version}.tgz ${download_host_username}@${download_host}:${download_host_path}

#ansible-playbook 创建目录, 设置目录和脚本权限，上传文件到宿主机,监测nginx 在那台宿主机上,

folder_name=$(basename "$PWD")
default_app_id=/temp/$(echo $folder_name | sed "s|_|-|g")

cd ansible-playbooks
cp templates/input.yml.j2  input.yml

OLDPATH="your_nginx_download_dir"
NEWPATH=${download_host_path}

OLD_APP_TGZ="your_marathon_app_tgz"
NEW_APP_TGZ=${app_tgz}

OLD_REPOSITORY_BRANCH_NAME="your_repository_branch_name"
NEW_REPOSITORY_BRANCH_NAME=$branch_name

OLD_APP_ID="your_app_id"

OLD_APP_JSON_FILENAME="your_app_json_filename"
APP_JSON_FILENAME=${folder_name}.json

sed -i -e "s|$OLDPATH|$NEWPATH|g" input.yml
sed -i -e "s|$OLD_APP_TGZ|$NEW_APP_TGZ|g" input.yml
sed -i -e "s|$OLD_REPOSITORY_BRANCH_NAME|$NEW_REPOSITORY_BRANCH_NAME|g" input.yml
sed -i -e "s|$OLD_APP_ID|$default_app_id|g" input.yml
sed -i -e "s|$OLD_APP_JSON_FILENAME|$APP_JSON_FILENAME|g" input.yml


ansible-playbook -i hosts main.yml
cd ${current_file_path}





