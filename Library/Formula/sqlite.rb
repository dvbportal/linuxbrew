class Sqlite < Formula
  desc "Command-line interface for SQLite"
  homepage "https://sqlite.org/"
  url "https://sqlite.org/2015/sqlite-autoconf-3081100.tar.gz"
  sha256 "89640082f56b0aec1e691ba4976fb592ac905c791e616905d0a5f0c38e88b616"
  version "3.8.11"

  bottle do
    cellar :any
    sha256 "a3a7f8e291c1fea08149243776b3c123599e7e34aa22d6300a29d91121ffebd1" => :yosemite
    sha256 "4daa2b1368deb11ecf8d4b3a4b1fc9719c4031504c3b5fbef2e0a7b94a2e850e" => :mavericks
    sha256 "1ed6ef3d95c4213210fbedccae777111407c27f97faed76d56b99e791c0dc808" => :mountain_lion
  end

  keg_only :provided_by_osx, "OS X provides an older sqlite3."

  option :universal
  option "with-docs", "Install HTML documentation"
  option "without-rtree", "Disable the R*Tree index module"
  option "with-fts", "Enable the FTS module"
  option "with-secure-delete", "Defaults secure_delete to on"
  option "with-unlock-notify", "Enable the unlock notification feature"
  option "with-icu4c", "Enable the ICU module"
  option "with-functions", "Enable more math and string functions for SQL queries"
  option "with-dbstat", "Enable the 'dbstat' virtual table"

  depends_on "readline" => :recommended
  depends_on "icu4c" => :optional

  resource "functions" do
    url "https://www.sqlite.org/contrib/download/extension-functions.c?get=25", :using  => :nounzip
    version "2010-01-06"
    sha256 "991b40fe8b2799edc215f7260b890f14a833512c9d9896aa080891330ffe4052"
  end

  resource "docs" do
    url "https://sqlite.org/2015/sqlite-doc-3081100.zip"
    version "3.8.11"
    sha256 "54d1679325a1df1b62cff9c969c2a916139a78cc7a90256b00659089769856ae"
  end

  def install
    # Fix error: sqlite3.o: No such file or directory
    # See https://github.com/Homebrew/linuxbrew/issues/407
    ENV.deparallelize

    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_RTREE" if build.with? "rtree"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS" if build.with? "fts"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_COLUMN_METADATA"
    ENV.append "CPPFLAGS", "-DSQLITE_SECURE_DELETE" if build.with? "secure-delete"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_UNLOCK_NOTIFY" if build.with? "unlock-notify"
    ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_DBSTAT_VTAB" if build.with? "dbstat"

    if build.with? "icu4c"
      icu4c = Formula["icu4c"]
      icu4cldflags = `#{icu4c.opt_bin}/icu-config --ldflags`.tr("\n", " ")
      icu4ccppflags = `#{icu4c.opt_bin}/icu-config --cppflags`.tr("\n", " ")
      ENV.append "LDFLAGS", icu4cldflags
      ENV.append "CPPFLAGS", icu4ccppflags
      ENV.append "CPPFLAGS", "-DSQLITE_ENABLE_ICU"
    end

    ENV.universal_binary if build.universal?

    system "./configure", "--prefix=#{prefix}", "--disable-dependency-tracking", "--enable-dynamic-extensions"
    system "make", "install"

    if build.with? "functions"
      buildpath.install resource("functions")
      system ENV.cc, "-fno-common",
                     "-dynamiclib",
                     "extension-functions.c",
                     "-o", "libsqlitefunctions.dylib",
                     *ENV.cflags.to_s.split
      lib.install "libsqlitefunctions.dylib"
    end
    doc.install resource("docs") if build.with? "docs"
  end

  def caveats
    if build.with? "functions" then <<-EOS.undent
      Usage instructions for applications calling the sqlite3 API functions:

        In your application, call sqlite3_enable_load_extension(db,1) to
        allow loading external libraries.  Then load the library libsqlitefunctions
        using sqlite3_load_extension; the third argument should be 0.
        See https://www.sqlite.org/loadext.html.
        Select statements may now use these functions, as in
        SELECT cos(radians(inclination)) FROM satsum WHERE satnum = 25544;

      Usage instructions for the sqlite3 program:

        If the program is built so that loading extensions is permitted,
        the following will work:
         sqlite> SELECT load_extension('#{lib}/libsqlitefunctions.dylib');
         sqlite> select cos(radians(45));
         0.707106781186548
      EOS
    end
  end

  test do
    path = testpath/"school.sql"
    path.write <<-EOS.undent
      create table students (name text, age integer);
      insert into students (name, age) values ('Bob', 14);
      insert into students (name, age) values ('Sue', 12);
      insert into students (name, age) values ('Tim', 13);
      select name from students order by age asc;
    EOS

    names = `#{bin}/sqlite3 < #{path}`.strip.split("\n")
    assert_equal %w[Sue Tim Bob], names
    assert_equal 0, $?.exitstatus
  end
end
