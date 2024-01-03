            <div id="space">&nbsp;</div>
            <div id="hr"><hr/></div>
            <div id="space">&nbsp;</div>
	    <h2><?php echo BRAND; ?> Data Processor Application ( <i class="fa-solid fa-magnifying-glass"></i> Decrypted)</h2>
            <div id="space">&nbsp;</div>
            
	  <div id="form" class="bg-danger-subtle rounded-3 p-3">

            <div id="dataset-decrypted" class="table-responsive">
              <table class="table">
                <thead>
                  <tr>
                    <th scope="col">#</th>
                    <th scope="col">Name</th>
                    <th scope="col">Telephone</th>
                    <th scope="col">Email</th>
		    <!--
                    <th scope="col">Date of Birth</th>
                    <th scope="col">SSN</th>
		    -->
                    <th scope="col">Credit Card Number</th>
                    <th scope="col">Expiration Date</th>
		    <!--
                    <th scope="col">Bank Routing Number</th>
                    <th scope="col">Bank Account Number</th>
                    -->
                  </tr>
                </thead>
                <tbody>
<?php
  $sql = 'SELECT * from ' . DB . '.' . TABLE;
  $count = 0;
  if ($result = $mysqli->query($sql)) {
    while ($row = $result->fetch_assoc()) {
      $count++;
      
      $name   = $row['name'];
      $phone  = $row['phone'];
      $email  = $row['email'];
      //$dob    = $row['dob'];
      //$ssn    = $row['ssn'];
      $ccn    = $row['ccn'];
      $expire = $row['expire'];
      //$brn    = $row['brn'];
      //$ban    = $row['ban'];
      
      //if (preg_match('/^vault:/', $dob))
      //{
      //  $dob = decrypt($dob);
      //};
      
      //if (preg_match('/^vault:/', $ssn))
      //{
      //  $ssn = decrypt($ssn);
      //};
      
      if (preg_match('/^vault:/', $ccn))
      {
        $ccn = decrypt($ccn);
      };

      echo '<tr>';
      echo '<th scope="row">' . $row['id'] . '</th>';
      echo '<td>' . $name . '</td>';
      echo '<td>' . $phone . '</td>';
      echo '<td>' . $email . '</td>';
      //echo '<td>' . $dob . '</td>';
      //echo '<td>' . $ssn . '</td>';
      echo '<td>' . $ccn . '</td>';
      echo '<td>' . $expire . '</td>';
      //echo '<td>' . $brn . '</td>';
      //echo '<td>' . $ban . '</td>';
      echo '</tr>';
    };
  }
?>
                </tbody>
              </table>
    </div>
    <div class="font-monospace mb-3 form-group">
      The <?php echo BRAND; ?> Secure Data Processor application is authorized to decrypt data using the <?php echo VAULT_ENCRYPTION_KEY;?> encryption key.
      <br/>It is not authorized to encrypt data using this key.
    </div>

  </div>

