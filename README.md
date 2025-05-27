# geoiplookup
✅ 特性一览：
功能项	状态
多线程域名并发解析	✅
支持空格/特殊字符	✅
完全无 xargs	✅
使用 geoiplookup	✅
CSV+国家分类输出	✅
错误记录	✅
进度实时刷新	✅（使用文件统计，100% 准确）

✅ 使用方法
nano geo_lookup.sh
chmod +x geo_lookup.sh
./geo_lookup.sh inputXX.txt 30    # 默认线程数是 20，可自定义

输出目录结构
bash
复制
编辑
geo_output/
├── output.csv              # 全部解析结果
├── failed.txt              # 解析失败域名
├── US.txt / CN.txt ...     # 按国家划分
