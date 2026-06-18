<?php
return array(
    //'配置项'=>'配置值'
    //'APP_DEBUG'=>true,
    'APP_GROUP_LIST'        => 'Home',
    'DEFAULT_GROUP'         => 'Home',
    'URL_MODEL'             => 1,
    'URL_CASE_INSENSITIVE'  => true,

    /*数据库配置：复制为 config.php 后按部署环境填写*/
    'DB_TYPE' => 'mysqli',
    'DB_HOST' => 'localhost',
    'DB_NAME' => 'your_database_name',
    'DB_USER' => 'your_database_user',
    'DB_PWD'  => 'change_me',
    'DB_PORT' => '3306',

    'SHOW_ERROR_MSG' => false,
    'LOG_RECORD'     => false,
    'LOG_LEVEL'      => 'EMERG,ALERT,CRIT,ERR',
);
?>
