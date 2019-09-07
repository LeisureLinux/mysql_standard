#!/bin/bash
# ##################################
# 标准化 MySQL 数据库
# @版权所无：上海甬洁网络科技有限公司 (info@yj777.cn)
# 微信公众号： yj777-cn (甬洁网络科技)
# 创建日期： 2019年9月7日
# 最后修改： 2019年9月7日 17:42 (北京时间)
# ##################################
# 所有的表默认字符集都修改为 utf8mb4
# 所有的字段默认字符集都去掉原先的 utf8
# 所有的 MyISAM 引擎修改为 InnoDB
# 检查所有没有注释的表
# 打印显示每张表的行数，表名，表注释
# ##################################
DB=$1
[ -z ${DB} ] && echo "语法: $0 DB_Name" && exit 1

backupDB () {
   echo "本脚本操作比较危险，数据库备份中 ..."
   mysqldump --force ${DB}  > /var/tmp/tmp.${DB}.sql
   [ $? != 0 ] && echo "备份数据库失败，请检查 " && exit 100
   echo "数据库已经备份到： /var/tmp/tmp.${DB}.sql，如果需要恢复，可自行从该文件恢复"
}

makeInnoDB () {
  # 把 MyISAM 表修改为 InnoDB
  for TBL in $(mysql ${DB} -Ns -e "SHOW TABLE STATUS WHERE ENGINE='MyISAM'"|awk '{print $1}'); do
     mysql ${DB} -e "ALTER TABLE $TBL ENGINE='InnoDB'"
     [ $? != 0 ] && echo "修改表 ${TBL} 引擎为 InnoDB 失败，请检查 " && exit 101
	   echo  "[${TBL}] 表引擎已经修改为 InnoDB "
  done
}

changeCollation () {
  # 把 utf8 修改为 utf8mb4
  for TBL in $(mysql ${DB} -Ns -e "SHOW TABLE STATUS WHERE Collation!='utf8mb4_general_ci'"|awk '{print $1}'); do
     mysql ${DB} -e "ALTER TABLE $TBL default charset='utf8mb4'"
     [ $? != 0 ] && echo "修改表 ${TBL} 字符集为 utf8mb4_general_ci 失败，请检查 " && exit 102
	   echo  "[${TBL}] 表字符集已经修改为 utf8mb4_general_ci "
  done
}

checkUtf8Column () {
  # 把 utf8 列修改为 utf8mb4
  for TBL in $(mysql ${DB} -Ns -e "SHOW TABLE STATUS WHERE comment not like 'VIEW%'"|awk '{print $1}'); do
     SQL=$(mysql -rNs ${DB} -e "SHOW CREATE TABLE ${TBL}"|grep "CHARACTER SET utf8 "| \
	     sed -e 's/CHARACTER SET utf8 / /g' -e 's/,$/;/g' -e "s/^/ALTER TABLE ${TBL} MODIFY /g")
	   # 部分是直接 utf8 结尾加逗号，即没有注释字段
     SQL=${SQL}$(mysql -rNs ${DB} -e "SHOW CREATE TABLE ${TBL}"|grep "CHARACTER SET utf8,"| \
	     sed -e 's/CHARACTER SET utf8,/;/g' -e "s/^/ALTER TABLE ${TBL} MODIFY /g")
	   echo ${SQL}|mysql -Nsq ${DB}
	   [ $? != 0 ] && echo "修改表结构失败，表名： ${TBL}" && exit 201
	   [ -n "${SQL}" ] && echo  "[${TBL}] 表执行了：
$SQL"
  done
}

checkNullComment () {
  # 检查没有注释的表
  for TBL in $(mysql ${DB} -Ns -e "SHOW TABLE STATUS WHERE comment=''"|awk '{print $1}'); do
	 echo  "[${TBL}] 表没有注释，请检查！"
  done
}

checkRows () {
  # 查看每张表的行数
  mysql ${DB} -Ns -e "SHOW TABLE STATUS WHERE comment not like 'VIEW%'"|awk \
   '{print $5,$1,"【" $NF "】"}'|sort -n
}

# Main Prog.
backupDB
makeInnoDB
changeCollation
checkNullComment
checkUtf8Column
checkRows
