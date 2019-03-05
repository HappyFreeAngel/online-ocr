#!/bin/bash
#devops 通用自动化脚本  version:0.0.1 2019.02.28
#基本环境变量设置如下:
if [ $# -eq 0 ]; then
    echo $0: 用法：$0  -p [端口号] -c [健康检测路径] -g [检测是否是git项目,如果不是则自动在默认配置的gitlab上创建一个master分支,并自动上传.]
fi

echo "build.sh 版本 2019.02.26 21:42"
#容器云平台缺省环境变量 mesos+marathon
export DEFAULT_DNS_HOST="10.20.5.31"
export MARATHON_LEADER=""
export MARATHON_HOST_LIST="10.20.5.71,10.20.5.72,10.20.5.73"
for marathon_host in $(echo $MARATHON_HOST_LIST | tr ',' "\n")
     do
        leader_query_result=$(curl http://${marathon_host}:8080/v2/leader | grep '\"leader\":' | tr '\"' ' ' | tr ':' ' ' | awk '{ print $3}')
        if [[ ! -z "$leader_query_result" ]];
        then
            MARATHON_LEADER=$leader_query_result
            break
        fi
     done
#get marathon leader
#http://10.20.5.71:8080/v2/leader
#{"leader":"10.20.5.72:8080"}


if [[ -z "$MARATHON_LEADER" ]];
then
     echo "ERROR! Marathon Leader is unknown!"     #todo 如果是单个marathon 会不会报错?
     exit 1
fi

#getUploadHost()  参考https://mesosphere.github.io/marathon/1.4/docs/rest-api.html
#export DEFAULT_UPLOAD_HOST="10.20.5.82"
DEFAULT_UPLOAD_HOST=$(curl http://${MARATHON_LEADER}:8080/v2/apps/data/download \
|  tr '\,'  '\n' | grep \"host\": | awk 'NR==1' | tr '\"' ' ' | tr ':' ' ' | awk '{print $2}')
#"host":"mesos-agent1.cityworks.cn"
echo "下载服务器所在的主机IP="DEFAULT_UPLOAD_HOST=$DEFAULT_UPLOAD_HOST
sleep 2

export DEFAULT_APP_PORT=8080
#gitlab 缺省环境变量
export GITLAB_HOST="gitlab.devops.marathon.mesos"
export GITLAB_HTTP_PORT=80
export GITLAB_HTTPS_PORT=443
export GITLAB_USER="root"
export PRIVATE_TOKEN="R-KaBYWVhn52-kZhAUJe"
export DEFAULT_APP_HEALTH_CHECK_PATH="/"

export INIT_FOLDER_AS_GIT_FOLDER="false"

export YOUR_DOWNLOAD_HOST_NAME=$DEFAULT_UPLOAD_HOST

#设置部署类型,发布到哪里去,开发环境还是生产环境.
export DEPLOY_TYPE="test"  #test,develop,product

export PROJECT_NAME=""
#getopts的使用形式是：getopts option_string variable 
#getopts一共有两个参数，第一个是-a这样的选项，第二个参数是 hello这样的参数。
#选项之间可以通过冒号:进行分隔，也可以直接相连接，：表示选项后面必须带有参数，如果没有可以不加实际值进行传递

#参数说明: -p app端口 -c app健康检查相对路径 -g git 初始化,如果部署git项目的话, -t 部署类型(test,dev,product)

while getopts "p:c:g:t" opt; do
  case $opt in
    p)
       DEFAULT_APP_PORT=$OPTARG
       echo "this is -p the arg is ! $OPTARG"
       ;;
    c)
      #健康状态检测的URL
      DEFAULT_APP_HEALTH_CHECK_PATH=$OPTARG
      echo "this is -c the arg is ! $OPTARG"
      ;;
    g)
      echo "this is -g the arg is ! $OPTARG"
      INIT_FOLDER_AS_GIT_FOLDER=$OPTARG
      ;;
    t)
      echo "this is -t the arg is ! $OPTARG"
      DEPLOY_TYPE=$OPTARG
      ;;
    n)
      echo "this is -n the arg is ! $OPTARG"
      PROJECT_NAME=$OPTARG
      ;;
    \?)  #没有的参数，会被存储在?中
      echo "Invalid option: -$OPTARG"
      ;;
  esac

done
#判断是否在jenkin环境里 有git source 的项目

MVN_COMMAND="mvn"
#ANSIBLE_PLAYBOOK_COMMAND="ansible-playbook"
if [[ ! -z "$GIT_BRANCH" ]];
then
    echo "检测到当前在jenkins环境里,设置M2_HOME,ANSIBLE_HOME 变量值."
     #maven 环境
    export M2_HOME=${JENKINS_HOME}/tools/maven
    #设置ansible 环境
    export ANSIBLE_HOME=${JENKINS_HOME}/tools/ansible/ansible2.6.10
    export PATH=$PATH:$M2_HOME/bin:/bin:.
    MVN_COMMAND=$M2_HOME/bin/mvn

else
     echo -e "\033[32m 如果你是在Jenkins环境下，却接收不到jenkins的环境变量，请用  source ./build.sh 调用本脚本. 不能用 sudo source ./build.sh \033[0m"
fi


#确保shell 切换到当前shell 脚本文件夹
current_file_path=$(cd "$(dirname "$0")"; pwd)
cd ${current_file_path}

NEW_APP_PORT=$DEFAULT_APP_PORT #spring boot app 缺省的端口是8080
#项目名称 假设一个项目目录下有多个子项目
cd ..
#project_name=$(basename "$PWD")
#project_name=$(echo "$project_name" | awk '{print tolower($0)}')
#project_name=$(echo $project_name | sed "s|_|-|g")
#project_name=$(echo $project_name | sed "s|\.|-|g")
#echo "项目名称="$project_name
cd ${current_file_path}
cd ..
parent_foldername=$(basename `pwd`)

cd ${current_file_path}
#如果ansible-playbooks 目录不存在则自动复制过来.
#单一的app，没有上级目录.
if [ $parent_foldername == "java-project" ]; then
     cp -r ../ansible-playbooks/  ansible-playbooks
     echo "ansible-playbooks自动复制完成."
else
  #有上层的目录
     cp -r ../../ansible-playbooks/  ansible-playbooks
     echo "ansible-playbooks自动复制完成."
fi

cd ${current_file_path}

OLD_DNS_HOST="your_dns_host"
NEW_DNS_HOST=$DEFAULT_DNS_HOST

app_name=$(basename "$PWD")
app_name=$(echo "$app_name" | awk '{print tolower($0)}')
app_name=$(echo $app_name | sed "s|_|-|g")
app_name=$(echo $app_name | sed "s|\.|-|g")

folder_name=$app_name
echo "appname="$app_name

namespace_id=1

#origin/develop
test_branch_name=""
if [ ! -z "$GIT_BRANCH" ];
then
    test_branch_name=$(basename "/"${GIT_BRANCH})  #前面要加个斜杠,才能表示linux 路径.
    echo "这是在jenkins docker 环境里."
else
    test_branch_name=$(git status | grep 'On branch' | awk '{print $3}')
fi

#自动为当前文件夹里的项目创建git项目并上传到指定的git服务器.
if [ $INIT_FOLDER_AS_GIT_FOLDER=="yes" ];
then
      #判断这个文件夹是否在git里，如果git项目已经存在不会重新初始化,避免误操作.
      if [ -z $test_branch_name ];
      then
        echo "检测到当前项目${folder_name}不是git项目,马上自动创建一个git项目,并把当前项目上传到远程gitlab服务器http://$GITLAB_HOST."
        curl --request POST --header "PRIVATE-TOKEN: ${PRIVATE_TOKEN}"  \
        --data "name=${folder_name}&namespace_id=${namespace_id}" http://${GITLAB_HOST}/api/v4/projects;
        #自动化上传
        #cd 项目文件夹
        cp ../../.gitignore  .
        git init
        git remote add origin http://gitlab.devops.marathon.mesos/root/${folder_name}.git
        git add .
        git commit -m "${folder_name} Initial commit"
        git push -u origin master
      fi

fi

#auto set jenkins
#to do 怎么使用模版?
#http://jenkins.devops.marathon.mesos:8080/job/spring-hello-world/configure
echo "GIT_BRANCH="$GIT_BRANCH
#origin/develop
if [ ! -z "$GIT_BRANCH" ];
then
    branch_name=$(basename "/"${GIT_BRANCH})  #前面要加个斜杠,才能表示linux 路径.
    echo "这是在jenkins docker 环境里."
else
    branch_name=$(git status | grep 'On branch' | awk '{print $3}')
fi

echo "正式的branch name="$branch_name

branch_name=$(echo $branch_name | sed "s|_|-|g")
branch_name=$(echo $branch_name | sed "s|\.|-|g")
branch_name=$(echo $branch_name | awk '{print tolower($0)}')
echo "git分支名称="$branch_name


#使用mvn 工具从pom.xml获取app版本号
project_version=$($MVN_COMMAND -q \
    -Dexec.executable=echo \
    -Dexec.args='${project.version}' \
    --non-recursive \
    exec:exec)

app_tgz=${app_name}-${project_version}.tgz

echo "app_tgz文件名称="$app_tgz
echo " {} "

#确保代码在不同目录层级下保持稳定的结构,app_id 保持一致.
if [ -z $PROJECT_NAME ];then
   #在没有手动设置项目名称的情况下
     PROJECT_NAME=$app_name
     project_name=$PROJECT_NAME
fi

default_app_id=/${DEPLOY_TYPE}/${PROJECT_NAME}/${branch_name}/${folder_name}

download_host=$DEFAULT_UPLOAD_HOST  #download.data.marathon.mesos 所在的主机
download_host_username=root
download_host_password=kaixin.com

ceph_rexray_bind_path=/var/lib/rexray/volumes/download-data/data
download_app_full_dir_path_on_host=${ceph_rexray_bind_path}/${PROJECT_NAME}/${branch_name}/${app_name}
download_host_relative_path=${PROJECT_NAME}/${branch_name}/${app_name}

#缺省的app_id=/test/项目名称/分支名称/应用名称
#default_app_id=/${DEPLOY_TYPE}/${PROJECT_NAME}/${branch_name}/${folder_name}

echo "default_app_id="$default_app_id

cd ${current_file_path}/ansible-playbooks
cp templates/input.yml.j2  input.yml

#自动替换input.yml.j2模版里的变量，自动生成input.yml 配置文件.
OLDPATH="your_download_dir"
NEWPATH=${download_host_relative_path}

OLD_APP_FILE_DIR_FULL_PATH_ON_HOST="your_app_file_full_dir_path"
APP_FILE_DIR_FULL_PATH_ON_HOST=$download_app_full_dir_path_on_host

OLD_APP_TGZ="your_marathon_app_tgz"
NEW_APP_TGZ=${app_tgz}

OLD_REPOSITORY_BRANCH_NAME="your_repository_branch_name"
NEW_REPOSITORY_BRANCH_NAME=$branch_name

OLD_APP_ID="your_app_id"

OLD_APP_JSON_FILENAME="your_app_json_filename"
APP_JSON_FILENAME=${folder_name}.json

OLD_DOWNLOAD_HOST="your_download_host_name" #虚拟机或物理机的域名或IP
OLD_DOWNLOAD_HOST_SSH_PORT="your_download_host_ssh_port"
OLD_DOWNLOAD_HOST_USERNAME="your_download_host_username"
OLD_DOWNLOAD_HOST_PASSWORD="your_download_host_password"

export YOUR_DOWNLOAD_HOST_NAME=$DEFAULT_UPLOAD_HOST
export YOUR_DOWNLOAD_HOST_SSH_PORT=22
export YOUR_DOWNLOAD_HOST_USERNAME="root"
export YOUR_DOWNLOAD_HOST_PASSWORD="kaixin.com"

OLD_APP_PORT="your_app_port"
##NEW_APP_PORT="8080" #缺省的端口是8080

OLD_APP_URI="your_app_uri"
NEW_APP_URI=http://${folder_name}.${branch_name}.${PROJECT_NAME}.${DEPLOY_TYPE}.marathon.mesos:$NEW_APP_PORT

OLD_APP_HEALTH_CHECK_PATH="your_app_health_check_path"
NEW_APP_HEALTH_CHECK_PATH=$DEFAULT_APP_HEALTH_CHECK_PATH

#如果实例有很多个,怎么处理?  getconf HOST_NAME_MAX  centos7 默认是64个字节. hostname 不能超过这个长度否则docker 无法启动.
OLD_CONTAINER_HOSTNAME="your_container_hostname"
NEW_CONTAINER_HOSTNAME=${folder_name}.${branch_name}.${PROJECT_NAME}.${DEPLOY_TYPE}.marathon.mesos

container_hostname_length=${#NEW_CONTAINER_HOSTNAME}
HOST_NAME_MAX=64 #getconf HOST_NAME_MAX

if [ $container_hostname_length -gt $HOST_NAME_MAX ]; then
    echo -e "\033[31m "${NEW_CONTAINER_HOSTNAME}"长度="${container_hostname_length}"字符.超过了"${HOST_NAME_MAX}字节" \033[0m"
    echo ${NEW_CONTAINER_HOSTNAME}"长度="${container_hostname_length}"字符.超过了"${HOST_NAME_MAX}"字节"
    exit 1
fi

#每次必须从模版复制，这样才能确保二次执行时结果一样.
cp templates/hosts.j2  hosts

#选项i的用途是直接在文件中进行替换。为防止误操作带来灾难性的后果，sed在替换前可以自动对文件进行备份，前提是需要提供一个后缀名。
#mac osx下是强制要求备份的，centos下是可选的
#sed -i '.bak' 's/foo/bar/g' ./m*
#如果不需要备份文件，使用空字符串''来取消备份，mac osx下可以使用如下命令完成替换操作：
#sed -i '' -e "s|8091|9999|g" input.yml

sed -i '' -e "s|$OLDPATH|$NEWPATH|g" input.yml
sed -i '' -e "s|$OLD_APP_FILE_DIR_FULL_PATH_ON_HOST|$APP_FILE_DIR_FULL_PATH_ON_HOST|g" input.yml
sed -i '' -e "s|$OLD_APP_TGZ|$NEW_APP_TGZ|g" input.yml
sed -i '' -e "s|$OLD_REPOSITORY_BRANCH_NAME|$NEW_REPOSITORY_BRANCH_NAME|g" input.yml
sed -i '' -e "s|$OLD_APP_ID|$default_app_id|g" input.yml
sed -i '' -e "s|$OLD_APP_JSON_FILENAME|$APP_JSON_FILENAME|g" input.yml
sed -i '' -e "s|$OLD_APP_PORT|$NEW_APP_PORT|g" input.yml
sed -i '' -e "s|$OLD_APP_URI|$NEW_APP_URI|g" input.yml
sed -i '' -e "s|$OLD_DNS_HOST|$NEW_DNS_HOST|g" input.yml

sed -i '' -e "s|$OLD_APP_HEALTH_CHECK_PATH|$NEW_APP_HEALTH_CHECK_PATH|g" input.yml
sed -i '' -e "s|$OLD_CONTAINER_HOSTNAME|$NEW_CONTAINER_HOSTNAME|g" input.yml

sed -i '' -e "s|$OLD_DOWNLOAD_HOST|$YOUR_DOWNLOAD_HOST_NAME|g" hosts
sed -i '' -e "s|$OLD_DOWNLOAD_HOST_SSH_PORT|$YOUR_DOWNLOAD_HOST_SSH_PORT|g" hosts
sed -i '' -e "s|$OLD_DOWNLOAD_HOST_USERNAME|$YOUR_DOWNLOAD_HOST_USERNAME|g" hosts
sed -i '' -e "s|$OLD_DOWNLOAD_HOST_PASSWORD|$YOUR_DOWNLOAD_HOST_PASSWORD|g" hosts

cd ${current_file_path}
#监测是否包含下面模块,如果没有则app无法在容器里运行.
#查找指定目录下的*.yml文件里内容包含有 |abs 的所有文件.
found_pom_file=$(find `pwd` -name "pom.xml")
springboot_maven_plugin_status=$(find `pwd` -name "pom.xml" -exec grep -l "spring-boot-maven-plugin" {} \;)
echo $found_pom_file
PLUGINS_END="</plugins>"
SPRING_BOOT_MAVEN_PLUGIN="<plugin>   \
<groupId>org.springframework.boot</groupId>       \
<artifactId>spring-boot-maven-plugin</artifactId>  \
</plugin>"

echo $SPRING_BOOT_MAVEN_PLUGIN

SPRING_BOOT_MAVEN_PLUGIN_WITH_PLUGINS_END=$SPRING_BOOT_MAVEN_PLUGIN"</plugins>"
PROJECT_END="</project>"
BUILD_PLUGINS_CONTENT="<build><plugins>"${SPRING_BOOT_MAVEN_PLUGIN}"</plugins></build></project>"

try_replace_result=0

if [[ ! -z "$springboot_maven_plugin_status" ]]; #已经有包含了,可以直接编译为java applicaiton,可以运行.
then
      echo $found_pom_file" 已经是合格的maven pom.xml,编译本app为独立运行的Java app 已经具体了条件."
      try_replace_result=0
else
      echo $found_pom_file" 尚未包含spring-boot-maven-plugin 插件,将自动添加spring-boot-maven-plugin,让本app成为可以独立运行的Java app."

      plugins_ends_status= $(cat $found_pom_file | grep "</plugins>")
      if [[ ! -z "$plugins_ends_status" ]];
      then
           sed -i '' -e "s|$PLUGINS_END|$SPRING_BOOT_MAVEN_PLUGIN_WITH_PLUGINS_END|g" $found_pom_file
           try_replace_result=$?
           ls -al $found_pom_file
      else
           echo ""$found_pom_file"没有包含<build></build>模块,马上添加."
           sed -i '' -e "s|$PROJECT_END|$BUILD_PLUGINS_CONTENT|g" $found_pom_file
           ls -al $found_pom_file
      fi
fi

# <build>
#	<plugins>
#		<!--    让jar 文件包含main class 主属性   -->
#		<plugin>
#			<groupId>org.springframework.boot</groupId>
#			<artifactId>spring-boot-maven-plugin</artifactId>
#		</plugin>
#		<!--    让jar 文件包含main class 主属性   -->
#	</plugins>
#</build>

#编译打包封装APP
#source java8  #切换java环境  source java11  或source java8
export M2_HOME=${M2_HOME}
$MVN_COMMAND clean compile package -e -X -DskipTests
export jarfile=$(ls target | grep -v .jar.original | grep .jar)


`rm -rf ${app_name}`
mkdir  ${app_name}
cp target/$jarfile ${app_name}

cat << EOF >> ${app_name}/run.sh
#!/bin/bash

pwd && ls -al

#source /etc/profile && java -jar ./TestWeb.jar --server.port=9090
source /etc/profile
java -jar ./${jarfile}
EOF

#project_version=$($MVN_COMMAND -q \
#    -Dexec.executable=echo \
#    -Dexec.args='${project.version}' \
#    --non-recursive \
#    exec:exec)
#
app_tgz=${app_name}-${project_version}.tgz
chmod +x ${app_name}/run.sh
tar -czf ${app_tgz} ${app_name}

#检测文件是否正常:大小至少>=10KB(包含10240B),否则视为不正常.
app_tgz_file_size=$(ls -al ${app_tgz} | awk '{ print $5}')

if [ $app_tgz_file_size -lt 10240 ]; #已经有包含了,可以直接编译为java applicaiton,可以运行.
then
    ls -al ${current_file_path}
    echo -e "\033[31m 编译打包的文件${app_tgz}大小<1024KB,这个可能是文件编译错误,这的程序估计是错误的程序. 软件部署被强制终止. \033[0m"
    sleep 3
    exit 1000
fi

#创建ansible-playbooks hosts 文件
#your_download_host_name  ansible_user=your_download_host_username   ansible_ssh_pass=your_download_host_password

#部署软件到目标机器
cd ${current_file_path}
echo ${app_tgz}

#如果存在的话,直接删除,如果不存在忽略删除错误(会提示文件不存在).
`rm ansible-playbooks/files/${app_tgz}`
cp ${app_tgz}  ansible-playbooks/files/
cd ansible-playbooks

#切换到ansible环境
source $ANSIBLE_HOME/venv/bin/activate
ansible-playbook -i hosts -vvv  main.yml
cd ${current_file_path}

