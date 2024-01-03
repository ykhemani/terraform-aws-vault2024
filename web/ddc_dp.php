<?php
  require_once 'vendor/autoload.php';
  $faker = Faker\Factory::create();

  require_once('config.php');
  require_once('protect.php');

  if (
    isset($_SERVER['HTTP_REFERER']) && 
    $_SERVER['HTTP_REFERER'] == SERVER . 'ddc_dp.php' && 
    isset($_POST['rek']) &&
    $_POST['rek'] == '1'
  )
  {
    $response = rek();
  };

  if (
    #isset($_SERVER['HTTP_REFERER']) && 
    #$_SERVER['HTTP_REFERER'] == SERVER . 'ddc_dp.php' && 
    isset($_POST['formname']) &&
    $_POST['formname'] == 'ddc'
  )
  {
    if (isset($_POST['ddc']))
    {
      if ($_POST['ddc'] == 1)
      {
        setcookie('ddc', 1, time() + (86400 * 30), '/');
        $ddc = 1;
      } else {
        setcookie('ddc', "", time() - 3600, '/');
        $ddc = 0;
      }
    } else {
      setcookie('ddc', "", time() - 3600, '/');
    }
  } elseif (isset($_COOKIE['ddc'])) {

    $ddc = $_COOKIE['ddc'];
  };

  if (isset($ddc) && ($ddc == 1)) {
    require_once('db-secure.php');
  } else {
    require_once('db.php');
  };

  if (isset($_SERVER['HTTP_REFERER']) && ($_SERVER['HTTP_REFERER'] == SERVER . 'ddc_dp.php') && isset($_REQUEST['edp']) && ($_REQUEST['edp'] == '1'))
  {
    $edp = 1;
  }
  else
  {
    $edp = 0;
  };

  if (isset($_SERVER['HTTP_REFERER']) && ($_SERVER['HTTP_REFERER'] == SERVER . 'ddc_dp.php') && isset($_REQUEST['name']) && ($_REQUEST['name'] != ''))
  {
    $name   = $mysqli->real_escape_string($_REQUEST['name']);
    $phone  = $mysqli->real_escape_string($_REQUEST['phone']);
    $email  = $mysqli->real_escape_string($_REQUEST['email']);
//    $dob    = $mysqli->real_escape_string($_REQUEST['dob']);
//    $ssn    = $mysqli->real_escape_string($_REQUEST['ssn']);
    $ccn    = $mysqli->real_escape_string($_REQUEST['ccn']);
    $expire = $mysqli->real_escape_string($_REQUEST['expire']);
//    $brn    = $mysqli->real_escape_string($_REQUEST['brn']);
//    $ban    = $mysqli->real_escape_string($_REQUEST['ban']);
    
    if (isset($_REQUEST['edp']) && ($_REQUEST['edp'] == '1')) {
//      $dob = encrypt($dob);
//      $ssn = encrypt($ssn);
      $ccn = encrypt($ccn);
    };
    
//    $sql = 'INSERT INTO ' . DB . '.' . TABLE . ' (name, phone, email, dob, ssn, ccn, expire, brn, ban) VALUES ';
//    $sql .= "('$name', '$phone', '$email', '$dob', '$ssn', '$ccn', '$expire', '$brn', '$ban')";

    $sql = 'INSERT INTO ' . DB . '.' . TABLE . ' (name, phone, email, ccn, expire) VALUES ';
    $sql .= "('$name', '$phone', '$email', '$ccn', '$expire')";

    if (!$mysqli -> query($sql)) {
      printf("%d Row inserted.\n", $mysqli->affected_rows);
    };
    
    if ($mysqli->error) {
      die($mysqli->error);
    };
  };
  
  // handle truncate table request
  if (isset($_SERVER['HTTP_REFERER']) && ($_SERVER['HTTP_REFERER'] == SERVER . 'ddc_dp.php') && isset($_POST['clear']) && ($_POST['clear'] == "1"))
  {
    $sql = 'TRUNCATE TABLE ' . DB . '.' . TABLE;
    
    if (!$mysqli -> query($sql)) {
      printf("%d Row inserted.\n", $mysqli->affected_rows);
    };
    
    if ($mysqli->error) {
      die($mysqli->error);
    };

  }

  include('_header.php');
  include('_nav.php');
?>
<div id="space">&nbsp;</div>

  <form role="form" name="reload" method="post">
  
  <h1>
    Dynamic Database Credential and Data Protection Demo
    <button class="btn btn-light" type="submit"><i class="fa-solid fa-rotate-right"></i></button>
  </h1>
  </form>
  
  <div id="space">&nbsp;</div>
  <div id="hr"><hr/></div>
  <div id="space">&nbsp;</div>

  <h2><?php echo BRAND; ?> Secure Data Intake Application</h2>
  <div id="space">&nbsp;</div>
  
<div id="form" class="bg-primary-subtle text-dark rounded-3 p-3">

  <div id="space">&nbsp;</div>
  <form role="form" name="load" method="post">

      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="name" class="col-sm-4 col-form-label">Name:</label>
          <div class="col-sm-4">
              <input type="text" class="form-control" id="name" name="name" value="<?php echo $faker->name(); ?>">
          </div>
      </div>
      
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="phone" class="col-sm-4 col-form-label"><i class="fa-solid fa-phone"></i> Telephone:</label>
          <div class="col-sm-4">
              <input type="tel" class="form-control" id="phone" name="phone" value="<?php echo $faker->phoneNumber(); ?>">
          </div>
      </div>
      
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="email" class="col-sm-4 col-form-label"><i class="fa-regular fa-envelope"></i> Email:</label>
          <div class="col-sm-4">
              <input type="email" class="form-control" id="email" name="email" value="<?php echo $faker->email(); ?>">
          </div>
      </div>
      
      <!--
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="dob" class="col-sm-4 col-form-label"><i class="fa-regular fa-calendar"></i> Date of Birth:</label>
          <div class="col-sm-4">
              <input type="text" class="form-control" id="dob" name="dob" value="<?php echo $faker->dateTimeBetween('-100 years', '-18 years')->format('m/d/Y'); ?>">
          </div>
      </div>
      -->

      <!--
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="ssn" class="col-sm-4 col-form-label"><i class="fa-regular fa-address-card"></i> SSN:</label>
          <div class="col-sm-4">
              <input type="text" class="form-control" id="ssn" name="ssn" value="<?php echo $faker->ssn(); ?>">
          </div>
      </div>
      -->
      
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="ccn" class="col-sm-4 col-form-label"><i class="fa-regular fa-credit-card"></i> Credit Card Number:</label>
          <div class="col-sm-4">
              <input type="text" class="form-control" id="ccn" name="ccn" value="<?php echo $faker->creditCardNumber('Visa', true); ?>">
          </div>
      </div>
      
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="expire" class="col-sm-4 col-form-label"><i class="fa-regular fa-calendar"></i> Expiration Date:</label>
          <div class="col-sm-4">
              <input type="text" class="form-control" id="expire" name="expire" value="<?php echo $faker->creditCardExpirationDateString(); ?>">
          </div>
      </div>
      
      <!--
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="brn" class="col-sm-4 col-form-label">Bank Routing Number:</label>
          <div class="col-sm-4">
              <input type="text" class="form-control" id="brn" name="brn" value="<?php echo $faker->bankAccountNumber(); ?>">
          </div>
      </div>
      -->
      
      <!--
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="ban" class="col-sm-4 col-form-label">Bank Account Number:</label>
          <div class="col-sm-4">
              <input type="text" class="form-control" id="ban" name="ban" value="<?php echo $faker->bankRoutingNumber(); ?>">
          </div>
      </div>
      -->
      
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="edp" class="col-sm-4 col-form-label">Enable Data Protection:</label>
          <div class="col-sm-4">
              <input type="checkbox" class="form-check-input" id="edp" name="edp" value="1" <?php if ($edp == 1) { echo 'checked'; }; ?>>
          </div>
      </div>
      
      <input type="hidden" id="ddc" name="ddc" value="<?php echo $ddc; ?>">

      <div class="form-group row mb-3">
          <div class="col-sm-4">
              &nbsp;
          </div>
          <div class="col-sm-4">
              <button type="submit" class="btn btn-success">Submit</button>
          </div>
      </div>

      <div class="font-monospace mb-3 form-group">
        The <?php echo BRAND; ?> Secure Data Intake application is authorized to encrypt data using the <?php echo VAULT_ENCRYPTION_KEY;?> encryption key.
        <br/>It is not authorized to decrypt data using this key.
      </div>
    </div>
    </form>

<?php
  // dynamic database credentials
  include('ddc.php');
  // rotate encryption key
  include('rek.php');
  // show raw data in database
  include('raw_data.php');
  // show data processor (unencrypted) view of data
  include('data_processor.php');
?>
<?php
  include('_footer.php');
?>
