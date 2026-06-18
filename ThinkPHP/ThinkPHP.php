<?php
// ThinkPHP 入口文件

// 记录开始运行时间
$GLOBALS['_beginTime'] = microtime(TRUE);
// 记录内存初始使用
define('MEMORY_LIMIT_ON', function_exists('memory_get_usage'));
if (MEMORY_LIMIT_ON) {
    $GLOBALS['_startUseMems'] = memory_get_usage();
}

// 系统目录定义
defined('THINK_PATH') or define('THINK_PATH', dirname(__FILE__) . '/');
defined('APP_PATH') or define('APP_PATH', dirname($_SERVER['SCRIPT_FILENAME']) . '/');
defined('APP_DEBUG') or define('APP_DEBUG', false);
defined('RUNTIME_PATH') or define('RUNTIME_PATH', APP_PATH . 'Runtime/');

if (defined('ENGINE_NAME')) {
    defined('ENGINE_PATH') or define('ENGINE_PATH', THINK_PATH . 'Extend/Engine/');
    require ENGINE_PATH . strtolower(ENGINE_NAME) . '.php';
} else {
    $runtime = defined('MODE_NAME') ? '~' . strtolower(MODE_NAME) . '_runtime.php' : '~runtime.php';
    defined('RUNTIME_FILE') or define('RUNTIME_FILE', RUNTIME_PATH . $runtime);
    if (!APP_DEBUG && is_file(RUNTIME_FILE)) {
        require RUNTIME_FILE;
    } else {
        require THINK_PATH . 'Common/runtime.php';
    }
}
