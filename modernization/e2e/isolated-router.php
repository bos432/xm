<?php

$app = require __DIR__.'/isolated-app.php';
$app->handleRequest(Illuminate\Http\Request::capture());
