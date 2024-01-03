            <div id="space">&nbsp;</div>
            <div id="hr"><hr/></div>
            <div id="space">&nbsp;</div>

            <h2><i class="fa-solid fa-database"></i> Dynamic Database Credentials</h2>

              <!-- Dynamic Database Credentials (ddc) Selection Form -->
              <div id="ddcform" class="bg-success-subtle text-dark rounded-3 p-3">
              <form>
                <div class="form-group row fs-5 font-monospace mb-3">
                    <label for="audiourl" class="col-sm-4 col-form-label">Username:</label>
                    <div class="col-sm-4">
                        <input type="text" class="form-control" id="ban" name="ban" value="<?php echo DBUSER; ?>" disabled>
                    </div>
                </div>
                
                <div class="form-group row fs-5 font-monospace mb-3">
                    <label for="audiourl" class="col-sm-4 col-form-label">Password:</label>
                    <div class="col-sm-4">
                        <input type="text" class="form-control" id="ban" name="ban" value="<?php echo DBPASSWORD; ?>" disabled>
                    </div>
                </div>
              </form>
           
              <form role="form" name="ddcform" method="post">
                <div class="form-group row fs-5 font-monospace mb-3">
                    <label for="ddc" class="col-sm-4 col-form-label">Use Dynamic <i class="fa-solid fa-database"></i> Credentials:</label>
                    <div class="col-sm-4">
                        <input type="checkbox" class="form-check-input" id="ddc" name="ddc" value="1" <?php if (isset($ddc) && ($ddc == 1)) { echo 'checked'; } ?>>
                    </div>
                </div>
                
                <input type="hidden" id="formname" name="formname" value="ddc">

                <div class="form-group row mb-3">
                    <div class="col-sm-4">
                        &nbsp;
                    </div>
                    <div class="col-sm-4">
                        <button type="submit" class="btn btn-info">Update <i class="fa-solid fa-database"></i> Credential Settings</button>
                    </div>
                </div>
                </form>

                <div class="font-monospace mb-3 form-group">
                  The <?php echo BRAND; ?> can use static, hard-coded or dynamically generated credentials for accessing the database.
                </div>
            </div>
