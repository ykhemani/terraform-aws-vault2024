            <div id="space">&nbsp;</div>
            <div id="hr"><hr/></div>
            <div id="space">&nbsp;</div>

            <h2><i class="fa-solid fa-key"></i> Vault Encryption Key</h2>

              <!-- rotate encryption key -->
              <div id="rekform" class="bg-info-subtle text-dark rounded-3 p-3">
                <form>
                  <div class="form-group row fs-5 font-monospace mb-3">
                      <label for="audiourl" class="col-sm-4 col-form-label">Encryption Key:</label>
                      <div class="col-sm-4">
                          <input type="text" class="form-control" id="ban" name="ban" value="<?php echo VAULT_ENCRYPTION_KEY; ?>" disabled>
                      </div>
                  </div>
                  <div class="form-group row fs-5 font-monospace mb-3">
                      <label for="audiourl" class="col-sm-4 col-form-label">Encryption Key Version:</label>
                      <div class="col-sm-4">
                          <input type="text" class="form-control" id="ban" name="ban" value="<?php echo get_encryption_key_version(); ?>" disabled>
                      </div>
                  </div>
              </form>

              <form role="form" name="rekform" method="post">
                <input type="hidden" id="formname" name="formname" value="rek">
                <input type="hidden" id="rek" name="rek" value="1">
                  <div class="form-group row mb-3">
                      <div class="col-sm-4">
                        &nbsp;
                      </div>
                      <div class="col-sm-4">
                        <button type="submit" class="btn btn-info"><i class="fa-solid fa-rotate"></i> Rotate Encryption Key</button>
                      </div>
                  </div>
              </form>
            </div>
