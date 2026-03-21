=begin

6DIPROGLANG | 2nd Semester, School Year 2025-2026
Final Project: OPAC (Online Public Access Catalog) System
Programming Language: Ruby
Framework: Sinatra (Web-based GUI)
Database: MySQL via mysql2 gem

File: opac_main.rb
Description: Main program file containing all classes, database logic, and Sinatra routes.

CLASSES: 
- Database        : Manages MySQL connection, table setup, and disconnection
- Book            : Abstract data type representing a book record
- BorrowedBook    : Abstract data type representing a borrowing transaction
- BookRepository  : Data access layer, all SQL operations on both tables

FEATURES:
- Add, Edit, Delete book records
- Borrow and Return books
- Overdue fee computation (PHP 10.00/day)
- Search by title, author, or ISBN
- Admin authentication with session management

=end

ENV['MARIADB_TLS_DISABLE_PEER_VERIFICATION'] = '1' #ignore (ssl fix)

DB_CONFIG = {
  host:     'localhost',
  username: 'root',
  password: '',
  database: 'opac_db' 
}.freeze

set :port, 4567 
set :bind, 'localhost'
set :server, 'webrick'


OVERDUE_FEE_PER_DAY = 10 
ADMIN_PASSWORD      = 'admin123'  


#class: database 
#purpose: manages mysql connection and table setup
class Database
  @connection = nil

  #subprogram: connect
  #purpose: opens mysql connection and table setup
  def self.connect
    @connection = Mysql2::Client.new(DB_CONFIG)
    setup_tables
    @connection
  rescue Mysql2::Error => e
    puts "[DB ERROR] #{e.message}"
    exit
  end


#subprogram: setup_tables
#purpose: creates opac_db, books_table, borrowed_books tables if they don't exist



#class: Book 
#purpose: represents a single book record from Books table
class Book 
  attr_accessor: 

  def initialize()

  end
end


#class: BorrowedBook
#purpose: represents borrowing transaction from Borrwed_Books table + overdue calculation
class BorrowedBook
  attr_accessor 

  def initialize()
  end

  #subprogram: overdue_info
  #purpose: date library. calculates if book is overdue + returns info
  def overdue_info
    return {} 

     if days_overdue > 0
      { overdue: true, days: days_overdue, fee: (days_overdue * OVERDUE_FEE_PER_DAY).to_f }
    else
      { overdue: false, days: 0, fee: 0.00 }
    end
  end
end

