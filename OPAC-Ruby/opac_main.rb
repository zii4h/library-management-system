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

# --- SSL FIX FOR MARIADB ---
ENV['MARIADB_TLS_DISABLE_PEER_VERIFICATION'] = '1'

# --- LIBRARIES ---
# sinatra : Lightweight Ruby web framework. Handles HTTP routes (GET/POST),
#           renders HTML views, and runs a local web server on port 4567.
# mysql2  : Ruby gem for connecting and querying a MySQL/MariaDB database.
# date    : Ruby standard library for date arithmetic (overdue calculation).
require 'sinatra'
require 'mysql2'
require 'date'

# =============================================================================
# CONSTANTS
# =============================================================================
DB_CONFIG = {
  
  host:     'localhost',
  username: 'root',
  password: '',
  database: 'opac_db' 
}.freeze

OVERDUE_FEE_PER_DAY = 10  # PHP 10 per day overdue
ADMIN_PASSWORD      = 'admin123'  # Change this to your preferred admin password

# =============================================================================
# SINATRA CONFIGURATION
# webrick used for stable single-threaded MySQL connection
# =============================================================================
set :port, 4567
set :bind, 'localhost'
set :server, 'webrick'

# =============================================================================
# CLASS: Database
# PURPOSE: Manages MySQL connection, table setup, and disconnection.
# DEMONSTRATES: Encapsulation, Memory Allocation, Garbage Collection
# =============================================================================
class Database
  @connection = nil

  # SUBPROGRAM: connect
  # PURPOSE: Opens MySQL connection and sets up the database and both tables.
  # MEMORY: Allocates a Mysql2::Client object in memory.
  def self.connect
    @connection = Mysql2::Client.new(DB_CONFIG)
    setup_tables
    @connection
  rescue Mysql2::Error => e
    puts "[DB ERROR] #{e.message}"
    exit
  end

  # SUBPROGRAM: setup_tables
  # PURPOSE: Creates opac_db, books table, and borrowed_books table
  #          if they do not already exist.
  def self.setup_tables
    @connection.query("CREATE DATABASE IF NOT EXISTS opac_db")
    @connection.query("USE opac_db")

    # books table — permanent book catalog records
    @connection.query("
      CREATE TABLE IF NOT EXISTS books (
        book_id   INT AUTO_INCREMENT PRIMARY KEY,
        title     VARCHAR(255)                   NOT NULL,
        author    VARCHAR(255)                   NOT NULL,
        isbn      VARCHAR(50)   UNIQUE           NOT NULL,
        genre     VARCHAR(100),
        status    ENUM('available','borrowed')   DEFAULT 'available'
      ) ENGINE=InnoDB
    ")

    # borrowed_books table — borrowing transaction history
    # overdue_fee is DECIMAL(10,2) for accurate currency storage
    @connection.query("
      CREATE TABLE IF NOT EXISTS borrowed_books (
        borrow_id     INT AUTO_INCREMENT PRIMARY KEY,
        book_id       INT           NOT NULL,
        borrower_name VARCHAR(255)  NOT NULL,
        borrow_date   DATE          NOT NULL,
        due_date      DATE          NOT NULL,
        return_date   DATE          DEFAULT NULL,
        overdue_fee   DECIMAL(10,2) DEFAULT 0.00,
        FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
      ) ENGINE=InnoDB
    ")
  end

  def self.connection
    @connection
  end

  # SUBPROGRAM: disconnect
  # PURPOSE: Closes connection and releases memory for garbage collection.
  def self.disconnect
    @connection&.close
    @connection = nil
  end
end

# =============================================================================
# CLASS: Book (Abstract Data Type)
# PURPOSE: Represents a single book record from the books table.
# DEMONSTRATES: OOP, Encapsulation, ADT, Parameter Passing
# =============================================================================
class Book
  attr_accessor :book_id, :title, :author, :isbn, :genre, :status

  # SUBPROGRAM: initialize
  # PURPOSE: Constructor — creates a Book object with keyword arguments (by value).
  # MEMORY: Allocates a new Book object on the heap.
  def initialize(book_id: nil, title:, author:, isbn:, genre: 'General', status: 'available')
    @book_id = book_id
    @title   = title
    @author  = author
    @isbn    = isbn
    @genre   = genre
    @status  = status
  end
end

# =============================================================================
# CLASS: BorrowedBook (Abstract Data Type)
# PURPOSE: Represents a borrowing transaction from the borrowed_books table.
# DEMONSTRATES: OOP, Encapsulation, ADT, DECIMAL data type for overdue fee
# =============================================================================
class BorrowedBook
  attr_accessor :borrow_id, :book_id, :borrower_name, :borrow_date,
                :due_date, :return_date, :overdue_fee,
                :title, :author, :isbn, :genre

  # SUBPROGRAM: initialize
  # PURPOSE: Creates a BorrowedBook object holding transaction + book info.
  # PARAMETER PASSING: Keyword arguments (by value)
  def initialize(borrow_id: nil, book_id:, borrower_name:, borrow_date:,
                 due_date:, return_date: nil, overdue_fee: 0.00,
                 title: nil, author: nil, isbn: nil, genre: nil)
    @borrow_id     = borrow_id
    @book_id       = book_id
    @borrower_name = borrower_name
    @borrow_date   = borrow_date
    @due_date      = due_date
    @return_date   = return_date
    @overdue_fee   = overdue_fee.to_f
    @title         = title
    @author        = author
    @isbn          = isbn
    @genre         = genre
  end

  # SUBPROGRAM: overdue_info
  # PURPOSE: Computes overdue days and fee using the 'date' library.
  #          Fee is stored as DECIMAL(10,2) compatible float.
  # RETURNS: Hash { overdue: bool, days: int, fee: float }
  def overdue_info
    return { overdue: false, days: 0, fee: 0.00 } if @due_date.nil? || !@return_date.nil?
    due          = Date.parse(@due_date.to_s)
    today        = Date.today
    days_overdue = (today - due).to_i
    if days_overdue > 0
      { overdue: true, days: days_overdue, fee: (days_overdue * OVERDUE_FEE_PER_DAY).to_f }
    else
      { overdue: false, days: 0, fee: 0.00 }
    end
  end
end

# =============================================================================
# CLASS: BookRepository (Data Access Layer)
# PURPOSE: All SQL operations on both books and borrowed_books tables.
# DEMONSTRATES: Subprograms, Parameter Passing by Reference
# =============================================================================
class BookRepository

  # SUBPROGRAM: initialize
  # PARAMETER PASSING: db passed by reference (same Mysql2::Client in memory)
  def initialize(db)
    @db = db
  end

  # --- BOOKS TABLE ---

  # SUBPROGRAM: add_book — INSERT new book into books table
  def add_book(book)
    stmt = @db.prepare("INSERT INTO books (title, author, isbn, genre, status) VALUES (?, ?, ?, ?, 'available')")
    stmt.execute(book.title, book.author, book.isbn, book.genre)
  rescue Mysql2::Error => e
    raise e.message
  end

  # SUBPROGRAM: all_books — SELECT all books
  def all_books
    @db.query("SELECT * FROM books ORDER BY book_id DESC").map { |row| row_to_book(row) }
  end

  # SUBPROGRAM: find_book_by_id — SELECT single book by primary key
  def find_book_by_id(id)
    result = @db.prepare("SELECT * FROM books WHERE book_id = ?").execute(id).first
    result ? row_to_book(result) : nil
  end

  # SUBPROGRAM: search_books — SELECT books matching search term
  def search_books(term)
    like = "%#{term}%"
    @db.prepare("SELECT * FROM books WHERE title LIKE ? OR author LIKE ? OR isbn LIKE ? ORDER BY book_id DESC")
       .execute(like, like, like).map { |row| row_to_book(row) }
  end

  # SUBPROGRAM: update_book — UPDATE existing book record
  def update_book(book)
    @db.prepare("UPDATE books SET title=?, author=?, isbn=?, genre=?, status=? WHERE book_id=?")
       .execute(book.title, book.author, book.isbn, book.genre, book.status, book.book_id)
  rescue Mysql2::Error => e
    raise e.message
  end

  # SUBPROGRAM: delete_book — DELETE book (CASCADE removes borrowed_books rows too)
  def delete_book(id)
    @db.prepare("DELETE FROM books WHERE book_id = ?").execute(id)
  end

  # --- BORROWED_BOOKS TABLE ---

  # SUBPROGRAM: borrow_book
  # PURPOSE: INSERT a new borrowing transaction and set book status to 'borrowed'
  def borrow_book(transaction)
    @db.prepare("INSERT INTO borrowed_books (book_id, borrower_name, borrow_date, due_date, overdue_fee) VALUES (?, ?, ?, ?, 0.00)")
       .execute(transaction.book_id, transaction.borrower_name, transaction.borrow_date, transaction.due_date)
    @db.prepare("UPDATE books SET status='borrowed' WHERE book_id=?").execute(transaction.book_id)
  rescue Mysql2::Error => e
    raise e.message
  end

  # SUBPROGRAM: return_book
  # PURPOSE: UPDATE borrowed_books with return_date and overdue_fee (DECIMAL),
  #          then set book status back to 'available'
  def return_book(borrow_id, book_id, return_date, overdue_fee)
    @db.prepare("UPDATE borrowed_books SET return_date=?, overdue_fee=? WHERE borrow_id=?")
       .execute(return_date, overdue_fee, borrow_id)
    @db.prepare("UPDATE books SET status='available' WHERE book_id=?").execute(book_id)
  end

  # SUBPROGRAM: active_borrow
  # PURPOSE: Find the current unreturned borrow record for a book (JOIN query)
  def active_borrow(book_id)
    result = @db.prepare("
      SELECT bb.*, b.title, b.author, b.isbn, b.genre
      FROM borrowed_books bb
      JOIN books b ON bb.book_id = b.book_id
      WHERE bb.book_id = ? AND bb.return_date IS NULL
      ORDER BY bb.borrow_id DESC LIMIT 1
    ").execute(book_id).first
    result ? row_to_borrowed(result) : nil
  end

  # SUBPROGRAM: all_borrowed — SELECT all active (unreturned) borrowed books
  def all_borrowed
    @db.query("
      SELECT bb.*, b.title, b.author, b.isbn, b.genre
      FROM borrowed_books bb
      JOIN books b ON bb.book_id = b.book_id
      WHERE bb.return_date IS NULL
      ORDER BY bb.due_date ASC
    ").map { |row| row_to_borrowed(row) }
  end

  # SUBPROGRAM: overdue_books — returns all active borrowed books past due date
  def overdue_books
    all_borrowed.select { |b| b.overdue_info[:overdue] }
  end

  # SUBPROGRAM: stats — summary counts for dashboard
  def stats
    total    = @db.query("SELECT COUNT(*) AS c FROM books").first['c']
    borrowed = @db.query("SELECT COUNT(*) AS c FROM books WHERE status='borrowed'").first['c']
    overdue  = overdue_books.size
    { total: total, borrowed: borrowed, overdue: overdue, available: total - borrowed }
  end

  private

  # SUBPROGRAM: row_to_book — converts DB row hash to Book object
  def row_to_book(row)
    Book.new(book_id: row['book_id'], title: row['title'], author: row['author'],
             isbn: row['isbn'], genre: row['genre'], status: row['status'])
  end

  # SUBPROGRAM: row_to_borrowed — converts DB row hash to BorrowedBook object
  def row_to_borrowed(row)
    BorrowedBook.new(
      borrow_id: row['borrow_id'], book_id: row['book_id'],
      borrower_name: row['borrower_name'], borrow_date: row['borrow_date'],
      due_date: row['due_date'], return_date: row['return_date'],
      overdue_fee: row['overdue_fee'].to_f,
      title: row['title'], author: row['author'], isbn: row['isbn'], genre: row['genre']
    )
  end
end

# =============================================================================
# INITIALIZATION
# =============================================================================
Database.connect

before do
  begin
    Database.connection.ping
  rescue
    Database.connect
  end
  @repo = BookRepository.new(Database.connection)
end

at_exit { Database.disconnect }
enable :sessions

# =============================================================================
# ADMIN AUTH HELPERS (defined before routes so they are available everywhere)
# =============================================================================

# SUBPROGRAM: admin?
# PURPOSE: Checks if the current session is logged in as admin.
def admin?
  session[:admin] == true
end

# SUBPROGRAM: require_admin
# PURPOSE: Redirects to login page if not logged in as admin.
def require_admin
  unless admin?
    session[:flash] = { type: 'error', msg: 'Please log in as admin to access that page.' }
    redirect '/login'
  end
end

# =============================================================================
# SINATRA ROUTES (Event-Driven Programming)
# =============================================================================

get '/' do
  search  = params[:search].to_s.strip
  @books  = search.empty? ? @repo.all_books : @repo.search_books(search)
  @stats  = @repo.stats
  @search = search
  @flash  = session.delete(:flash)
  erb :index
end

get '/login' do
  @flash = session.delete(:flash)
  erb :login
end

post '/login' do
  if params[:password] == ADMIN_PASSWORD
    session[:admin] = true
    session[:flash] = { type: 'success', msg: 'Logged in as admin.' }
    redirect '/'
  else
    session[:flash] = { type: 'error', msg: 'Incorrect password.' }
    redirect '/login'
  end
end

get '/logout' do
  session[:admin] = nil
  session[:flash] = { type: 'success', msg: 'Logged out successfully.' }
  redirect '/'
end

get '/add' do
  require_admin
  @flash = session.delete(:flash)
  erb :add
end

post '/add' do
  require_admin
  book = Book.new(title: params[:title].strip, author: params[:author].strip,
                  isbn: params[:isbn].strip, genre: params[:genre].strip)
  begin
    @repo.add_book(book)
    session[:flash] = { type: 'success', msg: "Book '#{book.title}' added successfully!" }
  rescue => e
    session[:flash] = { type: 'error', msg: "Error: #{e}" }
  end
  redirect '/'
end

get '/edit/:id' do
  require_admin
  @book  = @repo.find_book_by_id(params[:id].to_i)
  halt 404, "Book not found" if @book.nil?
  @flash = session.delete(:flash)
  erb :edit
end

post '/edit/:id' do
  require_admin
  book = @repo.find_book_by_id(params[:id].to_i)
  halt 404 if book.nil?
  book.title  = params[:title].strip
  book.author = params[:author].strip
  book.isbn   = params[:isbn].strip
  book.genre  = params[:genre].strip
  begin
    @repo.update_book(book)
    session[:flash] = { type: 'success', msg: "Book updated successfully!" }
  rescue => e
    session[:flash] = { type: 'error', msg: "Error: #{e}" }
  end
  redirect '/'
end

post '/delete/:id' do
  require_admin
  book = @repo.find_book_by_id(params[:id].to_i)
  if book
    @repo.delete_book(params[:id].to_i)
    session[:flash] = { type: 'success', msg: "Book '#{book.title}' deleted." }
  end
  redirect '/'
end

get '/borrow/:id' do
  require_admin
  @book  = @repo.find_book_by_id(params[:id].to_i)
  halt 404 if @book.nil?
  @today = Date.today.to_s
  erb :borrow
end

post '/borrow/:id' do
  require_admin
  book = @repo.find_book_by_id(params[:id].to_i)
  halt 404 if book.nil?
  transaction = BorrowedBook.new(book_id: book.book_id,
                                  borrower_name: params[:borrower].strip,
                                  borrow_date: params[:borrow_date],
                                  due_date: params[:due_date])
  begin
    @repo.borrow_book(transaction)
    session[:flash] = { type: 'success', msg: "Book borrowed by #{transaction.borrower_name}." }
  rescue => e
    session[:flash] = { type: 'error', msg: "Error: #{e}" }
  end
  redirect '/'
end

post '/return/:id' do
  require_admin
  book        = @repo.find_book_by_id(params[:id].to_i)
  halt 404 if book.nil?
  transaction = @repo.active_borrow(book.book_id)
  halt 404 if transaction.nil?

  info        = transaction.overdue_info
  overdue_fee = info[:fee]
  return_date = Date.today.to_s

  @repo.return_book(transaction.borrow_id, book.book_id, return_date, overdue_fee)

  msg = info[:overdue] ?
    "Book returned. Overdue fee: PHP #{'%.2f' % overdue_fee} (#{info[:days]} days overdue)" :
    "Book returned on time. No fees."

  session[:flash] = { type: info[:overdue] ? 'warning' : 'success', msg: msg }
  redirect '/'
end

get '/overdue' do
  require_admin
  @books = @repo.overdue_books
  @stats = @repo.stats
  @flash = session.delete(:flash)
  erb :overdue
end