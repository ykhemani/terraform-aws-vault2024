{{ with secret "database/creds/mysql-web-role" }}
<?php
  // database connection
  define ('DBSERVER', getenv('MYSQL_HOST'));
  define ('DBUSER', '{{ .Data.username }}');
  define ('DBPASSWORD', '{{ .Data.password }}');
  define ('DB', getenv('MYSQL_DB_NAME'));
  define ('TABLE', getenv('MYSQL_DB_TABLE'));

  $mysqli = new mysqli(
    DBSERVER,
    DBUSER,
    DBPASSWORD,
    DB
  );

  if ($mysqli->connect_error) {
    die("Database connection failed: " . $mysqli->connect_error);
  };
?>
{{ end }}
