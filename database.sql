-- ============================================================
-- DATABASE: erp_praktikum  (UTS Praktikum ERP - PHP Native)
-- Kompatibel: MySQL 5.7+/8 dan MariaDB 10.3+ (XAMPP/Laragon)
-- Cara impor: phpMyAdmin > Import, atau
--   mysql -u root -p < database.sql
-- ============================================================

DROP DATABASE IF EXISTS erp_praktikum;
CREATE DATABASE erp_praktikum CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE erp_praktikum;

-- ------------------------------------------------------------
-- PRAKTIKUM 2: PENGGUNA, PERAN, HAK AKSES, AUDIT, BACKUP
-- ------------------------------------------------------------
CREATE TABLE peran (
  id_peran INT AUTO_INCREMENT PRIMARY KEY,
  nama_peran VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE modul (
  id_modul INT AUTO_INCREMENT PRIMARY KEY,
  nama_modul VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Matriks hak akses (peran x modul)
CREATE TABLE hak_akses (
  id_peran INT NOT NULL,
  id_modul INT NOT NULL,
  level_akses VARCHAR(30) NOT NULL,           -- contoh: Kelola, Lihat stok, Terima barang
  bisa_ubah TINYINT(1) NOT NULL DEFAULT 0,    -- 1 = boleh mengubah data modul
  PRIMARY KEY (id_peran, id_modul),
  FOREIGN KEY (id_peran) REFERENCES peran(id_peran),
  FOREIGN KEY (id_modul) REFERENCES modul(id_modul)
) ENGINE=InnoDB;

CREATE TABLE pengguna (
  id_pengguna INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  nama_lengkap VARCHAR(100) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,        -- gunakan password_hash() di PHP
  id_peran INT NOT NULL,
  aktif TINYINT(1) NOT NULL DEFAULT 1,
  dibuat_pada TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (id_peran) REFERENCES peran(id_peran)
) ENGINE=InnoDB;

CREATE TABLE audit_log (
  id_log BIGINT AUTO_INCREMENT PRIMARY KEY,
  waktu TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  id_pengguna INT NULL,
  aksi VARCHAR(50) NOT NULL,                  -- LOGIN, INSERT, UPDATE, AKSES_DITOLAK, dll
  modul VARCHAR(50) NULL,
  keterangan VARCHAR(255) NULL,
  ip_address VARCHAR(45) NULL,
  FOREIGN KEY (id_pengguna) REFERENCES pengguna(id_pengguna) ON DELETE SET NULL,
  INDEX idx_audit_waktu (waktu)
) ENGINE=InnoDB;

CREATE TABLE backup_log (
  id_backup INT AUTO_INCREMENT PRIMARY KEY,
  jenis ENUM('Harian','Mingguan') NOT NULL,
  waktu_mulai DATETIME NOT NULL,
  status ENUM('Sukses','Gagal') NOT NULL,
  lokasi VARCHAR(150) NULL,
  terenkripsi TINYINT(1) NOT NULL DEFAULT 1,
  teruji_restore TINYINT(1) NOT NULL DEFAULT 0,
  retensi_hari INT NOT NULL DEFAULT 14
) ENGINE=InnoDB;

CREATE TABLE skenario_gangguan (
  id_skenario INT AUTO_INCREMENT PRIMARY KEY,
  kode VARCHAR(20) NOT NULL UNIQUE,           -- db, server, internet, access, backup
  nama_gangguan VARCHAR(100) NOT NULL,
  langkah_penanganan TEXT NOT NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- PRAKTIKUM 1: DATA MASTER & PESANAN
-- ------------------------------------------------------------
CREATE TABLE pelanggan (
  id_pelanggan INT AUTO_INCREMENT PRIMARY KEY,
  nama VARCHAR(100) NOT NULL,
  alamat VARCHAR(255) NULL,
  termin_bayar_hari INT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE pemasok (
  id_pemasok INT AUTO_INCREMENT PRIMARY KEY,
  nama VARCHAR(100) NOT NULL,
  kontak VARCHAR(100) NULL,
  lead_time_hari INT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE produk (
  id_produk INT AUTO_INCREMENT PRIMARY KEY,
  sku VARCHAR(30) NOT NULL UNIQUE,
  nama VARCHAR(100) NOT NULL,
  satuan VARCHAR(20) NOT NULL DEFAULT 'unit',
  harga DECIMAL(15,2) NOT NULL,
  stok INT NOT NULL DEFAULT 0,
  stok_minimum INT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE pesanan (
  id_pesanan INT AUTO_INCREMENT PRIMARY KEY,
  no_pesanan VARCHAR(30) NOT NULL UNIQUE,     -- ORD-2026-001
  id_pelanggan INT NOT NULL,
  tanggal DATE NOT NULL,
  status ENUM('Draft','Dikonfirmasi','Stok kurang','Selesai','Batal') NOT NULL DEFAULT 'Draft',
  total DECIMAL(15,2) NOT NULL DEFAULT 0,
  FOREIGN KEY (id_pelanggan) REFERENCES pelanggan(id_pelanggan)
) ENGINE=InnoDB;

CREATE TABLE pesanan_detail (
  id_detail INT AUTO_INCREMENT PRIMARY KEY,
  id_pesanan INT NOT NULL,
  id_produk INT NOT NULL,
  qty INT NOT NULL,
  harga_satuan DECIMAL(15,2) NOT NULL,
  CONSTRAINT chk_qty_positif CHECK (qty > 0),  -- aturan: jumlah harus positif
  FOREIGN KEY (id_pesanan) REFERENCES pesanan(id_pesanan) ON DELETE CASCADE,
  FOREIGN KEY (id_produk) REFERENCES produk(id_produk)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- PRAKTIKUM 3: PROSES BISNIS & PO
-- ------------------------------------------------------------
CREATE TABLE proses_bisnis (
  id_langkah INT AUTO_INCREMENT PRIMARY KEY,
  jenis ENUM('as-is','to-be') NOT NULL,
  urutan INT NOT NULL,
  nama_langkah VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE aturan_bisnis (
  id_aturan INT AUTO_INCREMENT PRIMARY KEY,
  kode VARCHAR(10) NOT NULL UNIQUE,
  deskripsi VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE po (
  id_po INT AUTO_INCREMENT PRIMARY KEY,
  no_po VARCHAR(30) NOT NULL UNIQUE,
  id_pemasok INT NOT NULL,
  tanggal DATE NOT NULL,
  total_nilai DECIMAL(15,2) NOT NULL DEFAULT 0,
  status ENUM('Draft','Disetujui','Sebagian diterima','Diterima','Batal') NOT NULL DEFAULT 'Draft',
  FOREIGN KEY (id_pemasok) REFERENCES pemasok(id_pemasok)
) ENGINE=InnoDB;

-- Simulasi perubahan harga PO (perlu persetujuan ulang)
CREATE TABLE po_perubahan_harga (
  id_perubahan INT AUTO_INCREMENT PRIMARY KEY,
  id_po INT NOT NULL,
  nilai_awal DECIMAL(15,2) NOT NULL,
  nilai_baru DECIMAL(15,2) NOT NULL,
  selisih DECIMAL(15,2) AS (nilai_baru - nilai_awal) STORED,
  persen DECIMAL(8,2) AS (IF(nilai_awal = 0, NULL, (nilai_baru - nilai_awal) / nilai_awal * 100)) STORED,
  status ENUM('Menunggu persetujuan','Disetujui','Ditolak') NOT NULL DEFAULT 'Menunggu persetujuan',
  FOREIGN KEY (id_po) REFERENCES po(id_po)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- PRAKTIKUM 4: KEUANGAN (JURNAL DOUBLE-ENTRY)
-- ------------------------------------------------------------
CREATE TABLE akun (
  id_akun INT AUTO_INCREMENT PRIMARY KEY,
  kode VARCHAR(10) NOT NULL UNIQUE,
  nama VARCHAR(100) NOT NULL,
  tipe ENUM('Aset','Kewajiban','Ekuitas','Pendapatan','Beban') NOT NULL,
  saldo_normal ENUM('D','K') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE jurnal (
  id_jurnal INT AUTO_INCREMENT PRIMARY KEY,
  no_referensi VARCHAR(30) NOT NULL UNIQUE,   -- UNIQUE => mencegah transaksi duplikat
  tanggal DATE NOT NULL,
  keterangan VARCHAR(255) NOT NULL,
  dibuat_oleh INT NULL,
  FOREIGN KEY (dibuat_oleh) REFERENCES pengguna(id_pengguna) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE jurnal_detail (
  id_detail INT AUTO_INCREMENT PRIMARY KEY,
  id_jurnal INT NOT NULL,
  id_akun INT NOT NULL,
  debit DECIMAL(15,2) NOT NULL DEFAULT 0,
  kredit DECIMAL(15,2) NOT NULL DEFAULT 0,
  CONSTRAINT chk_sisi CHECK ((debit > 0 AND kredit = 0) OR (kredit > 0 AND debit = 0)),
  FOREIGN KEY (id_jurnal) REFERENCES jurnal(id_jurnal) ON DELETE CASCADE,
  FOREIGN KEY (id_akun) REFERENCES akun(id_akun)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- PRAKTIKUM 5: SCM, BOM, KEBUTUHAN MATERIAL
-- ------------------------------------------------------------
CREATE TABLE bahan (
  id_bahan INT AUTO_INCREMENT PRIMARY KEY,
  nama VARCHAR(100) NOT NULL,
  satuan VARCHAR(20) NOT NULL DEFAULT 'unit',
  stok INT NOT NULL DEFAULT 0,
  lead_time_hari INT NOT NULL DEFAULT 0,       -- hari kerja
  id_pemasok INT NULL,
  FOREIGN KEY (id_pemasok) REFERENCES pemasok(id_pemasok) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE bom (
  id_produk INT NOT NULL,
  id_bahan INT NOT NULL,
  qty_per_produk DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id_produk, id_bahan),
  FOREIGN KEY (id_produk) REFERENCES produk(id_produk),
  FOREIGN KEY (id_bahan) REFERENCES bahan(id_bahan)
) ENGINE=InnoDB;

CREATE TABLE po_detail (
  id_detail INT AUTO_INCREMENT PRIMARY KEY,
  id_po INT NOT NULL,
  id_bahan INT NOT NULL,
  qty_pesan INT NOT NULL,
  qty_diterima INT NOT NULL DEFAULT 0,
  FOREIGN KEY (id_po) REFERENCES po(id_po) ON DELETE CASCADE,
  FOREIGN KEY (id_bahan) REFERENCES bahan(id_bahan)
) ENGINE=InnoDB;

CREATE TABLE rencana_produksi (
  id_rencana INT AUTO_INCREMENT PRIMARY KEY,
  id_produk INT NOT NULL,
  target_qty INT NOT NULL,
  batas_kebutuhan_hari INT NOT NULL,           -- tenggat material dibutuhkan (hari kerja)
  FOREIGN KEY (id_produk) REFERENCES produk(id_produk)
) ENGINE=InnoDB;

CREATE TABLE simulasi_keterlambatan (
  id_simulasi INT AUTO_INCREMENT PRIMARY KEY,
  id_bahan INT NOT NULL,
  lead_time_baru_hari INT NOT NULL,
  keputusan TEXT NULL,
  FOREIGN KEY (id_bahan) REFERENCES bahan(id_bahan)
) ENGINE=InnoDB;

-- ============================================================
-- DATA AWAL (SEED) - sesuai angka pada index.php
-- ============================================================

-- Peran & modul
INSERT INTO peran (nama_peran) VALUES
('Admin ERP'),('Penjualan'),('Gudang'),('Produksi'),('Pembelian'),('Keuangan');

INSERT INTO modul (nama_modul) VALUES
('Penjualan'),('Gudang'),('Produksi'),('Pembelian'),('Keuangan');

-- Matriks hak akses (urutan modul: 1 Penjualan, 2 Gudang, 3 Produksi, 4 Pembelian, 5 Keuangan)
INSERT INTO hak_akses (id_peran,id_modul,level_akses,bisa_ubah) VALUES
(1,1,'Kelola',1),(1,2,'Kelola',1),(1,3,'Kelola',1),(1,4,'Kelola',1),(1,5,'Kelola',1),
(2,1,'Kelola pesanan',1),(2,2,'Lihat stok',0),(2,3,'Lihat status',0),(2,5,'Lihat tagihan',0),
(3,1,'Lihat pesanan',0),(3,2,'Kelola stok',1),(3,3,'Lihat kebutuhan',0),(3,4,'Terima barang',1),
(4,2,'Lihat stok',0),(4,3,'Kelola jadwal',1),(4,4,'Lihat kebutuhan',0),
(5,2,'Lihat stok',0),(5,3,'Lihat kebutuhan',0),(5,4,'Kelola PO',1),(5,5,'Lihat tagihan',0),
(6,1,'Lihat faktur',0),(6,4,'Lihat tagihan',0),(6,5,'Kelola jurnal',1);

-- Pengguna contoh. Kolom password_hash sengaja diisi 'BELUM_DIISI';
-- jalankan setup_password.php sekali untuk mengisi hash (password awal: admin123).
INSERT INTO pengguna (username,nama_lengkap,password_hash,id_peran) VALUES
('admin','Administrator ERP','BELUM_DIISI',1),
('sales01','Staf Penjualan','BELUM_DIISI',2),
('gudang01','Staf Gudang','BELUM_DIISI',3),
('produksi01','Staf Produksi','BELUM_DIISI',4),
('beli01','Staf Pembelian','BELUM_DIISI',5),
('keu01','Staf Keuangan','BELUM_DIISI',6);

-- Backup & gangguan
INSERT INTO backup_log (jenis,waktu_mulai,status,lokasi,terenkripsi,teruji_restore,retensi_hari) VALUES
('Harian','2026-11-01 23:00:00','Sukses','/backup/harian/erp_20261101.sql.enc',1,1,14),
('Mingguan','2026-10-31 23:30:00','Sukses','Lokasi terpisah (offsite)/erp_w44.sql.enc',1,1,56);

INSERT INTO skenario_gangguan (kode,nama_gangguan,langkah_penanganan) VALUES
('db','Database tidak dapat diakses','Hentikan transaksi berisiko, periksa koneksi dan log, pulihkan dari backup tervalidasi, lalu rekonsiliasi transaksi.'),
('server','Server aplikasi terganggu','Periksa log dan sumber daya server, pulihkan layanan atau alihkan ke server cadangan, lalu uji transaksi sebelum sistem dibuka.'),
('internet','Internet terputus','Periksa jaringan/ISP. Hindari input transaksi ganda; gunakan prosedur offline yang disetujui dan rekonsiliasi setelah koneksi pulih.'),
('access','Pengguna tidak berwenang membuka keuangan','Tolak akses, catat percobaan dalam audit log, beri tahu administrator, dan periksa role pengguna.'),
('backup','Backup tidak berjalan / data hilang','Batasi perubahan, identifikasi backup valid, pulihkan di lingkungan pengujian, verifikasi integritas, lalu rekonsiliasi transaksi.');

-- Master data
INSERT INTO pelanggan (nama,alamat,termin_bayar_hari) VALUES
('Universitas Contoh','Jl. Pendidikan No. 1, Jakarta',30);

INSERT INTO pemasok (nama,kontak,lead_time_hari) VALUES
('Pemasok Bahan A','021-1111111',4),
('Pemasok Bahan B','021-2222222',7),
('Pemasok Perlengkapan Lab','021-3333333',5);

INSERT INTO produk (sku,nama,satuan,harga,stok,stok_minimum) VALUES
('MJ-PRK-001','Meja Praktikum','unit',250000,15,5);

-- Praktikum 1: pesanan ORD-2026-001 (10 unit x Rp250.000 = Rp2.500.000)
INSERT INTO pesanan (no_pesanan,id_pelanggan,tanggal,status,total) VALUES
('ORD-2026-001',1,'2026-11-02','Dikonfirmasi',2500000);
INSERT INTO pesanan_detail (id_pesanan,id_produk,qty,harga_satuan) VALUES (1,1,10,250000);

-- Praktikum 3: proses bisnis & aturan
INSERT INTO proses_bisnis (jenis,urutan,nama_langkah) VALUES
('as-is',1,'Dosen mengajukan permintaan'),
('as-is',2,'Kepala lab memverifikasi'),
('as-is',3,'Gudang mengecek stok'),
('as-is',4,'Pembelian memilih pemasok'),
('as-is',5,'Pimpinan menyetujui'),
('as-is',6,'Gudang menerima barang'),
('as-is',7,'Keuangan memproses pembayaran'),
('to-be',1,'Permintaan digital'),
('to-be',2,'Verifikasi'),
('to-be',3,'Cek stok ERP'),
('to-be',4,'Persetujuan'),
('to-be',5,'Purchase Order'),
('to-be',6,'Penerimaan'),
('to-be',7,'Pembayaran');

INSERT INTO aturan_bisnis (kode,deskripsi) VALUES
('01','Permintaan harus memiliki identitas pengaju.'),
('02','Pembelian harus diperiksa terhadap stok.'),
('03','Pesanan hanya boleh disetujui pihak berwenang.'),
('04','Pembayaran harus didukung dokumen yang sesuai.'),
('05','Barang diterima harus dicocokkan dengan PO dan jumlah aktual.');

-- PO simulasi harga (Rp5.000.000 -> penawaran baru Rp5.600.000)
INSERT INTO po (no_po,id_pemasok,tanggal,total_nilai,status) VALUES
('PO-2026-001',3,'2026-10-28',5000000,'Disetujui'),
-- PO bahan A yang belum diterima (100 unit), dipakai Praktikum 5
('PO-2026-002',1,'2026-10-30',0,'Disetujui');

INSERT INTO po_perubahan_harga (id_po,nilai_awal,nilai_baru) VALUES (1,5000000,5600000);

-- Praktikum 4: akun & jurnal
INSERT INTO akun (kode,nama,tipe,saldo_normal) VALUES
('1-100','Kas','Aset','D'),
('1-200','Piutang Usaha','Aset','D'),
('1-300','Persediaan','Aset','D'),
('2-100','Utang Usaha','Kewajiban','K'),
('3-100','Modal','Ekuitas','K'),
('4-100','Penjualan','Pendapatan','K'),
('5-100','Beban Operasional','Beban','D');

INSERT INTO jurnal (no_referensi,tanggal,keterangan) VALUES
('JU-000','2026-11-01','Saldo awal kas'),
('JU-001','2026-11-02','Pembelian bahan baku secara kredit'),
('JU-002','2026-11-02','Pembayaran utang pemasok'),
('JU-003','2026-11-02','Penjualan produk secara kredit'),
('JU-004','2026-11-02','Penerimaan pembayaran pelanggan'),
('JU-005','2026-11-02','Pembayaran biaya operasional tunai');

INSERT INTO jurnal_detail (id_jurnal,id_akun,debit,kredit) VALUES
(1,1,30000000,0),(1,5,0,30000000),   -- saldo awal: Kas D / Modal K
(2,3,8000000,0),(2,4,0,8000000),     -- Persediaan D / Utang Usaha K
(3,4,3000000,0),(3,1,0,3000000),     -- Utang Usaha D / Kas K
(4,2,12000000,0),(4,6,0,12000000),   -- Piutang D / Penjualan K
(5,1,5000000,0),(5,2,0,5000000),     -- Kas D / Piutang K
(6,7,1500000,0),(6,1,0,1500000);     -- Beban Operasional D / Kas K

-- Praktikum 5: bahan, BOM, PO belum diterima, rencana produksi
INSERT INTO bahan (nama,satuan,stok,lead_time_hari,id_pemasok) VALUES
('Bahan A','unit',400,4,1),
('Bahan B','unit',250,7,2);

INSERT INTO bom (id_produk,id_bahan,qty_per_produk) VALUES (1,1,3),(1,2,2);

INSERT INTO po_detail (id_po,id_bahan,qty_pesan,qty_diterima) VALUES (2,1,100,0);

INSERT INTO rencana_produksi (id_produk,target_qty,batas_kebutuhan_hari) VALUES (1,300,6);

INSERT INTO simulasi_keterlambatan (id_bahan,lead_time_baru_hari,keputusan) VALUES
(2,10,'Cari pemasok alternatif, verifikasi spesifikasi dan kualitas, minta persetujuan biaya tambahan, atau susun ulang jadwal produksi. Pantau PO dan penerimaan barang di ERP.');

-- ============================================================
-- VIEW HASIL PERHITUNGAN
-- ============================================================

-- Saldo tiap akun (Praktikum 4): kas akhir = 30.500.000, piutang = 7.000.000, utang = 5.000.000
CREATE VIEW v_saldo_akun AS
SELECT a.kode, a.nama, a.tipe,
       CASE WHEN a.saldo_normal='D'
            THEN COALESCE(SUM(d.debit),0) - COALESCE(SUM(d.kredit),0)
            ELSE COALESCE(SUM(d.kredit),0) - COALESCE(SUM(d.debit),0) END AS saldo
FROM akun a
LEFT JOIN jurnal_detail d ON d.id_akun = a.id_akun
GROUP BY a.id_akun, a.kode, a.nama, a.tipe, a.saldo_normal;

-- Cek jurnal seimbang (debit = kredit); semua baris harus 'Seimbang'
CREATE VIEW v_cek_jurnal AS
SELECT j.no_referensi, SUM(d.debit) AS total_debit, SUM(d.kredit) AS total_kredit,
       IF(SUM(d.debit)=SUM(d.kredit),'Seimbang','TIDAK SEIMBANG') AS status
FROM jurnal j JOIN jurnal_detail d ON d.id_jurnal = j.id_jurnal
GROUP BY j.id_jurnal, j.no_referensi;

-- Kebutuhan material (Praktikum 5):
-- bersih = GREATEST(0, bruto - stok - PO belum diterima)
-- Hasil: Bahan A = 0, Bahan B = 350
CREATE VIEW v_kebutuhan_material AS
SELECT b.nama AS bahan,
       r.target_qty,
       m.qty_per_produk,
       r.target_qty * m.qty_per_produk AS kebutuhan_bruto,
       b.stok AS stok_tersedia,
       COALESCE((SELECT SUM(pd.qty_pesan - pd.qty_diterima)
                 FROM po_detail pd JOIN po p ON p.id_po = pd.id_po
                 WHERE pd.id_bahan = b.id_bahan AND p.status <> 'Batal'),0) AS po_belum_diterima,
       GREATEST(0, r.target_qty * m.qty_per_produk - b.stok
                 - COALESCE((SELECT SUM(pd.qty_pesan - pd.qty_diterima)
                             FROM po_detail pd JOIN po p ON p.id_po = pd.id_po
                             WHERE pd.id_bahan = b.id_bahan AND p.status <> 'Batal'),0)) AS kebutuhan_bersih,
       b.lead_time_hari
FROM rencana_produksi r
JOIN bom m ON m.id_produk = r.id_produk
JOIN bahan b ON b.id_bahan = m.id_bahan;

-- Simulasi keterlambatan pemasok: potensi terlambat = lead time baru - batas kebutuhan (Bahan B: 4 hari)
CREATE VIEW v_keterlambatan AS
SELECT b.nama AS bahan, b.lead_time_hari AS lead_time_lama, s.lead_time_baru_hari,
       r.batas_kebutuhan_hari,
       GREATEST(0, s.lead_time_baru_hari - r.batas_kebutuhan_hari) AS potensi_terlambat_hari,
       s.keputusan
FROM simulasi_keterlambatan s
JOIN bahan b ON b.id_bahan = s.id_bahan
JOIN rencana_produksi r ON r.id_rencana = 1;

-- Status ketersediaan stok pesanan (Praktikum 1)
CREATE VIEW v_status_pesanan AS
SELECT p.no_pesanan, pr.nama AS produk, d.qty AS jumlah_pesan,
       pr.stok AS stok_awal, pr.stok - d.qty AS stok_setelah_pesanan,
       IF(d.qty <= pr.stok,'Dapat diproses','Stok kurang') AS status,
       p.total
FROM pesanan p
JOIN pesanan_detail d ON d.id_pesanan = p.id_pesanan
JOIN produk pr ON pr.id_produk = d.id_produk;

-- ============================================================
-- CONTOH PENGUJIAN (jalankan manual)
-- ============================================================
-- SELECT * FROM v_saldo_akun;
-- SELECT * FROM v_cek_jurnal;
-- SELECT * FROM v_kebutuhan_material;
-- SELECT * FROM v_keterlambatan;
-- SELECT * FROM v_status_pesanan;
--
-- Uji transaksi duplikat (Praktikum 4C): ini akan GAGAL karena no_referensi UNIQUE
-- INSERT INTO jurnal (no_referensi,tanggal,keterangan)
-- VALUES ('JU-002','2026-11-02','Pembayaran utang pemasok');
