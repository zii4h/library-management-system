# -------------------------------------------------------------------
# 6DIPROGLANG | 2nd Semester, School Year 2025-2026
# Final Project: OPAC (Online Public Access Catalog) System
# Programming Language: Ruby
# Framework: Sinatra (Web-based GUI)
# -------------------------------------------------------------------

ENV['MARIADB_TLS_DISABLE_PEER_VERIFICATION'] = '1' #ssl

DB_CONFIG = {
  host:     'localhost',
  username: 'root',
  password: '',
  database: 'opac_db' #xampp default db name
}.freeze

set :port, 4567 
set :bind, 'localhost'
set :server, 'webrick'


