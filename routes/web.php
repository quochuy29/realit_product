<?php

use Illuminate\Support\Facades\Route;

Route::view('/login', 'welcome')->name('login');

Route::get('/{any?}', function () {
    return view('welcome');
})->where('any', '.*');