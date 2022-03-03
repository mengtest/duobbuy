# mongodump.sh
#!/bin/bash


sourcepath='/root/mongodb-linux-x86_64-3.0.7'/bin  
#存放备份数据的路径
targetpath='/root/mongodb-linux-x86_64-3.0.7/dump'
#获取昨天的日期
dayTime=$(date +%Y%m%d)  
nowtime=$(date +%Y%m%d%H%M%S)  

if [ ! -d "${targetpath}/${dayTime}/" ]  
then  
 mkdir ${targetpath}/${dayTime}  
fi  

if [ ! -d "${targetpath}/${dayTime}/${nowtime}/" ]  
then  
 mkdir ${targetpath}/${dayTime}/${nowtime}  
fi  

start()  
{  
  ${sourcepath}/mongodump -u admin -p admin -o ${targetpath}/${dayTime}/${nowtime}  
}  
execute()  
{  
  start  
  if [ $? -eq 0 ]  
  then  
    echo "back successfully!"  
  else  
    echo "back failure!"  
  fi  
}  

execute  
echo "============== back end ${nowtime} ==============" 