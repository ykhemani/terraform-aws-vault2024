            <div id="space">&nbsp;</div>
            <div id="hr"><hr/></div>
            <div id="space">&nbsp;</div>
	    <h2><?php echo BRAND; ?> Data Storage View ( <i class="fa-solid fa-magnifying-glass"></i> Raw)</h2>
            <div id="space">&nbsp;</div>

	  <div id="form" class="bg-warning-subtle text-dark rounded-3 p-3">

            <div id="dataset-raw" class="table-responsive">
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
    
    <form role="form" name="clear" method="post">
      <input type="hidden" name="clear" value="1"/>
      <div class="form-group row mb-3">
          <div class="col-sm-4">
              &nbsp;
          </div>
          <div class="col-sm-4">
              <button type="submit" class="btn btn-danger"><i class="fa-solid fa-triangle-exclamation"></i> Truncate Table</button>
          </div>
      </div>
    </form>

    <div class="font-monospace mb-3 form-group">
      A view of the raw data in the demodb.pii table.
      <br/>A prefix of "vault" indicates that the value in the database is ciphertext rather than plain text.
    </div>
  </div>
