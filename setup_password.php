<?php
// Jalankan SEKALI setelah impor database.sql: http://localhost:8000/setup_password.php
// Lalu HAPUS file ini.
$pdo = new PDO('mysql:host=localhost;dbname=erp_praktikum;charset=utf8mb4', 'root', ''); // sesuaikan user/password
$hash = password_hash('admin123', PASSWORD_DEFAULT);
$n = $pdo->prepare("UPDATE pengguna SET password_hash=? WHERE password_hash='BELUM_DIISI'")->execute([$hash]);
echo "Selesai. Semua pengguna contoh sekarang berpassword: admin123";
