<?php

return [
    'upload_max_kb' => env('UPLOAD_MAX_KB', 20480),
    'upload_allowed_extensions' => env('UPLOAD_ALLOWED_EXTENSIONS', 'jpg,jpeg,png,pdf,doc,docx,xls,xlsx,zip'),
    'upload_blocked_extensions' => env('UPLOAD_BLOCKED_EXTENSIONS', 'php,phtml,phar,asp,aspx,jsp,jspx,cer,asa,cdx,war,sh,bat,cmd,ps1,exe,dll'),
];

