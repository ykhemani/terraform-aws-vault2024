<?php
  require_once 'vendor/autoload.php';
  $faker = Faker\Factory::create();

  require_once('config.php');
  require_once('protect.php');

  include('_header.php');
  include('_nav.php');
?>

<div id="space">&nbsp;</div>

  <form role="form" name="reload" method="post">
  
  <h1>
    Advanced Data Protection Demo
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
          <label for="ssn" class="col-sm-4 col-form-label"><i class="fa-regular fa-address-card"></i> SSN:</label>
          <div class="col-sm-4">
              <input type="text" class="form-control" id="ssn" name="ssn" value="<?php echo $faker->ssn(); ?>">
          </div>
      </div>
      
      <div class="form-group row fs-5 font-monospace mb-3">
          <label for="ccn" class="col-sm-4 col-form-label"><i class="fa-regular fa-credit-card"></i> Credit Card Number:</label>
          <div class="col-sm-4">
              <input type="text" class="form-control" id="ccn" name="ccn" value="<?php echo $faker->creditCardNumber('Visa', true); ?>">
          </div>
      </div>

      <div class="form-group row fs-5 font-monospace mb-3">
        <label class="col-sm-4 col-form-label">Data Protection:</label>
        <div class="col-sm-4">
          <input class="form-check-input" type="radio" name="adp" id="adp-none" value="none">
          <label class="form-check-label" for="adp-none">None</label>
          <br/>
          <input class="form-check-input" type="radio" name="adp" id="adp-transit" value="transit">
          <label class="form-check-label" for="adp-transit">Transit</label>
          <br/>
          <input class="form-check-input" type="radio" name="adp" id="adp-fpe" value="fpe">
          <label class="form-check-label" for="adp-fpe">Format Preserving Encryption</label>
        </div>
      </div>

      <!-- <div class="form-group row fs-5 font-monospace mb-3">
          <label for="adp" class="col-sm-4 col-form-label">Data Protection:</label>
          <div class="col-sm-4">
              <select class="form-select" name="adp">
                <option value="plaintext"></option>
                <option value="transit">Encrypt</option>
                <option value="fpe">FPE</option>
                <option value="tokenize">Tokenize</option>
              </select>
          </div>
      </div> -->
      
      <div class="form-group row mb-3">
          <div class="col-sm-4">
              &nbsp;
          </div>
          <div class="col-sm-4">
              <button type="submit" class="btn btn-success">Submit</button>
          </div>
      </div>

      <div class="font-monospace mb-3 form-group">
        The <?php echo BRAND; ?> Secure Data Intake application is authorized to encrypt/encode data.
      </div>
    </div>
    </form>

    <div id="space">&nbsp;</div>
    <div id="hr"><hr/></div>
    <div id="space">&nbsp;</div>



<?php
  include('_footer.php');
?>