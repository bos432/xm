<?php

namespace App\Http\Controllers;

use App\Models\DictionaryItem;
use Illuminate\Http\Request;

class DictionaryController extends Controller
{
    public function index(Request $request)
    {
        $query = DictionaryItem::query()->where('is_active', true);

        if ($group = $request->query('group')) {
            $query->where('group', $group);
        }

        return $query->orderBy('group')->orderBy('sort_order')->orderBy('id')->get();
    }
}

