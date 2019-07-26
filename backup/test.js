sh.enableSharding("myDB");
sh.status();
use admin;
db.admin.runCommand("getShardMap");

