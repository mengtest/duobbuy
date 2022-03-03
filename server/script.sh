
make_proto()
{
	echo "------------------------------------------------------------------------"
	echo "make_proto..."
	for dir in $(ls protos/)
	do
    	echo "  .${dir%%.*}"
    	protoc -opb/${dir%%.*}.pb -Iprotos protos/${dir%%.*}.proto	
	done 
	#protoc -opb/task.pb -Iprotos protos/task.proto
	echo "end!"
	echo "------------------------------------------------------------------------"
}

sync_proto()
{
	echo "------------------------------------------------------------------------"
	echo "begin sync..."
	echo "  .proto_map.lua..."
	rsync -a --delete service/proto_map.lua /Users/zhangjing/project/fish/client/src/app/proto_map.lua 
	echo "  .proto..."
	rsync -a --delete protos/ /Users/zhangjing/project/fish/client/proto/
	echo "  .pb..."
	rsync -a --delete pb/ /Users/zhangjing/project/fish/client/res/pb/
	echo "  .errorcode..."
	rsync -a --delete service/errorcode.lua /Users/zhangjing/project/fish/client/src/app/errorcode.lua
	echo "end SUCCESS!!!"
	echo "------------------------------------------------------------------------"
}

copy_data()
{
	echo "------------------------------------------------------------------------"
	echo "begin sync..."
	cd ../doc/
	svn up
	cd ../server/
	cp -rf ../doc/default/server/ logic/config/
	cp -rf ../doc/default/client/ /Users/zhangjing/project/fish/client/src/config/
	echo "end SUCCESS!!!"
	echo "------------------------------------------------------------------------"
}

deploy_server()
{
	echo "------------------------------------------------------------------------"
	echo "restart_server..."
	
	echo "------------------------------------------------------------------------"
}


case "$1" in
	-m)
		make_proto
		;;
	-c)
		copy_data
		;;
	-s)
		sync_proto
		;;
	*)
		echo "script usage:"
		echo " "
		echo "  -m  	生成协议"
		echo "  -c  	拷贝配置"
		echo "  -s  	同步服务器协议到客户端"
		echo "  -d55 	部署55服务器"
		exit 2
esac


