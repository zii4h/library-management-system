<img width="1920" height="1080" alt="Image" src="https://github.com/user-attachments/assets/961e99c5-4056-454c-a1f3-cf69ac08e7ac" />

# OPAC System — Online Public Access Catalog

Built with Ruby + Sinatra + MySQL

---

## Requirements
- Ruby 3.x with DevKit — https://rubyinstaller.org
- XAMPP — https://www.apachefriends.org

---

## Setup

**1. Install gems**
```
gem install sinatra
gem install webrick
gem install mysql2 -- --with-mysql-lib="C:/Ruby34-x64/msys64/ucrt64/lib" --with-mysql-include="C:/Ruby34-x64/msys64/ucrt64/include/mariadb"
```

**2. Start XAMPP — run both MySQL and Apache**

**3. Import the database**
- Go to `http://localhost/phpmyadmin`
- Create a database named `opac_db`
- Import `opac_db.sql` from the project folder

**4. Run the program**
```
ruby opac_main.rb
```

**5. Open in browser**
```
http://localhost:4567
```

---

## Troubleshooting

**MySQL won't start**
- Open `services.msc`, stop any conflicting MySQL/MariaDB service, then retry.

**Access denied error** 
- Make sure MySQL is running in XAMPP before running the program.

**mysql2 install fails** 
- Make sure Ruby was installed with DevKit and `ridk install` was completed.

**Books not showing** — Import `opac_db.sql` in phpMyAdmin first.
